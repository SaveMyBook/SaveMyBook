import 'package:flutter/material.dart';
import '../services/theme_provider.dart';
import '../utils/app_colors.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            const Text('外觀設定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildDarkModeCard(context, c),
            const SizedBox(height: 32),
            const Text('關於我們', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildExpandableCard(
              c,
              icon: Icons.help_outline_rounded,
              title: '說明與支援',
              children: [
                _buildSubItem(c, icon: Icons.mail_outline_rounded, title: '支援信箱'),
                _buildSubItem(c, icon: Icons.phone_in_talk_outlined, title: '聯絡我們'),
                _buildSubItem(c, icon: Icons.person_outline_rounded, title: '幫助中心'),
              ],
            ),
            const SizedBox(height: 24),
            _buildExpandableCard(
              c,
              icon: Icons.security_rounded,
              title: '設定與隱私',
              children: [
                _buildSubItem(c, icon: Icons.key_outlined, title: '更改密碼'),
                _buildSubItem(
                  c,
                  icon: Icons.privacy_tip_outlined,
                  title: '隱私權政策',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                ),
                _buildSubItem(
                  c,
                  icon: Icons.description_outlined,
                  title: '服務條款',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
                ),
                _buildSubItem(c, icon: Icons.info_outline_rounded, title: '關於'),
                _buildSubItem(c, icon: Icons.update_rounded, title: '更新'),
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
        final isDark = themeProvider.isDark(context);
        return Container(
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: c.textPrimary),
                title: Text('深色模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                trailing: Switch.adaptive(value: isDark, activeColor: AppColors.primary, onChanged: (_) => themeProvider.toggle()),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandableCard(AppColors c, {required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
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
}