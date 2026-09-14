import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import 'app_select.dart';
import 'state_views.dart';
import '../utils/motion.dart';
import 'animations.dart';
import '../i18n/strings.dart';

enum FieldState { normal, empty, locked }

class FormRowCard extends StatelessWidget {
  final String label;
  final Widget child;
  final bool alignTop;
  final double labelWidth;
  final EdgeInsetsGeometry margin;
  final FieldState state;
  final bool isRequired;

  const FormRowCard({
    super.key,
    required this.label,
    required this.child,
    this.alignTop = false,
    this.labelWidth = 76,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.state = FieldState.normal,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final note = switch (state) {
      FieldState.empty => (icon: Icons.edit_note_rounded, text: S.notFilled, color: c.warning),
      FieldState.locked => (icon: Icons.lock_outline_rounded, text: S.canTChanged, color: c.textHint),
      FieldState.normal => null,
    };
    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired)
                TextSpan(text: ' *', style: TextStyle(color: c.danger, fontWeight: FontWeight.bold)),
            ],
          ),
          style: labelStyle.copyWith(color: c.textPrimary),
        ),
        if (note != null) ...[
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(note.icon, size: 12, color: note.color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  note.text,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: note.color),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return AppCard(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: isRequired ? '$label *' : label, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final stacked = painter.width > labelWidth;
          painter.dispose();

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelColumn, const SizedBox(height: 8), child],
            );
          }
          return Row(
            crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: labelWidth,
                child: Padding(
                  padding: EdgeInsets.only(top: alignTop ? 10 : 0),
                  child: labelColumn,
                ),
              ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final int? minLines;
  final String? label;
  final Iterable<String>? autofillHints;

  static const double singleLineHeight = 48;

  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefixText,
    this.textInputAction,
    this.focusNode,
    this.minLines,
    this.label,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final singleLine = obscureText || (maxLines == 1 && (minLines ?? 1) == 1);

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? null : minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      autofillHints: autofillHints,
      textAlignVertical: singleLine ? TextAlignVertical.center : null,
      style: TextStyle(color: enabled ? c.textPrimary : c.textHint, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        errorText: errorText,
        errorMaxLines: 2,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: c.textPrimary, fontSize: 14),
        suffixIcon: suffix == null
            ? null
            : SizedBox(
                child: IconButtonTheme(
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: const EdgeInsets.all(8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  child: Center(widthFactor: 1, child: suffix),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 24, maxHeight: 40),
        hintStyle: TextStyle(color: c.textHint, fontSize: 13),
        filled: true,
        fillColor: c.inputFill,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: singleLine ? 14 : 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.danger, width: 1.4),
        ),
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
        ),
        field,
      ],
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? title;
  final String? errorText;
  final IconData? leadingIcon;
  final bool? searchable;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.title,
    this.errorText,
    this.leadingIcon,
    this.searchable,
  });

  static String _textOf(Widget child) {
    if (child is Text) return child.data ?? child.textSpan?.toPlainText() ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;

    return AppSelect<T>(
      value: value,
      hint: hint,
      title: title ?? hint,
      errorText: errorText,
      leadingIcon: leadingIcon,
      searchable: searchable,
      options: [
        for (final item in items)
          if (item.value is T)
            AppSelectOption<T>(
              value: item.value as T,
              label: _textOf(item.child),
              labelWidget: item.child is Text ? null : item.child,
              enabled: item.enabled,
            ),
      ],
      onChanged: onChanged == null ? null : (picked) => onChanged(picked),
    );
  }
}

class PriceInputFormatter extends TextInputFormatter {
  final int max;

  const PriceInputFormatter({this.max = 99999});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (digits.isNotEmpty && (int.tryParse(digits) ?? max + 1) > max) {
      HapticFeedback.lightImpact();
      return oldValue;
    }
    if (digits == newValue.text) return newValue;
    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}

String? normalizeIsbn(String raw) {
  final s = raw.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
  if (RegExp(r'^\d{13}$').hasMatch(s)) return s;
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(s)) return s;
  return null;
}

bool isbnChecksumValid(String isbn) {
  if (isbn.length == 13) {
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      final d = int.parse(isbn[i]);
      sum += i.isEven ? d : d * 3;
    }
    return sum % 10 == 0;
  }
  if (isbn.length == 10) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final ch = isbn[i];
      final d = ch == 'X' ? 10 : int.parse(ch);
      if (ch == 'X' && i != 9) return false;
      sum += d * (10 - i);
    }
    return sum % 11 == 0;
  }
  return false;
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: c.iconInactive, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => SwitchIn(
            duration: Motion.micro,
            child: value.text.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : IconButton(
                    key: const ValueKey('clear'),
                    icon: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onSubmitted?.call('');
                    },
                  ),
          ),
        ),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
      ),
    );
  }
}

class AppDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? hint;

  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helpText;
  final bool clearable;
  final bool enabled;

  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.helpText,
    this.clearable = true,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final c = AppColors.of(context);
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 100);
    final last = lastDate ?? now;

    var initial = value ?? (last.isBefore(now) ? last : now);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText ?? S.pickDate2,
      cancelText: S.actionCancel,
      confirmText: S.actionConfirm,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent),
        ),
        child: child!,
      ),
    );

    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final date = value;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _pick(context) : null,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date == null
                    ? (hint ?? S.pickDate)
                    : S.msg5(date.year, date.month, date.day),
                style: TextStyle(
                  fontSize: 14,
                  color: date == null ? c.textHint : c.textPrimary,
                ),
              ),
            ),
            if (date != null && clearable)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.close_rounded, size: 18, color: c.iconInactive),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today_outlined, size: 16, color: enabled ? c.accent : c.iconInactive),
          ],
        ),
      ),
    );
  }
}

class Validators {
  const Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^0\d{8,9}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPhone(String value) => _phone.hasMatch(value.trim().replaceAll('-', ''));

  static String? password(String value) {
    if (value.length < 8) return S.passwordsNeedLeast8Characters;
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return S.passwordsMustIncludeLetter;
    if (!RegExp(r'[0-9]').hasMatch(value)) return S.passwordsMustIncludeNumber;
    return null;
  }
}

class CabinetSelectField extends StatefulWidget {
  final int? value;
  final void Function(Map<String, dynamic>? cabinet, bool byUser) onChanged;
  final bool autoSelectNearest;
  final int? keepSelectableId;
  final String? errorText;

  const CabinetSelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.autoSelectNearest = false,
    this.keepSelectableId,
    this.errorText,
  });

  static int? idOf(Map<String, dynamic> cabinet) => (cabinet['cabinet_id'] as num?)?.toInt();

  static int? slotsOf(Map<String, dynamic> cabinet) => int.tryParse('${cabinet['available_slots']}');

  static num? distanceOf(Map<String, dynamic> cabinet) => num.tryParse('${cabinet['distance_m']}');

  static String nameOf(Map<String, dynamic> cabinet) {
    final name = '${cabinet['cabinet_name'] ?? ''}'.trim();
    return name.isEmpty ? S.unknownLocker : name;
  }

  @override
  State<CabinetSelectField> createState() => _CabinetSelectFieldState();
}

class _CabinetSelectFieldState extends State<CabinetSelectField> with WidgetsBindingObserver {
  final _api = ApiService();
  List<Map<String, dynamic>> _cabinets = [];
  bool _loading = true;
  bool _located = false;
  bool _locating = false;
  bool _awaitingSettings = false;
  int? _autoPickedId;
  int? _reportedId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(requestLocation: true);
  }

  @override
  void didUpdateWidget(CabinetSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_loading) _reconcile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      _locate(request: false);
    }
  }

  Future<void> _load({bool requestLocation = false}) async {
    final generation = ++_generation;
    if (_cabinets.isEmpty && !_loading) setState(() => _loading = true);

    final known = LocationService.lastKnown;
    await _fetch(known?.latitude, known?.longitude, generation);
    if (!mounted || generation != _generation) return;
    if (known == null) await _locate(request: requestLocation);
  }

  Future<void> _fetch(double? lat, double? lng, int generation) async {
    final list = await _api.fetchCabinets(latitude: lat, longitude: lng);
    if (!mounted || generation != _generation) return;
    setState(() {
      _cabinets = list;
      _loading = false;
      _located = lat != null && list.any((cab) => CabinetSelectField.distanceOf(cab) != null);
    });
    _reconcile();
  }

  Future<void> _locate({required bool request}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final position = await LocationService.current(request: request);
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) return;
    await _fetch(position.latitude, position.longitude, ++_generation);
  }

  Future<void> _enableLocation() async {
    HapticFeedback.selectionClick();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _awaitingSettings = true;
        await Geolocator.openLocationSettings();
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        _awaitingSettings = true;
        await Geolocator.openAppSettings();
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    await _locate(request: true);
    if (mounted && !_located) {
      showAppSnackBar(context, S.couldnTGetLocationLockersShown, isError: true);
    }
  }

  bool _selectable(Map<String, dynamic> cabinet) {
    final slots = CabinetSelectField.slotsOf(cabinet);
    return slots == null || slots > 0 || CabinetSelectField.idOf(cabinet) == widget.keepSelectableId;
  }

  void _reconcile() {
    if (_cabinets.isEmpty) return;
    final value = widget.value;
    final current = value == null
        ? null
        : _cabinets.where((cab) => CabinetSelectField.idOf(cab) == value).firstOrNull;

    Map<String, dynamic>? next = current;
    if (value != null && current == null) next = null;

    final canAutoPick = widget.autoSelectNearest && (value == null || value == _autoPickedId);
    if (canAutoPick) {
      final nearest = _cabinets.where(_selectable).firstOrNull;
      if (nearest != null) {
        next = nearest;
        _autoPickedId = CabinetSelectField.idOf(nearest);
      }
    }

    final nextId = next == null ? null : CabinetSelectField.idOf(next);
    if (nextId != value || nextId != _reportedId) {
      _reportedId = nextId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(next, false);
      });
    }
  }

  List<AppSelectOption<int>> _options() {
    final nearestId = _located
        ? _cabinets.where(_selectable).map(CabinetSelectField.idOf).firstOrNull
        : null;

    return [
      for (final cab in _cabinets)
        if (CabinetSelectField.idOf(cab) != null)
          _option(cab, nearest: CabinetSelectField.idOf(cab) == nearestId),
    ];
  }

  AppSelectOption<int> _option(Map<String, dynamic> cab, {required bool nearest}) {
    final c = AppColors.of(context);
    final slots = CabinetSelectField.slotsOf(cab);
    final distance = CabinetSelectField.distanceOf(cab);
    final hours = formatTimeRange(cab['open_time'], cab['close_time']);
    final address = '${cab['address'] ?? ''}'.trim();
    final selectable = _selectable(cab);

    return AppSelectOption<int>(
      value: CabinetSelectField.idOf(cab)!,
      label: CabinetSelectField.nameOf(cab),
      subtitle: address.isEmpty ? null : address,
      caption: [
        if (slots != null) S.p0SlotsFree(slots),
        if (hours.isNotEmpty) S.openP0(hours),
      ].join('・'),
      icon: Icons.inventory_2_outlined,
      iconColor: slots == 0 ? c.danger : null,
      trailing: distance == null ? null : LocationService.formatDistance(distance),
      badge: nearest ? S.nearest : null,
      enabled: selectable,
      disabledReason: selectable ? null : S.noFreeSlots,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selected = widget.value == null
        ? null
        : _cabinets.where((cab) => CabinetSelectField.idOf(cab) == widget.value).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelect<int>(
          value: widget.value,
          options: _options(),
          loading: _loading,
          hint: _loading ? S.loading : S.chooseLocker,
          title: S.lockerLocation,
          sheetSubtitle: _located ? S.sortedByDistance : S.turnLocationSortByDistance,
          emptyText: S.noLockersMatch,
          errorText: widget.errorText,
          leadingIcon: Icons.inventory_2_outlined,
          onChanged: _cabinets.isEmpty
              ? null
              : (id) {
                  final cab = _cabinets.firstWhere((e) => CabinetSelectField.idOf(e) == id);
                  _autoPickedId = null;
                  _reportedId = id;
                  widget.onChanged(cab, true);
                },
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.standard,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected != null) _buildSelectedInfo(c, selected),
              if (!_loading && _cabinets.isEmpty) _buildEmpty(c),
              if (!_loading && _cabinets.isNotEmpty && !_located) _buildLocationHint(c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedInfo(AppColors c, Map<String, dynamic> cab) {
    final distance = CabinetSelectField.distanceOf(cab);
    final address = '${cab['address'] ?? ''}'.trim();
    final slots = CabinetSelectField.slotsOf(cab);
    final parts = [
      if (distance != null) LocationService.formatDistance(distance),
      if (address.isNotEmpty) address,
    ];
    if (parts.isEmpty && slots != 0) return const SizedBox.shrink();

    return FadeSlideIn(
      key: ValueKey(CabinetSelectField.idOf(cab)),
      offsetY: 6,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parts.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.near_me_rounded, size: 13, color: c.accent),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      parts.join('・'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            if (slots == 0) ...[
              const SizedBox(height: 3),
              Text(
                S.lockerNoFreeSlotsRightNow,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHint(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined, size: 13, color: c.textHint),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              S.turnLocationSortByDistance,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ),
          _locating
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                  ),
                )
              : TextButton(
                  onPressed: _enableLocation,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(S.turn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: c.warning),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              S.noLockersAvailable,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _load(),
            style: TextButton.styleFrom(
              foregroundColor: c.accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(S.reload, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
