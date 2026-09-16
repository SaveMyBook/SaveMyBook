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

/// 帳號安全的「通行密鑰」：列出已註冊的裝置，提供新增與刪除。
class PasskeysCard extends StatefulWidget {
  /// 新增或刪除後通知外層重新整理安全狀態（身分驗證的預設方式會跟著改變）。
  final VoidCallback? onChanged;

  /// 測試用：直接帶入資料，不再呼叫伺服器。
  final List<PasskeyItem>? initialItems;

  const PasskeysCard({super.key, this.onChanged, this.initialItems});

  @override
  State<PasskeysCard> createState() => _PasskeysCardState();
}

class _PasskeysCardState extends State<PasskeysCard> {
  final ApiService _api = ApiService();

  late List<PasskeyItem> _items = widget.initialItems ?? const [];
  late bool _loading = widget.initialItems == null;
  String? _error;
  bool _adding = false;
  String? _deleting;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchPasskeys();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk) {
        _items = result.data!;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _add() async {
    if (_adding || _deleting != null) return;
    final first = _items.isEmpty;
    setState(() => _adding = true);
    final result = await PasskeyService.register(context);
    if (!mounted) return;
    setState(() => _adding = false);

    if (!result.isOk) {
      if (!result.isCancelled) showAppSnackBar(context, result.message, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _items = result.data!);
    widget.onChanged?.call();

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

  Future<void> _delete(PasskeyItem item) async {
    if (_adding || _deleting != null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.deletePasskey,
      message: S.noLongerAbleSignVerifyIdentity,
      confirmLabel: S.actionDelete,
      isDestructive: true,
      icon: Icons.key_off_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = item.passkeyId);
    final result = await _api.deletePasskey(item.passkeyId);
    if (!mounted) return;
    setState(() => _deleting = null);

    if (!result.isOk) {
      if (!result.isCancelled) showAppSnackBar(context, result.message, isError: true);
      return;
    }
    setState(() => _items = result.data!);
    showAppSnackBar(context, S.passkeyDeleted);
    widget.onChanged?.call();
  }

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

    if (_error != null) {
      return AppCard(child: ErrorView(message: _error, onRetry: _load));
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
            const SizedBox(height: 12),
          ],
          SecondaryButton(
            label: S.addPasskey,
            icon: Icons.add_rounded,
            height: 44,
            isLoading: _adding,
            onPressed: _deleting != null ? null : _add,
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, PasskeyItem item) {
    final created = formatDate(item.createdAt);
    final lastUsed = item.lastUsedAt == null ? S.notUsedYet : S.lastUsedFormatdateItemLastusedat(formatDate(item.lastUsedAt));
    final subtitle = [if (created.isNotEmpty) S.createdCreated(created), lastUsed].join('　');

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(item.backedUp ? Icons.cloud_done_outlined : Icons.phone_iphone_rounded, size: 19, color: c.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (item.deviceLabel?.isNotEmpty ?? false) ? item.deviceLabel! : S.passkeys,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SmallActionButton(
          label: S.actionDelete,
          color: c.danger,
          isLoading: _deleting == item.passkeyId,
          onTap: _deleting != null || _adding ? null : () => _delete(item),
        ),
      ],
    );
  }
}
