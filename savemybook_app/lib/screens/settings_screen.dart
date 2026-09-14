import 'dart:io';

import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/theme_provider.dart';
import '../utils/app_colors.dart';
import 'change_password_screen.dart';
import 'help_center_screen.dart';
import 'legal_doc_screen.dart';
import 'support_ticket_screen.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/biometric_icon.dart';
import '../widgets/state_views.dart';
import '../utils/motion.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import 'account_privacy_screen.dart';
import 'security/security_center_screen.dart';
import '../services/locale_provider.dart';
import '../services/push_service.dart';
import '../services/api_service.dart';
import '../models/support.dart';
import '../i18n/strings.dart';

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
    var index = 0;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.settings, icon: Icons.settings_outlined),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _section(c, index++, S.appearance2, _buildAppearanceCard(c)),
                _section(c, index++, S.faqCatAccount, _buildAccountCard(c)),
                _section(c, index++, S.alerts, _buildPushCard(c)),
                _section(c, index++, S.helpSupport, _buildSupportCard(c)),
                _section(c, index++, S.storage, _buildStorageCard(c)),
              ],
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

  Widget _divider(AppColors c) => Divider(height: 1, indent: 56, color: c.divider);

  Widget _buildAppearanceCard(AppColors c) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeProvider,
            builder: (context, mode, _) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: SwitchIn(
                duration: Motion.micro,
                child: Icon(_themeIcon(mode), key: ValueKey(mode), color: c.textPrimary),
              ),
              title: Text(S.appearance, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              subtitle: Text(_themeLabel(mode), style: TextStyle(fontSize: 12, color: c.textSecondary)),
              trailing: Icon(Icons.chevron_right_rounded, color: c.iconInactive),
              onTap: () => _pickTheme(mode),
            ),
          ),
          _divider(c),
          ValueListenableBuilder<Locale?>(
            valueListenable: localeProvider,
            builder: (context, locale, _) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(Icons.language_rounded, color: c.textPrimary),
              title: Text(S.language, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              subtitle: Text(
                locale == null ? S.languageSystem : LocaleProvider.nameOf(locale),
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: c.iconInactive),
              onTap: () => _pickLanguage(locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AppColors c) {
    return Column(
      children: [
        AppMenuItem(
          icon: Icons.verified_user_outlined,
          iconColor: c.textPrimary,
          title: S.accountSecurity,
          subtitle: S.paymentPinBiometricPaymentDevices,
          onTap: () => _push(const SecurityCenterScreen()),
        ),
        AppMenuItem(
          icon: Icons.key_outlined,
          iconColor: c.textPrimary,
          title: S.changePassword,
          onTap: () => _push(const ChangePasswordScreen()),
        ),
        if (_biometricAvailable)
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: _biometricLabel == 'Face ID'
                  ? FaceIdIcon(size: 22, color: c.textPrimary)
                  : Icon(Icons.fingerprint_rounded, color: c.textPrimary),
              title: Text(
                S.sign3(_biometricLabel),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              subtitle: Text(
                S.unlockWithWhenOpenApp(_biometricLabel),
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              activeThumbColor: c.accent,
              value: BiometricService.isEnabled,
              onChanged: _togglingBiometric ? null : _toggleBiometric,
            ),
          ),
        if (_biometricAvailable) _divider(c),
        AppMenuItem(
          icon: Icons.shield_outlined,
          iconColor: c.textPrimary,
          title: S.account,
          onTap: () => _push(const AccountPrivacyScreen()),
        ),
        AppMenuItem(
          icon: Icons.privacy_tip_outlined,
          iconColor: c.textPrimary,
          title: S.privacyPolicy,
          onTap: () => _push(LegalDocScreen(
            docKey: 'privacy',
            fallbackTitle: S.privacyPolicy,
            icon: Icons.privacy_tip_outlined,
          )),
        ),
        AppMenuItem(
          icon: Icons.description_outlined,
          iconColor: c.textPrimary,
          title: S.termsService,
          isLast: true,
          onTap: () => _push(LegalDocScreen(docKey: 'terms', fallbackTitle: S.termsService)),
        ),
      ],
    );
  }

  Widget _buildSupportCard(AppColors c) {
    return Column(
      children: [
        AppMenuItem(
          icon: Icons.quiz_outlined,
          iconColor: c.textPrimary,
          title: S.helpCentre,
          onTap: () => _push(const HelpCenterScreen()),
        ),
        AppMenuItem(
          icon: Icons.support_agent_rounded,
          iconColor: c.textPrimary,
          title: S.contactUs,
          onTap: () => _push(const SupportTicketScreen()),
        ),
        AppMenuItem(
          icon: Icons.info_outline_rounded,
          iconColor: c.textPrimary,
          title: S.aboutSavemybook,
          isLast: true,
          onTap: () => _push(LegalDocScreen(
            docKey: 'about',
            fallbackTitle: S.aboutUs,
            icon: Icons.info_outline_rounded,
          )),
        ),
      ],
    );
  }

  Widget _buildStorageCard(AppColors c) {
    return AppMenuItem(
      icon: Icons.cleaning_services_outlined,
      iconColor: c.textPrimary,
      title: S.clearCache,
      subtitle: S.removesCachedImagesFilesAccountData,
      isLast: true,
      showChevron: !_clearingCache,
      trailing: _clearingCache
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
          : null,
      onTap: _clearingCache ? null : _clearCache,
    );
  }

  Widget _buildPushCard(AppColors c) {
    final settings = _notificationSettings;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          if (_isAdmin) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(Icons.notifications_active_outlined, color: c.textPrimary),
              title: Text(
                S.sendTestNotification,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              subtitle: Text(
                S.arrives10SecondsGoHomeScreen,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              trailing: SwitchIn(
                duration: Motion.micro,
                child: _sendingTestPush
                    ? SizedBox(
                        key: const ValueKey('sending'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                      )
                    : Icon(Icons.send_rounded, key: const ValueKey('send'), size: 20, color: c.accent),
              ),
              onTap: _sendingTestPush ? null : _sendTestPush,
            ),
            _divider(c),
          ],
          Reveal(
            visible: _notificationLoadFailed,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(Icons.cloud_off_rounded, color: c.warning),
              title: Text(S.couldNotLoadNotificationSettings, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              trailing: Text(S.retry, style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
              onTap: _loadNotificationSettings,
            ),
          ),
          for (final (i, item) in [
            (key: 'order', icon: Icons.receipt_long_outlined, title: S.orderProgress, subtitle: S.salesDropOffsPickupsRefundsDisputes),
            (key: 'message', icon: Icons.chat_bubble_outline_rounded, title: S.chatMessages, subtitle: S.newMessagesFromBuyersSellers),
            (key: 'promotion', icon: Icons.local_offer_outlined, title: S.promotions2, subtitle: S.announcementsAboutPromotions),
          ].indexed) ...[
            if (i > 0) _divider(c),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Icon(item.icon, color: c.textPrimary),
              title: Text(item.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary)),
              subtitle: Text(item.subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              activeThumbColor: c.accent,
              value: switch (item.key) {
                'order' => settings?.order ?? true,
                'message' => settings?.message ?? true,
                _ => settings?.promotion ?? true,
              },
              onChanged: settings == null ? null : (v) => _toggleNotification(item.key, v),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 10),
            child: Text(
              S.supportRepliesPasswordResetsPolicyUpdates,
              style: TextStyle(fontSize: 11, height: 1.5, color: c.textHint),
            ),
          ),
          _divider(c),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Icon(Icons.tune_rounded, color: c.textPrimary),
            title: Text(
              S.systemNotificationSettings,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            subtitle: Text(
              S.turnNotificationsSoundsLockScreenPreviews,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: c.iconInactive),
            onTap: PushService.openSystemSettings,
          ),
        ],
      ),
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
      subtitle: S.appearanceHint,
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

  Future<void> _pickLanguage(Locale? current) async {
    final picked = await showOptionSheet<int>(
      context,
      title: S.language,
      subtitle: S.languageHint,
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
