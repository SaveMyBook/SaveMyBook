import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/photo_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/guards.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

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
  bool _saved = false;
  bool _uploadingAvatar = false;
  String? _phoneError;

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
    if (_uploadingAvatar) return;
    _uploadingAvatar = true;
    try {
      await _pickAvatar();
    } finally {
      _uploadingAvatar = false;
    }
  }

  Future<void> _pickAvatar() async {
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
    final result = await showTextInputDialog(
      context,
      title: S.changeDisplayName,
      hint: S.enterDisplayName,
      initialValue: _nicknameController.text,
      maxLength: 50,
      validator: (value) {
        if (value.isEmpty) return S.displayNameCannotBlank;
        if (value.length < 2 || value.length > 50) return S.displayNames250Characters;
        return null;
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
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
      setState(() => _phoneError = S.invalidPhoneNumberEG0912345678);
      return;
    }
    FocusScope.of(context).unfocus();

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
      setState(() => _saved = true);
      showAppSnackBar(context, S.profileUpdated);
      Navigator.of(context).pop();
    }
  }

  bool get _isDirty {
    if (_saved || _isSaving) return false;
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 20, bottom: 20),
              child: Column(
                children: [
                  Stack(
                    children: [
                      PressableScale(
                        onTap: _changeAvatar,
                        child: UserAvatar(imageUrl: avatarUrl, radius: 48),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: PressableScale(
                          scale: 0.9,
                          onTap: _changeAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: c.card,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6)],
                            ),
                            child: Icon(Icons.photo_camera_outlined, size: 18, color: c.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PressableScale(
                    onTap: _editNickname,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _nicknameController.text.isEmpty ? S.user : _nicknameController.text,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit_outlined, size: 16, color: c.iconInactive),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.tapPhotoNameChange,
                    style: TextStyle(fontSize: 12, color: c.textHint),
                  ),
                  const SizedBox(height: 18),
                  FormRowCard(
                    label: S.bio,
                    alignTop: true,
                    state: _bioController.text.trim().isEmpty ? FieldState.empty : FieldState.normal,
                    child: AppTextField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 200,
                      hint: S.tellPeopleAboutYourself,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  FormRowCard(
                    label: S.phone,
                    state: _phoneController.text.trim().isEmpty ? FieldState.empty : FieldState.normal,
                    child: AppTextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      hint: '0912345678',
                      errorText: _phoneError,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => _phoneError = null),
                    ),
                  ),
                  FormRowCard(
                    label: S.email,
                    state: FieldState.locked,
                    child: AppTextField(
                      controller: _emailController,
                      enabled: false,
                      hint: S.emailCannotChanged,
                      suffix: Icon(Icons.lock_outline_rounded, size: 16, color: c.textHint),
                    ),
                  ),
                  FormRowCard(
                    label: S.dateBirth,
                    state: _birthday == null ? FieldState.empty : FieldState.normal,
                    child: AppDateField(
                      value: _birthday,
                      hint: S.tapPickDateBirth,
                      helpText: S.pickDateBirth,
                      onChanged: (value) => setState(() => _birthday = value),
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: S.actionSave,
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
