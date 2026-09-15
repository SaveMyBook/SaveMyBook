import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import '../../widgets/responsive.dart';
import 'admin_layout.dart';

class AdminCabinetEditScreen extends StatefulWidget {
  final Cabinet? cabinet;
  const AdminCabinetEditScreen({super.key, this.cabinet});

  @override
  State<AdminCabinetEditScreen> createState() => _AdminCabinetEditScreenState();
}

class _AdminCabinetEditScreenState extends State<AdminCabinetEditScreen> {
  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  final ApiService _api = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _slotsController;
  late final TextEditingController _openController;
  late final TextEditingController _closeController;
  late final List<TextEditingController> _all;
  late final List<String> _initial;

  bool _isSaving = false;
  bool _saved = false;
  bool _dirty = false;
  Map<String, String> _errors = {};

  bool get _isEdit => widget.cabinet != null;

  @override
  void initState() {
    super.initState();
    final cabinet = widget.cabinet;
    _nameController = TextEditingController(text: cabinet?.cabinetName ?? '');
    _addressController = TextEditingController(text: cabinet?.address ?? '');
    _latController = TextEditingController(text: cabinet?.latitude.toString() ?? '');
    _lngController = TextEditingController(text: cabinet?.longitude.toString() ?? '');
    _slotsController = TextEditingController(text: (cabinet?.totalSlots ?? 20).toString());

    final hours = cabinet?.openHours.split('~') ?? const [];
    _openController = TextEditingController(text: hours.isNotEmpty ? hours[0] : '');
    _closeController = TextEditingController(text: hours.length > 1 ? hours[1] : '');

    _all = [
      _nameController,
      _addressController,
      _latController,
      _lngController,
      _slotsController,
      _openController,
      _closeController,
    ];
    _initial = _all.map((e) => e.text).toList();
    for (final controller in _all) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    var dirty = false;
    for (var i = 0; i < _all.length; i++) {
      if (_all[i].text != _initial[i]) dirty = true;
    }
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors = {..._errors}..remove(key));
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (name.isEmpty) errors['name'] = S.enterLockerNameAddress;
    if (address.isEmpty) errors['address'] = S.enterLockerNameAddress;

    if (lat == null) {
      errors['lat'] = S.enterValidLatitudeLongitude;
    } else if (lat < -90 || lat > 90) {
      errors['lat'] = S.latitudeMustBetween9090;
    }
    if (lng == null) {
      errors['lng'] = S.enterValidLatitudeLongitude;
    } else if (lng < -180 || lng > 180) {
      errors['lng'] = S.longitudeMustBetween180180;
    }
    if (lat == 0 && lng == 0) errors['lat'] = S.enterValidLatitudeLongitude;

    if (!_isEdit) {
      final slots = int.tryParse(_slotsController.text.trim());
      if (slots == null || slots < 1 || slots > 100) errors['slots'] = S.slotCountMustBetween1100;
    }

    final openTime = _openController.text.trim();
    final closeTime = _closeController.text.trim();
    if (openTime.isNotEmpty && !_timePattern.hasMatch(openTime)) {
      errors['open'] = S.p0MustLookLikeHhMm(S.openingHours);
    }
    if (closeTime.isNotEmpty && !_timePattern.hasMatch(closeTime)) {
      errors['close'] = S.p0MustLookLikeHhMm(S.closingTime);
    }
    if (!errors.containsKey('open') && !errors.containsKey('close')) {
      if (openTime.isNotEmpty != closeTime.isNotEmpty) {
        errors[openTime.isEmpty ? 'open' : 'close'] = S.fillBothOpeningClosingTimes;
      } else if (openTime.isNotEmpty && openTime == closeTime) {
        errors['close'] = S.openingClosingTimesCanTSame;
      }
    }
    return errors;
  }

  Future<void> _pickTime(TextEditingController controller, String errorKey) async {
    FocusScope.of(context).unfocus();
    final parts = controller.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _clearError(errorKey);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final errors = _validate();
    if (errors.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _errors = errors);
      showAppSnackBar(context, errors.values.first, isError: true);
      return;
    }

    final openTime = _openController.text.trim();
    final closeTime = _closeController.text.trim();

    setState(() {
      _errors = {};
      _isSaving = true;
    });
    String? error;
    try {
      error = await _api.saveCabinet(
        cabinetId: widget.cabinet?.cabinetId,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        totalSlots: int.tryParse(_slotsController.text.trim()) ?? 20,
        openTime: openTime.isEmpty ? null : '$openTime:00',
        closeTime: closeTime.isEmpty ? null : '$closeTime:00',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return;
    }
    _saved = true;
    showAppSnackBar(context, _isEdit ? S.lockerUpdated : S.lockerAdded);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final coordinate = FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,3}(\.\d{0,7})?'));

    final fields = <Widget>[
      _field(S.lockerName, _nameController, c, errorKey: 'name', maxLength: 100),
      _field(S.address, _addressController, c, errorKey: 'address', maxLines: 2, maxLength: 500),
      _field(
        S.latitude,
        _latController,
        c,
        errorKey: 'lat',
        hint: '25.033964',
        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
        inputFormatters: [coordinate],
      ),
      _field(
        S.longitude,
        _lngController,
        c,
        errorKey: 'lng',
        hint: '121.564468',
        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
        inputFormatters: [coordinate],
      ),
      if (!_isEdit)
        _field(
          S.slotCount,
          _slotsController,
          c,
          errorKey: 'slots',
          hint: '1–100',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        ),
      _timeField(S.openingHours, _openController, c, errorKey: 'open', hint: '09:00'),
      _timeField(S.closingTime, _closeController, c, errorKey: 'close', hint: '21:00'),
    ];

    return UnsavedGuard(
      isDirty: _dirty && !_saved,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: AdminLayout(
          builder: (context, frame) => Column(
            children: [
              AppHeader(title: _isEdit ? S.editLocker : S.newLocker, icon: Icons.storage_rounded),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: frame.inset(const EdgeInsets.all(20), maxWidth: Breakpoints.formMaxWidth),
                  child: Column(
                    children: [
                      for (var i = 0; i < fields.length; i++) FadeSlideIn(index: i, child: fields[i]),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: _isEdit ? S.saveChanges : S.createLocker,
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    AppColors c, {
    required String errorKey,
    int maxLines = 1,
    int? maxLength,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return FormRowCard(
      label: label,
      alignTop: maxLines > 1 || _errors.containsKey(errorKey),
      child: AppTextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        hint: hint,
        errorText: _errors[errorKey],
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (_) => _clearError(errorKey),
      ),
    );
  }

  Widget _timeField(
    String label,
    TextEditingController controller,
    AppColors c, {
    required String errorKey,
    required String hint,
  }) {
    return FormRowCard(
      label: label,
      alignTop: _errors.containsKey(errorKey),
      child: AppTextField(
        controller: controller,
        hint: hint,
        errorText: _errors[errorKey],
        keyboardType: TextInputType.datetime,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
          LengthLimitingTextInputFormatter(5),
        ],
        onChanged: (_) => _clearError(errorKey),
        suffix: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.text.isNotEmpty)
                PressableScale(
                  onTap: () {
                    controller.clear();
                    _clearError(errorKey);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 16, color: c.iconInactive),
                  ),
                ),
              PressableScale(
                onTap: () => _pickTime(controller, errorKey),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.schedule_rounded, size: 18, color: c.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
