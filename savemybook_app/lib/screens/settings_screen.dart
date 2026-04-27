import 'package:flutter/material.dart';
import '../services/theme_provider.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.headerBg,
        title: const Text('設定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('外觀設定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeProvider,
              builder: (context, mode, _) {
                final isDark = themeProvider.isDark(context);
                return Container(
                  decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: ListTile(
                    leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                    title: Text('夜間模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary)),
                    trailing: Switch.adaptive(value: isDark, activeColor: AppColors.primary, onChanged: (_) => themeProvider.toggle()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}