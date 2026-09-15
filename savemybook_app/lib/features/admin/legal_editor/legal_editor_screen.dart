import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../i18n/strings.dart';
import '../../../models/support.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/buyer/undo_snackbar.dart';
import '../../../widgets/guards.dart';
import '../../../widgets/state_views.dart';
import 'legal_draft_store.dart';
import 'legal_editor_banners.dart';
import 'legal_editor_header.dart';
import 'legal_preview.dart';
import 'legal_raw_panels.dart';
import 'legal_save_sheet.dart';
import 'legal_section.dart';
import 'legal_section_list.dart';
import 'legal_section_page.dart';
import 'legal_text.dart';
import 'legal_title_card.dart';

enum _Mode { sections, raw, preview }

enum _RowAction { edit, rename, insert, up, down, delete }

class LegalEditorScreen extends StatefulWidget {
  final String docKey;
  final String fallbackTitle;
  final LegalDoc? doc;
  final bool requiresConsent;

  const LegalEditorScreen({
    super.key,
    required this.docKey,
    required this.fallbackTitle,
    required this.doc,
    required this.requiresConsent,
  });

  @override
  State<LegalEditorScreen> createState() => _LegalEditorScreenState();
}

class _LegalEditorScreenState extends State<LegalEditorScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();

  late LegalDoc? _doc = widget.doc;
  late final TextEditingController _title = TextEditingController(text: widget.doc?.title ?? widget.fallbackTitle);
  final TextEditingController _intro = TextEditingController();
  final TextEditingController _raw = TextEditingController();
  final List<LegalSection> _sections = [];
  final Set<LegalSection> _detached = {};
  final ValueNotifier<String> _stats = ValueNotifier('');

  _Mode _mode = _Mode.sections;
  bool _rawSource = false;
  String? _sectionsSnapshot;
  ({String raw, String composed})? _conversion;
  bool _formatNotice = false;
  bool _helpOpen = false;

  late String _baseTitle;
  late String _baseContent;

  bool _dirty = false;
  bool _busy = false;
  bool _saving = false;
  bool _showTitleError = false;
  Set<String> _flagged = {};

  LegalDraft? _pendingDraft;
  LegalDraft? _bannerDraft;
  bool _draftSaved = false;
  bool _discarding = false;
  Timer? _draftTimer;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final content = widget.doc?.content ?? '';
    _baseTitle = _title.text.trim();
    _baseContent = LegalText.normalize(content).trim();

    final structure = LegalText.parse(content);
    if (content.trim().isNotEmpty && (structure.sections.isEmpty || !LegalText.isLossless(content))) {
      _rawSource = true;
      _mode = _Mode.raw;
      _formatNotice = structure.sections.isNotEmpty;
      _raw.text = LegalText.normalize(content);
    } else {
      _loadSections(content);
    }
    _helpOpen = content.trim().isEmpty;

    _title.addListener(_onChanged);
    _intro.addListener(_onChanged);
    _raw.addListener(_onChanged);
    _refreshStats();
    _checkDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_draftTimer?.isActive ?? false) {
      _draftTimer!.cancel();
      _persistDraft();
    }
    _title.dispose();
    _intro.dispose();
    _raw.dispose();
    for (final section in [..._sections, ..._detached]) {
      section.dispose();
    }
    _stats.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && (_draftTimer?.isActive ?? false)) {
      _draftTimer!.cancel();
      _persistDraft();
    }
  }

  LegalSection _attach(LegalSection section) {
    section.title.addListener(_onChanged);
    section.body.addListener(_onChanged);
    return section;
  }

  // 被刪除章節的 controller 可能仍掛在退場中的章節頁 TextField 上，立即 dispose 會在其解除監聽時拋錯。
  void _retire(LegalSection section) {
    section.title.removeListener(_onChanged);
    section.body.removeListener(_onChanged);
    _detached.remove(section);
    Future.delayed(const Duration(seconds: 1), section.dispose);
  }

  void _loadSections(String content) {
    for (final section in _sections) {
      _retire(section);
    }
    _sections.clear();
    final structure = LegalText.parse(content);
    _intro.text = structure.intro;
    for (final data in structure.sections) {
      _sections.add(_attach(LegalSection(id: 's${_nextId++}', title: data.title, body: data.body)));
    }
    _sectionsSnapshot = _composeSections();
  }

  String _composeSections() => LegalText.compose(_intro.text, [for (final s in _sections) s.data]);

  String get _content => LegalText.normalize(_rawSource ? _raw.text : _composeSections()).trim();

  String get _displayTitle => _title.text.trim().isEmpty ? widget.fallbackTitle : _title.text.trim();

  void _onChanged() {
    _refreshStats();
    final dirty = _title.text.trim() != _baseTitle || _content != _baseContent;
    final flagged = _flagged.isEmpty ? _flagged : {for (final s in _sections) if (s.missingTitle && _flagged.contains(s.id)) s.id};
    final titleError = _showTitleError && _title.text.trim().isEmpty;

    if (dirty != _dirty || flagged.length != _flagged.length || titleError != _showTitleError) {
      setState(() {
        _dirty = dirty;
        _flagged = flagged;
        _showTitleError = titleError;
      });
    }
    _scheduleDraft();
  }

  void _refreshStats() {
    final content = _content;
    final chars = LegalText.charCount(content);
    _stats.value = _rawSource
        ? S.p0Characters(chars)
        : S.p0SectionsP1Characters(_sections.where((s) => !s.isBlank).length, chars);
  }

  void _scheduleDraft() {
    if (_pendingDraft != null || _discarding) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (_discarding || _pendingDraft != null) return;
    if (!_dirty) {
      await LegalDraftStore.clear(widget.docKey);
      return;
    }
    await LegalDraftStore.save(
      widget.docKey,
      LegalDraft(
        title: _title.text,
        content: _content,
        raw: _rawSource,
        baseUpdatedAt: _doc?.updatedAt?.toIso8601String(),
        savedAt: DateTime.now(),
      ),
    );
    if (mounted && !_draftSaved && _dirty) setState(() => _draftSaved = true);
  }

  Future<void> _checkDraft() async {
    final draft = await LegalDraftStore.load(widget.docKey);
    if (!mounted || draft == null) return;
    if (draft.title.trim() == _baseTitle && LegalText.normalize(draft.content).trim() == _baseContent) {
      await LegalDraftStore.clear(widget.docKey);
      return;
    }
    setState(() {
      _pendingDraft = draft;
      _bannerDraft = draft;
    });
  }

  void _restoreDraft() {
    final draft = _pendingDraft;
    if (draft == null) return;
    FocusScope.of(context).unfocus();
    _pendingDraft = null;
    _conversion = null;
    _formatNotice = false;
    if (draft.raw) {
      _rawSource = true;
      _sectionsSnapshot = null;
      _raw.text = draft.content;
      if (_mode == _Mode.sections) _mode = _Mode.raw;
    } else {
      _rawSource = false;
      _loadSections(draft.content);
      if (_mode == _Mode.raw) _mode = _Mode.sections;
    }
    _title.text = draft.title;
    setState(() {});
    _onChanged();
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.draftRestored);
  }

  Future<void> _discardDraft() async {
    setState(() => _pendingDraft = null);
    await LegalDraftStore.clear(widget.docKey);
    if (mounted && _dirty) _scheduleDraft();
  }

  Future<void> _switchMode(_Mode mode) async {
    if (mode == _mode) return;
    FocusScope.of(context).unfocus();

    if (mode == _Mode.raw && !_rawSource) {
      final composed = _composeSections();
      final conversion = _conversion;
      _raw.text = conversion != null && conversion.composed == composed ? conversion.raw : composed;
      _sectionsSnapshot = composed;
      _rawSource = true;
    } else if (mode == _Mode.sections && _rawSource) {
      if (!await _convertRawToSections()) return;
      if (!mounted) return;
    }

    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
    _onChanged();
  }

  Future<bool> _convertRawToSections() async {
    final text = LegalText.normalize(_raw.text);
    final snapshot = _sectionsSnapshot;
    if (snapshot != null && snapshot == text) {
      _rawSource = false;
      return true;
    }

    final structure = LegalText.parse(text);
    if (!LegalText.isLossless(text)) {
      final ok = await showConfirmDialog(
        context,
        title: S.convertSections,
        message: S.currentContentDoesNotFullyMatch,
        confirmLabel: S.convert,
        cancelLabel: S.keepPlainText,
        icon: Icons.segment_rounded,
      );
      if (!ok || !mounted) return false;
    }

    _rawSource = false;
    _formatNotice = false;
    _loadSections(text);
    _conversion = (raw: _raw.text, composed: _sectionsSnapshot!);
    if (structure.sections.isEmpty && text.trim().isNotEmpty) {
      showAppSnackBar(context, S.noSectionHeadingsDetectedFullText);
    }
    return true;
  }

  int _insertSection(int at) {
    final section = _attach(LegalSection(id: 's${_nextId++}'));
    setState(() => _sections.insert(at, section));
    _onChanged();
    return at;
  }

  Future<void> _openSection(int index, {String? freshId}) async {
    FocusScope.of(context).unfocus();
    final existing = {for (final s in _sections) if (s.id != freshId) s.id};
    final deleteIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalSectionPage(
          sections: _sections,
          intro: _intro,
          initialIndex: index,
          onAppend: () => _insertSection(_sections.length),
        ),
      ),
    );
    if (!mounted) return;
    final target = deleteIndex != null && deleteIndex < _sections.length ? _sections[deleteIndex] : null;
    final abandoned = [for (final s in _sections) if (!existing.contains(s.id) && s.isBlank && s != target) s];
    setState(() => _sections.removeWhere(abandoned.contains));
    for (final section in abandoned) {
      _retire(section);
    }
    if (abandoned.isNotEmpty) _onChanged();
    if (target != null) _deleteSection(target, confirmed: true);
  }

  Future<void> _addSection({int? after}) async {
    HapticFeedback.selectionClick();
    final index = _insertSection(after == null ? _sections.length : after + 1);
    final id = _sections[index].id;
    await Future<void>.delayed(Motion.micro);
    if (!mounted) return;
    final current = _sections.indexWhere((s) => s.id == id);
    if (current >= 0) _openSection(current, freshId: id);
  }

  Future<void> _deleteSection(LegalSection section, {bool confirmed = false}) async {
    final title = section.title.text.trim();
    final hasContent = !section.isBlank;

    if (!confirmed && hasContent) {
      final ok = await showConfirmDialog(
        context,
        title: S.deleteSection,
        message: title.isEmpty ? S.contentsSectionRemovedWith : S.p0ItsContentsRemoved(title),
        confirmLabel: S.actionDelete,
        isDestructive: true,
      );
      if (!ok || !mounted) return;
    }

    HapticFeedback.mediumImpact();
    setState(() => section.removing = true);
    await Future<void>.delayed(Motion.base);
    if (!mounted) return;

    final at = _sections.indexOf(section);
    if (at < 0) return;
    setState(() {
      _sections.removeAt(at);
      section.removing = false;
      _flagged.remove(section.id);
    });
    _detached.add(section);
    _onChanged();

    if (!hasContent) {
      _retire(section);
      return;
    }

    final name = title.isEmpty ? S.untitledSection : title;
    final undo = await showUndoSnackBar(context, S.deletedP0(name));
    if (!mounted) return;
    if (undo) {
      _detached.remove(section);
      setState(() => _sections.insert(math.min(at, _sections.length), section));
      _onChanged();
    } else {
      _retire(section);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    _moveSection(oldIndex, newIndex > oldIndex ? newIndex - 1 : newIndex);
  }

  void _moveSection(int from, int to) {
    if (to < 0 || to >= _sections.length || from == to) return;
    setState(() => _sections.insert(to, _sections.removeAt(from)));
    _onChanged();
    HapticFeedback.selectionClick();
  }

  Future<void> _renameSection(LegalSection section) async {
    final value = await showTextInputDialog(
      context,
      title: S.renameSection,
      hint: S.sectionTitle,
      initialValue: section.title.text,
      maxLength: LegalText.maxTitleLength,
      confirmLabel: S.actionSave,
    );
    if (value == null || !mounted) return;
    section.title.text = value.trim();
    setState(() {});
  }

  Future<void> _showRowMenu(int index) async {
    final c = AppColors.of(context);
    final section = _sections[index];
    final title = section.title.text.trim();

    final action = await showOptionSheet<_RowAction>(
      context,
      title: title.isEmpty ? S.untitledSection : title,
      options: [
        SheetOption(value: _RowAction.edit, label: S.editContent, icon: Icons.edit_note_rounded),
        SheetOption(value: _RowAction.rename, label: S.rename, icon: Icons.drive_file_rename_outline_rounded),
        SheetOption(value: _RowAction.insert, label: S.addSectionBelow, icon: Icons.playlist_add_rounded),
        if (index > 0) SheetOption(value: _RowAction.up, label: S.moveUp, icon: Icons.arrow_upward_rounded),
        if (index < _sections.length - 1)
          SheetOption(value: _RowAction.down, label: S.moveDown, icon: Icons.arrow_downward_rounded),
        SheetOption(
          value: _RowAction.delete,
          label: S.actionDelete,
          icon: Icons.delete_outline_rounded,
          color: c.danger,
        ),
      ],
    );
    if (action == null || !mounted) return;

    final current = _sections.indexOf(section);
    if (current < 0) return;
    switch (action) {
      case _RowAction.edit:
        _openSection(current);
      case _RowAction.rename:
        _renameSection(section);
      case _RowAction.insert:
        _addSection(after: current);
      case _RowAction.up:
        _moveSection(current, current - 1);
      case _RowAction.down:
        _moveSection(current, current + 1);
      case _RowAction.delete:
        _deleteSection(section);
    }
  }

  Future<void> _save() async {
    if (_busy || !_dirty) return;
    FocusScope.of(context).unfocus();

    final title = _title.text.trim();
    final content = _content;

    if (title.isEmpty) {
      setState(() => _showTitleError = true);
      if (_mode == _Mode.preview) setState(() => _mode = _rawSource ? _Mode.raw : _Mode.sections);
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterDocumentTitle, isError: true);
      return;
    }
    if (content.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterDocumentContent, isError: true);
      return;
    }
    if (!_rawSource) {
      final missing = [for (var i = 0; i < _sections.length; i++) if (_sections[i].missingTitle) i];
      if (missing.isNotEmpty) {
        setState(() {
          _flagged = {for (final i in missing) _sections[i].id};
          _mode = _Mode.sections;
        });
        HapticFeedback.heavyImpact();
        showAppSnackBar(context, S.sectionP0NoTitleYet(missing.map((i) => i + 1).join('、')), isError: true);
        return;
      }
    }

    _busy = true;
    try {
      final contentChanged = content != _baseContent;
      final major = await showLegalSaveSheet(
        context,
        title: title,
        currentVersion: _doc?.version,
        requiresConsent: widget.requiresConsent,
        contentChanged: contentChanged,
        diff: LegalText.diff(
          oldTitle: _baseTitle,
          oldContent: _baseContent,
          newTitle: title,
          newContent: content,
        ),
      );
      if (major == null || !mounted) return;

      setState(() => _saving = true);
      final result = await _api.saveLegalDoc(widget.docKey, title: title, content: content, major: major);
      if (!mounted) return;
      setState(() => _saving = false);

      if (result.error != null) {
        HapticFeedback.heavyImpact();
        showAppSnackBar(context, result.error!, isError: true);
        return;
      }

      _draftTimer?.cancel();
      await LegalDraftStore.clear(widget.docKey);
      final previous = _doc;
      final bumped = major && contentChanged;
      final version = previous == null ? 1 : (bumped ? previous.version + 1 : previous.version);

      if (!mounted) return;
      setState(() {
        _baseTitle = title;
        _baseContent = content;
        _dirty = false;
        _draftSaved = false;
        _doc = LegalDoc(
          docId: previous?.docId ?? 0,
          key: widget.docKey,
          title: title,
          content: content,
          version: version,
          updatedAt: DateTime.now(),
        );
      });
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, bumped ? S.p0NowVersionP1(result.message, version) : result.message);
      _refreshDoc();
    } finally {
      _busy = false;
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _refreshDoc() async {
    final docs = await _api.fetchAdminLegalDocs();
    final fresh = docs.where((d) => d.key == widget.docKey).firstOrNull;
    if (!mounted || fresh == null) return;
    setState(() => _doc = fresh);
  }

  Future<void> _handlePop() async {
    final navigator = Navigator.of(context);
    if (!await UnsavedGuard.confirm(context, message: S.documentUnsavedChangesTheyLostIf)) return;
    _discarding = true;
    _draftTimer?.cancel();
    await LegalDraftStore.clear(widget.docKey);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _title,
              builder: (_, _, _) => AppHeader(
                title: _displayTitle,
                bottom: LegalEditorHeaderBar(
                  selectedMode: _mode.index,
                  onSelectMode: (i) => _switchMode(_Mode.values[i]),
                  dirty: _dirty,
                  saving: _saving,
                  onSave: _dirty && !_saving && !_busy ? _save : null,
                ),
              ),
            ),
            LegalStatusStrip(doc: _doc, dirty: _dirty, draftSaved: _draftSaved, stats: _stats),
            Reveal(
              visible: _pendingDraft != null,
              child: _bannerDraft == null
                  ? const SizedBox(width: double.infinity)
                  : LegalDraftBanner(draft: _bannerDraft!, doc: _doc, onDiscard: _discardDraft, onRestore: _restoreDraft),
            ),
            Expanded(
              child: SwitchIn(
                child: switch (_mode) {
                  _Mode.sections => _buildSections(),
                  _Mode.raw => _buildRaw(),
                  _Mode.preview => LegalPreview(
                      key: const ValueKey('preview'),
                      title: _displayTitle,
                      content: _content,
                      updatedAt: _dirty ? DateTime.now() : _doc?.updatedAt ?? DateTime.now(),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      key: const ValueKey('sections'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LegalTitleCard(controller: _title, showError: _showTitleError),
                const SizedBox(height: 12),
                LegalIntroRow(intro: _intro, onTap: () => _openSection(-1)),
                const SizedBox(height: 20),
                LegalSectionsHeading(count: _sections.length),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverReorderableList(
            itemCount: _sections.length,
            onReorder: _reorder,
            proxyDecorator: legalLiftDragged,
            itemBuilder: (_, i) {
              final section = _sections[i];
              return LegalSectionRow(
                key: ValueKey(section.id),
                section: section,
                index: i,
                flagged: _flagged.contains(section.id),
                onOpen: () => _openSection(_sections.indexOf(section)),
                onMenu: () => _showRowMenu(_sections.indexOf(section)),
              );
            },
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 32 + bottomInset),
          sliver: SliverToBoxAdapter(
            child: LegalAddSectionButton(showEmptyHint: _sections.isEmpty, onTap: () => _addSection()),
          ),
        ),
      ],
    );
  }

  Widget _buildRaw() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const ValueKey('raw'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomInset),
      children: [
        LegalTitleCard(controller: _title, showError: _showTitleError),
        const SizedBox(height: 12),
        if (_formatNotice) ...[
          const LegalFormatNotice(),
          const SizedBox(height: 12),
        ],
        LegalFormatHelpCard(open: _helpOpen, onToggle: () => setState(() => _helpOpen = !_helpOpen)),
        const SizedBox(height: 12),
        LegalRawTextField(controller: _raw),
        const SizedBox(height: 8),
        LegalDetectedSectionCount(controller: _raw),
      ],
    );
  }
}
