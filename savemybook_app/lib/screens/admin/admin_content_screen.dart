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
import '../../widgets/guards.dart';
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
  Map<String, String> get _known => {
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
          AppHeader(title: S.legalDocuments, icon: Icons.gavel_outlined),
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
                  doc == null ? S.notCreatedYet : S.updatedP0(formatDate(doc.updatedAt)),
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

enum _EditMode { sections, raw, preview }

class _Section {
  final String id;
  final TextEditingController title;
  final TextEditingController body;
  bool expanded = true;

  _Section({required this.id, String title = '', String body = ''})
      : title = TextEditingController(text: title),
        body = TextEditingController(text: body);

  void dispose() {
    title.dispose();
    body.dispose();
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
  static final _heading = RegExp(r'^\s*(\d{1,3})\s*[.、．)）]\s*(\S.*)$');

  final ApiService _api = ApiService();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle);
  final TextEditingController _introController = TextEditingController();
  final TextEditingController _rawController = TextEditingController();

  final List<_Section> _sections = [];
  final ValueNotifier<String> _stats = ValueNotifier('');

  _EditMode _mode = _EditMode.sections;
  int _nextId = 0;
  bool _isSaving = false;
  bool _dirty = false;

  late String _baseline;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadInto(widget.initialContent);
    _baseline = _compose();
    _titleController.addListener(_onChanged);
    _introController.addListener(_onChanged);
    _rawController.addListener(_onChanged);
    _ready = true;
    _refreshStats();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _introController.dispose();
    _rawController.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    _stats.dispose();
    super.dispose();
  }

  // ---------- 純文字 ⇄ 章節 ----------

  void _loadInto(String content) {
    for (final section in _sections) {
      _retire(section);
    }
    _sections.clear();

    final intro = <String>[];
    for (final block in content.split(RegExp(r'\n\s*\n'))) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final cut = trimmed.indexOf('\n');
      final match = _heading.firstMatch(cut < 0 ? trimmed : trimmed.substring(0, cut));

      if (match != null) {
        _sections.add(_attach(_Section(
          id: 's${_nextId++}',
          title: match.group(2)!.trim(),
          body: cut < 0 ? '' : trimmed.substring(cut + 1).trim(),
        )));
      } else if (_sections.isEmpty) {
        intro.add(trimmed);
      } else {
        final last = _sections.last.body;
        last.text = last.text.isEmpty ? trimmed : '${last.text}\n\n$trimmed';
      }
    }
    _introController.text = intro.join('\n\n');
  }

  _Section _attach(_Section section) {
    section.title.addListener(_onChanged);
    section.body.addListener(_onChanged);
    return section;
  }

  // 這一幀的 TextField 仍握著 controller，當場 dispose 會在 EditableText 解除監聽時踩到已釋放的 notifier。
  void _retire(_Section section) {
    section.title.removeListener(_onChanged);
    section.body.removeListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => section.dispose());
  }

  String _compose() {
    final parts = <String>[];
    final intro = _introController.text.trim();
    if (intro.isNotEmpty) parts.add(intro);

    for (var i = 0; i < _sections.length; i++) {
      final title = _sections[i].title.text.trim();
      final body = _sections[i].body.text.trim();
      if (title.isEmpty && body.isEmpty) continue;
      final head = '${i + 1}. $title';
      parts.add(body.isEmpty ? head : '$head\n$body');
    }
    return parts.join('\n\n');
  }

  String get _content =>
      _mode == _EditMode.raw ? _rawController.text.trim() : _compose();

  void _switchMode(_EditMode mode) {
    if (mode == _mode) return;
    FocusScope.of(context).unfocus();

    setState(() {
      if (mode == _EditMode.raw) {
        _rawController.text = _compose();
      } else if (_mode == _EditMode.raw) {
        _loadInto(_rawController.text);
      }
      _mode = mode;
    });
    _refreshStats();
  }

  // ---------- 狀態 ----------

  void _onChanged() {
    if (!_ready) return;
    _refreshStats();
    final dirty = _titleController.text != widget.initialTitle || _content != _baseline;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _refreshStats() {
    final text = _content;
    final chars = text.replaceAll(RegExp(r'\s'), '').length;
    _stats.value = _mode == _EditMode.raw
        ? S.p0Characters(chars)
        : S.p0SectionsP1Characters(_sections.length, chars);
  }

  // ---------- 章節操作 ----------

  void _addSection() {
    setState(() {
      _sections.add(_attach(_Section(id: 's${_nextId++}')));
    });
    _onChanged();
    HapticFeedback.selectionClick();
  }

  Future<void> _removeSection(int index) async {
    final section = _sections[index];
    final title = section.title.text.trim();
    final hasContent = title.isNotEmpty || section.body.text.trim().isNotEmpty;

    if (hasContent) {
      final ok = await showConfirmDialog(
        context,
        title: S.deleteSection,
        message: title.isEmpty ? S.contentsSectionRemovedWith : S.p0ItsContentsRemoved(title),
        confirmLabel: S.actionDelete,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _retire(_sections.removeAt(index)));
    _onChanged();
  }

  void _reorderSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    setState(() => _sections.insert(newIndex, _sections.removeAt(oldIndex)));
    _onChanged();
    HapticFeedback.selectionClick();
  }

  // ---------- 儲存 ----------

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    final title = _titleController.text.trim();
    final content = _content;

    if (title.isEmpty || content.isEmpty) {
      showAppSnackBar(context, S.bothTitleContentRequired, isError: true);
      return;
    }

    final blank = <int>[];
    for (var i = 0; i < _sections.length; i++) {
      if (_sections[i].title.text.trim().isEmpty &&
          _sections[i].body.text.trim().isNotEmpty) {
        blank.add(i + 1);
      }
    }
    if (_mode != _EditMode.raw && blank.isNotEmpty) {
      final numbers = blank.join('、');
      showAppSnackBar(context, S.sectionP0NoTitleYet(numbers), isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.updateP0(title),
      message: S.documentBindingEveryUserSubmittingReplaces,
      confirmLabel: S.yesUpdate,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final c = AppColors.of(context);
    final major = await showAppPicker<bool>(
      context,
      title: S.majorUpdate,
      subtitle: S.majorUpdateNotifiesEveryUserTerms,
      options: [
        AppSelectOption(value: false, label: S.minorEdit, icon: Icons.edit_note_rounded),
        AppSelectOption(value: true, label: S.majorUpdate2, icon: Icons.campaign_outlined, iconColor: c.warning),
      ],
    );
    if (major == null || !mounted) return;

    setState(() => _isSaving = true);
    final result = await _api.saveLegalDoc(
      widget.docKey,
      title: title,
      content: content,
      major: major,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.error != null) {
      showAppSnackBar(context, result.error!, isError: true);
      return;
    }
    _dirty = false;
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, result.message);
    Navigator.pop(context, true);
  }

  // ---------- 畫面 ----------

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _dirty,
      message: S.documentUnsavedChangesTheyLostIf,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: widget.initialTitle, icon: Icons.edit_note_rounded),
            _buildToolbar(c),
            Expanded(
              child: SwitchIn(
                child: switch (_mode) {
                  _EditMode.sections => _buildSectionEditor(c),
                  _EditMode.raw => _buildRawEditor(c),
                  _EditMode.preview => _buildPreview(c),
                },
              ),
            ),
            _buildBottomBar(c),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      color: c.card,
      child: Row(
        children: [
          _ModeTab(
            label: S.sections,
            icon: Icons.segment_rounded,
            selected: _mode == _EditMode.sections,
            onTap: () => _switchMode(_EditMode.sections),
          ),
          const SizedBox(width: 8),
          _ModeTab(
            label: S.plainText,
            icon: Icons.notes_rounded,
            selected: _mode == _EditMode.raw,
            onTap: () => _switchMode(_EditMode.raw),
          ),
          const SizedBox(width: 8),
          _ModeTab(
            label: S.preview,
            icon: Icons.visibility_rounded,
            selected: _mode == _EditMode.preview,
            onTap: () => _switchMode(_EditMode.preview),
          ),
          const Spacer(),
          ValueListenableBuilder<String>(
            valueListenable: _stats,
            builder: (_, value, _) => Text(
              value,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEditor(AppColors c) {
    return CustomScrollView(
      key: const ValueKey('sections'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(S.documentTitle, c),
                AppTextField(controller: _titleController, hint: S.documentTitle, maxLength: 100),
                const SizedBox(height: 18),
                _fieldLabel(S.preamble, c),
                _buildPlainBox(
                  c,
                  controller: _introController,
                  hint: S.unnumberedOpeningTextLeaveEmptyIf,
                  minHeight: 84,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _fieldLabel(S.articles, c, bottom: 0),
                    const SizedBox(width: 8),
                    Text(
                      S.numberedAutomatically,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverReorderableList(
            itemCount: _sections.length,
            onReorder: _reorderSections,
            proxyDecorator: liftDraggedCard,
            itemBuilder: (_, i) => _buildSectionCard(i, c),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (_sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      S.noArticlesYetAddFirstOne,
                      style: TextStyle(fontSize: 13, color: c.textHint),
                    ),
                  ),
                PressableScale(
                  onTap: _addSection,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                      color: c.accent.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: c.accent),
                        const SizedBox(width: 6),
                        Text(
                          S.addSection,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(int index, AppColors c) {
    final section = _sections[index];
    final collapsed = !section.expanded;

    return Padding(
      key: ValueKey(section.id),
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: collapsed ? c.border : c.accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: collapsed
                        ? Text(
                            section.title.text.trim().isEmpty
                                ? S.untitledSection
                                : section.title.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: section.title.text.trim().isEmpty
                                  ? c.textHint
                                  : c.textPrimary,
                            ),
                          )
                        : TextField(
                            controller: section.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: S.sectionTitle,
                              hintStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: c.textHint,
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: AnimatedRotation(
                      turns: collapsed ? 0 : 0.5,
                      duration: Motion.base,
                      curve: Motion.emphasized,
                      child: Icon(Icons.expand_more_rounded, size: 20, color: c.iconInactive),
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => section.expanded = !section.expanded);
                    },
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
                    onPressed: () => _removeSection(index),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.drag_handle_rounded, size: 20, color: c.iconInactive),
                    ),
                  ),
                ],
              ),
            ),
            Reveal(
              visible: !collapsed,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildPlainBox(
                  c,
                  controller: section.body,
                  hint: S.bodySectionSingleLineBreaksKept,
                  minHeight: 110,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, AppColors c, {double bottom = 8}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
      ),
    );
  }

  Widget _buildPlainBox(
    AppColors c, {
    required TextEditingController controller,
    required String hint,
    required double minHeight,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: c.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: hint,
          hintStyle: TextStyle(color: c.textHint, height: 1.8, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildRawEditor(AppColors c) {
    return Padding(
      key: const ValueKey('raw'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          AppTextField(controller: _titleController, hint: S.documentTitle, maxLength: 100),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: c.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: TextField(
                controller: _rawController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: S.emptyLineStartsParagraphParagraphWhose,
                  hintStyle: TextStyle(color: c.textHint, height: 1.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColors c) {
    final text = _content;

    return ListView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        Row(
          children: [
            Icon(Icons.smartphone_rounded, size: 13, color: c.textHint),
            const SizedBox(width: 5),
            Text(
              S.howUsersSee,
              style: TextStyle(fontSize: 11, color: c.textHint),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.trim().isEmpty
                    ? widget.initialTitle
                    : _titleController.text.trim(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                text.isEmpty ? S.noContentYet : text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.9,
                  color: text.isEmpty ? c.textHint : c.textPrimary,
                ),
              ),
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
                      Text(S.unsaved, style: TextStyle(fontSize: 12, color: c.warning)),
                    ],
                  )
                : Row(
                    key: const ValueKey('clean'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: c.success),
                      const SizedBox(width: 5),
                      Text(S.upDate, style: TextStyle(fontSize: 12, color: c.textHint)),
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
      body: Column(
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
                                      child: _buildSectionHeader(entry.key, entry.value.length, c),
                                    ),
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    );
  }

  Widget _buildSectionHeader(String category, int count, AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
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
