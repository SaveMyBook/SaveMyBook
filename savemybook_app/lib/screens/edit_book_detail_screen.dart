import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/guards.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../utils/app_labels.dart';
import '../i18n/strings.dart';

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
  // AppLabels 會隨語系變動，不能是 const。
  List<({String value, String label})> get _conditions => AppLabels.conditionOptions;

  final ApiService _api = ApiService();

  late final TextEditingController _priceController;
  late String _condition;
  int? _cabinetId;

  /// 前三格固定對應封面／背面／條碼，跟新增書籍時一致。
  List<String> get _requiredLabels => AppLabels.photoSlots;

  final List<BookImage?> _slotExisting = List<BookImage?>.filled(3, null, growable: false);
  final List<XFile?> _slotNew = List<XFile?>.filled(3, null, growable: false);

  List<BookImage> _extraExisting = [];
  final List<XFile> _extraNew = [];
  List<Map<String, dynamic>> _cabinets = [];
  bool _isLoading = true;
  bool _isSaving = false;

  late final String _initialPrice;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.book.price.toStringAsFixed(0));
    _initialPrice = _priceController.text;
    _condition = widget.book.conditionLevel;
    _cabinetId = widget.book.cabinetId;
    _distributeImages(widget.book.images);
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

  /// 依 image_type 把既有照片放回三個固定欄位。
  /// 新增書籍時條碼是存成 other，所以第一張 other 視為條碼，其餘算補充照片。
  void _distributeImages(List<BookImage> images) {
    final rest = <BookImage>[];
    var barcodeTaken = false;

    for (final image in images) {
      switch (image.type) {
        case 'cover' when _slotExisting[0] == null:
          _slotExisting[0] = image;
        case 'back' when _slotExisting[1] == null:
          _slotExisting[1] = image;
        case 'other' when !barcodeTaken && _slotExisting[2] == null:
          _slotExisting[2] = image;
          barcodeTaken = true;
        default:
          rest.add(image);
      }
    }

    // 型別對不上（舊資料）時，用剩下的照片把空欄位補滿，不要留空。
    for (var i = 0; i < _slotExisting.length && rest.isNotEmpty; i++) {
      if (_slotExisting[i] == null) _slotExisting[i] = rest.removeAt(0);
    }

    _extraExisting = rest;
  }

  int get _filledRequired => List.generate(
        _requiredLabels.length,
        (i) => _slotExisting[i] != null || _slotNew[i] != null,
      ).where((filled) => filled).length;

  int get _totalImages =>
      _filledRequired + _extraExisting.length + _extraNew.length;

  Future<void> _pickSlot(int slot) async {
    final path = await PhotoService.pickAndCrop(context, aspectRatio: 3 / 4, outputSize: 1200);
    if (path == null || !mounted) return;

    // 換掉既有的照片：先把伺服器上那張刪掉，再把新的排進上傳佇列。
    final old = _slotExisting[slot];
    if (old != null) {
      final ok = await _api.deleteBookImage(widget.book.bookId, old.imageId);
      if (!mounted) return;
      if (!ok) {
        showAppSnackBar(context, S.couldNotReplacePhotoPleaseTry, isError: true);
        return;
      }
    }

    setState(() {
      _slotExisting[slot] = null;
      _slotNew[slot] = XFile(path);
    });
  }

  Future<void> _clearSlot(int slot) async {
    if (_totalImages <= 1) {
      showAppSnackBar(context, S.keepLeastOnePhoto, isError: true);
      return;
    }

    final existing = _slotExisting[slot];
    if (existing == null) {
      setState(() => _slotNew[slot] = null);
      return;
    }

    if (!await _confirmDelete() || !mounted) return;

    final ok = await runBusy(context, () => _api.deleteBookImage(widget.book.bookId, existing.imageId));
    if (!mounted) return;

    if (ok == true) {
      setState(() => _slotExisting[slot] = null);
      showAppSnackBar(context, S.photoDeleted);
    } else {
      showAppSnackBar(context, S.couldNotDeletePhotoPleaseTry, isError: true);
    }
  }

  Future<void> _addExtraImages() async {
    final remaining = 10 - _totalImages;
    if (remaining <= 0) {
      showAppSnackBar(context, S.canUp10Photos, isError: true);
      return;
    }

    final paths = await PhotoService.pickAndCropMultiple(
      context,
      remaining: remaining,
      aspectRatio: 3 / 4,
      outputSize: 1200,
    );
    if (paths.isEmpty || !mounted) return;

    setState(() => _extraNew.addAll(paths.map(XFile.new)));
  }

  Future<bool> _confirmDelete() => showConfirmDialog(
        context,
        title: S.deletePhoto,
        message: S.cannotUndoneContinue,
        confirmLabel: S.actionDelete,
        isDestructive: true,
      );

  Future<void> _removeExtraExisting(BookImage image) async {
    if (_totalImages <= 1) {
      showAppSnackBar(context, S.keepLeastOnePhoto, isError: true);
      return;
    }
    if (image.imageId == 0) {
      showAppSnackBar(context, S.photoMissingDataRefreshTryAgain, isError: true);
      return;
    }
    if (!await _confirmDelete() || !mounted) return;

    final ok = await runBusy(context, () => _api.deleteBookImage(widget.book.bookId, image.imageId));
    if (!mounted) return;

    if (ok == true) {
      setState(() => _extraExisting.removeWhere((e) => e.imageId == image.imageId));
      showAppSnackBar(context, S.photoDeleted);
    } else {
      showAppSnackBar(context, S.couldNotDeletePhotoPleaseTry, isError: true);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      showAppSnackBar(context, S.enterPrice, isError: true);
      return;
    }
    if (price <= 0) {
      showAppSnackBar(context, S.priceMustGreaterThan0, isError: true);
      return;
    }
    if (price > 999999) {
      showAppSnackBar(context, S.priceCannotExceed999999, isError: true);
      return;
    }
    if (_cabinetId == null) {
      showAppSnackBar(context, S.chooseLockerLocation, isError: true);
      return;
    }
    if (_filledRequired < _requiredLabels.length) {
      final missing = [
        for (var i = 0; i < _requiredLabels.length; i++)
          if (_slotExisting[i] == null && _slotNew[i] == null) _requiredLabels[i],
      ].join('、');
      showAppSnackBar(context, S.missingTheseThreeRequired(missing), isError: true);
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

    final pending = [
      ..._slotNew.whereType<XFile>(),
      ..._extraNew,
    ].map((f) => f.path).toList();

    if (ok && pending.isNotEmpty) {
      await _api.uploadBookImages(widget.book.bookId, pending);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      showAppSnackBar(context, S.bookUpdated);

      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pop();
    } else {
      showAppSnackBar(context, AppLabels.updateFailed, isError: true);
    }
  }

  /// 換過照片或改過價格就別讓返回鍵直接吃掉。
  /// 刪照片在 _clearSlot 當下就送出去了，不算未存的修改；
  /// 只有價格與還沒上傳的新照片需要攔。
  bool get _isDirty =>
      _priceController.text != _initialPrice || _slotNew.any((f) => f != null);

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
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageSection(c),
                        const SizedBox(height: 16),
                        _buildRowCard(
                          c,
                          S.condition,
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
                          S.customPrice,
                          AppTextField(
                            controller: _priceController,
                            hint: S.enterPrice2,
                            keyboardType: TextInputType.number,
                            prefixText: '\$ ',
                            maxLength: 6,
                          ),
                        ),
                        _buildRowCard(
                          c,
                          S.lockerLocation,
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _cabinetId,
                              isExpanded: true,
                              hint: Text(S.chooseLocker, style: TextStyle(color: c.textHint, fontSize: 14)),
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
                                : Text(S.saveChanges,
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
    ),
    );
  }

  Widget _buildImageSection(AppColors c) {
    final canAddMore = _totalImages < 10;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: S.bookPhotos,
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                '($_filledRequired/3)',
                style: TextStyle(
                  fontSize: 14,
                  color: _filledRequired < 3 ? c.danger : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text('$_totalImages/10', style: TextStyle(fontSize: 14, color: c.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _requiredLabels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildSlot(c, i),
                  ),
                for (final image in _extraExisting)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildImageTile(
                      c,
                      label: S.morePhotos,
                      isRequired: false,
                      onRemove: () => _removeExtraExisting(image),
                      image: AppNetworkImage(
                        url: image.url,
                        fallbackIcon: Icons.broken_image_outlined,
                        fallbackIconSize: 24,
                      ),
                    ),
                  ),
                for (final file in _extraNew)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildImageTile(
                      c,
                      label: S.morePhotos,
                      isRequired: false,
                      onRemove: () => setState(() => _extraNew.remove(file)),
                      image: Image.file(File(file.path), fit: BoxFit.cover),
                    ),
                  ),
                if (canAddMore)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildAddButton(c, S.morePhotos, _addExtraImages),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(AppColors c, int slot) {
    final existing = _slotExisting[slot];
    final picked = _slotNew[slot];
    final label = _requiredLabels[slot];

    if (existing == null && picked == null) {
      return _buildAddButton(c, label, () => _pickSlot(slot), isRequired: true);
    }

    return _buildImageTile(
      c,
      label: label,
      isRequired: true,
      onRemove: () => _clearSlot(slot),
      onTap: () => _pickSlot(slot),
      image: picked != null
          ? Image.file(File(picked.path), fit: BoxFit.cover)
          : AppNetworkImage(
              url: existing!.url,
              fallbackIcon: Icons.broken_image_outlined,
              fallbackIconSize: 24,
            ),
    );
  }

  Widget _buildImageTile(
    AppColors c, {
    required String label,
    required bool isRequired,
    required VoidCallback onRemove,
    required Widget image,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 90,
            height: 110,
            decoration: BoxDecoration(
              border: Border.all(color: c.divider, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.black87, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isRequired ? c.danger : c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(
    AppColors c,
    String label,
    VoidCallback onTap, {
    bool isRequired = false,
  }) {
    return Column(
      children: [
        Material(
          color: c.accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 90,
              height: 110,
              decoration: BoxDecoration(
                border: Border.all(color: c.accent.withValues(alpha: 0.5), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: c.accent, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    S.add,
                    style: TextStyle(color: c.accent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isRequired ? c.danger : c.textHint,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
