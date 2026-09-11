import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/biometric_icon.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/state_views.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../i18n/strings.dart';

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
  bool _canUseBiometric = false;
  String _biometricLabel = S.biometrics;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    if (!BiometricService.isEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    if (!await BiometricService.isAvailable()) return;
    final label = await BiometricService.label();
    if (!mounted) return;

    setState(() {
      _canUseBiometric = true;
      _biometricLabel = label;
    });
  }

  Future<void> _biometricLogin() async {
    if (_isLoading) return;

    final ok = await BiometricService.authenticate(reason: S.verifySignSavemybook);
    if (!ok || !mounted) return;

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _canUseBiometric = false;
      });
      showAppSnackBar(context, S.sessionExpiredPleaseEnterPasswordAgain, isError: true);
      return;
    }

    ApiService.authToken = token;
    await _apiService.fetchCurrentUser();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ApiService.currentUser == null) {
      setState(() => _canUseBiometric = false);
      showAppSnackBar(context, S.sessionExpiredPleaseEnterPasswordAgain, isError: true);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _offerBiometric() async {
    if (BiometricService.isEnabled) return;
    if (!await BiometricService.isAvailable() || !mounted) return;

    final label = await BiometricService.label();
    if (!mounted) return;

    final ok = await showConfirmDialog(
      context,
      title: S.turnSign(label),
      message: S.nextTimeOpenAppCanUnlock(label),
      confirmLabel: S.enable,
      cancelLabel: S.notNow,
    );
    if (ok) await BiometricService.setEnabled(true);
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = S.enterEmail;
    } else if (!Validators.isEmail(email)) {
      emailError = S.emailAddressNotValid;
    }

    if (password.isEmpty) {
      passwordError = S.enterPassword;
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
      await _offerBiometric();
      if (!mounted) return;
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
      title: S.noAccountWithEmail,
      message: S.noAccountCreateOneNow(email),
      confirmLabel: S.signUp,
      cancelLabel: S.tryAgain,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 鍵盤打開時 Scaffold 已經把高度縮掉了，這裡要跟著用縮過的高度，
              // 否則 ConstrainedBox 還撐著整個畫面高，輸入框會被推到看不見的地方。
              final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: keyboardOpen ? 20 : 0),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: FadeSlideIn(
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: keyboardOpen ? 72 : 120,
                                height: keyboardOpen ? 72 : 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(Icons.menu_book_rounded, size: 100, color: c.accent),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 12 : 24),
                      FadeSlideIn(
                        index: 1,
                        child: Text(
                          'SaveMyBook',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.accent),
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 24 : 48),
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
                          hint: S.password,
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
                      SizedBox(height: keyboardOpen ? 20 : 32),
                      FadeSlideIn(
                        index: 4,
                        child: PrimaryButton(
                          label: S.sign,
                          height: 50,
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ),
                      ),
                      if (_canUseBiometric) ...[
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          index: 5,
                          child: SecondaryButton(
                            label: S.signWith(_biometricLabel),
                            iconBuilder: _biometricLabel == 'Face ID'
                                ? (color) => FaceIdIcon(size: 19, color: color)
                                : null,
                            icon: _biometricLabel == 'Face ID'
                                ? null
                                : Icons.fingerprint_rounded,
                            height: 50,
                            onPressed: _isLoading ? null : _biometricLogin,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
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
                          child: Text(S.noAccountYetSignUp, style: TextStyle(color: c.accent)),
                        ),
                      ),
                      SizedBox(height: keyboardOpen ? 16 : 0),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
