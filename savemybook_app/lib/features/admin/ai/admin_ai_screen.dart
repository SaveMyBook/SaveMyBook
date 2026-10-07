import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/guards.dart';
import '../admin_report_screen.dart';
import '../admin_workspace.dart';
import 'ai_decisions_tab.dart';
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
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  final _settingsKey = GlobalKey<AiSettingsTabState>();
  bool _dirty = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openReviews() {
    const reviews = AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab);
    if (AdminWorkspace.show(context, AdminSections.moderation, root: reviews)) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => reviews),
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
                tabs: [S.usage, S.settings, S.outcomes],
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
                  const AiDecisionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
