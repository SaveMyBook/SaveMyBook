import 'package:flutter/material.dart';
import '../../models/support.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import 'support_ticket_screen.dart';
import 'ai_support_entry.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<FaqItem> _faqs = [];
  String _keyword = '';
  bool _isLoading = true;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
    AiStatus.refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final faqs = await _api.fetchFaqs();
    if (!mounted) return;
    setState(() {
      if (faqs.isNotEmpty || _faqs.isEmpty) _faqs = faqs;
      _isLoading = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  void _openSupport() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketScreen()));
  }

  List<FaqItem> get _visible {
    if (_keyword.isEmpty) return _faqs;
    final key = _keyword.toLowerCase();
    return _faqs
        .where((f) =>
            f.question.toLowerCase().contains(key) || f.answer.toLowerCase().contains(key))
        .toList();
  }

  Map<String, List<FaqItem>> get _grouped {
    final map = <String, List<FaqItem>>{};
    for (final faq in _visible) {
      map.putIfAbsent(faq.category, () => []).add(faq);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.helpCentre2, icon: Icons.support_agent_rounded),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (context.isWide && constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _buildSearch(c, horizontal: 24),
                              const AiSupportEntry(maxWidth: Breakpoints.readingMaxWidth, horizontal: 24),
                              _buildContact(c, horizontal: 24),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, thickness: 1, color: c.divider),
                      Expanded(child: _buildFaqs(c, horizontal: 24, top: 16)),
                    ],
                  );
                }
                final horizontal = context.isWide ? 24.0 : 20.0;
                return Column(
                  children: [
                    _buildSearch(c, horizontal: horizontal),
                    AiSupportEntry(maxWidth: Breakpoints.readingMaxWidth, horizontal: horizontal),
                    _buildContact(c, horizontal: horizontal),
                    Expanded(child: _buildFaqs(c, horizontal: horizontal, top: 8)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(AppColors c, {required double horizontal}) {
    return ResponsiveListPadding(
      maxWidth: Breakpoints.readingMaxWidth,
      horizontal: horizontal,
      top: 16,
      bottom: 8,
      builder: (context, padding) => Padding(
        padding: padding,
        child: AppSearchField(
          controller: _searchController,
          hint: S.searchQuestions,
          onChanged: (value) => setState(() => _keyword = value.trim()),
        ),
      ),
    );
  }

  Widget _buildContact(AppColors c, {required double horizontal}) {
    return ResponsiveListPadding(
      maxWidth: Breakpoints.readingMaxWidth,
      horizontal: horizontal,
      top: 12,
      bottom: 4,
      builder: (context, padding) => Padding(
        padding: padding,
        child: AppCard(
          key: const ValueKey('help_contact_support'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: _openSupport,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.support_agent_rounded, size: 20, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.contactSupport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.iconInactive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqs(AppColors c, {required double horizontal, required double top}) {
    final grouped = _grouped;
    return SwitchIn(
      child: _isLoading
          ? const LoadingView.list(key: ValueKey('loading'))
          : grouped.isEmpty
              ? RefreshableCenter(
                  key: ValueKey('empty_${_keyword.isEmpty}'),
                  onRefresh: _load,
                  child: EmptyView(
                    icon: _keyword.isEmpty ? Icons.help_outline_rounded : Icons.search_off_rounded,
                    message: _keyword.isEmpty
                        ? S.noQuestionsYet
                        : S.noMatchingQuestions,
                    actionLabel: _keyword.isEmpty ? S.retry : S.contactSupport,
                    actionIcon: _keyword.isEmpty ? Icons.refresh_rounded : Icons.support_agent_rounded,
                    onAction: _keyword.isEmpty ? _retry : _openSupport,
                  ),
                )
              : RefreshIndicator(
                  key: const ValueKey('list'),
                  color: c.accent,
                  onRefresh: _load,
                  child: LayoutBuilder(builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: horizontal, top: top, bottom: 40),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
                          child: Text(
                            AppLabels.faqCategory[entry.key] ?? entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                        for (var i = 0; i < entry.value.length; i++)
                          RevealOnScroll(
                            index: i,
                            child: _buildTile(entry.value[i], c),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  )),
                ),
    );
  }

  Widget _buildTile(FaqItem faq, AppColors c) {
    final expanded = _expandedId == faq.faqId;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      onTap: () => setState(() => _expandedId = expanded ? null : faq.faqId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    faq.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more_rounded, color: c.iconInactive),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14, right: 4),
                    child: Text(
                      faq.answer,
                      style: TextStyle(fontSize: 13, height: 1.7, color: c.textSecondary),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
