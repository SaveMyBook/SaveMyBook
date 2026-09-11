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
import '../../utils/app_radius.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

class AdminLegalScreen extends StatefulWidget {
  const AdminLegalScreen({super.key});

  @override
  State<AdminLegalScreen> createState() => _AdminLegalScreenState();
}

class _AdminLegalScreenState extends State<AdminLegalScreen> {
  static const _known = {
    'terms': S.termsService,
    'privacy': S.privacyPolicy,
    'about': S.aboutUs,
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
              borderRadius: BorderRadius.circular(14),
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
  bool _dirty = false;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_checkDirty);
    _contentController.addListener(_checkDirty);
  }

  void _checkDirty() {
    final dirty = _titleController.text != widget.initialTitle ||
        _contentController.text != widget.initialContent;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    _titleController.removeListener(_checkDirty);
    _contentController.removeListener(_checkDirty);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 條款動輒上千字，改到一半誤觸返回等於全部重打。
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return showConfirmDialog(
      context,
      title: '捨棄變更？',
      message: '這份文件有尚未儲存的修改，離開後會遺失。',
      confirmLabel: '捨棄',
      cancelLabel: '繼續編輯',
      isDestructive: true,
    );
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
    _dirty = false;
    showAppSnackBar(context, result.message);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = _contentController.text;
    final paragraphs = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) {
          if (!mounted) return;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: widget.initialTitle, icon: Icons.edit_note_rounded),
            _buildToolbar(c, text.length, paragraphs),
            Expanded(
              child: SwitchIn(
                child: _previewing ? _buildPreview(c, text) : _buildEditor(c),
              ),
            ),
            _buildBottomBar(c),
          ],
        ),
      ),
    );
  }

  /// 編輯／預覽切換與即時統計。條款是給使用者看的，寫的時候
  /// 要能隨時確認排版起來長什麼樣。
  Widget _buildToolbar(AppColors c, int length, int paragraphs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      color: c.card,
      child: Row(
        children: [
          _ModeTab(
            label: S.actionEdit,
            icon: Icons.edit_rounded,
            selected: !_previewing,
            onTap: () => setState(() => _previewing = false),
          ),
          const SizedBox(width: 8),
          _ModeTab(
            label: '預覽',
            icon: Icons.visibility_rounded,
            selected: _previewing,
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _previewing = true);
            },
          ),
          const Spacer(),
          Text(
            '$paragraphs 段・$length 字',
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(AppColors c) {
    return Padding(
      key: const ValueKey('edit'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          AppTextField(
            controller: _titleController,
            hint: '文件標題',
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          // 內容區吃掉剩下的所有高度。放進 ListView 裡的多行輸入框會變成
          // 「捲動中的捲動」，改幾千字的條款完全沒辦法用。
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: c.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '空一行分段。條款內容會照這裡的排版呈現給使用者。',
                  hintStyle: TextStyle(color: c.textHint, height: 1.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 照使用者端的樣式呈現：同一個字級、行高與段距。
  Widget _buildPreview(AppColors c, String text) {
    final paragraphs = text.trim().split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return ListView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.trim().isEmpty
                    ? widget.initialTitle
                    : _titleController.text.trim(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (paragraphs.isEmpty)
                Text('尚無內容', style: TextStyle(fontSize: 14, color: c.textHint))
              else
                for (final p in paragraphs) ...[
                  Text(
                    p.trim(),
                    style: TextStyle(fontSize: 14, height: 1.8, color: c.textSecondary),
                  ),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppColors c) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          SwitchIn(
            duration: Motion.micro,
            child: _dirty
                ? Row(
                    key: const ValueKey('dirty'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 13, color: c.warning),
                      const SizedBox(width: 5),
                      Text('尚未儲存', style: TextStyle(fontSize: 12, color: c.warning)),
                    ],
                  )
                : Row(
                    key: const ValueKey('clean'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: c.success),
                      const SizedBox(width: 5),
                      Text('已是最新版本', style: TextStyle(fontSize: 12, color: c.textHint)),
                    ],
                  ),
          ),
          const Spacer(),
          SizedBox(
            width: 132,
            child: PrimaryButton(
              label: S.actionSave,
              height: 46,
              isLoading: _isSaving,
              onPressed: _dirty ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 編輯／預覽的分段按鈕。
class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return PressableScale(
      scale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : c.iconInactive),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : c.textSecondary,
              ),
            ),
          ],
        ),
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
                    child: Text(S.actionSave, style: TextStyle(fontWeight: FontWeight.bold)),
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
      confirmLabel: S.actionDelete,
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
                      child: SwitchIn(child: _faqs.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(icon: Icons.quiz_outlined, message: '尚無常見問題'),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              itemCount: _faqs.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_faqs[i], c),
                              ),
                            )),
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
