import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await ApiService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity, height: 200,
            decoration: BoxDecoration(color: c.headerBg,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
            child: SafeArea(
              bottom: false,
              child: Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(radius: 35,
                          backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=200&auto=format&fit=crop'),
                          child: user?.nickname == null ? const Icon(Icons.person, size: 35, color: Colors.grey) : null)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(user?.nickname ?? '使用者', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star, color: Colors.amber, size: 12), SizedBox(width: 4),
                          Text('資深書友', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ])),
                  ])),
                ]),
              )),
            ),
          ),
          const SizedBox(height: 20),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatItem(label: '我的代幣', value: '520', c: c), _StatVerticalDivider(c: c),
              _StatItem(label: '書籍管理', value: '8', c: c), _StatVerticalDivider(c: c),
              _StatItem(label: '收藏清單', value: '12', c: c),
            ]),
          )),
          const SizedBox(height: 20),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(children: [
              _ProfileMenuItem(icon: Icons.qr_code_scanner, title: '分享個人檔案', c: c),
              _ProfileMenuItem(icon: Icons.person_outline, title: '編輯個人檔案', c: c),
              _ProfileMenuItem(icon: Icons.history, title: '購買紀錄', c: c),
              _ProfileMenuItem(icon: Icons.inventory_2_outlined, title: '銷售紀錄', c: c),
              _ProfileMenuItem(icon: Icons.settings_outlined, title: '設定', c: c, isLast: true),
            ]),
          )),
          const SizedBox(height: 20),

          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeProvider,
              builder: (context, mode, _) {
                final isDark = themeProvider.isDark(context);
                return Container(
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: ListTile(
                    leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                    title: Text('夜間模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary)),
                    trailing: Switch.adaptive(value: isDark, activeColor: AppColors.primary, onChanged: (_) => themeProvider.toggle()),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          Padding(padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40), child: GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                backgroundColor: c.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('確認登出', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
                content: Text('確定要登出帳號嗎？', style: TextStyle(color: c.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('登出', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ],
              ));
              if (confirmed == true && context.mounted) _handleLogout(context);
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout, color: Colors.red, size: 20), SizedBox(width: 8),
                Text('登出', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            ),
          )),
          const SizedBox(height: 120),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final AppColors c;
  const _StatItem({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _StatVerticalDivider extends StatelessWidget {
  final AppColors c;
  const _StatVerticalDivider({required this.c});

  @override
  Widget build(BuildContext context) => Container(height: 30, width: 1, color: c.divider);
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final bool isLast;
  final AppColors c;

  const _ProfileMenuItem({required this.icon, required this.title, required this.c, this.trailingText, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: Icon(icon, color: c.iconInactive),
        title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailingText != null) Text(trailingText!, style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 16, color: c.iconInactive),
        ]),
        onTap: () {},
      ),
      if (!isLast) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: c.divider)),
    ]);
  }
}