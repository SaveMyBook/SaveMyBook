import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai.dart';
import '../../models/book.dart';
import '../../models/category.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/guards.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../books/barcode_scanner_screen.dart';
import 'ai_listing_assist.dart';
import 'edit_book_detail_screen.dart';
import 'sell_book_screen.dart' show parsePublishDate;
import '../../i18n/strings.dart';

class EditBookScreen extends StatefulWidget {
  final Book book;
  const EditBookScreen({super.key, required this.book});

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  final ApiService _api = ApiService();

  late final TextEditingController _isbnController;
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _publisherController;
  DateTime? _publishDate;

  List<Category> _categories = [];
  int? _categoryId;
  bool _isLoading = true;
  bool _showErrors = false;
  bool _navigating = false;
  bool _saved = false;
  bool _aiRunning = false;
  final Map<String, int> _flash = {};

  late final String _initialIsbn;
  late final String _initialAuthor;
  late final String _initialPublisher;
  DateTime? _initialDate;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _isbnController = TextEditingController(text: book.isbn == S.noIsbn ? '' : book.isbn);
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author == S.unknownAuthor ? '' : book.author);
    _publisherController = TextEditingController(text: book.publisher == S.unknownPublisher ? '' : book.publisher);

    _initialIsbn = _isbnController.text;
    _initialAuthor = _authorController.text;
    _initialPublisher = _publisherController.text;

    _publishDate = DateTime.tryParse(book.publishDate.replaceAll('/', '-'));
    _initialDate = _publishDate;

    _categoryId = book.categoryId;
    _loadCategories();
    AiStatus.refresh();
  }

  static String _formatDate(DateTime? date) => date == null
      ? ''
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _onAiAssist() async {
    if (_aiRunning) return;
    FocusScope.of(context).unfocus();
    final isbnText = _isbnController.text.trim();
    final isbn = normalizeIsbn(isbnText);
    final title = _titleController.text.trim();
    if (isbn == null && title.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterIsbnTitleFirst, isError: true);
      return;
    }
    _aiRunning = true;
    final result = await runAiListingAssist(context, isbn: isbn, title: title);
    _aiRunning = false;
    if (result == null || !mounted) return;
    final selection = await showAiListingResultSheet(
      context,
      result: result,
      targets: AiListingTargets(
        fields: {
          'title': title,
          'author': _authorController.text.trim(),
          'publisher': _publisherController.text.trim(),
          'publish_date': _formatDate(_publishDate),
          'isbn': isbnText,
        },
        categoryId: _categoryId,
        categories: _categories,
        supportsCategory: true,
      ),
    );
    if (selection == null || !mounted) return;
    final flashed = <String>[];
    setState(() {
      for (final key in selection.fields) {
        final value = result.fields[key] ?? '';
        switch (key) {
          case 'title':
            _titleController.text = value;
          case 'author':
            _authorController.text = value;
          case 'publisher':
            _publisherController.text = value;
          case 'isbn':
            final normalized = normalizeIsbn(value);
            if (normalized == null) continue;
            _isbnController.text = normalized;
          case 'publish_date':
            final date = parsePublishDate(value);
            if (date == null) continue;
            _publishDate = date;
        }
        flashed.add(key);
      }
      if (selection.category && result.category != null && _categories.any((c) => c.categoryId == result.category!.categoryId)) {
        _categoryId = result.category!.categoryId;
        flashed.add('category');
      }
      for (final key in flashed) {
        _flash[key] = (_flash[key] ?? 0) + 1;
      }
    });
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.appliedP0AiSuggestions(flashed.length));
  }

  Widget _flashed(String key, Widget child) => AiFlash(trigger: _flash[key] ?? 0, child: child);

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!_isLoading) setState(() => _isLoading = true);
    final categories = await _api.fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (_categoryId != null && categories.isNotEmpty && !categories.any((c) => c.categoryId == _categoryId)) {
        _categoryId = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _scanIsbn() async {
    FocusScope.of(context).unfocus();
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final isbn = normalizeIsbn(code);
    if (isbn == null || (isbn.length == 13 && !isbn.startsWith('978') && !isbn.startsWith('979'))) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.sNotIsbnBarcodeScanOne, isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _isbnController.text = isbn);
  }

  Future<void> _next() async {
    if (_navigating) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);

    final title = _titleController.text.trim();
    final isbn = _isbnController.text.trim();

    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterTitle, isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, S.titleLimited255Characters, isError: true);
      return;
    }
    if (isbn != _initialIsbn && isbn.isNotEmpty && normalizeIsbn(isbn) == null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.isbn1013Digits, isError: true);
      return;
    }
    if (_categoryId == null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.chooseCategory, isError: true);
      return;
    }

    final date = _publishDate;
    final publishDate = date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    _navigating = true;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditBookDetailScreen(
          book: widget.book,
          isbn: isbn,
          title: title,
          author: _authorController.text.trim(),
          publisher: _publisherController.text.trim(),
          publishDate: publishDate,
          categoryId: _categoryId,
        ),
      ),
    );
    _navigating = false;
    if (saved == true && mounted) {
      setState(() => _saved = true);
      Navigator.of(context).pop(true);
    }
  }

  bool get _isDirty =>
      !_saved &&
      (_titleController.text != widget.book.title ||
          _authorController.text.trim() != _initialAuthor ||
          _publisherController.text.trim() != _initialPublisher ||
          _isbnController.text.trim() != _initialIsbn ||
          _categoryId != widget.book.categoryId ||
          _publishDate != _initialDate);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: S.editBook, icon: Icons.edit_note_rounded),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: responsiveListPadding(
                      constraints,
                      maxWidth: Breakpoints.formMaxWidth,
                      top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      children: [
                        ValueListenableBuilder<AiStatusInfo>(
                          valueListenable: AiStatus.listenable,
                          builder: (context, status, _) => AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: status.listingAssist
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AiAssistButton(onTap: _onAiAssist),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ),
                        FadeSlideIn(
                          child: _flashed('isbn', FormRowCard(
                            label: 'ISBN',
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _isbnController,
                                    hint: S.k1013Digits,
                                    maxLength: 13,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                                      TextInputFormatter.withFunction(
                                        (_, value) => value.copyWith(text: value.text.toUpperCase()),
                                      ),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PressableScale(
                                  haptic: true,
                                  onTap: _scanIsbn,
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
                              ],
                            ),
                          )),
                        ),
                        FadeSlideIn(
                          index: 1,
                          child: _flashed('title', FormRowCard(
                            label: S.title,
                            isRequired: true,
                            child: AppTextField(
                              controller: _titleController,
                              hint: S.actionRequired,
                              maxLength: 255,
                              textInputAction: TextInputAction.next,
                              errorText: _showErrors && _titleController.text.trim().isEmpty ? S.enterTitle : null,
                              onChanged: (_) => setState(() {}),
                            ),
                          )),
                        ),
                        FadeSlideIn(
                          index: 2,
                          child: _flashed('author', FormRowCard(
                            label: S.author2,
                            child: AppTextField(
                              controller: _authorController,
                              hint: S.optional,
                              maxLength: 255,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                            ),
                          )),
                        ),
                        FadeSlideIn(
                          index: 3,
                          child: _flashed('publisher', FormRowCard(
                            label: S.publisher2,
                            child: AppTextField(
                              controller: _publisherController,
                              hint: S.optional,
                              maxLength: 255,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                            ),
                          )),
                        ),
                        FadeSlideIn(
                          index: 4,
                          child: _flashed('publish_date', FormRowCard(
                            label: S.publicationDate,
                            child: AppDateField(
                              value: _publishDate,
                              hint: S.tapPickPublicationDate,
                              helpText: S.pickPublicationDate,
                              onChanged: (value) => setState(() => _publishDate = value),
                            ),
                          )),
                        ),
                        FadeSlideIn(
                          index: 5,
                          child: _flashed('category', FormRowCard(
                            label: S.pickCategory,
                            isRequired: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppSelect<int>(
                                  value: _categoryId,
                                  loading: _isLoading,
                                  title: S.pickCategory,
                                  leadingIcon: Icons.category_outlined,
                                  errorText: _showErrors && _categoryId == null ? S.chooseCategory : null,
                                  options: [
                                    for (final cat in _categories)
                                      AppSelectOption(value: cat.categoryId, label: cat.categoryName),
                                  ],
                                  onChanged: _categories.isEmpty ? null : (value) => setState(() => _categoryId = value),
                                ),
                                if (!_isLoading && _categories.isEmpty)
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
                          )),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(label: S.next, icon: Icons.arrow_forward_rounded, onPressed: _next),
                        const SizedBox(height: 40),
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
}
