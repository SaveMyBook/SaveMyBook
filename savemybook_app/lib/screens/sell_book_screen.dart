import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_forms.dart';
import 'barcode_scanner_screen.dart';
import 'sell_book_detail_screen.dart';

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
  Category? _selectedCategory;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService().fetchCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_titleController.text.trim().isEmpty) {
      _showError('請輸入書名');
      return;
    }
    if (_selectedCategory == null) {
      _showError('請選擇分類');
      return;
    }

    String formattedDate = '';
    if (_selectedDate != null) {
      formattedDate = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellBookDetailScreen(
          isbn: _isbnController.text.trim(),
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          publisher: _publisherController.text.trim(),
          publishDate: formattedDate,
          description: _descriptionController.text.trim(),
          categoryId: _selectedCategory!.categoryId,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.of(context).danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _onScanISBN() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _isbnController.text = result);
      _fetchBookInfoByIsbn(result);
    }
  }

  Future<void> _fetchBookInfoByIsbn(String isbn) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final bookData = await ApiService().fetchBookByIsbn(isbn);

    if (bookData != null) {
      if (mounted) Navigator.pop(context);
      _fillBookData(bookData);
      _showSuccess('已自動帶入書籍資訊！');
      return;
    }

    final backupData = await _fetchFromBackupApi(isbn);

    if (!mounted) return;
    Navigator.pop(context);

    if (backupData != null) {
      _fillBookData(backupData);
      _showSuccess('已透過備援系統帶入書籍資訊！');
    } else {
      _showError('各系統皆找不到此 ISBN，請嘗試手動輸入');
    }
  }

  void _fillBookData(Map<String, dynamic> bookData) {
    setState(() {
      _titleController.text = bookData['title'] ?? '';
      _authorController.text = bookData['author'] ?? '';
      _publisherController.text = bookData['publisher'] ?? '';
      _descriptionController.text = bookData['description'] ?? '';

      String publishDate = bookData['publish_date'] ?? '';
      if (publishDate.isNotEmpty) {
        publishDate = publishDate.replaceAll(RegExp(r'[年月]'), '-').replaceAll('日', '');
        final parts = publishDate.split('-');
        if (parts.isNotEmpty) {
          int y = int.tryParse(parts[0]) ?? DateTime.now().year;
          int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
          int d = parts.length > 2 ? (int.tryParse(parts[2]) ?? 1) : 1;
          _selectedDate = DateTime(y, m, d);
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _fetchFromBackupApi(String isbn) async {
    try {
      final url = Uri.parse('https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final key = 'ISBN:$isbn';

        if (data.containsKey(key)) {
          final bookInfo = data[key];
          return {
            'title': bookInfo['title'] ?? '',
            'author': (bookInfo['authors'] as List?)?.map((a) => a['name']).join(', ') ?? '',
            'publisher': (bookInfo['publishers'] as List?)?.map((p) => p['name']).join(', ') ?? '',
            'publish_date': bookInfo['publish_date'] ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('Backup API Error: $e');
    }
    return null;
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
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: _buildStep1(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AppColors c) {
    return Column(
      children: [
        _buildFieldRow(c, label: 'ISBN', child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _isbnController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 15, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '可點擊右側圖示掃描',
                  hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: c.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onSubmitted: (val) {
                  if (val.isNotEmpty) _fetchBookInfoByIsbn(val);
                },
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _onScanISBN,
              child: Icon(Icons.qr_code_scanner_rounded, size: 28, color: c.textPrimary),
            ),
          ],
        )),
        _buildFieldRow(c, label: '書名', isRequired: true, child: _buildInput(c, _titleController)),
        _buildFieldRow(c, label: '作者', child: _buildInput(c, _authorController)),
        _buildFieldRow(c, label: '出版社', child: _buildInput(c, _publisherController)),
        _buildFieldRow(
          c,
          label: '出版日期',
          child: AppDateField(
            value: _selectedDate,
            hint: '點擊選擇出版日期',
            helpText: '選擇出版日期',
            onChanged: (value) => setState(() => _selectedDate = value),
          ),
        ),
        _buildFieldRow(c, label: '選擇分類', isRequired: true, child: _buildCategoryDropdown(c)),
        _buildFieldRow(c, label: '書籍簡介', child: _buildInput(c, _descriptionController, maxLines: 4)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('下一步', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _buildAppBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(color: c.headerBg),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 這頁同時是首頁的分頁跟被 push 的路由，只有後者需要返回鍵。
              if (Navigator.of(context).canPop())
                SizedBox(
                  width: 32,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                  ),
                )
              else
                const SizedBox(width: 32),
              const Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('我要賣書', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(AppColors c, {required String label, required Widget child, bool isRequired = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: 90,
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (isRequired)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInput(AppColors c, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(fontSize: 15, color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: c.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCategoryDropdown(AppColors c) {
    return Material(
      color: c.inputFill,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: c.divider), borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Category>(
            value: _selectedCategory,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: c.iconInactive),
            hint: Text('', style: TextStyle(color: c.textHint, fontSize: 15)),
            dropdownColor: c.card,
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(fontSize: 15, color: c.textPrimary),
            items: _isLoadingCategories
                ? [DropdownMenuItem<Category>(value: null, child: Text('載入中...', style: TextStyle(color: c.textHint)))]
                : _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.categoryName))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val),
          ),
        ),
      ),
    );
  }
}