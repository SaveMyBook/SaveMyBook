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
    _isbnController = TextEditingController(text: book.isbn == '未提供 ISBN' ? '' : book.isbn);
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author == '未知作者' ? '' : book.author);
    _publisherController = TextEditingController(text: book.publisher == '未知出版社' ? '' : book.publisher);

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
      showAppSnackBar(context, '請填寫書名', isError: true);
      return;
    }
    if (title.length > 255) {
      showAppSnackBar(context, '書名不可超過 255 個字元', isError: true);
      return;
    }
    if (isbn.isNotEmpty && isbn.length != 10 && isbn.length != 13) {
      showAppSnackBar(context, 'ISBN 應為 10 碼或 13 碼', isError: true);
      return;
    }

    if (_categoryId == null) {
      showAppSnackBar(context, '請選擇書籍分類', isError: true);
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
          const AppHeader(title: '編輯書籍', icon: Icons.edit_note_rounded),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        FormRowCard(
                          label: 'ISBN',
                          child: Row(
                            children: [
                              Expanded(child: AppTextField(controller: _isbnController, keyboardType: TextInputType.number)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _scanIsbn,
                                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        FormRowCard(label: '書名', child: AppTextField(controller: _titleController)),
                        FormRowCard(label: '作者', child: AppTextField(controller: _authorController)),
                        FormRowCard(label: '出版社', child: AppTextField(controller: _publisherController)),
                        FormRowCard(
                          label: '出版日期',
                          child: AppDateField(
                            value: _publishDate,
                            hint: '點擊選擇出版日期',
                            helpText: '選擇出版日期',
                            onChanged: (value) => setState(() => _publishDate = value),
                          ),
                        ),
                        FormRowCard(
                          label: '選擇分類',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _categoryId,
                              isExpanded: true,
                              hint: Text('請選擇', style: TextStyle(color: c.textHint, fontSize: 14)),
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
                            child: const Text('下一步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
