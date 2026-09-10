import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class EditBookDetailScreen extends StatefulWidget {
  final Book book;
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String publishDate;
  final int? categoryId;

  const EditBookDetailScreen({
    super.key,
    required this.book,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.categoryId,
  });

  @override
  State<EditBookDetailScreen> createState() => _EditBookDetailScreenState();
}

class _EditBookDetailScreenState extends State<EditBookDetailScreen> {
  static const _conditions = [
    (value: 'like_new', label: '全新'),
    (value: 'good', label: '近全新'),
    (value: 'fair', label: '良好'),
    (value: 'poor', label: '尚可'),
  ];

  final ApiService _api = ApiService();

  late final TextEditingController _priceController;
  late String _condition;
  int? _cabinetId;

  List<BookImage> _existingImages = [];
  final List<XFile> _newImages = [];
  List<Map<String, dynamic>> _cabinets = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.book.price.toStringAsFixed(0));
    _condition = widget.book.conditionLevel;
    _cabinetId = widget.book.cabinetId;
    _existingImages = List.of(widget.book.images);
    _loadCabinets();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadCabinets() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/cabinets'),
        headers: {
          'Authorization': 'Bearer ${ApiService.authToken}',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (!mounted) return;
        setState(() {
          _cabinets = list;
          if (_cabinetId != null && !list.any((c) => c['cabinet_id'] == _cabinetId)) {
            _cabinetId = null;
          }
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickImages() async {
    final remaining = 8 - (_existingImages.length + _newImages.length);
    if (remaining <= 0) {
      showAppSnackBar(context, '最多只能有 8 張照片', isError: true);
      return;
    }

    final paths = await PhotoService.pickAndCropMultiple(
      context,
      remaining: remaining,
      aspectRatio: 1,
      outputSize: 1080,
    );
    if (paths.isEmpty || !mounted) return;

    setState(() => _newImages.addAll(paths.map(XFile.new)));
  }

  Future<void> _removeExistingImage(BookImage image) async {
    if (_existingImages.length + _newImages.length <= 1) {
      showAppSnackBar(context, '至少要保留一張照片', isError: true);
      return;
    }
    if (image.imageId == 0) {
      showAppSnackBar(context, '這張照片的資料不完整，請重新整理後再試', isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '刪除照片',
      message: '刪除後無法復原，確定嗎？',
      confirmLabel: '刪除',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.deleteBookImage(widget.book.bookId, image.imageId));
    if (!mounted) return;

    if (ok == true) {
      setState(() => _existingImages.removeWhere((e) => e.imageId == image.imageId));
      showAppSnackBar(context, '已刪除照片');
    } else {
      showAppSnackBar(context, '刪除圖片失敗，請稍後再試', isError: true);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      showAppSnackBar(context, '請填寫價格', isError: true);
      return;
    }
    if (price <= 0) {
      showAppSnackBar(context, '價格必須大於 0', isError: true);
      return;
    }
    if (price > 999999) {
      showAppSnackBar(context, '價格不可超過 999,999', isError: true);
      return;
    }
    if (_cabinetId == null) {
      showAppSnackBar(context, '請選擇存放區域', isError: true);
      return;
    }
    if (_existingImages.isEmpty && _newImages.isEmpty) {
      showAppSnackBar(context, '請至少保留一張書籍照片', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final ok = await _api.updateBook(widget.book.bookId, {
      'title': widget.title,
      'author': widget.author.isEmpty ? null : widget.author,
      'publisher': widget.publisher.isEmpty ? null : widget.publisher,
      'publish_date': widget.publishDate.isEmpty ? null : widget.publishDate,
      'isbn': widget.isbn.isEmpty ? null : widget.isbn,
      'category_id': widget.categoryId,
      'price': price,
      'condition_level': _condition,
      'cabinet_id': _cabinetId,
    });

    if (ok && _newImages.isNotEmpty) {
      await _api.uploadBookImages(widget.book.bookId, _newImages.map((f) => f.path).toList());
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      showAppSnackBar(context, '書籍已更新');

      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pop();
    } else {
      showAppSnackBar(context, '更新失敗，請稍後再試', isError: true);
    }
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageSection(c),
                        const SizedBox(height: 16),
                        _buildRowCard(
                          c,
                          '書況',
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _condition,
                              isExpanded: true,
                              dropdownColor: c.card,
                              style: TextStyle(color: c.textPrimary, fontSize: 14),
                              items: _conditions
                                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.label)))
                                  .toList(),
                              onChanged: (value) => setState(() => _condition = value ?? _condition),
                            ),
                          ),
                        ),
                        _buildRowCard(
                          c,
                          '自訂價格',
                          AppTextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            prefixText: '\$ ',
                            maxLength: 6,
                          ),
                        ),
                        _buildRowCard(
                          c,
                          '存放區域',
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _cabinetId,
                              isExpanded: true,
                              hint: Text('請選擇書櫃', style: TextStyle(color: c.textHint, fontSize: 14)),
                              dropdownColor: c.card,
                              style: TextStyle(color: c.textPrimary, fontSize: 14),
                              items: _cabinets
                                  .map((cab) => DropdownMenuItem<int>(
                                        value: cab['cabinet_id'] as int?,
                                        child: Text(
                                          '${cab['cabinet_name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _cabinetId = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: c.accent.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('儲存變更',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildImageSection(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Text('照片上傳', style: TextStyle(color: c.textSecondary, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final image in _existingImages)
                  _thumb(
                    child: Image.network(
                      image.url,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 84,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 84,
                        color: c.inputFill,
                        child: Icon(Icons.broken_image_outlined, color: c.iconInactive),
                      ),
                    ),
                    onRemove: () => _removeExistingImage(image),
                    c: c,
                  ),
                for (final file in _newImages)
                  _thumb(
                    child: Image.file(File(file.path), fit: BoxFit.cover, width: 64, height: 84),
                    onRemove: () => setState(() => _newImages.remove(file)),
                    c: c,
                  ),
                if (_existingImages.isEmpty && _newImages.isEmpty)
                  Center(
                    child: Text('尚未上傳照片', style: TextStyle(color: c.textHint, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb({required Widget child, required VoidCallback onRemove, required AppColors c}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 4)],
                ),
                child: Icon(Icons.cancel, size: 18, color: c.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(AppColors c, String label, Widget child) {
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
