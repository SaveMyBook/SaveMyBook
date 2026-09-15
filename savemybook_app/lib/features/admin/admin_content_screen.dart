import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/app_labels.dart';
import '../../utils/app_radius.dart';
import '../../i18n/strings.dart';
import 'legal_editor/legal_draft_store.dart';
import 'legal_editor/legal_editor_screen.dart';
import 'admin_layout.dart';

class AdminLegalScreen extends StatefulWidget {
  const AdminLegalScreen({super.key});

  @override
  State<AdminLegalScreen> createState() => _AdminLegalScreenState();
}

class _AdminLegalScreenState extends State<AdminLegalScreen> {
  Map<String, String> get _known => {
    'terms': S.termsService,
    'privacy': S.privacyPolicy,
    'about': S.aboutUs,
  };

  static const _consentKeys = {'terms', 'privacy'};

  final ApiService _api = ApiService();
  List<LegalDoc> _docs = [];
  Set<String> _drafts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String> get _keys => [
    ..._known.keys,
    for (final doc in _docs)
      if (!_known.containsKey(doc.key)) doc.key,
  ];

  Future<void> _load() async {
    final docs = await _api.fetchAdminLegalDocs();
    final keys = {..._known.keys, for (final doc in docs) doc.key};
    final drafts = await LegalDraftStore.keysWithDrafts(keys);
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _drafts = drafts;
      _isLoading = false;
    });
  }

  Future<void> _edit(String key, LegalDoc? doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalEditorScreen(
          docKey: key,
          fallbackTitle: _known[key] ?? key,
          doc: doc,
          requiresConsent: doc?.requiresConsent ?? _consentKeys.contains(key),
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final keys = _keys;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.legalDocuments, icon: Icons.gavel_outlined),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: frame.inset(const EdgeInsets.fromLTRB(20, 20, 20, 40)),
                          children: [
                            for (var i = 0; i < keys.length; i++)
                              FadeSlideIn(
                                index: i,
                                child: _buildCard(keys[i], c),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String key) => switch (key) {
    'terms' => Icons.gavel_rounded,
    'privacy' => Icons.privacy_tip_outlined,
    'about' => Icons.info_outline_rounded,
    _ => Icons.article_outlined,
  };

  Widget _buildCard(String key, AppColors c) {
    final doc = _docs.where((d) => d.key == key).firstOrNull;
    final title = doc?.title.trim().isNotEmpty == true ? doc!.title : (_known[key] ?? key);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(key, doc),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(key), color: c.accent, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  doc == null ? S.notCreatedYet : S.updatedP0(formatDateTime(doc.updatedAt)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (doc != null) StatusBadge(label: S.versionP0(doc.version), color: c.accent),
                    if (doc?.requiresConsent ?? _consentKeys.contains(key)) StatusBadge(label: S.requiresUserConsent, color: c.warning),
                    if (_drafts.contains(key)) StatusBadge(label: S.unsavedDraft, color: c.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      ),
    );
  }
}

Widget liftDraggedCard(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeOut.transform(animation.value);
      final c = AppColors.of(context);
      return Transform.scale(
        scale: 1 + 0.03 * t,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.18 * t),
                blurRadius: 24 * t,
                offset: Offset(0, 8 * t),
              ),
            ],
          ),
          child: child,
        ),
      );
    },
  );
}

class AdminFaqScreen extends StatefulWidget {
  const AdminFaqScreen({super.key});

  @override
  State<AdminFaqScreen> createState() => _AdminFaqScreenState();
}

class _AdminFaqScreenState extends State<AdminFaqScreen> {
  final ApiService _api = ApiService();
  List<FaqItem> _faqs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final faqs = await _api.fetchAdminFaqs();
    if (!mounted) return;
    setState(() {
      _faqs = faqs;
      _isLoading = false;
    });
  }

  Future<void> _edit({FaqItem? faq}) async {
    final c = AppColors.of(context);
    final questionController = TextEditingController(text: faq?.question ?? '');
    final answerController = TextEditingController(text: faq?.answer ?? '');
    var category = faq?.category ?? 'general';
    var visible = faq?.isVisible ?? true;
    var showErrors = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: c.iconInactive.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    faq == null ? S.newQuestion : S.editQuestion,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  AppSelect<String>(
                    value: category,
                    title: S.category,
                    leadingIcon: Icons.folder_outlined,
                    options: [
                      for (final e in AppLabels.faqCategory.entries) AppSelectOption(value: e.key, label: e.value),
                    ],
                    onChanged: (value) => setSheetState(() => category = value),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: questionController,
                    hint: S.question,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    errorText: showErrors && questionController.text.trim().isEmpty ? S.bothQuestionAnswerRequired : null,
                    onChanged: (_) {
                      if (showErrors) setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: answerController,
                    hint: S.answer,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    keyboardType: TextInputType.multiline,
                    errorText: showErrors && answerController.text.trim().isEmpty ? S.bothQuestionAnswerRequired : null,
                    onChanged: (_) {
                      if (showErrors) setSheetState(() {});
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.showHelpCentre, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                    value: visible,
                    activeThumbColor: c.accent,
                    onChanged: (value) => setSheetState(() => visible = value),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: S.actionSave,
                    height: 46,
                    onPressed: () {
                      if (questionController.text.trim().isEmpty || answerController.text.trim().isEmpty) {
                        HapticFeedback.heavyImpact();
                        setSheetState(() => showErrors = true);
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final question = questionController.text.trim();
    final answer = answerController.text.trim();
    Future.delayed(const Duration(milliseconds: 800), () {
      questionController.dispose();
      answerController.dispose();
    });

    if (saved != true || !mounted) return;

    final error = await runBusy(
      context,
      () => _api.saveFaq(
        faqId: faq?.faqId,
        category: category,
        question: question,
        answer: answer,
        sortOrder: faq?.sortOrder ?? _faqs.length,
        isVisible: visible,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, faq == null ? S.added : S.updated);
      _load();
    }
  }

  Future<void> _delete(FaqItem faq) async {
    final ok = await showConfirmDialog(
      context,
      title: S.deleteQuestion,
      message: S.deleteP0(faq.question),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final error = await runBusy(context, () => _api.deleteFaq(faq.faqId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.deleted);
      _load();
    }
  }

  Map<String, List<FaqItem>> get _grouped {
    final map = <String, List<FaqItem>>{};
    for (final faq in _faqs) {
      map.putIfAbsent(faq.category, () => []).add(faq);
    }
    return map;
  }

  Future<void> _reorder(String category, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    final grouped = _grouped;
    final group = grouped[category]!;
    group.insert(newIndex, group.removeAt(oldIndex));

    final previous = _faqs;
    setState(() => _faqs = [for (final entry in grouped.entries) ...entry.value]);
    HapticFeedback.selectionClick();

    final error = await _api.reorderFaqs([for (final faq in group) faq.faqId]);
    if (!mounted) return;
    if (error != null) {
      setState(() => _faqs = previous);
      showAppSnackBar(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.faq,
              icon: Icons.quiz_outlined,
              actions: [
                HeaderIconButton(icon: Icons.add_rounded, onTap: () => _edit()),
              ],
            ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: SwitchIn(
                          child: _faqs.isEmpty
                              ? ListView(
                                  key: const ValueKey('empty'),
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  children: [
                                    SizedBox(height: 60),
                                    EmptyView(icon: Icons.quiz_outlined, message: S.noQuestionsYet2),
                                  ],
                                )
                              : CustomScrollView(
                                  key: const ValueKey('items'),
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  slivers: [
                                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                                    for (final entry in grouped.entries) ...[
                                      SliverToBoxAdapter(
                                        child: _buildSectionHeader(entry.key, entry.value.length, c, frame),
                                      ),
                                      SliverPadding(
                                        padding: frame.inset(const EdgeInsets.symmetric(horizontal: 20)),
                                        sliver: SliverReorderableList(
                                          itemCount: entry.value.length,
                                          onReorder: (from, to) => _reorder(entry.key, from, to),
                                          proxyDecorator: liftDraggedCard,
                                          itemBuilder: (_, i) =>
                                              _buildCard(entry.value[i], i, entry.value.length, c),
                                        ),
                                      ),
                                    ],
                                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                                  ],
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String category, int count, AppColors c, AdminFrame frame) {
    return Padding(
      padding: frame.inset(const EdgeInsets.fromLTRB(20, 12, 20, 10)),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(AppRadius.tag),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLabels.faqCategory[category] ?? category,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 12, color: c.textHint)),
          const Spacer(),
          if (count > 1)
            Row(
              children: [
                Icon(Icons.swap_vert_rounded, size: 13, color: c.textHint),
                const SizedBox(width: 3),
                Text(S.dragHandleRightReorder,
                    style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCard(FaqItem faq, int index, int total, AppColors c) {
    return Padding(
      key: ValueKey(faq.faqId),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _edit(faq: faq),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: faq.isVisible ? c.accent.withValues(alpha: 0.12) : c.inputFill,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: faq.isVisible ? c.accent : c.textHint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.question,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    faq.answer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.5),
                  ),
                  if (!faq.isVisible) ...[
                    const SizedBox(height: 8),
                    StatusBadge(label: S.hidden, color: c.iconInactive),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
                  onPressed: () => _delete(faq),
                ),
                if (total > 1)
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      height: 32,
                      width: 32,
                      alignment: Alignment.center,
                      child: Icon(Icons.drag_handle_rounded, color: c.iconInactive, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
