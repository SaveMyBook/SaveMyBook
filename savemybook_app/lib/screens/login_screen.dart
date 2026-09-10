import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/state_views.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = '請輸入 Email';
    } else if (!Validators.isEmail(email)) {
      emailError = 'Email 格式不正確';
    }

    if (password.isEmpty) {
      passwordError = '請輸入密碼';
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });

    return emailError == null && passwordError == null;
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !_validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final outcome = await _apiService.login(_emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (outcome.isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (outcome.accountNotFound) {
      await _offerRegistration();
      return;
    }

    _passwordController.clear();
    setState(() => _passwordError = outcome.message);
    showAppSnackBar(context, outcome.message, isError: true);
  }

  Future<void> _offerRegistration() async {
    final email = _emailController.text.trim();

    final confirmed = await showConfirmDialog(
      context,
      title: '此帳號尚未註冊',
      message: '找不到「$email」這個帳號。要現在建立一個嗎？',
      confirmLabel: '前往註冊',
      cancelLabel: '重新輸入',
    );

    if (!confirmed || !mounted) return;

    final registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(initialEmail: email)),
    );

    if (registeredEmail != null && mounted) {
      _emailController.text = registeredEmail;
      _passwordController.clear();
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.card,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.menu_book_rounded, size: 100, color: c.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 1,
                    child: Text(
                      'SaveMyBook',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.accent),
                    ),
                  ),
                  const SizedBox(height: 48),
                  FadeSlideIn(
                    index: 2,
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
                    index: 3,
                    child: AppTextField(
                      controller: _passwordController,
                      hint: '密碼',
                      errorText: _passwordError,
                      obscureText: _obscurePassword,
                      maxLength: 64,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
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
                  const SizedBox(height: 32),
                  FadeSlideIn(
                    index: 4,
                    child: PrimaryButton(
                      label: '登入',
                      height: 50,
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 5,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final registeredEmail = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(
                                    initialEmail: _emailController.text.trim(),
                                  ),
                                ),
                              );
                              if (registeredEmail != null && mounted) {
                                _emailController.text = registeredEmail;
                              }
                            },
                      child: Text('還沒有帳號？立即註冊', style: TextStyle(color: c.accent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
