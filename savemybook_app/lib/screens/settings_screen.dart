import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../services/theme_provider.dart';
import '../utils/app_colors.dart';
import 'change_password_screen.dart';
import 'help_center_screen.dart';
import 'legal_doc_screen.dart';
import 'support_ticket_screen.dart';
import '../widgets/biometric_icon.dart';
import '../widgets/state_views.dart';
import '../utils/motion.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import 'account_privacy_screen.dart';
import '../services/locale_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricAvailable = false;
  String _biometricLabel = '生物辨識';

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final label = available ? await BiometricService.label() : '生物辨識';
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricLabel = label;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !await BiometricService.authenticate(reason: '驗證身分以啟用快速登入')) {
      return;
    }
    await BiometricService.setEnabled(value);
    if (!mounted) return;
    setState(() {});
    showAppSnackBar(context, value ? '已啟用 $_biometricLabel 登入' : '已關閉快速登入');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.headerBg,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('設定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('外觀設定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary)),
            const SizedBox(height: 12),
            _buildDarkModeCard(context, c),
            if (_biometricAvailable) ...[
              const SizedBox(height: 32),
              Text('登入方式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary)),
              const SizedBox(height: 12),
              _buildBiometricCard(c),
            ],
            const SizedBox(height: 32),
            Text('關於我們', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary)),
            const SizedBox(height: 12),
            _buildExpandableCard(
              c,
              icon: Icons.help_outline_rounded,
              title: '說明與支援',
              children: [
                _buildSubItem(
                  c,
                  icon: Icons.quiz_outlined,
                  title: '幫助中心',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                  ),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.support_agent_rounded,
                  title: '聯絡我們',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportTicketScreen()),
                  ),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.info_outline_rounded,
                  title: '關於 SaveMyBook',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalDocScreen(
                        docKey: 'about',
                        fallbackTitle: '關於我們',
                        icon: Icons.info_outline_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildExpandableCard(
              c,
              icon: Icons.security_rounded,
              title: '設定與隱私',
              children: [
                _buildSubItem(
                  c,
                  icon: Icons.key_outlined,
                  title: '更改密碼',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.shield_outlined,
                  title: '帳號與隱私',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AccountPrivacyScreen())),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.privacy_tip_outlined,
                  title: '隱私權政策',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalDocScreen(
                        docKey: 'privacy',
                        fallbackTitle: '隱私權政策',
                        icon: Icons.privacy_tip_outlined,
                      ),
                    ),
                  ),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.description_outlined,
                  title: '服務條款',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalDocScreen(
                        docKey: 'terms',
                        fallbackTitle: '服務條款',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeCard(BuildContext context, AppColors c) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (context, mode, _) {
        return Container(
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: SwitchIn(
                  duration: Motion.micro,
                  child: Icon(
                    _themeIcon(mode),
                    key: ValueKey(mode),
                    color: c.textPrimary,
                  ),
                ),
                title: Text('外觀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                subtitle: Text(_themeLabel(mode), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                trailing: Icon(Icons.chevron_right_rounded, color: c.iconInactive),
                onTap: () => _pickTheme(mode),
              ),
              Divider(height: 1, indent: 56, color: c.divider),
              ValueListenableBuilder<Locale?>(
                valueListenable: localeProvider,
                builder: (context, locale, _) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.language_rounded, color: c.textPrimary),
                  title: Text('語言',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  subtitle: Text(
                    locale == null ? '跟隨系統' : LocaleProvider.nameOf(locale),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: c.iconInactive),
                  onTap: () => _pickLanguage(locale),
                ),
              ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBiometricCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _biometricLabel == 'Face ID'
                ? FaceIdIcon(size: 22, color: c.textPrimary)
                : Icon(Icons.fingerprint_rounded, color: c.textPrimary),
            title: Text(
              '$_biometricLabel 登入',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
            subtitle: Text(
              '開啟 App 時用 $_biometricLabel 解鎖',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            trailing: Switch.adaptive(
              value: BiometricService.isEnabled,
              activeThumbColor: c.accent,
              onChanged: _toggleBiometric,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableCard(AppColors c, {required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(icon, color: c.textPrimary),
              title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
              iconColor: c.textPrimary,
              collapsedIconColor: c.textHint,
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem(AppColors c, {required IconData icon, required String title, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap ?? () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: c.textPrimary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary))),
                    Icon(Icons.arrow_forward_ios, size: 14, color: c.iconInactive),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => '淺色',
        ThemeMode.dark => '深色',
        ThemeMode.system => '跟隨系統',
      };

  Future<void> _pickTheme(ThemeMode current) async {
    final picked = await showOptionSheet<ThemeMode>(
      context,
      title: '外觀',
      subtitle: '選擇「跟隨系統」時，會依裝置的深淺色設定自動切換',
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
    // 用 -1 代表「跟隨系統」，SheetOption 的 value 不能是 null。
    final picked = await showOptionSheet<int>(
      context,
      title: '語言',
      subtitle: '選擇「跟隨系統」時，會依裝置的語言設定顯示',
      options: [
        SheetOption(
          value: -1,
          label: '跟隨系統',
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