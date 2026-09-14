import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/motion.dart';
import '../animations.dart';
import '../app_dialogs.dart';
import '../app_forms.dart';
import '../app_header.dart';
import '../buyer/undo_snackbar.dart';
import '../guards.dart';
import '../state_views.dart';
import 'legal_draft_store.dart';
import 'legal_save_sheet.dart';
import 'legal_section.dart';
import 'legal_section_page.dart';
import 'legal_text.dart';

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
                bottom: _buildHeaderBar(c),
              ),
            ),
            _buildStatusStrip(c),
            Reveal(
              visible: _pendingDraft != null,
              child: _bannerDraft == null ? const SizedBox(width: double.infinity) : _buildDraftBanner(_bannerDraft!, c),
            ),
            Expanded(
              child: SwitchIn(
                child: switch (_mode) {
                  _Mode.sections => _buildSections(c),
                  _Mode.raw => _buildRaw(c),
                  _Mode.preview => _buildPreview(c),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(AppColors c) {
    final canSave = _dirty && !_saving && !_busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegments(
              labels: [S.sections, S.plainText, S.preview],
              selected: _mode.index,
              onSelect: (i) => _switchMode(_Mode.values[i]),
            ),
          ),
          const SizedBox(width: 10),
          PressableScale(
            scale: 0.95,
            onTap: canSave ? _save : null,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              height: 36,
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _dirty ? Colors.white : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.headerBg),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: Motion.base,
                          width: _dirty ? 7 : 0,
                          height: 7,
                          margin: EdgeInsets.only(right: _dirty ? 6 : 0),
                          decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle),
                        ),
                        Text(
                          S.actionSave,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _dirty ? c.headerBg : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(AppColors c) {
    final doc = _doc;
    final String label;
    final IconData icon;
    final Color tint;

    if (_dirty) {
      label = _draftSaved ? '${S.unsaved}・${S.draftSavedAutomatically}' : S.unsaved;
      icon = Icons.edit_rounded;
      tint = c.warning;
    } else if (doc == null) {
      label = S.notCreatedYet;
      icon = Icons.fiber_new_outlined;
      tint = c.textHint;
    } else {
      final updated = S.updatedP0(formatDateTime(doc.updatedAt));
      label = S.versionP0P1(doc.version, updated);
      icon = Icons.check_circle_rounded;
      tint = c.success;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          SwitchIn(
            duration: Motion.micro,
            child: Icon(icon, key: ValueKey(icon), size: 14, color: tint),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: _dirty ? c.warning : c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: ValueListenableBuilder<String>(
              valueListenable: _stats,
              builder: (_, value, _) => Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftBanner(LegalDraft draft, AppColors c) {
    final stale = draft.baseUpdatedAt != _doc?.updatedAt?.toIso8601String();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.warning.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restore_rounded, size: 18, color: c.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.unsavedDraftFromP0Found(formatDateTime(draft.savedAt)),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
              ],
            ),
            if (stale) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  S.documentWasUpdatedAfterDraftWas,
                  style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _discardDraft,
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: Text(S.discardDraft, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: _restoreDraft,
                    style: TextButton.styleFrom(foregroundColor: c.accent),
                    child: Text(S.restoreDraft, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(S.documentTitle, c),
          AppTextField(
            controller: _title,
            hint: S.documentTitle,
            maxLength: 100,
            errorText: _showTitleError ? S.enterDocumentTitle : null,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
      ),
    );
  }

  Widget _buildSections(AppColors c) {
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
                _buildTitleCard(c),
                const SizedBox(height: 12),
                _buildIntroRow(c),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${S.articles}（${_sections.length}）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_sections.length > 1)
                      Expanded(
                        child: Text(
                          S.dragHandleRightReorder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
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
            onReorder: _reorder,
            proxyDecorator: _liftDragged,
            itemBuilder: (_, i) => _buildSectionRow(i, c),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 32 + bottomInset),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (_sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      S.noArticlesYetAddFirstOne,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: c.textHint),
                    ),
                  ),
                PressableScale(
                  onTap: () => _addSection(),
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
                        Flexible(
                          child: Text(
                            S.addSection,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.accent),
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

  Widget _buildIntroRow(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: () => _openSection(-1),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _intro,
        builder: (_, value, _) {
          final text = value.text.trim();
          return Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(Icons.notes_rounded, size: 16, color: c.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.preamble,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.isEmpty ? S.unnumberedOpeningTextLeaveEmptyIf : _snippet(text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: text.isEmpty ? c.textHint : c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.iconInactive),
            ],
          );
        },
      ),
    );
  }

  String _snippet(String text) => '${S.p0Characters(LegalText.charCount(text))}・${text.trim().split('\n').first}';

  Widget _buildSectionRow(int index, AppColors c) {
    final section = _sections[index];

    return Padding(
      key: ValueKey(section.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: Reveal(
        visible: !section.removing,
        child: FadeSlideIn(
          index: math.min(index, 8),
          offsetY: 12,
          child: ListenableBuilder(
            listenable: Listenable.merge([section.title, section.body]),
            builder: (context, _) {
              final title = section.title.text.trim();
              final body = section.body.text.trim();
              final flagged = _flagged.contains(section.id);

              return AnimatedContainer(
                duration: Motion.base,
                curve: Motion.standard,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: flagged ? c.danger : c.border, width: flagged ? 1.4 : 1),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => _openSection(_sections.indexOf(section)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (flagged ? c.danger : c.accent).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: flagged ? c.danger : c.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.isEmpty ? (flagged ? S.sectionTitleRequired : S.untitledSection) : title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: title.isEmpty ? (flagged ? c.danger : c.textHint) : c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  body.isEmpty ? S.noContentYet : _snippet(body),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: body.isEmpty ? c.textHint : c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.more_horiz_rounded, size: 20, color: c.iconInactive),
                            onPressed: () => _showRowMenu(_sections.indexOf(section)),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 40,
                              height: 44,
                              child: Icon(Icons.drag_indicator_rounded, size: 20, color: c.iconInactive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRaw(AppColors c) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      key: const ValueKey('raw'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottomInset),
      children: [
        _buildTitleCard(c),
        const SizedBox(height: 12),
        if (_formatNotice) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.documentSFormatDoesNotFully,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildHelpCard(c),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: _raw,
            maxLines: null,
            minLines: 14,
            keyboardType: TextInputType.multiline,
            scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: S.enterPasteFullTextHere,
              hintStyle: TextStyle(color: c.textHint, height: 1.8, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _raw,
          builder: (_, value, _) {
            final count = LegalText.parse(value.text).sections.length;
            return Row(
              children: [
                Icon(Icons.segment_rounded, size: 13, color: c.textHint),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    count == 0 ? S.noSectionHeadingsDetected : S.p0SectionsDetected(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textHint),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHelpCard(AppColors c) {
    final rules = [
      S.paragraphWhoseFirstLine1Title,
      S.sectionNumbersMustStart1Increase,
      S.blankLineStartsNewParagraphSingle,
      S.whenSwitchingSectionsAskedConfirmAny,
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => setState(() => _helpOpen = !_helpOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.howSectionHeadingsDetected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _helpOpen ? 0.5 : 0,
                    duration: Motion.base,
                    curve: Motion.emphasized,
                    child: Icon(Icons.expand_more_rounded, size: 20, color: c.iconInactive),
                  ),
                ],
              ),
            ),
          ),
          Reveal(
            visible: _helpOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: c.textHint, shape: BoxShape.circle),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rule,
                              style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColors c) {
    final content = _content;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final updatedAt = _dirty ? DateTime.now() : _doc?.updatedAt ?? DateTime.now();

    return ListView(
      key: const ValueKey('preview'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + bottomInset),
      children: [
        Row(
          children: [
            Icon(Icons.smartphone_rounded, size: 13, color: c.textHint),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                S.howUsersSee,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.scaffold,
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 46,
                color: c.headerBg,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                alignment: Alignment.center,
                child: Text(
                  _displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        content.isEmpty ? S.noContentYet : content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.9,
                          color: content.isEmpty ? c.textHint : c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      S.lastUpdated(formatDate(updatedAt)),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _liftDragged(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeOut.transform(animation.value);
      final c = AppColors.of(context);
      return Transform.scale(
        scale: 1 + 0.03 * t,
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
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
        ),
      );
    },
  );
}

class _ModeSegments extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ModeSegments({required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.emphasized,
                left: width * selected,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.control - 3),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.base,
                                  style: DefaultTextStyle.of(context).style.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: i == selected ? c.headerBg : Colors.white.withValues(alpha: 0.85),
                                  ),
                                  child: Text(labels[i], maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
