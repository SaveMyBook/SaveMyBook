import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_select.dart';
import '../widgets/guards.dart';
import '../widgets/state_views.dart';
import 'barcode_scanner_screen.dart';
import 'sell_book_detail_screen.dart';
import '../i18n/strings.dart';

class SellBookScreen extends StatefulWidget {
  const SellBookScreen({super.key});

  @override
  State<SellBookScreen> createState() => _SellBookScreenState();
}

class _SellBookScreenState extends State<SellBookScreen> {
  final _isbnController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  List<Category> _categories = [];
  int? _categoryId;
  bool _isLoadingCategories = true;
  bool _showErrors = false;
  bool _lookingUp = false;
  bool _navigating = false;

  Map<String, dynamic>? _draftOffer;
  DateTime? _draftSavedAt;
  Timer? _saveTimer;
  final int _epoch = SellDraft.epoch;
  bool _touched = false;

  List<TextEditingController> get _controllers =>
      [_isbnController, _titleController, _authorController, _publisherController, _descriptionController];

  @override
  void initState() {
    super.initState();
    for (final ctl in _controllers) {
      ctl.addListener(_scheduleSave);
    }
    _loadCategories();
    _checkDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_draftOffer == null) _saveDraftNow(disposing: true);
    for (final ctl in _controllers) {
      ctl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!_isLoadingCategories) setState(() => _isLoadingCategories = true);
    final categories = await ApiService().fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  Future<void> _checkDraft() async {
    final draft = await SellDraft.load();
    if (!mounted || draft == null) return;
    final step1 = draft['step1'];
    final hasStep1 = step1 is Map && step1.values.any((v) => v != null && '$v'.trim().isNotEmpty);
    if (!hasStep1 && draft['step2'] == null) return;
    if (_isDirty) {
      await SellDraft.clear();
      _saveDraftNow();
      return;
    }
    setState(() => _draftOffer = draft);
  }

  Future<void> _resumeDraft() async {
    if (_draftOffer == null) return;
    HapticFeedback.selectionClick();
    final draft = await SellDraft.load();
    if (!mounted) return;
    if (draft == null) {
      setState(() => _draftOffer = null);
      return;
    }
    final step1 = draft['step1'] is Map ? Map<String, dynamic>.from(draft['step1']) : <String, dynamic>{};
    setState(() {
      _isbnController.text = '${step1['isbn'] ?? ''}';
      _titleController.text = '${step1['title'] ?? ''}';
      _authorController.text = '${step1['author'] ?? ''}';
      _publisherController.text = '${step1['publisher'] ?? ''}';
      _descriptionController.text = '${step1['description'] ?? ''}';
      _selectedDate = DateTime.tryParse('${step1['publish_date'] ?? ''}');
      final categoryId = step1['category_id'];
      _categoryId = categoryId is num ? categoryId.toInt() : null;
      _draftOffer = null;
      _touched = true;
    });
    showAppSnackBar(context, S.restoredUnfinishedListing);
  }

  Future<void> _discardDraft() async {
    HapticFeedback.selectionClick();
    setState(() => _draftOffer = null);
    await SellDraft.clear();
    _saveDraftNow();
  }

  void _scheduleSave() {
    _touched = true;
    if (_draftOffer != null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveDraftNow);
  }

  void _saveDraftNow({bool disposing = false}) {
    _saveTimer?.cancel();
    if (!_touched || _draftOffer != null || _epoch != SellDraft.epoch) return;
    if (!_isDirty) {
      SellDraft.saveSection('step1', null);
      if (!disposing && _draftSavedAt != null) setState(() => _draftSavedAt = null);
      return;
    }
    SellDraft.saveSection('step1', {
      'isbn': _isbnController.text.trim(),
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      'publisher': _publisherController.text.trim(),
      'description': _descriptionController.text.trim(),
      'publish_date': _selectedDate == null ? null : _formatDate(_selectedDate!),
      'category_id': _categoryId,
    });
    if (!disposing && mounted) setState(() => _draftSavedAt = DateTime.now());
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool get _isDirty =>
      _categoryId != null || _selectedDate != null || _controllers.any((ctl) => ctl.text.trim().isNotEmpty);

  List<String> get _missing => [
        if (_titleController.text.trim().isEmpty) S.title,
        if (_categoryId == null) S.category,
      ];

  Future<void> _onNext() async {
    if (_navigating) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      _showError(S.enterTitle2);
      return;
    }
    if (_categoryId == null) {
      HapticFeedback.heavyImpact();
      _showError(S.chooseCategory2);
      return;
    }
    final isbn = _isbnController.text.trim();
    if (isbn.isNotEmpty && normalizeIsbn(isbn) == null) {
      HapticFeedback.heavyImpact();
      _showError(S.isbnMust1013DigitsOne(isbn.length));
      return;
    }

    if (_draftOffer != null) {
      _draftOffer = null;
      await SellDraft.clear();
    }
    _saveDraftNow();
    if (!mounted) return;

    _navigating = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellBookDetailScreen(
          isbn: isbn,
          title: title,
          author: _authorController.text.trim(),
          publisher: _publisherController.text.trim(),
          publishDate: _selectedDate == null ? '' : _formatDate(_selectedDate!),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
        ),
      ),
    );
    _navigating = false;
  }

  void _showError(String msg) => showAppSnackBar(context, msg, isError: true);

  Future<void> _onScanISBN() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;

    final isbn = normalizeIsbn(result);
    if (isbn == null || (isbn.length == 13 && !isbn.startsWith('978') && !isbn.startsWith('979'))) {
      HapticFeedback.heavyImpact();
      _showError(S.sNotIsbnBarcodeScanOne);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _isbnController.text = isbn);
    _fetchBookInfoByIsbn(isbn);
  }

  Future<void> _fetchBookInfoByIsbn(String raw) async {
    if (_lookingUp) return;
    FocusScope.of(context).unfocus();
    final isbn = normalizeIsbn(raw);
    if (isbn == null) {
      _showError(S.isbnMust1013DigitsOne(raw.trim().length));
      return;
    }
    if (!isbnChecksumValid(isbn)) {
      HapticFeedback.heavyImpact();
      _showError(S.isbnSCheckDigitInvalidPlease);
      return;
    }

    _lookingUp = true;
    final result = await runBusy(context, () async {
      final primary = await ApiService().fetchBookByIsbn(isbn);
      if (primary != null) return (primary, true);
      return (await _fetchFromBackupApi(isbn), false);
    }, message: S.lookingUpBook);
    _lookingUp = false;
    if (!mounted || result == null) return;

    final (data, fromPrimary) = result;
    if (data == null) {
      _showError(S.noSourceIsbnPleaseEnterDetails);
      return;
    }
    _fillBookData(data);
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, fromPrimary ? S.bookDetailsFilledAutomatically : S.bookDetailsFilledFromBackupSource);
  }

  Future<void> _fillBookData(Map<String, dynamic> bookData) async {
    final hadOffer = _draftOffer != null;
    _touched = true;
    void fill(TextEditingController controller, Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) controller.text = text;
    }

    setState(() {
      if (_draftOffer != null) _draftOffer = null;
      fill(_titleController, bookData['title']);
      fill(_authorController, bookData['author']);
      fill(_publisherController, bookData['publisher']);
      fill(_descriptionController, bookData['description']);
      final date = _parsePublishDate('${bookData['publish_date'] ?? ''}');
      if (date != null) _selectedDate = date;
      final categoryId = bookData['category_id'];
      if (_categoryId == null && categoryId is num && _categories.any((c) => c.categoryId == categoryId)) {
        _categoryId = categoryId.toInt();
      }
    });
    if (hadOffer) await SellDraft.clear();
    _saveDraftNow();
  }

  static DateTime? _parsePublishDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final now = DateTime.now();
    final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.isEmpty) return null;

    var yearIndex = numbers.indexWhere((n) => n >= 1000 && n <= 9999);
    var year = yearIndex < 0 ? null : numbers[yearIndex];
    final roc = RegExp(r'^\s*(民國)?\s*(\d{2,3})\s*年').firstMatch(text);
    if (year == null && roc != null) {
      year = int.parse(roc.group(2)!) + 1911;
      yearIndex = 0;
    }
    if (year == null || year < now.year - 150 || year > now.year) return null;

    var month = 1;
    var day = 1;
    const monthNames = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final lower = text.toLowerCase();
    final named = monthNames.indexWhere(lower.contains);
    if (named >= 0) {
      month = named + 1;
      final others = [for (var i = 0; i < numbers.length; i++) if (i != yearIndex) numbers[i]];
      if (others.isNotEmpty) day = others.first;
    } else {
      final after = numbers.sublist(yearIndex + 1);
      if (after.isNotEmpty) month = after[0];
      if (after.length > 1) day = after[1];
    }
    if (month < 1 || month > 12) month = 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > lastDay) day = 1;

    final date = DateTime(year, month, day);
    return date.isAfter(now) ? DateTime(now.year, now.month, now.day) : date;
  }

  Future<Map<String, dynamic>?> _fetchFromBackupApi(String isbn) async {
    try {
      final url = Uri.parse('https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final bookInfo = data is Map ? data['ISBN:$isbn'] : null;
      if (bookInfo is! Map) return null;

      String names(Object? list) =>
          list is List ? list.whereType<Map>().map((e) => '${e['name'] ?? ''}').where((s) => s.isNotEmpty).join(', ') : '';

      return {
        'title': '${bookInfo['title'] ?? ''}',
        'author': names(bookInfo['authors']),
        'publisher': names(bookInfo['publishers']),
        'publish_date': '${bookInfo['publish_date'] ?? ''}',
      };
    } catch (e) {
      debugPrint('Backup API Error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          _buildAppBar(c),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: _buildStep1(c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AppColors c) {
    final isbnText = _isbnController.text.trim();
    final canLookup = normalizeIsbn(isbnText) != null;

    return Column(
      children: [
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          alignment: Alignment.topCenter,
          child: _draftOffer == null ? const SizedBox(width: double.infinity) : _buildDraftBanner(c),
        ),
        FormRowCard(
          label: 'ISBN',
          labelWidth: 88,
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _isbnController,
                  hint: S.tapIconRightScan,
                  maxLength: 13,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                    TextInputFormatter.withFunction(
                      (_, value) => value.copyWith(text: value.text.toUpperCase()),
                    ),
                  ],
                  suffix: SwitchIn(
                    duration: Motion.micro,
                    child: canLookup
                        ? IconButton(
                            key: const ValueKey('lookup'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.search_rounded, size: 20, color: c.accent),
                            onPressed: () => _fetchBookInfoByIsbn(isbnText),
                          )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) _fetchBookInfoByIsbn(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: S.scan,
                child: PressableScale(
                  haptic: true,
                  onTap: _onScanISBN,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.qr_code_scanner_rounded, size: 20, color: c.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        FormRowCard(
          label: S.title,
          labelWidth: 88,
          isRequired: true,
          child: AppTextField(
            controller: _titleController,
            maxLength: 255,
            textInputAction: TextInputAction.next,
            errorText: _showErrors && _titleController.text.trim().isEmpty ? S.enterTitle2 : null,
            onChanged: (_) => setState(() {}),
          ),
        ),
        FormRowCard(
          label: S.author2,
          labelWidth: 88,
          child: AppTextField(controller: _authorController, maxLength: 255, textInputAction: TextInputAction.next),
        ),
        FormRowCard(
          label: S.publisher2,
          labelWidth: 88,
          child: AppTextField(controller: _publisherController, maxLength: 255, textInputAction: TextInputAction.next),
        ),
        FormRowCard(
          label: S.publicationDate,
          labelWidth: 88,
          child: AppDateField(
            value: _selectedDate,
            hint: S.tapPickPublicationDate,
            helpText: S.pickPublicationDate,
            onChanged: (value) {
              setState(() => _selectedDate = value);
              _scheduleSave();
            },
          ),
        ),
        FormRowCard(
          label: S.pickCategory,
          labelWidth: 88,
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelect<int>(
                value: _categoryId,
                loading: _isLoadingCategories,
                title: S.pickCategory,
                leadingIcon: Icons.category_outlined,
                errorText: _showErrors && _categoryId == null ? S.chooseCategory2 : null,
                options: [
                  for (final cat in _categories) AppSelectOption(value: cat.categoryId, label: cat.categoryName),
                ],
                onChanged: _categories.isEmpty
                    ? null
                    : (value) {
                        setState(() => _categoryId = value);
                        _scheduleSave();
                      },
              ),
              if (!_isLoadingCategories && _categories.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loadCategories,
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(S.couldnTLoadCategoriesTapRetry, style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
        FormRowCard(
          label: S.description,
          labelWidth: 88,
          alignTop: true,
          child: AppTextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            keyboardType: TextInputType.multiline,
          ),
        ),
        const SizedBox(height: 12),
        MissingHint(missing: _missing),
        PrimaryButton(label: S.next, height: 50, icon: Icons.arrow_forward_rounded, onPressed: _onNext),
        AnimatedOpacity(
          opacity: _draftSavedAt == null ? 0 : 1,
          duration: Motion.base,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done_outlined, size: 14, color: c.textHint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    S.draftSavedAutomatically,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textHint),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildDraftBanner(AppColors c) {
    final draft = _draftOffer!;
    final step1 = draft['step1'] is Map ? draft['step1'] as Map : const {};
    final title = '${step1['title'] ?? ''}'.trim();
    final savedAt = DateTime.tryParse('${draft['saved_at'] ?? ''}');
    final detail = [
      if (title.isNotEmpty) title,
      if (savedAt != null) formatRelative(savedAt),
    ].join('・');

    return FadeSlideIn(
      offsetY: 10,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: c.isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_edu_rounded, size: 22, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.continueUnfinishedListing,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: _discardDraft,
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                  child: Text(S.discard),
                ),
                TextButton(
                  onPressed: _resumeDraft,
                  style: TextButton.styleFrom(foregroundColor: c.accent),
                  child: Text(S.actionContinue, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppColors c) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final inTab = context.findAncestorWidgetOfExactType<IndexedStack>() != null;

    return Container(
      decoration: BoxDecoration(color: c.headerBg),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: canPop && !inTab
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        S.sellBook,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '1 / 2',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
