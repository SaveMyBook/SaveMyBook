import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/passkey.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/passkey_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

enum _RowAction { rename, delete }

class PasskeysCard extends StatefulWidget {
  final VoidCallback? onChanged;

  final List<PasskeyItem>? initialItems;

  final int refreshTick;

  const PasskeysCard({super.key, this.onChanged, this.initialItems, this.refreshTick = 0});

  static String? authenticatorName(String? id) => switch (id) {
        'icloud_keychain' => S.icloudKeychain,
        'google_password_manager' => S.googlePasswordManager,
        'samsung_pass' => 'Samsung Pass',
        '1password' => '1Password',
        'bitwarden' => 'Bitwarden',
        'dashlane' => 'Dashlane',
        'chrome_mac' => 'Chrome',
        'windows_hello' => 'Windows Hello',
        _ => null,
      };

  static String syncSummary(PasskeyItem item) {
    final name = authenticatorName(item.authenticator);
    final sync = item.backedUp ? S.synced : S.notSynced;
    return name == null ? sync : '$name・$sync';
  }

  static String alreadyRegisteredMessage() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS =>
          S.passkeySavedIcloudKeychainWorksEvery,
        TargetPlatform.android =>
          S.passkeySavedGooglePasswordManagerWorks,
        _ => S.passkeySavedDeviceSPasswordManager,
      };

  @override
  State<PasskeysCard> createState() => _PasskeysCardState();
}

class _PasskeysCardState extends State<PasskeysCard> {
  final ApiService _api = ApiService();

  late List<PasskeyItem> _items = widget.initialItems ?? const [];
  late bool _loading = widget.initialItems == null;
  String? _loadError;
  String? _actionError;
  bool _adding = false;
  String? _busyId;

  bool get _busy => _adding || _busyId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems == null) _load();
  }

  @override
  void didUpdateWidget(covariant PasskeysCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTick != oldWidget.refreshTick && widget.initialItems == null && !_busy) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _loadError = null;
    });
    final result = await _api.fetchPasskeys();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk) {
        _items = result.data!;
      } else if (!silent || _items.isEmpty) {
        _loadError = result.message;
      }
    });
  }

  void _apply(List<PasskeyItem> items) {
    setState(() {
      _items = items;
      _actionError = null;
    });
    widget.onChanged?.call();
  }

  Future<void> _add() async {
    if (_busy) return;
    final first = _items.isEmpty;
    setState(() {
      _adding = true;
      _actionError = null;
    });
    PasskeyOutcome<List<PasskeyItem>> result;
    try {
      result = await PasskeyService.register(context);
    } catch (_) {
      result = PasskeyOutcome.fail('UNKNOWN', S.somethingWentWrongPleaseTryAgain);
    }
    if (!mounted) return;
    setState(() => _adding = false);

    if (result.isCancelled) return;
    if (result.isAlreadyRegistered) {
      if (result.code == 'PASSKEY_ALREADY_REGISTERED') unawaited(_load(silent: true));
      await _explainAlreadyRegistered();
      return;
    }
    if (!result.isOk) {
      setState(() => _actionError = result.message);
      return;
    }

    HapticFeedback.mediumImpact();
    _apply(result.data!);
    if (!first) {
      showAppSnackBar(context, S.passkeyAdded);
      return;
    }
    final label = await BiometricService.isAvailable() ? await BiometricService.label() : S.screenLock;
    if (!mounted) return;
    await showConfirmDialog(
      context,
      title: S.passkeyAdded,
      message: S.fromNowCanSignVerifyIdentity(label),
      confirmLabel: S.got,
      icon: Icons.key_rounded,
    );
  }

  Future<void> _explainAlreadyRegistered() async {
    final retry = await showConfirmDialog(
      context,
      title: S.alreadyPasskey,
      message: PasskeysCard.alreadyRegisteredMessage(),
      confirmLabel: S.addAgain,
      cancelLabel: S.got,
      icon: Icons.cloud_done_outlined,
    );
    if (retry && mounted) await _add();
  }

  Future<void> _openActions(PasskeyItem item) async {
    if (_busy) return;
    final action = await showOptionSheet<_RowAction>(
      context,
      title: _titleOf(item),
      subtitle: PasskeysCard.syncSummary(item),
      options: [
        SheetOption(value: _RowAction.rename, label: S.rename, icon: Icons.edit_outlined),
        SheetOption(
          value: _RowAction.delete,
          label: S.deletePasskey,
          icon: Icons.delete_outline_rounded,
          color: AppColors.of(context).danger,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _RowAction.rename:
        await _rename(item);
      case _RowAction.delete:
        await _delete(item);
      case null:
        break;
    }
  }

  Future<void> _rename(PasskeyItem item) async {
    final label = await showTextInputDialog(
      context,
      title: S.rename,
      initialValue: item.deviceLabel ?? '',
      maxLength: 50,
      confirmLabel: S.actionSave,
      validator: (value) => value.trim().isEmpty ? S.enterName : null,
    );
    final trimmed = label?.trim() ?? '';
    if (!mounted || trimmed.isEmpty || trimmed == item.deviceLabel) return;

    setState(() => _busyId = item.passkeyId);
    final result = await PasskeyService.rename(item.passkeyId, trimmed);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (!result.isOk) {
      if (!result.isCancelled) setState(() => _actionError = result.message);
      return;
    }
    _apply(result.data!);
  }

  Future<void> _delete(PasskeyItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.deletePasskey,
      message: S.noLongerAbleSignVerifyIdentity,
      confirmLabel: S.actionDelete,
      isDestructive: true,
      icon: Icons.key_off_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyId = item.passkeyId;
      _actionError = null;
    });
    final result = await _api.deletePasskey(item.passkeyId);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (!result.isOk) {
      if (result.isCancelled) return;
      setState(() => _actionError = result.message);
      unawaited(_load(silent: true));
      return;
    }
    _apply(result.data!);
    showAppSnackBar(context, S.passkeyDeleted);
  }

  String _titleOf(PasskeyItem item) => (item.deviceLabel?.isNotEmpty ?? false) ? item.deviceLabel! : S.passkeys;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_loading) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
        ),
      );
    }

    if (_loadError != null) {
      return AppCard(child: ErrorView(message: _loadError, onRetry: _load));
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.key_rounded, size: 22, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.signVerifyIdentityWithFaceId,
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in _items) ...[
            _row(c, item),
            const SizedBox(height: 10),
          ],
          if (_actionError != null) ...[
            _alert(c, _actionError!),
            const SizedBox(height: 10),
          ],
          SecondaryButton(
            label: S.addPasskey,
            icon: Icons.add_rounded,
            height: 44,
            isLoading: _adding,
            onPressed: _busyId != null ? null : _add,
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, PasskeyItem item) {
    final created = formatDate(item.createdAt);
    final lastUsed = item.lastUsedAt == null ? S.notUsedYet : S.lastUsedFormatdateItemLastusedat(formatDate(item.lastUsedAt));
    final dates = [if (created.isNotEmpty) S.createdCreated(created), lastUsed].join('　');
    final busy = _busyId == item.passkeyId;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _busy ? null : () => _openActions(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(item.backedUp ? Icons.cloud_done_outlined : Icons.phone_iphone_rounded, size: 19, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PasskeysCard.syncSummary(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.35, color: item.backedUp ? c.success : c.textSecondary),
                  ),
                  Text(
                    dates,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              height: 40,
              child: busy
                  ? Center(
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                    )
                  : IconButton(
                      tooltip: S.moreOptions,
                      icon: Icon(Icons.more_horiz_rounded, color: c.iconInactive),
                      onPressed: _busy ? null : () => _openActions(item),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alert(AppColors c, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, height: 1.5, color: c.danger))),
        ],
      ),
    );
  }
}
