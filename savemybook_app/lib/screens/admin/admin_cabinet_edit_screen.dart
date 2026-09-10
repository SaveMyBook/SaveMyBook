import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

/// 硬體維護－新增／修改書櫃
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

    setState(() => _isSaving = true);
    final error = await _api.saveCabinet(
      cabinetId: widget.cabinet?.cabinetId,
      name: name,
      address: address,
      latitude: lat,
      longitude: lng,
      totalSlots: int.tryParse(_slotsController.text.trim()) ?? 20,
      openTime: _openController.text.trim().isEmpty ? null : '${_openController.text.trim()}:00',
      closeTime: _closeController.text.trim().isEmpty ? null : '${_closeController.text.trim()}:00',
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 10 : 0),
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: TextStyle(color: c.textHint, fontSize: 13),
                filled: true,
                fillColor: c.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
