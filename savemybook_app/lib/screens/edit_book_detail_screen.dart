import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_service.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/guards.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/app_select.dart';
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
  static const _maxImages = 10;
  static const _maxPrice = 99999;

  final ApiService _api = ApiService();

  late final TextEditingController _priceController;
  late String _condition;
  int? _cabinetId;

  List<String> get _requiredLabels => AppLabels.photoSlots;

  final List<BookImage?> _slotExisting = List<BookImage?>.filled(3, null, growable: false);
  final List<BookImage?> _slotReplaced = List<BookImage?>.filled(3, null, growable: false);
  final List<XFile?> _slotNew = List<XFile?>.filled(3, null, growable: false);

  List<BookImage> _extraExisting = [];
  final List<XFile> _extraNew = [];
  bool _isSaving = false;
  bool _saved = false;
  bool _showErrors = false;

  late final String _initialPrice;
  late final String _initialCondition;
  bool _cabinetTouched = false;

  @override
  void initState() {
    super.initState();
    final price = widget.book.price.round();
    _priceController = TextEditingController(text: price > 0 ? '$price' : '');
    _initialPrice = _priceController.text;
    _condition = AppLabels.condition.containsKey(widget.book.conditionLevel) ? widget.book.conditionLevel : 'good';
    _initialCondition = _condition;
    _cabinetId = widget.book.cabinetId;
    _distributeImages(widget.book.images);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

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

    for (var i = 0; i < _slotExisting.length && rest.isNotEmpty; i++) {
      if (_slotExisting[i] == null) _slotExisting[i] = rest.removeAt(0);
    }

    _extraExisting = rest;
  }

  int get _filledRequired => List.generate(
        _requiredLabels.length,
        (i) => _slotExisting[i] != null || _slotNew[i] != null,
      ).where((filled) => filled).length;

  int get _totalImages => _filledRequired + _extraExisting.length + _extraNew.length;

  Future<void> _pickSlot(int slot) async {
    if (_isSaving) return;
    final path = await PhotoService.pickAndCrop(context, aspectRatio: 3 / 4, outputSize: 1200);
    if (path == null || !mounted) return;
    HapticFeedback.selectionClick();

    setState(() {
      final old = _slotExisting[slot];
      if (old != null) _slotReplaced[slot] = old;
      _slotExisting[slot] = null;
      _slotNew[slot] = XFile(path);
    });
  }

  Future<void> _clearSlot(int slot) async {
    if (_isSaving) return;

    if (_slotNew[slot] != null) {
      setState(() {
        _slotNew[slot] = null;
        _slotExisting[slot] = _slotReplaced[slot];
        _slotReplaced[slot] = null;
      });
      return;
    }

    final existing = _slotExisting[slot];
    if (existing == null) return;
    if (_totalImages <= 1) {
      showAppSnackBar(context, S.keepLeastOnePhoto, isError: true);
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
    if (_isSaving) return;
    final remaining = _maxImages - _totalImages;
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
    HapticFeedback.selectionClick();
    setState(() => _extraNew.addAll(paths.take(_maxImages - _totalImages).map(XFile.new)));
  }

  Future<bool> _confirmDelete() => showConfirmDialog(
        context,
        title: S.deletePhoto,
        message: S.cannotUndoneContinue,
        confirmLabel: S.actionDelete,
        isDestructive: true,
      );

  Future<void> _removeExtraExisting(BookImage image) async {
    if (_isSaving) return;
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

  int? get _price => int.tryParse(_priceController.text.trim());

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);

    final price = _price;
    if (price == null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterPrice, isError: true);
      return;
    }
    if (price <= 0) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.priceMustGreaterThan0, isError: true);
      return;
    }
    if (price > _maxPrice) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.priceCannotExceed99999, isError: true);
      return;
    }
    if (_cabinetId == null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.chooseLockerLocation, isError: true);
      return;
    }
    if (_filledRequired < _requiredLabels.length) {
      final missing = [
        for (var i = 0; i < _requiredLabels.length; i++)
          if (_slotExisting[i] == null && _slotNew[i] == null) _requiredLabels[i],
      ].join('、');
      HapticFeedback.heavyImpact();
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

    if (!ok) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, AppLabels.updateFailed, isError: true);
      return;
    }

    const slotTypes = ['cover', 'back', 'other'];
    final pending = <String>[];
    final types = <String>[];
    for (var i = 0; i < _slotNew.length; i++) {
      final file = _slotNew[i];
      if (file == null) continue;
      pending.add(file.path);
      types.add(slotTypes[i]);
    }
    for (final file in _extraNew) {
      pending.add(file.path);
      types.add('inside');
    }
    final uploaded = pending.isEmpty || await _api.uploadBookImages(widget.book.bookId, pending, types: types);

    if (uploaded) {
      for (final old in _slotReplaced.whereType<BookImage>()) {
        if (old.imageId != 0) await _api.deleteBookImage(widget.book.bookId, old.imageId);
      }
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saved = true;
    });

    if (uploaded) {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.bookUpdated);
    } else {
      showAppSnackBar(context, S.bookDetailsUpdatedButPhotosCouldn, isError: true);
    }
    Navigator.of(context).pop(true);
  }

  bool get _isDirty =>
      !_saved &&
      (_priceController.text != _initialPrice ||
          _condition != _initialCondition ||
          (_cabinetTouched && _cabinetId != widget.book.cabinetId) ||
          _slotNew.any((f) => f != null) ||
          _extraNew.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return PopScope(
      canPop: !_isSaving,
      child: UnsavedGuard(
        isDirty: _isDirty && !_isSaving,
        child: Scaffold(
          backgroundColor: c.scaffold,
          body: Column(
            children: [
              AppHeader(title: S.editBook, icon: Icons.edit_note_rounded),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: AbsorbPointer(
                    absorbing: _isSaving,
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(child: _buildImageSection(c)),
                          const SizedBox(height: 12),
                          FadeSlideIn(
                            index: 1,
                            child: FormRowCard(
                              label: S.condition,
                              labelWidth: 88,
                              child: AppSelect<String>(
                                value: _condition,
                                title: S.condition,
                                options: [
                                  for (final option in AppLabels.conditionOptions)
                                    AppSelectOption(
                                      value: option.value,
                                      label: option.label,
                                      icon: Icons.menu_book_rounded,
                                      iconColor: c.conditionColor(option.value),
                                    ),
                                ],
                                onChanged: (value) => setState(() => _condition = value),
                              ),
                            ),
                          ),
                          FadeSlideIn(
                            index: 2,
                            child: FormRowCard(
                              label: S.customPrice,
                              labelWidth: 88,
                              child: AppTextField(
                                controller: _priceController,
                                hint: S.enterPrice2,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                prefixText: '\$ ',
                                errorText: _showErrors && (_price ?? 0) <= 0 ? S.enterPrice : null,
                                inputFormatters: const [PriceInputFormatter(max: _maxPrice)],
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                          FadeSlideIn(
                            index: 3,
                            child: FormRowCard(
                              label: S.lockerLocation,
                              labelWidth: 88,
                              alignTop: true,
                              child: CabinetSelectField(
                                value: _cabinetId,
                                keepSelectableId: widget.book.cabinetId,
                                errorText: _showErrors && _cabinetId == null ? S.chooseLocker : null,
                                onChanged: (cabinet, byUser) => setState(() {
                                  if (byUser) _cabinetTouched = true;
                                  _cabinetId = cabinet == null ? null : CabinetSelectField.idOf(cabinet);
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: S.saveChanges,
                            icon: Icons.check_rounded,
                            isLoading: _isSaving,
                            onPressed: _save,
                          ),
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
      ),
    );
  }

  Widget _buildImageSection(AppColors c) {
    final canAddMore = _totalImages < _maxImages;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: S.bookPhotos,
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: c.danger, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($_filledRequired/3)',
                style: TextStyle(
                  fontSize: 14,
                  color: _filledRequired < 3 ? c.danger : c.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text('$_totalImages/$_maxImages', style: TextStyle(fontSize: 14, color: c.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView(
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
                      onRemove: () {
                        if (!_isSaving) setState(() => _extraNew.remove(file));
                      },
                      image: Image.file(File(file.path), fit: BoxFit.cover, cacheWidth: 270),
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
          ? Image.file(File(picked.path), fit: BoxFit.cover, cacheWidth: 270)
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
        PressableScale(
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
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isRequired ? c.success : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isRequired ? c.danger : c.textHint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
