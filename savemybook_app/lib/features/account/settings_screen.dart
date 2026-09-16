import 'dart:io';

import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';
import 'package:flutter/services.dart';
import '../../services/app_permissions.dart';
import '../../services/biometric_service.dart';
import '../../services/home_preferences.dart';
import '../../services/theme_provider.dart';
import '../../utils/app_colors.dart';
import 'change_password_screen.dart';
import 'help_center_screen.dart';
import 'legal_doc_screen.dart';
import 'support_ticket_screen.dart';
import '../../widgets/app_header.dart';
import '../../widgets/biometric_icon.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import 'account_privacy_screen.dart';
import 'app_permissions_screen.dart';
import '../chat/blocked_users_screen.dart';
import '../security/security_center_screen.dart';
import '../../services/locale_provider.dart';
import '../../services/push_service.dart';
import '../../services/api_service.dart';
import '../../models/support.dart';
import '../../i18n/strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricAvailable = false;
  bool _togglingBiometric = false;
  String _biometricLabel = S.biometrics;

  bool _sendingTestPush = false;
  bool _clearingCache = false;
  bool get _isAdmin => ApiService.currentUser?.role == 'admin';
  NotificationSettings? _notificationSettings;
  bool _notificationLoadFailed = false;
  int _notificationRequest = 0;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadNotificationSettings();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final label = available ? await BiometricService.label() : S.biometrics;
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricLabel = label;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_togglingBiometric) return;
    setState(() => _togglingBiometric = true);
    try {
      if (value && !await BiometricService.authenticate(reason: S.verifyEnableQuickSign)) {
        return;
      }
      await BiometricService.setEnabled(value);
      if (!mounted) return;
      showAppSnackBar(context, value ? S.sign2(_biometricLabel) : S.quickSignTurnedOff);
    } finally {
      if (mounted) setState(() => _togglingBiometric = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (_notificationLoadFailed) setState(() => _notificationLoadFailed = false);
    final settings = await ApiService().fetchNotificationSettings();
    if (!mounted) return;
    setState(() {
      if (settings != null) _notificationSettings = settings;
      _notificationLoadFailed = settings == null && _notificationSettings == null;
    });
  }

  Future<void> _toggleNotification(String key, bool value) async {
    final previous = _notificationSettings;
    final request = ++_notificationRequest;
    setState(() => _notificationSettings = NotificationSettings(
          order: key == 'order' ? value : previous?.order ?? true,
          message: key == 'message' ? value : previous?.message ?? true,
          promotion: key == 'promotion' ? value : previous?.promotion ?? true,
        ));
    final saved = await ApiService().updateNotificationSettings({key: value});
    if (!mounted || request != _notificationRequest) return;
    if (saved == null) {
      setState(() => _notificationSettings = previous);
      showAppSnackBar(context, S.updateFailed2, isError: true);
    } else {
      setState(() => _notificationSettings = saved);
    }
  }

  Future<void> _sendTestPush() async {
    if (_sendingTestPush) return;
    setState(() => _sendingTestPush = true);
    final (message, isError, needsSettings) = await PushService.sendTest();
    if (!mounted) return;
    setState(() => _sendingTestPush = false);

    if (needsSettings) {
      final go = await showConfirmDialog(
        context,
        title: S.notificationsTurnedOff,
        message: message,
        confirmLabel: S.openSettings,
      );
      if (go) await PushService.openSystemSettings();
      return;
    }
    showAppSnackBar(context, message, isError: isError);
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    var freed = 0;
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      freed += imageCache.currentSizeBytes;
      imageCache.clear();
      imageCache.clearLiveImages();

      final temp = Directory.systemTemp;
      if (await temp.exists()) {
        await for (final entity in temp.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          final ours = name.startsWith('crop_') || name.startsWith('savemybook');
          if (!ours) continue;
          try {
            freed += await entity.length();
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _clearingCache = false);
    final mb = freed / (1024 * 1024);
    showAppSnackBar(context, mb >= 0.1 ? S.clearedP0MbCache(mb.toStringAsFixed(1)) : S.cacheCleared);
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.settings, icon: Icons.settings_outlined),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = context.screenSize == ScreenSize.expanded && constraints.maxWidth >= 840;
                var index = 0;
                final sections = [
                  _section(c, index++, S.appearance2, _buildAppearanceCard(c)),
                  _section(c, index++, S.faqCatAccount, _buildAccountCard(c)),
                  _section(c, index++, S.alerts, _buildPushCard(c)),
                  _section(c, index++, S.helpSupport, _buildSupportCard(c)),
                  _section(c, index++, S.storage, _buildStorageCard(c)),
                ];

                return ListView(
                  padding: responsiveListPadding(
                    constraints,
                    maxWidth: twoColumn ? Breakpoints.listMaxWidth : Breakpoints.formMaxWidth,
                    horizontal: 20,
                    top: 20,
                    bottom: 40,
                  ),
                  children: twoColumn
                      ? [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections.sublist(0, 2))),
                              const SizedBox(width: 20),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections.sublist(2))),
                            ],
                          ),
                        ]
                      : sections,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors c, int index, String title, Widget card) {
    return FadeSlideIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
            ),
            AppCard(padding: EdgeInsets.zero, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: card)),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColors c) => Divider(height: 1, thickness: 1, indent: 56, color: c.divider);

  Widget _chevron(AppColors c) => Icon(Icons.chevron_right_rounded, size: 22, color: c.iconInactive);

  Widget _row(
    AppColors c, {
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _SettingsRow(leading: leading, title: title, subtitle: subtitle, trailing: trailing ?? _chevron(c), onTap: onTap);
  }

  Widget _switchRow(
    AppColors c, {
    required Widget leading,
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return _SettingsRow(
      leading: leading,
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: Switch.adaptive(value: value, activeThumbColor: c.accent, onChanged: onChanged),
    );
  }

  Widget _icon(AppColors c, IconData icon) => Icon(icon, size: 22, color: c.textPrimary);

  Widget _buildAppearanceCard(AppColors c) {
    return Column(
      children: [
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeProvider,
          builder: (context, mode, _) => _row(
            c,
            leading: SwitchIn(
              duration: Motion.micro,
              child: Icon(_themeIcon(mode), key: ValueKey(mode), size: 22, color: c.textPrimary),
            ),
            title: S.appearance,
            subtitle: _themeLabel(mode),
            onTap: () => _pickTheme(mode),
          ),
        ),
        _divider(c),
        ValueListenableBuilder<AppPalette>(
          valueListenable: paletteProvider,
          builder: (context, palette, _) => _row(
            c,
            leading: _PaletteDot(palette: palette, size: 22),
            title: S.themeColour,
            subtitle: _paletteName(palette),
            onTap: _pickPalette,
          ),
        ),
        _divider(c),
        ValueListenableBuilder<Locale?>(
          valueListenable: localeProvider,
          builder: (context, locale, _) => _row(
            c,
            leading: _icon(c, Icons.language_rounded),
            title: S.language,
            subtitle: locale == null ? S.languageSystem : LocaleProvider.nameOf(locale),
            onTap: () => _pickLanguage(locale),
          ),
        ),
        _divider(c),
        ValueListenableBuilder<bool>(
          valueListenable: HomePreferences.showDiscovery,
          builder: (context, show, _) => _switchRow(
            c,
            leading: _icon(c, Icons.auto_awesome_outlined),
            title: S.homeRecommendations,
            value: show,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              HomePreferences.setShowDiscovery(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard(AppColors c) {
    final rows = <Widget>[
      _row(
        c,
        leading: _icon(c, Icons.verified_user_outlined),
        title: S.accountSecurity,
        onTap: () => _push(const SecurityCenterScreen()),
      ),
      _row(
        c,
        leading: _icon(c, Icons.key_outlined),
        title: S.changePassword,
        onTap: () => _push(const ChangePasswordScreen()),
      ),
      if (_biometricAvailable)
        _switchRow(
          c,
          leading: _biometricLabel == 'Face ID' ? FaceIdIcon(size: 22, color: c.textPrimary) : _icon(c, Icons.fingerprint_rounded),
          title: S.sign3(_biometricLabel),
          value: BiometricService.isEnabled,
          onChanged: _togglingBiometric ? null : _toggleBiometric,
        ),
      if (AppPermissions.isSupportedPlatform)
        _row(
          c,
          leading: _icon(c, Icons.app_settings_alt_outlined),
          title: S.appPermissions,
          onTap: () => _push(const AppPermissionsScreen()),
        ),
      _row(
        c,
        leading: _icon(c, Icons.shield_outlined),
        title: S.account,
        onTap: () => _push(const AccountPrivacyScreen()),
      ),
      _row(
        c,
        leading: _icon(c, Icons.block_rounded),
        title: S.blockedUsers,
        onTap: () => _push(const BlockedUsersScreen()),
      ),
      _row(
        c,
        leading: _icon(c, Icons.privacy_tip_outlined),
        title: S.privacyPolicy,
        onTap: () => _push(LegalDocScreen(docKey: 'privacy', fallbackTitle: S.privacyPolicy, icon: Icons.privacy_tip_outlined)),
      ),
      _row(
        c,
        leading: _icon(c, Icons.description_outlined),
        title: S.termsService,
        onTap: () => _push(LegalDocScreen(docKey: 'terms', fallbackTitle: S.termsService)),
      ),
    ];
    return _joined(c, rows);
  }

  Widget _joined(AppColors c, List<Widget> rows) {
    return Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) _divider(c),
          row,
        ],
      ],
    );
  }

  Widget _buildSupportCard(AppColors c) {
    return _joined(c, [
      _row(c, leading: _icon(c, Icons.quiz_outlined), title: S.helpCentre, onTap: () => _push(const HelpCenterScreen())),
      _row(c, leading: _icon(c, Icons.support_agent_rounded), title: S.contactUs, onTap: () => _push(const SupportTicketScreen())),
      _row(
        c,
        leading: _icon(c, Icons.info_outline_rounded),
        title: S.aboutSavemybook,
        onTap: () => _push(LegalDocScreen(docKey: 'about', fallbackTitle: S.aboutUs, icon: Icons.info_outline_rounded)),
      ),
    ]);
  }

  Widget _buildStorageCard(AppColors c) {
    return _row(
      c,
      leading: _icon(c, Icons.cleaning_services_outlined),
      title: S.clearCache,
      trailing: _clearingCache
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
          : _chevron(c),
      onTap: _clearingCache ? null : _clearCache,
    );
  }

  Widget _buildPushCard(AppColors c) {
    final settings = _notificationSettings;

    final rows = <Widget>[
      if (_isAdmin)
        _row(
          c,
          leading: _icon(c, Icons.notifications_active_outlined),
          title: S.sendTestNotification,
          subtitle: S.arrives10SecondsGoHomeScreen,
          trailing: SwitchIn(
            duration: Motion.micro,
            child: _sendingTestPush
                ? SizedBox(key: const ValueKey('sending'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                : Icon(Icons.send_rounded, key: const ValueKey('send'), size: 20, color: c.accent),
          ),
          onTap: _sendingTestPush ? null : _sendTestPush,
        ),
      if (_notificationLoadFailed)
        _row(
          c,
          leading: Icon(Icons.cloud_off_rounded, size: 22, color: c.warning),
          title: S.couldNotLoadNotificationSettings,
          trailing: Text(S.retry, style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
          onTap: _loadNotificationSettings,
        ),
      for (final item in [
        (key: 'order', icon: Icons.receipt_long_outlined, title: S.orderProgress),
        (key: 'message', icon: Icons.chat_bubble_outline_rounded, title: S.chatMessages),
        (key: 'promotion', icon: Icons.local_offer_outlined, title: S.promotions2),
      ])
        _switchRow(
          c,
          leading: _icon(c, item.icon),
          title: item.title,
          value: switch (item.key) {
            'order' => settings?.order ?? true,
            'message' => settings?.message ?? true,
            _ => settings?.promotion ?? true,
          },
          onChanged: settings == null ? null : (v) => _toggleNotification(item.key, v),
        ),
      _row(
        c,
        leading: _icon(c, Icons.tune_rounded),
        title: S.systemNotificationSettings,
        onTap: PushService.openSystemSettings,
      ),
    ];

    return Column(
      children: [
        _joined(c, rows),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(color: c.cardAlt, border: Border(top: BorderSide(color: c.divider))),
          child: Text(
            S.supportRepliesPasswordResetsPolicyUpdates,
            style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
          ),
        ),
      ],
    );
  }

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => S.appearanceLight,
        ThemeMode.dark => S.appearanceDark,
        ThemeMode.system => S.appearanceSystem,
      };

  Future<void> _pickTheme(ThemeMode current) async {
    final picked = await showOptionSheet<ThemeMode>(
      context,
      title: S.appearance,
      options: [
        for (final mode in ThemeMode.values)
          SheetOption(
            value: mode,
            label: _themeLabel(mode),
            icon: _themeIcon(mode),
            selected: mode == current,
          ),
      ],
    );
    if (picked != null) await themeProvider.setMode(picked);
  }

  static String _paletteName(AppPalette palette) {
    switch (palette.id) {
      case 'forest':
        return S.forestGreen;
      case 'ocean':
        return S.oceanBlue;
      case 'lavender':
        return S.lavender;
      case 'terracotta':
        return S.terracotta;
      case 'amber':
        return S.amber;
      case 'rose':
        return S.rose;
      case 'graphite':
        return S.graphite;
      default:
        return S.mistBlue;
    }
  }

  Future<void> _pickPalette() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ValueListenableBuilder<AppPalette>(
        valueListenable: paletteProvider,
        builder: (context, current, _) {
          final c = AppColors.of(context);
          return Container(
            decoration: BoxDecoration(color: c.sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    Text(S.themeColour, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 360 ? 4 : 3;
                        const spacing = 12.0;
                        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: 16,
                          children: [
                            for (final palette in AppPalette.all)
                              SizedBox(
                                width: width,
                                child: PressableScale(
                                  scale: 0.94,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    paletteProvider.select(palette);
                                  },
                                  child: Column(
                                    children: [
                                      AnimatedContainer(
                                        duration: Motion.base,
                                        curve: Motion.standard,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: palette.id == current.id ? palette.primary : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: _PaletteDot(palette: palette, size: 48, selected: palette.id == current.id),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _paletteName(palette),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: palette.id == current.id ? FontWeight.bold : FontWeight.w500,
                                          color: palette.id == current.id ? c.textPrimary : c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(S.completed, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickLanguage(Locale? current) async {
    final picked = await showOptionSheet<int>(
      context,
      title: S.language,
      options: [
        SheetOption(
          value: -1,
          label: S.languageSystem,
          icon: Icons.brightness_auto_rounded,
          selected: current == null,
        ),
        for (var i = 0; i < LocaleProvider.supported.length; i++)
          SheetOption(
            value: i,
            label: LocaleProvider.nameOf(LocaleProvider.supported[i]),
            selected: current != null &&
                LocaleProvider.tagOf(current) ==
                    LocaleProvider.tagOf(LocaleProvider.supported[i]),
          ),
      ],
    );
    if (picked == null) return;
    await localeProvider.setLocale(picked < 0 ? null : LocaleProvider.supported[picked]);
  }
}

class _SettingsRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({required this.leading, required this.title, this.subtitle, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(width: 24, child: Center(child: leading)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final AppPalette palette;
  final double size;
  final bool selected;

  const _PaletteDot({required this.palette, required this.size, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primaryDark, palette.primary],
        ),
      ),
      child: selected ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.5) : null,
    );
  }
}
