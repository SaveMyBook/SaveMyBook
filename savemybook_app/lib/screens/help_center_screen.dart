import 'package:flutter/material.dart';
import '../models/support.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../utils/app_labels.dart';
import '../i18n/strings.dart';

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
      _faqs = faqs;
      _isLoading = false;
    });
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
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.helpCentre, icon: Icons.help_outline_rounded),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: S.searchQuestions,
              onChanged: (value) => setState(() => _keyword = value.trim()),
            ),
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : grouped.isEmpty
                      ? EmptyView(
                          icon: Icons.search_off_rounded,
                          message: _keyword.isEmpty ? S.noQuestionsYet : S.noMatchingQuestions,
                        )
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                                  FadeSlideIn(
                                    index: i,
                                    child: _buildTile(entry.value[i], c),
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
            ),
          ),
        ],
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
