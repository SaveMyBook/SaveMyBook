import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'barcode_scanner_screen.dart';
import 'edit_book_detail_screen.dart';
import '../i18n/strings.dart';

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

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _isbnController = TextEditingController(text: book.isbn == S.noIsbn ? '' : book.isbn);
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author == S.unknownAuthor ? '' : book.author);
    _publisherController = TextEditingController(text: book.publisher == S.unknownPublisher ? '' : book.publisher);

    _publishDate = DateTime.tryParse(book.publishDate.replaceAll('/', '-'));

    _categoryId = book.categoryId;
    _loadCategories();
  }

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _api.fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (_categoryId != null && !categories.any((c) => c.categoryId == _categoryId)) {
        _categoryId = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _scanIsbn() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      setState(() => _isbnController.text = code);
    }
  }

  void _next() {
    final title = _titleController.text.trim();
    final isbn = _isbnController.text.trim();

    if (title.isEmpty) {
      showAppSnackBar(context, S.enterTitle, isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, S.titleLimited255Characters, isError: true);
      return;
    }
    if (isbn.isNotEmpty && isbn.length != 10 && isbn.length != 13) {
      showAppSnackBar(context, S.isbn1013Digits, isError: true);
      return;
    }

    if (_categoryId == null) {
      showAppSnackBar(context, S.chooseCategory, isError: true);
      return;
    }

    final date = _publishDate;
    final publishDate = date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    Navigator.push(
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
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.editBook, icon: Icons.edit_note_rounded),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                    child: Column(
                      children: [
                        FormRowCard(
                          label: 'ISBN',
                          child: Row(
                            children: [
                              Expanded(child: AppTextField(controller: _isbnController, hint: S.k1013Digits, keyboardType: TextInputType.number)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _scanIsbn,
                                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        FormRowCard(label: S.title, child: AppTextField(controller: _titleController, hint: S.required)),
                        FormRowCard(label: S.author2, child: AppTextField(controller: _authorController, hint: S.optional)),
                        FormRowCard(label: S.publisher2, child: AppTextField(controller: _publisherController, hint: S.optional)),
                        FormRowCard(
                          label: S.publicationDate,
                          child: AppDateField(
                            value: _publishDate,
                            hint: S.tapPickPublicationDate,
                            helpText: S.pickPublicationDate,
                            onChanged: (value) => setState(() => _publishDate = value),
                          ),
                        ),
                        FormRowCard(
                          label: S.pickCategory,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _categoryId,
                              isExpanded: true,
                              hint: Text(S.actionSelect, style: TextStyle(color: c.textHint, fontSize: 14)),
                              dropdownColor: c.card,
                              style: TextStyle(color: c.textPrimary, fontSize: 14),
                              items: _categories
                                  .map((cat) => DropdownMenuItem(
                                        value: cat.categoryId,
                                        child: Text(cat.categoryName),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _categoryId = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(S.next, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    );
  }
}
