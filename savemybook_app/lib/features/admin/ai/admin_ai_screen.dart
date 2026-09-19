import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/guards.dart';
import '../admin_report_screen.dart';
import 'ai_settings_tab.dart';
import 'ai_usage_tab.dart';
import '../../../i18n/strings.dart';

class AdminAiScreen extends StatefulWidget {
  final int initialTab;
  final bool initialAdvancedOpen;

  const AdminAiScreen({super.key, this.initialTab = 0, this.initialAdvancedOpen = false});

  @override
  State<AdminAiScreen> createState() => _AdminAiScreenState();
}

class _AdminAiScreenState extends State<AdminAiScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
  final _settingsKey = GlobalKey<AiSettingsTabState>();
  bool _dirty = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // 上架審核與檢舉同屬內容審核，統一在內容審核頁處理。
  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _dirty,
      message: S.aiSettingsNotSavedChangesLost,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(
              title: S.aiFeatures,
              icon: Icons.auto_awesome_rounded,
              bottom: AppTabBar(
                controller: _tabs,
                tabs: [S.usage, S.settings],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AiUsageTab(onOpenReviews: _openReviews),
                  AiSettingsTab(
                    key: _settingsKey,
                    initialAdvancedOpen: widget.initialAdvancedOpen,
                    onDirtyChanged: (dirty) {
                      if (mounted) setState(() => _dirty = dirty);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
