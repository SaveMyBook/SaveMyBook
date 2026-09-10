import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_forms.dart';
import '../widgets/state_views.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';

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
      nicknameError = '請輸入暱稱';
    } else if (nickname.length < 2) {
      nicknameError = '暱稱至少 2 個字元';
    } else if (nickname.length > 50) {
      nicknameError = '暱稱不可超過 50 個字元';
    }

    if (email.isEmpty) {
      emailError = '請輸入 Email';
    } else if (!Validators.isEmail(email)) {
      emailError = 'Email 格式不正確';
    }

    passwordError = password.isEmpty ? '請輸入密碼' : Validators.password(password);

    if (confirm.isEmpty) {
      confirmError = '請再輸入一次密碼';
    } else if (confirm != password) {
      confirmError = '兩次輸入的密碼不一致';
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
      showAppSnackBar(context, '請先閱讀並同意服務條款與隱私權政策', isError: true);
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

    showAppSnackBar(context, '註冊成功，請使用新帳號登入');
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            activeColor: c.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, height: 1.6, color: c.textSecondary),
                children: [
                  const TextSpan(text: '我已閱讀並同意 '),
                  TextSpan(
                    text: '服務條款',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TermsScreen()),
                          ),
                  ),
                  const TextSpan(text: ' 與 '),
                  TextSpan(
                    text: '隱私權政策',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.card,
      appBar: AppBar(
        backgroundColor: c.card,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text('建立帳號', style: TextStyle(color: c.textPrimary, fontSize: 18)),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text(
                  '加入 SaveMyBook',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                index: 1,
                child: Text(
                  '註冊後就能買書、賣書與使用智慧書櫃',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(height: 32),
              FadeSlideIn(
                index: 2,
                child: AppTextField(
                  controller: _nicknameController,
                  hint: '暱稱',
                  errorText: _nicknameError,
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_nicknameError != null) setState(() => _nicknameError = null);
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 3,
                child: AppTextField(
                  controller: _emailController,
                  hint: 'Email',
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  maxLength: 255,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 4,
                child: AppTextField(
                  controller: _passwordController,
                  hint: '密碼（至少 8 碼，含英文與數字）',
                  errorText: _passwordError,
                  obscureText: _obscurePassword,
                  maxLength: 64,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_passwordError != null) setState(() => _passwordError = null);
                  },
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
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 5,
                child: AppTextField(
                  controller: _confirmController,
                  hint: '再次輸入密碼',
                  errorText: _confirmError,
                  obscureText: _obscurePassword,
                  maxLength: 64,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                  onChanged: (_) {
                    if (_confirmError != null) setState(() => _confirmError = null);
                  },
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(index: 6, child: _buildTermsRow(c)),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 7,
                child: PrimaryButton(
                  label: '建立帳號',
                  height: 50,
                  isLoading: _isLoading,
                  onPressed: _agreedToTerms ? _handleRegister : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
