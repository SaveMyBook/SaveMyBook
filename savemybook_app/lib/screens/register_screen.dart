import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'legal_doc_screen.dart';
import '../i18n/strings.dart';

class RegisterScreen extends StatefulWidget {
  final String initialEmail;
  const RegisterScreen({super.key, this.initialEmail = ''});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nicknameController = TextEditingController();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  String? _nicknameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? nicknameError;
    String? emailError;
    String? passwordError;
    String? confirmError;

    if (nickname.isEmpty) {
      nicknameError = S.enterDisplayName;
    } else if (nickname.length < 2) {
      nicknameError = S.displayNameNeedsLeast2Characters;
    } else if (nickname.length > 50) {
      nicknameError = S.displayNameLimited50Characters;
    }

    if (email.isEmpty) {
      emailError = S.enterEmail;
    } else if (!Validators.isEmail(email)) {
      emailError = S.emailAddressNotValid;
    }

    passwordError = password.isEmpty ? S.enterPassword : Validators.password(password);

    if (confirm.isEmpty) {
      confirmError = S.enterPasswordAgain;
    } else if (confirm != password) {
      confirmError = S.passwordsDoNotMatch2;
    }

    setState(() {
      _nicknameError = nicknameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    final passed = nicknameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmError == null;

    if (passed && !_agreedToTerms) {
      showAppSnackBar(context, S.pleaseReadAcceptTermsServicePrivacy, isError: true);
      return false;
    }

    return passed;
  }

  Future<void> _handleRegister() async {
    if (_isLoading || !_validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    setState(() => _isLoading = true);
    final error = await _apiService.register(
      email,
      _passwordController.text,
      _nicknameController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      if (error.contains('Email')) setState(() => _emailError = error);
      showAppSnackBar(context, error, isError: true);
      return;
    }

    showAppSnackBar(context, S.accountCreatedSignWith);
    Navigator.pop(context, email);
  }

  Widget _buildTermsRow(AppColors c) {
    final linkStyle = TextStyle(
      color: c.accent,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.accent,
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              activeColor: c.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 13, height: 1.6, color: c.textSecondary),
                  children: [
                    TextSpan(text: S.iReadAccept),
                    TextSpan(
                      text: S.termsService,
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(
                              builder: (_) => LegalDocScreen(
                                docKey: 'terms',
                                fallbackTitle: S.termsService,
                              ),
                            ),
                            ),
                    ),
                    TextSpan(text: S.and),
                    TextSpan(
                      text: S.privacyPolicy,
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => Navigator.push(
                              context,
                              MaterialPageRoute(
                              builder: (_) => LegalDocScreen(
                                docKey: 'privacy',
                                fallbackTitle: S.privacyPolicy,
                                icon: Icons.privacy_tip_outlined,
                              ),
                            ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required int index,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required AppColors c,
    String? hint,
    String? errorText,
    bool obscureText = false,
    bool isLast = false,
    int? maxLength,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return FadeSlideIn(
      index: index,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: controller,
              hint: hint,
              errorText: errorText,
              obscureText: obscureText,
              maxLength: maxLength,
              keyboardType: keyboardType,
              textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
              suffix: suffix,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.createAccount, icon: Icons.person_add_alt_1_rounded),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  FadeSlideIn(
                    child: AppCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.menu_book_rounded, color: c.accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  S.joinSavemybook,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  S.signUpBuySellUseSmart,
                                  style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildField(
                    index: 1,
                    icon: Icons.badge_outlined,
                    label: S.displayName,
                    hint: S.nameOthersSee,
                    controller: _nicknameController,
                    errorText: _nicknameError,
                    maxLength: 50,
                    c: c,
                    onChanged: (_) {
                      if (_nicknameError != null) setState(() => _nicknameError = null);
                    },
                  ),
                  _buildField(
                    index: 2,
                    icon: Icons.alternate_email_rounded,
                    label: 'Email',
                    hint: S.emailSignWith,
                    controller: _emailController,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 255,
                    c: c,
                    onChanged: (_) {
                      if (_emailError != null) setState(() => _emailError = null);
                    },
                  ),
                  _buildField(
                    index: 3,
                    icon: Icons.lock_outline_rounded,
                    label: S.password,
                    hint: S.least8CharactersWithLettersNumbers,
                    controller: _passwordController,
                    errorText: _passwordError,
                    obscureText: _obscurePassword,
                    maxLength: 64,
                    c: c,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: c.iconInactive,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onChanged: (_) {
                      if (_passwordError != null) setState(() => _passwordError = null);
                    },
                  ),
                  _buildField(
                    index: 4,
                    icon: Icons.lock_reset_rounded,
                    label: S.confirmPassword,
                    hint: S.enterPasswordAgain2,
                    controller: _confirmController,
                    errorText: _confirmError,
                    obscureText: _obscurePassword,
                    maxLength: 64,
                    isLast: true,
                    c: c,
                    onSubmitted: (_) => _handleRegister(),
                    onChanged: (_) {
                      if (_confirmError != null) setState(() => _confirmError = null);
                    },
                  ),
                  const SizedBox(height: 4),
                  FadeSlideIn(index: 5, child: _buildTermsRow(c)),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 6,
                    child: PrimaryButton(
                      label: S.createAccount,
                      height: 50,
                      isLoading: _isLoading,
                      onPressed: _agreedToTerms ? _handleRegister : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 7,
                    child: Center(
                      child: Text(
                        S.alreadyAccountGoBackSign,
                        style: TextStyle(fontSize: 12, color: c.textHint),
                      ),
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
}
