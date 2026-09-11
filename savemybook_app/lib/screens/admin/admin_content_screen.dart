import 'package:flutter/material.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/app_labels.dart';

class AdminLegalScreen extends StatefulWidget {
  const AdminLegalScreen({super.key});

  @override
  State<AdminLegalScreen> createState() => _AdminLegalScreenState();
}

class _AdminLegalScreenState extends State<AdminLegalScreen> {
  static const _known = {
    'terms': '服務條款',
    'privacy': '隱私權政策',
    'about': '關於我們',
  };

  final ApiService _api = ApiService();
  List<LegalDoc> _docs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await _api.fetchAdminLegalDocs();
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _isLoading = false;
    });
  }

  Future<void> _edit(String key, LegalDoc? doc) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminLegalEditScreen(
          docKey: key,
          initialTitle: doc?.title ?? _known[key] ?? key,
          initialContent: doc?.content ?? '',
        ),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '法律文件', icon: Icons.gavel_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        children: [
                          for (final entry in _known.entries)
                            FadeSlideIn(
                              index: _known.keys.toList().indexOf(entry.key),
                              child: _buildCard(entry.key, entry.value, c),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String key, String fallbackTitle, AppColors c) {
    final doc = _docs.where((d) => d.key == key).firstOrNull;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(key, doc),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.article_outlined, color: c.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doc?.title ?? fallbackTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doc == null ? '尚未建立' : '最後更新 ${formatDate(doc.updatedAt)}',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      ),
    );
  }
}

class AdminLegalEditScreen extends StatefulWidget {
  final String docKey;
  final String initialTitle;
  final String initialContent;

  const AdminLegalEditScreen({
    super.key,
    required this.docKey,
    required this.initialTitle,
    required this.initialContent,
  });

  @override
  State<AdminLegalEditScreen> createState() => _AdminLegalEditScreenState();
}

class _AdminLegalEditScreenState extends State<AdminLegalEditScreen> {
  final ApiService _api = ApiService();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _contentController =
      TextEditingController(text: widget.initialContent);

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      showAppSnackBar(context, '標題與內容都要填寫', isError: true);
      return;
    }

    final unchanged = content == widget.initialContent && title == widget.initialTitle;
    if (unchanged) {
      showAppSnackBar(context, '內容沒有變更');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '確認更新$title？',
      message: '這份文件對所有使用者都有效力，送出後會立刻取代目前的版本。',
      confirmLabel: '我確認要更新',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final notify = await showConfirmDialog(
      context,
      title: '要通知所有使用者嗎？',
      message: '每一位啟用中的會員都會收到一則「$title已更新」的通知。',
      confirmLabel: '更新並通知',
      cancelLabel: '只更新不通知',
    );
    if (!mounted) return;

    setState(() => _isSaving = true);
    final result = await _api.saveLegalDoc(
      widget.docKey,
      title: title,
      content: content,
      notify: notify,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.error != null) {
      showAppSnackBar(context, result.error!, isError: true);
      return;
    }
    showAppSnackBar(context, result.message);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: widget.initialTitle, icon: Icons.edit_note_rounded),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 40,
                ),
                children: [
                  FormRowCard(
                    label: '標題',
                    child: AppTextField(controller: _titleController, hint: '文件標題', maxLength: 100),
                  ),
                  FormRowCard(
                    label: '內容',
                    alignTop: true,
                    child: AppTextField(
                      controller: _contentController,
                      hint: '文件內容',
                      maxLines: 20,
                      maxLength: 20000,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: '儲存',
                    height: 50,
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq == null ? '新增問題' : '編輯問題',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 16),
                AppDropdownField<String>(
                  value: category,
                  items: AppLabels.faqCategory.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (value) => setSheetState(() => category = value ?? 'general'),
                ),
                const SizedBox(height: 12),
                AppTextField(controller: questionController, hint: '問題', maxLength: 200),
                const SizedBox(height: 12),
                AppTextField(
                  controller: answerController,
                  hint: '答案',
                  maxLines: 6,
                  maxLength: 2000,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('顯示在幫助中心', style: TextStyle(fontSize: 14, color: c.textPrimary)),
                  value: visible,
                  activeThumbColor: c.accent,
                  onChanged: (value) => setSheetState(() => visible = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('儲存', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;

    if (questionController.text.trim().isEmpty || answerController.text.trim().isEmpty) {
      showAppSnackBar(context, '問題與答案都要填寫', isError: true);
      return;
    }

    final error = await runBusy(
      context,
      () => _api.saveFaq(
        faqId: faq?.faqId,
        category: category,
        question: questionController.text.trim(),
        answer: answerController.text.trim(),
        sortOrder: faq?.sortOrder ?? _faqs.length,
        isVisible: visible,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, faq == null ? '已新增' : '已更新');
      _load();
    }
  }

  Future<void> _delete(FaqItem faq) async {
    final ok = await showConfirmDialog(
      context,
      title: '刪除問題',
      message: '要刪除「${faq.question}」嗎？',
      confirmLabel: '刪除',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final error = await runBusy(context, () => _api.deleteFaq(faq.faqId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '已刪除');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '常見問題',
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
                      child: _faqs.isEmpty
                          ? ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(icon: Icons.quiz_outlined, message: '還沒有常見問題'),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              itemCount: _faqs.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_faqs[i], c),
                              ),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(FaqItem faq, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(faq: faq),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(label: faq.categoryText, color: c.accent),
              const SizedBox(width: 8),
              if (!faq.isVisible) StatusBadge(label: '已隱藏', color: c.iconInactive),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
                onPressed: () => _delete(faq),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
        ],
      ),
    );
  }
}
