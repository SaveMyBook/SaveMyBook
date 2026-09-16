import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/auth_social.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/guards.dart';
import '../../widgets/state_views.dart';
import '../auth/social_sign_in.dart';
import 'admin_layout.dart';
import '../../i18n/strings.dart';

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final ApiService _api = ApiService();

  AuthSettingsBundle? _bundle;
  AuthSettings? _draft;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  bool get _dirty => _bundle != null && _draft != null && !_draft!.sameAs(_bundle!.settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchAuthSettings();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk && result.data != null) {
        _bundle = result.data;
        _draft = result.data!.settings;
      } else {
        _error = result.message;
      }
    });
  }

  void _update(AuthSettings next) {
    setState(() => _draft = next);
    HapticFeedback.selectionClick();
  }

  void _revert() {
    final bundle = _bundle;
    if (bundle == null) return;
    HapticFeedback.selectionClick();
    setState(() => _draft = bundle.settings);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;

    setState(() => _saving = true);
    final result = await _api.saveAuthSettings(draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.isOk && result.data != null) {
        _bundle = result.data;
        _draft = result.data!.settings;
      }
    });

    if (!result.isOk) {
      if (result.isCancelled) return;
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, result.message, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.signMethodSettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bundle = _bundle;
    final draft = _draft;

    return UnsavedGuard(
      isDirty: _dirty,
      message: S.signMethodSettingsUnsavedLeavingDiscards,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: S.signMethod, icon: Icons.login_rounded),
            Expanded(
              child: SwitchIn(
                child: _loading
                    ? const LoadingView.list()
                    : bundle == null || draft == null
                        ? RefreshableCenter(
                            onRefresh: _load,
                            child: ErrorView(message: _error, onRetry: _load),
                          )
                        : AdminLayout(
                            builder: (context, frame) => Column(
                              children: [
                                Expanded(
                                  child: ListView(
                                    padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 32), maxWidth: 900),
                                    children: [
                                      if (!bundle.migrationReady) ...[
                                        _notice(c, S.serverNotRunDatabaseUpdate014),
                                        const SizedBox(height: 12),
                                      ],
                                      FadeSlideIn(child: _masterCard(c, draft)),
                                      const SizedBox(height: 22),
                                      SectionHeading(title: S.signChannels),
                                      const SizedBox(height: 10),
                                      FadeSlideIn(index: 1, child: _channelCards(c, bundle, draft)),
                                    ],
                                  ),
                                ),
                                _saveBar(c, frame),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(AppColors c, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: c.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textPrimary))),
        ],
      ),
    );
  }

  Widget _masterCard(AppColors c, AuthSettings draft) {
    final on = draft.socialEnabled;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Motion.base,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (on ? c.accent : c.iconInactive).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.login_rounded, color: on ? c.accent : c.iconInactive),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.socialSmsSign,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  S.whenOffSignPageHidesThese,
                  style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeTrackColor: c.accent,
            onChanged: _saving ? null : (value) => _update(draft.copyWith(socialEnabled: value)),
          ),
        ],
      ),
    );
  }

  Widget _channelCards(AppColors c, AuthSettingsBundle bundle, AuthSettings draft) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        children: [
          for (final id in AuthProviders.ids) ...[
            if (id != AuthProviders.ids.first) Divider(color: c.divider, height: 1),
            _channelRow(c, bundle, draft, id),
          ],
        ],
      ),
    );
  }

  Widget _channelRow(AppColors c, AuthSettingsBundle bundle, AuthSettings draft, String id) {
    final configured = bundle.isConfigured(id);
    final channel = draft.channelOf(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 26, child: Center(child: ProviderGlyph(provider: id, size: 20))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            AuthProviders.labelOf(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                        ),
                        if (!configured) ...[
                          const SizedBox(width: 8),
                          StatusBadge(label: S.notConfigured, color: c.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.allowSigningLinkingWithMethod,
                      style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: channel.enabled && configured,
                activeTrackColor: c.accent,
                onChanged: !configured || _saving
                    ? null
                    : (value) => _update(draft.copyWith(id: id, channel: channel.copyWith(enabled: value))),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    configured ? S.allowCreatingNewAccountsWithMethod : S.serverNoCredentialsChannel,
                    style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: channel.signup && configured,
                  activeTrackColor: c.accent,
                  onChanged: !configured || _saving
                      ? null
                      : (value) => _update(draft.copyWith(id: id, channel: channel.copyWith(signup: value))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar(AppColors c, AdminFrame frame) {
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: !_dirty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: [
                  BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2)),
                ],
              ),
              padding: frame.inset(
                EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 10),
                maxWidth: 900,
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 20, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.unsavedChanges2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _revert,
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: Text(S.undo),
                  ),
                  const SizedBox(width: 4),
                  PrimaryButton(
                    label: S.actionSave,
                    icon: Icons.check_rounded,
                    expand: false,
                    height: 42,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }
}
