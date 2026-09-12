import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/photo_service.dart';
import '../utils/app_colors.dart';
import '../widgets/guards.dart';
import '../widgets/app_tiles.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../i18n/strings.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _api = ApiService();

  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  DateTime? _birthday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _birthday = user?.birthday;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final path = await PhotoService.pickAndCrop(context, circular: true, outputSize: 720);
    if (path == null || !mounted) return;

    final ok = await runBusy(context, () => _api.uploadAvatar(path), message: S.uploading);
    if (!mounted) return;
    if (ok == true) {
      setState(() {});
      showAppSnackBar(context, S.profilePhotoUpdated);
    } else {
      showAppSnackBar(context, S.couldNotUploadPhoto, isError: true);
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
        title: Text(S.changeDisplayName, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(hintText: S.enterDisplayName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.actionCancel, style: TextStyle(color: c.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(S.actionConfirm, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _nicknameController.text = result);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final nickname = _nicknameController.text.trim();
    final phone = _phoneController.text.trim();

    if (nickname.isEmpty) {
      showAppSnackBar(context, S.displayNameCannotBlank, isError: true);
      return;
    }
    if (nickname.length < 2 || nickname.length > 50) {
      showAppSnackBar(context, S.displayNames250Characters, isError: true);
      return;
    }
    if (phone.isNotEmpty && !Validators.isPhone(phone)) {
      showAppSnackBar(context, S.invalidPhoneNumberEG0912345678, isError: true);
      return;
    }

    final date = _birthday;
    final birthday = date == null
        ? null
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    setState(() => _isSaving = true);
    final error = await _api.updateProfile(
      nickname: nickname,
      bio: _bioController.text.trim(),
      phone: phone,
      birthday: birthday,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.profileUpdated);
      Navigator.of(context).maybePop();
    }
  }

  /// 跟載入時的值比對。沒動過就不要在返回時多問一句。
  /// 頭像是即時上傳的，不算在這裡。
  bool get _isDirty {
    final user = ApiService.currentUser;
    return _nicknameController.text != (user?.nickname ?? '') ||
        _bioController.text != (user?.bio ?? '') ||
        _phoneController.text != (user?.phone ?? '') ||
        _birthday != user?.birthday;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final avatarUrl = ApiService.currentUser?.avatarUrl;

    return UnsavedGuard(
      isDirty: _isDirty,
      child: Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.editProfile, icon: Icons.edit_outlined),
          Expanded(
            child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      UserAvatar(imageUrl: avatarUrl, radius: 48),
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
                          _nicknameController.text.isEmpty ? S.user : _nicknameController.text,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 16, color: c.iconInactive),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FormRowCard(
                    label: S.bio,
                    alignTop: true,
                    child: AppTextField(controller: _bioController, maxLines: 4, maxLength: 200, hint: S.tellPeopleAboutYourself),
                  ),
                  FormRowCard(label: S.phone, child: AppTextField(controller: _phoneController, keyboardType: TextInputType.phone, maxLength: 20, hint: '0912345678')),
                  FormRowCard(
                    label: S.email,
                    child: AppTextField(controller: _emailController, enabled: false, hint: S.emailCannotChanged),
                  ),
                  FormRowCard(
                    label: S.dateBirth,
                    child: AppDateField(
                      value: _birthday,
                      hint: S.tapPickDateBirth,
                      helpText: S.pickDateBirth,
                      onChanged: (value) => setState(() => _birthday = value),
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
                          : Text(S.actionSave, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
