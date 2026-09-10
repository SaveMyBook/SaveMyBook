import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

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
      showAppSnackBar(context, '請填寫書櫃名稱與地址', isError: true);
      return;
    }
    if (lat == null || lng == null) {
      showAppSnackBar(context, '請填寫正確的經緯度', isError: true);
      return;
    }
    if (lat < -90 || lat > 90) {
      showAppSnackBar(context, '緯度必須介於 -90 ~ 90', isError: true);
      return;
    }
    if (lng < -180 || lng > 180) {
      showAppSnackBar(context, '經度必須介於 -180 ~ 180', isError: true);
      return;
    }

    final slots = int.tryParse(_slotsController.text.trim()) ?? 20;
    if (!_isEdit && (slots < 1 || slots > 100)) {
      showAppSnackBar(context, '櫃位數量必須介於 1 ~ 100', isError: true);
      return;
    }

    final openTime = _openController.text.trim();
    final closeTime = _closeController.text.trim();
    final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    for (final entry in [(openTime, '開放時間'), (closeTime, '關閉時間')]) {
      if (entry.$1.isNotEmpty && !timePattern.hasMatch(entry.$1)) {
        showAppSnackBar(context, '${entry.$2}格式應為 HH:mm，例：09:00', isError: true);
        return;
      }
    }
    if (openTime.isNotEmpty != closeTime.isNotEmpty) {
      showAppSnackBar(context, '開放與關閉時間請一起填寫', isError: true);
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
      showAppSnackBar(context, _isEdit ? '書櫃已更新' : '書櫃已新增');
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
          AppHeader(title: _isEdit ? '修改書櫃' : '新增書櫃', icon: Icons.storage_rounded),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field('書櫃名稱', _nameController, c),
                  _field('地址', _addressController, c, maxLines: 2),
                  _field('緯度', _latController, c, keyboardType: TextInputType.number),
                  _field('經度', _lngController, c, keyboardType: TextInputType.number),
                  if (!_isEdit)
                    _field('櫃位數量', _slotsController, c, keyboardType: TextInputType.number),
                  _field('開放時間', _openController, c, hint: '09:00'),
                  _field('關閉時間', _closeController, c, hint: '21:00'),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: c.accent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isEdit ? '儲存變更' : '建立書櫃',
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
