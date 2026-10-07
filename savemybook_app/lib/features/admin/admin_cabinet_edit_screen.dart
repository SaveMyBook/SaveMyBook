import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../models/transit.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/map_links.dart';
import '../../utils/motion.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import '../../widgets/responsive.dart';
import '../cabinet/cabinet_guide_screen.dart' show mrtStationLabel, transitDistance;
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

  bool _locating = false;
  // 只有座標仍是「使用目前位置」填入的值時才顯示精確度，手動改過就不適用。
  ({String lat, String lng, double accuracy})? _located;
  Timer? _previewTimer;
  String? _previewKey;
  bool _previewLoading = false;
  TransitResult<TransitNearby>? _preview;

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
    _latController.addListener(_schedulePreview);
    _lngController.addListener(_schedulePreview);
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
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

  ({double lat, double lng})? get _coordinates {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
    return (lat: lat, lng: lng);
  }

  void _schedulePreview({bool immediate = false}) {
    _previewTimer?.cancel();
    final point = _coordinates;
    if (point == null) {
      if (_previewKey != null || _preview != null) {
        setState(() {
          _previewKey = null;
          _preview = null;
          _previewLoading = false;
        });
      }
      return;
    }
    final key = '${point.lat},${point.lng}';
    if (key == _previewKey) return;
    _previewTimer = Timer(immediate ? Duration.zero : const Duration(milliseconds: 700), () => _loadPreview(point.lat, point.lng, key));
  }

  Future<void> _loadPreview(double lat, double lng, String key) async {
    if (!mounted) return;
    setState(() {
      _previewKey = key;
      _previewLoading = true;
    });
    final result = await _api.previewNearby(lat, lng);
    if (!mounted || _previewKey != key) return;
    setState(() {
      _preview = result;
      _previewLoading = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() => _locating = true);
    final location = await LocationService.fresh(
      purposeKey: LocationService.setupPurposeKey,
      timeLimit: const Duration(seconds: 10),
    );
    if (!mounted) return;
    setState(() => _locating = false);
    if (!location.isGranted) {
      showAppSnackBar(
        context,
        location.isImprecise ? S.preciseLocationRequiredCabinetSetup : S.couldnTGetLocationCheckLocation,
        isError: true,
      );
      return;
    }
    final lat = location.lat!.toStringAsFixed(7);
    final lng = location.lng!.toStringAsFixed(7);
    _latController.text = lat;
    _lngController.text = lng;
    setState(() {
      _errors = {..._errors}
        ..remove('lat')
        ..remove('lng');
      _located = (lat: lat, lng: lng, accuracy: location.accuracyM ?? 0);
    });
    showAppSnackBar(context, S.currentLocationFilled);
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

    final location = <Widget>[
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
      _buildLocationTools(c),
    ];
    final details = <Widget>[
      _buildPreview(c),
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
    final fields = [...location, ...details];
    final submit = PrimaryButton(
      label: _isEdit ? S.saveChanges : S.createLocker,
      isLoading: _isSaving,
      onPressed: _save,
    );

    return UnsavedGuard(
      isDirty: _dirty && !_saved,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: AdminLayout(
          builder: (context, frame) {
            final twoColumns = frame.width >= 900;
            return Column(
              children: [
                AppHeader(title: _isEdit ? S.editLocker : S.newLocker, icon: Icons.storage_rounded),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: frame.inset(
                      frame.isWide ? const EdgeInsets.all(24) : const EdgeInsets.all(20),
                      maxWidth: twoColumns ? 1080 : Breakpoints.formMaxWidth,
                    ),
                    child: Column(
                      children: [
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < location.length; i++) FadeSlideIn(index: i, child: location[i]),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var i = 0; i < details.length; i++) FadeSlideIn(index: i, child: details[i]),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          for (var i = 0; i < fields.length; i++) FadeSlideIn(index: i, child: fields[i]),
                        const SizedBox(height: 28),
                        if (frame.isWide)
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: submit)
                        else
                          submit,
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationTools(AppColors c) {
    final located = _located;
    final accuracy = located != null && located.lat == _latController.text.trim() && located.lng == _lngController.text.trim()
        ? located.accuracy
        : null;
    final point = _coordinates;
    final low = accuracy != null && accuracy > 50;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: _locating ? S.locating : S.useCurrentLocation,
                  icon: Icons.my_location_rounded,
                  isLoading: _locating,
                  onPressed: _useCurrentLocation,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: S.checkOnMap,
                  icon: Icons.map_outlined,
                  onPressed: point == null ? null : () => openMapAt(point.lat, point.lng),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topLeft,
            child: accuracy == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            low ? Icons.warning_amber_rounded : Icons.gps_fixed_rounded,
                            size: 14,
                            color: low ? c.warning : c.success,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [S.locationAccuracyP0(accuracy.round()), if (low) S.locationAccuracyLow].join('，'),
                            style: TextStyle(fontSize: 12, height: 1.4, color: low ? c.warning : c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppColors c) {
    final data = _preview?.data;
    final List<String> lines;
    if (_coordinates == null) {
      lines = [S.nearbyPreviewHint];
    } else if (_preview?.error != null) {
      lines = [_preview!.error!];
    } else if (data == null) {
      lines = const [];
    } else {
      final station = data.mrt.items.firstOrNull;
      final roadside = [...data.roadsideCar, ...data.roadsideMotorcycle]..sort((a, b) => a.distanceM.compareTo(b.distanceM));
      final roads = <String>[];
      for (final s in roadside) {
        if (!roads.contains(s.name)) roads.add(s.name);
        if (roads.length == 3) break;
      }
      lines = [
        if (station != null) S.nearestMrtP0P1(mrtStationLabel(station.name), transitDistance(station.distanceM)),
        if (data.bus.items.isNotEmpty || data.youbike.items.isNotEmpty || data.parkingLots.items.isNotEmpty)
          [
            if (data.bus.items.isNotEmpty) S.busStopsP0(data.bus.items.length),
            if (data.youbike.items.isNotEmpty) S.youbikeStationsP0(data.youbike.items.length),
            if (data.parkingLots.items.isNotEmpty) S.parkingLotsP0(data.parkingLots.items.length),
          ].join('・'),
        if (roads.isNotEmpty) S.roadsideNearP0(roads.join('、')),
        if (data.bus.items.isEmpty && data.youbike.items.isEmpty && data.parkingLots.items.isEmpty && roads.isEmpty) S.noNearbyTransit,
      ];
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_rounded, size: 16, color: c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(S.nearbyPreview, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ),
              if (_previewLoading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
            ],
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _coordinates == null || data == null ? c.textHint : c.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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
      alignTop: maxLines > 1,
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
