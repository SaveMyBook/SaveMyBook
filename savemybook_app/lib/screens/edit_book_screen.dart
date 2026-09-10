import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'barcode_scanner_screen.dart';
import 'edit_book_detail_screen.dart';

/// 編輯書籍 (1/2)：ISBN、書名、作者、出版社、出版日期、分類
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
  late final TextEditingController _yearController;
  late final TextEditingController _monthController;
  late final TextEditingController _dayController;

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

    final parts = book.publishDate.split(RegExp(r'[-/]'));
    _yearController = TextEditingController(text: parts.isNotEmpty ? parts[0] : '');
    _monthController = TextEditingController(text: parts.length > 1 ? parts[1] : '');
    _dayController = TextEditingController(text: parts.length > 2 ? parts[2] : '');

    _categoryId = book.categoryId;
    _loadCategories();
  }

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
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
    if (_titleController.text.trim().isEmpty) {
      showAppSnackBar(context, '請填寫書名', isError: true);
      return;
    }

    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();
    final publishDate = [year, month, day].where((e) => e.isNotEmpty).join('-');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBookDetailScreen(
          book: widget.book,
          isbn: _isbnController.text.trim(),
          title: _titleController.text.trim(),
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
            child: _isLoading
                ? const LoadingView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _FormRow(
                          label: 'ISBN',
                          child: Row(
                            children: [
                              Expanded(child: _textField(_isbnController, c, keyboardType: TextInputType.number)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _scanIsbn,
                                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        _FormRow(label: '書名', child: _textField(_titleController, c)),
                        _FormRow(label: '作者', child: _textField(_authorController, c)),
                        _FormRow(label: '出版社', child: _textField(_publisherController, c)),
                        _FormRow(
                          label: '出版日期',
                          child: Row(
                            children: [
                              Expanded(child: _textField(_yearController, c, keyboardType: TextInputType.number)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('年', style: TextStyle(color: c.textPrimary)),
                              ),
                              Expanded(child: _textField(_monthController, c, keyboardType: TextInputType.number)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('月', style: TextStyle(color: c.textPrimary)),
                              ),
                              Expanded(child: _textField(_dayController, c, keyboardType: TextInputType.number)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('日', style: TextStyle(color: c.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                        _FormRow(
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
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('下一步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController controller, AppColors c, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
