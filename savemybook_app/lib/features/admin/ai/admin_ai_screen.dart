import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/guards.dart';
import 'ai_review_tab.dart';
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
  int? _pending;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _setPending(int count) {
    if (!mounted || _pending == count) return;
    setState(() => _pending = count);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pending = _pending ?? 0;

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
              bottom: AnimatedBuilder(
                animation: _tabs,
                builder: (context, _) => AppTabBar(
                  controller: _tabs,
                  tabs: [
                    S.usage,
                    _dirty ? S.settings2 : S.settings,
                    pending > 0 ? S.reviewP0(pending) : S.review,
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AiUsageTab(
                    onPendingReviews: _setPending,
                    onOpenReviews: () => _tabs.animateTo(2),
                  ),
                  AiSettingsTab(
                    key: _settingsKey,
                    initialAdvancedOpen: widget.initialAdvancedOpen,
                    onDirtyChanged: (dirty) {
                      if (mounted) setState(() => _dirty = dirty);
                    },
                  ),
                  AiReviewTab(onCountChanged: _setPending),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
