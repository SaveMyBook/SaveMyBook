import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _yearController;
  late final TextEditingController _monthController;
  late final TextEditingController _dayController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _yearController = TextEditingController(text: user?.birthday?.year.toString() ?? '');
    _monthController = TextEditingController(text: user?.birthday?.month.toString() ?? '');
    _dayController = TextEditingController(text: user?.birthday?.day.toString() ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final ok = await _api.uploadAvatar(picked.path);
    if (!mounted) return;
    if (ok) {
      setState(() {});
      showAppSnackBar(context, '頭像已更新');
    } else {
      showAppSnackBar(context, '頭像上傳失敗', isError: true);
    }
  }

  Future<void> _editNickname() async {
    final c = AppColors.of(context);
    final controller = TextEditingController(text: _nicknameController.text);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('修改暱稱', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: const InputDecoration(hintText: '請輸入暱稱'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('確定', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _nicknameController.text = result);
    }
  }

  Future<void> _save() async {
    if (_nicknameController.text.trim().isEmpty) {
      showAppSnackBar(context, '暱稱不可空白', isError: true);
      return;
    }

    String? birthday;
    final year = _yearController.text.trim();
    final month = _monthController.text.trim();
    final day = _dayController.text.trim();
    if (year.isNotEmpty && month.isNotEmpty && day.isNotEmpty) {
      birthday = '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
    }

    setState(() => _isSaving = true);
    final error = await _api.updateProfile(
      nickname: _nicknameController.text.trim(),
      bio: _bioController.text.trim(),
      phone: _phoneController.text.trim(),
      birthday: birthday,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '個人檔案已更新');
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final avatarUrl = ApiService.currentUser?.avatarUrl;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '編輯個人檔案', icon: Icons.edit_outlined),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: c.inputFill,
                        backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
                        child: avatarUrl == null
                            ? Icon(Icons.person, size: 48, color: c.iconInactive)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _changeAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: c.card,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6)],
                            ),
                            child: const Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _editNickname,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nicknameController.text.isEmpty ? '使用者' : _nicknameController.text,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 16, color: c.iconInactive),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FieldCard(
                    label: '個人簡介',
                    alignTop: true,
                    child: _input(_bioController, c, maxLines: 4, hint: '介紹一下自己吧'),
                  ),
                  _FieldCard(label: '電話', child: _input(_phoneController, c, keyboardType: TextInputType.phone)),
                  _FieldCard(
                    label: '信箱',
                    child: _input(_emailController, c, enabled: false, hint: '信箱無法修改'),
                  ),
                  _FieldCard(
                    label: '生日',
                    child: Row(
                      children: [
                        Expanded(child: _input(_yearController, c, keyboardType: TextInputType.number)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('年', style: TextStyle(color: c.textPrimary)),
                        ),
                        Expanded(child: _input(_monthController, c, keyboardType: TextInputType.number)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('月', style: TextStyle(color: c.textPrimary)),
                        ),
                        Expanded(child: _input(_dayController, c, keyboardType: TextInputType.number)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('日', style: TextStyle(color: c.textPrimary)),
                        ),
                      ],
                    ),
                  ),
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
                          : const Text('儲存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _input(
    TextEditingController controller,
    AppColors c, {
    int maxLines = 1,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? c.textPrimary : c.textHint, fontSize: 14),
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
    );
  }
}

class _FieldCard extends StatelessWidget {
  final String label;
  final Widget child;
  final bool alignTop;

  const _FieldCard({required this.label, required this.child, this.alignTop = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 10 : 0),
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
