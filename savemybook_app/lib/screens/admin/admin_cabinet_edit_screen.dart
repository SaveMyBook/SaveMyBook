import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminCabinetEditScreen extends StatefulWidget {
  final Cabinet? cabinet;
  const AdminCabinetEditScreen({super.key, this.cabinet});

  @override
  State<AdminCabinetEditScreen> createState() => _AdminCabinetEditScreenState();
}

class _AdminCabinetEditScreenState extends State<AdminCabinetEditScreen> {
  final ApiService _api = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _slotsController;
  late final TextEditingController _openController;
  late final TextEditingController _closeController;

  bool _isSaving = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _slotsController.dispose();
    _openController.dispose();
    _closeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (name.isEmpty || address.isEmpty) {
      showAppSnackBar(context, S.enterLockerNameAddress, isError: true);
      return;
    }
    if (lat == null || lng == null) {
      showAppSnackBar(context, S.enterValidLatitudeLongitude, isError: true);
      return;
    }
    if (lat < -90 || lat > 90) {
      showAppSnackBar(context, S.latitudeMustBetween9090, isError: true);
      return;
    }
    if (lng < -180 || lng > 180) {
      showAppSnackBar(context, S.longitudeMustBetween180180, isError: true);
      return;
    }

    final slots = int.tryParse(_slotsController.text.trim()) ?? 20;
    if (!_isEdit && (slots < 1 || slots > 100)) {
      showAppSnackBar(context, S.slotCountMustBetween1100, isError: true);
      return;
    }

    final openTime = _openController.text.trim();
    final closeTime = _closeController.text.trim();
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    for (final entry in [(openTime, S.openingHours), (closeTime, S.closingTime)]) {
      if (entry.$1.isNotEmpty && !timePattern.hasMatch(entry.$1)) {
        showAppSnackBar(context, S.p0MustLookLikeHhMm(entry.$2), isError: true);
        return;
      }
    }
    if (openTime.isNotEmpty != closeTime.isNotEmpty) {
      showAppSnackBar(context, S.fillBothOpeningClosingTimes, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final error = await _api.saveCabinet(
      cabinetId: widget.cabinet?.cabinetId,
      name: name,
      address: address,
      latitude: lat,
      longitude: lng,
      totalSlots: slots,
      openTime: openTime.isEmpty ? null : '$openTime:00',
      closeTime: closeTime.isEmpty ? null : '$closeTime:00',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, _isEdit ? S.lockerUpdated : S.lockerAdded);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: _isEdit ? S.editLocker : S.newLocker, icon: Icons.storage_rounded),
          Expanded(
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(S.lockerName, _nameController, c),
                  _field(S.address, _addressController, c, maxLines: 2),
                  _field(S.latitude, _latController, c, keyboardType: TextInputType.number),
                  _field(S.longitude, _lngController, c, keyboardType: TextInputType.number),
                  if (!_isEdit)
                    _field(S.slotCount, _slotsController, c, keyboardType: TextInputType.number),
                  _field(S.openingHours, _openController, c, hint: '09:00'),
                  _field(S.closingTime, _closeController, c, hint: '21:00'),
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
                          : Text(_isEdit ? S.saveChanges : S.createLocker,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _field(
    String label,
    TextEditingController controller,
    AppColors c, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return FormRowCard(
      label: label,
      alignTop: maxLines > 1,
      child: AppTextField(
        controller: controller,
        maxLines: maxLines,
        hint: hint,
        keyboardType: keyboardType,
      ),
    );
  }
}
