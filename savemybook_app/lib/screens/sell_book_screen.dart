import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
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
      _showError(S.enterTitle2);
      return;
    }
    if (_selectedCategory == null) {
      _showError(S.chooseCategory2);
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

  void _showError(String msg) => showAppSnackBar(context, msg, isError: true);

  void _showSuccess(String msg) => showAppSnackBar(context, msg);

  /// 還沒填完的必填項。列在送出鍵上方，不用按下去撞牆才知道。
  List<String> get _missing => [
        if (_titleController.text.trim().isEmpty) S.title,
        if (_selectedCategory == null) S.category,
      ];

  bool get _isDirty =>
      _selectedCategory != null ||
      _selectedDate != null ||
      [_isbnController, _titleController, _authorController, _publisherController, _descriptionController]
          .any((ctl) => ctl.text.trim().isNotEmpty);

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
    // ISBN 只有 10 或 13 碼。長度不對就直接擋下，不用白跑兩支外部 API。
    if (isbn.length != 10 && isbn.length != 13) {
      _showError(S.isbnMust1013DigitsOne(isbn.length));
      return;
    }

    final result = await runBusy(context, () async {
      final primary = await ApiService().fetchBookByIsbn(isbn);
      if (primary != null) return (primary, true);
      return (await _fetchFromBackupApi(isbn), false);
    }, message: S.lookingUpBook);
    if (!mounted || result == null) return;

    final (data, fromPrimary) = result;
    if (data == null) {
      _showError(S.noSourceIsbnPleaseEnterDetails);
      return;
    }
    _fillBookData(data);
    _showSuccess(fromPrimary
        ? S.bookDetailsFilledAutomatically
        : S.bookDetailsFilledFromBackupSource);
  }

  void _fillBookData(Map<String, dynamic> bookData) {
    setState(() {
      _titleController.text = bookData['title'] ?? '';
      _authorController.text = bookData['author'] ?? '';
      _publisherController.text = bookData['publisher'] ?? '';
      _descriptionController.text = bookData['description'] ?? '';

      String publishDate = bookData['publish_date'] ?? '';
      if (publishDate.isNotEmpty) {
        publishDate = publishDate.replaceAll(RegExp(r'[年月]'), '-').replaceAll(S.day, '');
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

    return UnsavedGuard(
      isDirty: _isDirty,
      child: Scaffold(
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
                // ISBN 只有數字。不擋的話輸入法上的連字號跟空白會一起進來，
                // 查詢必定落空，使用者卻看不出是自己打錯。
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 15, color: c.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: S.tapIconRightScan,
                  hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true, fillColor: c.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) {
                  if (val.isNotEmpty) _fetchBookInfoByIsbn(val.trim());
                },
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: _onScanISBN,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 5),
                    Text(
                      S.scan,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )),
        _buildFieldRow(c, label: S.title, isRequired: true,
            child: _buildInput(c, _titleController, onChanged: (_) => setState(() {}))),
        _buildFieldRow(c, label: S.author2, child: _buildInput(c, _authorController)),
        _buildFieldRow(c, label: S.publisher2, child: _buildInput(c, _publisherController)),
        _buildFieldRow(
          c,
          label: S.publicationDate,
          child: AppDateField(
            value: _selectedDate,
            hint: S.tapPickPublicationDate,
            helpText: S.pickPublicationDate,
            onChanged: (value) => setState(() => _selectedDate = value),
          ),
        ),
        _buildFieldRow(c, label: S.pickCategory, isRequired: true, child: _buildCategoryDropdown(c)),
        _buildFieldRow(c, label: S.description, child: _buildInput(c, _descriptionController, maxLines: 4)),
        const SizedBox(height: 24),
        MissingHint(missing: _missing),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(S.next, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
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
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(S.sellBook, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // 上架分兩步。不標的話使用者在第一步不知道還有第二步，
              // 到了第二步也不知道還有多久結束。
              SizedBox(
                width: 32,
                child: Text(
                  '1 / 2',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
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

  Widget _buildInput(AppColors c, TextEditingController controller,
      {TextInputType? keyboardType, int maxLines = 1, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
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
            hint: Text(S.actionSelect, style: TextStyle(color: c.textHint, fontSize: 15)),
            dropdownColor: c.card,
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(fontSize: 15, color: c.textPrimary),
            items: _categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.categoryName)))
                .toList(),
            // 載入中原本是塞一個假的「載入中…」選項，那是可以選的，選了等於
            // 把分類設成 null。改成整個停用，並用 disabledHint 說明狀態。
            onChanged: _isLoadingCategories ? null : (val) => setState(() => _selectedCategory = val),
            disabledHint: Text(S.loading, style: TextStyle(color: c.textHint, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}