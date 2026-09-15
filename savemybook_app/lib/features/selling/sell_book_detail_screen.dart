import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ai.dart';
import '../../services/ai_status.dart';
import '../../services/photo_service.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_select.dart';
import '../../widgets/guards.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../home/home_screen.dart';
import 'ai_listing_assist.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

class SellDraft {
  const SellDraft._();

  static const _key = 'sell_draft_v1';

  static int epoch = 0;

  static Future<void> finish() {
    epoch++;
    return clear();
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSection(String section, Map<String, dynamic>? values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await load() ?? <String, dynamic>{};
      if (values == null) {
        current.remove(section);
      } else {
        current[section] = values;
      }
      current.remove('saved_at');
      if (current.isEmpty) {
        await prefs.remove(_key);
        return;
      }
      current['saved_at'] = DateTime.now().toIso8601String();
      await prefs.setString(_key, jsonEncode(current));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

class SellBookDetailScreen extends StatefulWidget {
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String publishDate;
  final String description;
  final int categoryId;
  final String? aiCondition;
  final int? aiPrice;

  const SellBookDetailScreen({
    super.key,
    required this.isbn,
    required this.title,
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.description,
    required this.categoryId,
    this.aiCondition,
    this.aiPrice,
  });

  @override
  State<SellBookDetailScreen> createState() => _SellBookDetailScreenState();
}

class _SellBookDetailScreenState extends State<SellBookDetailScreen> {
  static const _maxImages = 10;
  static const _maxPrice = 99999;

  final _priceController = TextEditingController();
  final _scrollController = ScrollController();
  String _condition = 'good';
  int? _selectedCabinet;
  Map<String, dynamic>? _cabinet;
  bool _cabinetTouched = false;
  bool _showErrors = false;
  bool _isSubmitting = false;
  bool _confirming = false;
  bool _submitted = false;
  Timer? _saveTimer;
  bool _conditionTouched = false;
  bool _aiRunning = false;
  final Map<String, int> _flash = {};

  List<String> get _requiredLabels => AppLabels.photoSlots;
  late final List<XFile?> _slots = List<XFile?>.filled(_requiredLabels.length, null, growable: false);
  final List<XFile> _extra = [];

  int get _filledRequired => _slots.where((f) => f != null).length;
  int get _totalImages => _filledRequired + _extra.length;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_scheduleSave);
    _restoreDraft().whenComplete(_applyCarriedSuggestion);
    AiStatus.refresh();
  }

  void _applyCarriedSuggestion() {
    if (!mounted) return;
    final flashed = <String>[];
    setState(() {
      final condition = widget.aiCondition;
      if (condition != null && !_conditionTouched && AppLabels.condition.containsKey(condition)) {
        _condition = condition;
        flashed.add('condition');
      }
      final price = widget.aiPrice;
      if (price != null && price > 0 && _priceController.text.trim().isEmpty) {
        _priceController.text = '${price.clamp(1, _maxPrice)}';
        flashed.add('price');
      }
      for (final key in flashed) {
        _flash[key] = (_flash[key] ?? 0) + 1;
      }
    });
  }

  List<String> get _aiImagePaths => [
        for (final f in _slots)
          if (f != null) f.path,
        for (final f in _extra) f.path,
      ].take(4).toList();

  Future<void> _onAiAssist() async {
    if (_aiRunning || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    final images = _aiImagePaths;
    if (images.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.addBookPhotosFirst, isError: true);
      return;
    }
    setState(() => _aiRunning = true);
    final result = await runAiListingAssist(
      context,
      isbn: widget.isbn,
      title: widget.title,
      imagePaths: images,
    );
    if (!mounted) return;
    setState(() => _aiRunning = false);
    if (result == null) return;
    final selection = await showAiListingResultSheet(
      context,
      result: result,
      targets: AiListingTargets(
        supportsCondition: true,
        condition: _condition,
        conditionTouched: _conditionTouched,
        supportsPrice: true,
        price: _price,
      ),
    );
    if (selection == null || !mounted) return;
    final flashed = <String>[];
    setState(() {
      if (selection.condition && result.condition != null && AppLabels.condition.containsKey(result.condition!.level)) {
        _condition = result.condition!.level;
        _conditionTouched = true;
        flashed.add('condition');
      }
      if (selection.price && result.price != null) {
        _priceController.text = '${result.price!.suggested.clamp(1, _maxPrice)}';
        flashed.add('price');
      }
      for (final key in flashed) {
        _flash[key] = (_flash[key] ?? 0) + 1;
      }
    });
    _saveDraftNow();
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.appliedP0AiSuggestions(flashed.length));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!_submitted) _saveDraftNow();
    _priceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await SellDraft.load();
    final step2 = draft?['step2'];
    if (!mounted || step2 is! Map) return;

    bool exists(Object? path) => path is String && path.isNotEmpty && File(path).existsSync();
    final slots = step2['slots'];
    final extra = step2['extra'];

    setState(() {
      final price = '${step2['price'] ?? ''}';
      if (price.isNotEmpty && _priceController.text.isEmpty) _priceController.text = price;
      final condition = step2['condition'];
      if (condition is String && AppLabels.condition.containsKey(condition)) {
        _condition = condition;
        _conditionTouched = true;
      }
      final cabinetId = step2['cabinet_id'];
      if (cabinetId is num) {
        _selectedCabinet = cabinetId.toInt();
        _cabinetTouched = true;
      }
      if (slots is List) {
        for (var i = 0; i < _slots.length && i < slots.length; i++) {
          if (exists(slots[i])) _slots[i] = XFile(slots[i] as String);
        }
      }
      if (extra is List) {
        _extra.addAll(extra.where(exists).take(_maxImages - _filledRequired).map((p) => XFile(p as String)));
      }
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveDraftNow);
  }

  void _saveDraftNow() {
    _saveTimer?.cancel();
    if (_submitted) return;
    SellDraft.saveSection('step2', {
      'price': _priceController.text.trim(),
      'condition': _condition,
      if (_cabinetTouched && _selectedCabinet != null) 'cabinet_id': _selectedCabinet,
      'slots': [for (final f in _slots) f?.path],
      'extra': [for (final f in _extra) f.path],
    });
  }

  Future<void> _pickRequired(int slot) async {
    if (_isSubmitting) return;
    final path = await PhotoService.pickAndCrop(context, aspectRatio: 3 / 4, outputSize: 1200);
    if (path == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _slots[slot] = XFile(path));
    _saveDraftNow();
  }

  Future<void> _addExtraImages() async {
    if (_isSubmitting) return;
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) {
      _showAlertDialog(S.photoLimitReached, S.canUploadUp10Photos);
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
    setState(() => _extra.addAll(paths.take(_maxImages - _totalImages).map(XFile.new)));
    _saveDraftNow();
  }

  void _removeRequired(int slot) {
    if (_isSubmitting) return;
    setState(() => _slots[slot] = null);
    _saveDraftNow();
  }

  void _removeExtra(int index) {
    if (_isSubmitting || index >= _extra.length) return;
    setState(() => _extra.removeAt(index));
    _saveDraftNow();
  }

  void _showAlertDialog(String title, String content) {
    showConfirmDialog(context, title: title, message: content, confirmLabel: S.actionConfirm);
  }

  int? get _price => int.tryParse(_priceController.text.trim());

  List<String> get _missing {
    final price = _price;
    return [
      for (var i = 0; i < _slots.length; i++)
        if (_slots[i] == null) _requiredLabels[i],
      if (price == null || price <= 0) S.customPrice,
      if (_selectedCabinet == null) S.lockerLocation,
    ];
  }

  String? get _priceError => _showErrors && (_price ?? 0) <= 0 ? S.enterPrice2 : null;

  Future<void> _submitForm() async {
    if (_isSubmitting || _confirming) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);

    if (_filledRequired < _requiredLabels.length) {
      final missing = [
        for (var i = 0; i < _slots.length; i++)
          if (_slots[i] == null) _requiredLabels[i],
      ].join('、');
      HapticFeedback.heavyImpact();
      _scrollController.animateTo(0, duration: Motion.base, curve: Motion.standard);
      _showAlertDialog(S.photosMissing, S.missingTheseThreeRequired2(missing));
      return;
    }
    final price = _price;
    if (price == null) {
      HapticFeedback.heavyImpact();
      _showAlertDialog(S.missingInformation, S.enterOwnPrice);
      return;
    }
    if (price <= 0) {
      HapticFeedback.heavyImpact();
      _showAlertDialog(S.invalidPrice, S.priceMustGreaterThan02);
      return;
    }
    if (price > _maxPrice) {
      HapticFeedback.heavyImpact();
      _showAlertDialog(S.invalidPrice, S.priceCannotExceed99999);
      return;
    }
    if (_selectedCabinet == null) {
      HapticFeedback.heavyImpact();
      _showAlertDialog(S.missingInformation, S.chooseLockerLocation2);
      return;
    }
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.pleaseSignFirst, isError: true);
      return;
    }

    final cabinetName = _cabinet == null ? '' : CabinetSelectField.nameOf(_cabinet!);
    final summary = [
      '${S.customPrice}：\$$price',
      '${S.condition}：${AppLabels.conditionOf(_condition)}',
      '${S.lockerLocation}：$cabinetName',
      S.photosP0(_totalImages),
    ].join('\n');

    _confirming = true;
    final confirmed = await showConfirmDialog(
      context,
      title: S.confirmListing,
      message: '${widget.title}\n\n$summary',
      confirmLabel: S.listBook,
      icon: Icons.publish_rounded,
    );
    _confirming = false;
    if (!confirmed || !mounted) return;
    setState(() => _isSubmitting = true);

    final outcome = await ApiService().createBook({
      'title': widget.title,
      'author': widget.author,
      'publisher': widget.publisher,
      'publish_date': widget.publishDate,
      'isbn': widget.isbn,
      'description': widget.description,
      'category_id': widget.categoryId.toString(),
      'price': '$price',
      'condition_level': _condition,
      'cabinet_id': '$_selectedCabinet',
    }, [
      ('cover_image', _slots[0]!.path),
      ('back_image', _slots[1]!.path),
      ('barcode_image', _slots[2]!.path),
      for (final file in _extra) ('optional_images', file.path),
    ]);
    if (!mounted) return;

    if (outcome.isOk) {
      _submitted = true;
      _saveTimer?.cancel();
      await SellDraft.finish();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (outcome.pendingReview) {
        await showPendingReviewNotice(context);
        if (!mounted) return;
      } else {
        showAppSnackBar(context, S.listed2);
      }
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: Motion.enter,
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
      return;
    }

    setState(() => _isSubmitting = false);
    HapticFeedback.heavyImpact();
    if (outcome.isRejected) {
      await showListingRejectedDialog(context, outcome);
      return;
    }
    _showAlertDialog(S.couldNotListBook, S.serverError(outcome.error ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            _buildAppBar(c),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: AbsorbPointer(
                  absorbing: _isSubmitting,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: responsiveListPadding(
                        constraints,
                        maxWidth: Breakpoints.formMaxWidth,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        children: [
                          FadeSlideIn(child: _buildImageUploadSection(c)),
                          const SizedBox(height: 12),
                          FadeSlideIn(
                            index: 1,
                            child: AiFlash(trigger: _flash['condition'] ?? 0, child: FormRowCard(
                              label: S.condition,
                              labelWidth: 88,
                              isRequired: true,
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
                                onChanged: (value) {
                                  setState(() {
                                    _condition = value;
                                    _conditionTouched = true;
                                  });
                                  _saveDraftNow();
                                },
                              ),
                            )),
                          ),
                          FadeSlideIn(
                            index: 2,
                            child: AiFlash(trigger: _flash['price'] ?? 0, child: FormRowCard(
                              label: S.customPrice,
                              labelWidth: 88,
                              isRequired: true,
                              child: AppTextField(
                                controller: _priceController,
                                hint: S.enterPrice2,
                                prefixText: '\$ ',
                                errorText: _priceError,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: const [PriceInputFormatter(max: _maxPrice)],
                                onChanged: (_) => setState(() {}),
                              ),
                            )),
                          ),
                          FadeSlideIn(
                            index: 3,
                            child: FormRowCard(
                              label: S.lockerLocation,
                              labelWidth: 88,
                              isRequired: true,
                              alignTop: true,
                              child: CabinetSelectField(
                                value: _selectedCabinet,
                                autoSelectNearest: !_cabinetTouched,
                                errorText: _showErrors && _selectedCabinet == null ? S.chooseLocker : null,
                                onChanged: (cabinet, byUser) {
                                  setState(() {
                                    if (byUser) _cabinetTouched = true;
                                    _selectedCabinet = cabinet == null ? null : CabinetSelectField.idOf(cabinet);
                                    _cabinet = cabinet;
                                  });
                                  if (byUser) _saveDraftNow();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          MissingHint(missing: _missing),
                          PrimaryButton(
                            label: S.listBook,
                            icon: Icons.publish_rounded,
                            height: 50,
                            isLoading: _isSubmitting,
                            onPressed: _submitForm,
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
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

  Widget _buildAppBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(color: c.headerBg),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                onPressed: _isSubmitting ? null : () => Navigator.maybePop(context),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        S.detailsPhotos,
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
                  '2 / 2',
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

  Widget _buildImageUploadSection(AppColors c) {
    final canAddMore = _totalImages < _maxImages;
    final missingPhotos = _showErrors && _filledRequired < _requiredLabels.length;

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: missingPhotos ? c.danger.withValues(alpha: 0.6) : Colors.transparent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: S.bookPhotos,
                          children: [
                            TextSpan(text: ' *', style: TextStyle(color: c.danger, fontWeight: FontWeight.bold)),
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
                  ],
                ),
              ),
              Text('$_totalImages/$_maxImages', style: TextStyle(fontSize: 14, color: c.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _slots.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SwitchIn(
                      child: _slots[i] == null
                          ? _buildAddImageButton(c, _requiredLabels[i], () => _pickRequired(i),
                              key: ValueKey('add$i'), isRequired: true)
                          : _buildImageItem(
                              c,
                              _requiredLabels[i],
                              _slots[i]!,
                              key: ValueKey(_slots[i]!.path),
                              isRequired: true,
                              onTap: () => _pickRequired(i),
                              onRemove: () => _removeRequired(i),
                            ),
                    ),
                  ),
                for (var i = 0; i < _extra.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildImageItem(
                      c,
                      S.morePhotos,
                      _extra[i],
                      key: ValueKey(_extra[i].path),
                      isRequired: false,
                      onRemove: () => _removeExtra(i),
                    ),
                  ),
                if (canAddMore)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildAddImageButton(c, S.morePhotos, _addExtraImages),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<AiStatusInfo>(
            valueListenable: AiStatus.listenable,
            builder: (context, status, _) => AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              alignment: Alignment.topCenter,
              child: status.listingAssist
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AiAssistButton(onTap: _onAiAssist, busy: _aiRunning),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageItem(
    AppColors c,
    String label,
    XFile imageFile, {
    Key? key,
    required bool isRequired,
    required VoidCallback onRemove,
    VoidCallback? onTap,
  }) {
    return Column(
      key: key,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.file(
                    File(imageFile.path),
                    fit: BoxFit.cover,
                    cacheWidth: 270,
                    errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: c.iconInactive),
                  ),
                ),
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

  Widget _buildAddImageButton(AppColors c, String label, VoidCallback onTap, {Key? key, bool isRequired = false}) {
    return Column(
      key: key,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
