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

  /// 展開中的渠道；預設全部收合，一眼只看得到狀態。
  final Set<String> _expanded = {};

  bool get _dirty => _bundle != null && _draft != null && !_draft!.sameAs(_bundle!.settings);

  // 憑證缺少時要指出伺服器該補哪一組環境變數，管理員才知道找誰處理。
  static String _envVarsOf(String id) => switch (id) {
        AuthProviders.line => 'LINE_CHANNEL_ID、LINE_CHANNEL_SECRET',
        AuthProviders.discord => 'DISCORD_CLIENT_ID、DISCORD_CLIENT_SECRET',
        _ => 'FIREBASE_PROJECT_ID / FCM_SERVICE_ACCOUNT_FILE',
      };

  void _toggleExpanded(String id) {
    HapticFeedback.selectionClick();
    setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id));
  }

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
                                      FadeSlideIn(child: _masterCard(c, draft)),
                                      const SizedBox(height: 22),
                                      SectionHeading(title: S.signChannels),
                                      const SizedBox(height: 10),
                                      _channelGrid(c, bundle, draft, frame),
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

  Widget _masterCard(AppColors c, AuthSettings draft) {
    final on = draft.socialEnabled;
    final total = AuthProviders.ids.length;
    final active = AuthProviders.ids
        .where((id) => (_bundle?.isConfigured(id) ?? false) && draft.channelOf(id).enabled)
        .length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: Motion.base,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (on ? c.accent : c.iconInactive).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
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
                      on ? S.p1P0MethodsEnabled(total, active) : S.masterSwitchOffSoEveryMethod,
                      style: TextStyle(fontSize: 12.5, color: on ? c.textSecondary : c.warning),
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
          const SizedBox(height: 10),
          Text(
            S.whenOffSignPageHidesThese,
            style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _channelGrid(AppColors c, AuthSettingsBundle bundle, AuthSettings draft, AdminFrame frame) {
    final cards = [
      for (final (i, id) in AuthProviders.ids.indexed)
        FadeSlideIn(index: i + 1, child: _channelCard(c, bundle, draft, id)),
    ];

    if (!frame.isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            card,
          ],
        ],
      );
    }

    // 寬螢幕分兩欄；奇數張時左欄多一張，右欄不會留下半張卡的空洞。
    final split = (cards.length + 1) ~/ 2;
    return AdminColumns(
      spacing: 12,
      columns: [cards.sublist(0, split), cards.sublist(split)],
    );
  }

  Widget _channelCard(AppColors c, AuthSettingsBundle bundle, AuthSettings draft, String id) {
    final configured = bundle.isConfigured(id);
    final channel = draft.channelOf(id);
    final on = configured && channel.enabled;
    final expanded = _expanded.contains(id);

    final (label, tone) = !configured
        ? (S.notConfigured, c.warning)
        : on
            ? (S.on, c.success)
            : (S.disabled, c.iconInactive);

    return Opacity(
      opacity: configured ? 1 : 0.55,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(expanded ? 0 : 16),
              ),
              onTap: configured ? () => _toggleExpanded(id) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ProviderGlyph.colorOf(id, c).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: ProviderGlyph(provider: id, size: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthProviders.labelOf(id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            configured && channel.signup ? S.signLinkingDirectSignUpAllowed : S.allowSigningLinkingWithMethod,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(label: label, color: tone),
                    if (configured)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: Motion.base,
                        child: Icon(Icons.expand_more_rounded, size: 20, color: c.textHint),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: !configured
                  ? _credentialHint(c, id)
                  : expanded
                      ? _channelOptions(c, draft, id, channel)
                      : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialHint(AppColors c, String id) {
    final vars = _envVarsOf(id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_off_rounded, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.credentialsNotSetPleaseConfigureP0(vars),
              style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelOptions(AppColors c, AuthSettings draft, String id, AuthChannelSetting channel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: c.divider, height: 1),
        _option(
          c,
          title: S.allowSigningLinkingWithMethod,
          subtitle: S.whenOffMethodHiddenFromSign,
          value: channel.enabled,
          onChanged: (value) => _update(draft.copyWith(id: id, channel: channel.copyWith(enabled: value))),
        ),
        Divider(color: c.divider, height: 1, indent: 16, endIndent: 16),
        _option(
          c,
          title: S.allowCreatingNewAccountsWithMethod,
          subtitle: S.whenOffOnlyAccountsAlreadyLinked,
          value: channel.signup,
          enabled: channel.enabled,
          onChanged: (value) => _update(draft.copyWith(id: id, channel: channel.copyWith(signup: value))),
        ),
      ],
    );
  }

  Widget _option(
    AppColors c, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, height: 1.4, color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              activeTrackColor: c.accent,
              onChanged: !enabled || _saving ? null : onChanged,
            ),
          ],
        ),
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
