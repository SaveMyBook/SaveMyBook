import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/biometric_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/biometric_icon.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../home/home_screen.dart';
import '../../models/auth_social.dart';
import '../security/passkey_sign_in_button.dart';
import 'register_screen.dart';
import 'social_sign_in.dart';
import '../../services/social_auth_service.dart';
import '../../i18n/strings.dart';
import '../../utils/app_info.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();

  static const _lastEmailKey = 'last_login_email';

  bool _isLoading = false;
  bool _biometricBusy = false;
  int _shake = 0;
  bool _obscurePassword = true;
  bool _canUseBiometric = false;
  String _biometricLabel = S.biometrics;
  String? _emailError;
  String? _passwordError;
  AuthProvidersInfo _providers = AuthProvidersInfo.none;
  String? _socialBusy;

  @override
  void initState() {
    super.initState();
    _restoreEmail();
    _checkBiometric();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final providers = await _apiService.fetchAuthProviders();
    if (!mounted) return;
    setState(() => _providers = providers);
  }

  Future<void> _handlePasskeySignedIn() async {
    unawaited(HomeWidgetService.sync(force: true));
    final email = ApiService.currentUser?.email;
    if (email != null && email.isNotEmpty) await _rememberEmail(email);
    await _offerBiometric();
    if (!mounted) return;
    _goHome();
  }

  Future<void> _handleSocial(String provider) async {
    if (_isLoading || _socialBusy != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _socialBusy = provider);

    final ok = await SocialSignInFlow.signIn(context, provider);
    if (!mounted) return;
    setState(() => _socialBusy = null);
    if (!ok) return;

    unawaited(HomeWidgetService.sync(force: true));
    await _offerBiometric();
    if (!mounted) return;
    _goHome();
  }

  Future<void> _restoreEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_lastEmailKey);
    if (!mounted || email == null || email.isEmpty || _emailController.text.isNotEmpty) return;
    _emailController.text = email;
  }

  Future<void> _rememberEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailKey, email);
  }

  @override
  void dispose() {
    // 離開登入頁時不留下等待中的 LINE／Discord 授權。
    SocialAuth.cancelOAuthWait();
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
    if (_isLoading || _biometricBusy) return;

    _biometricBusy = true;
    final ok = await BiometricService.authenticate(reason: S.verifySignSavemybook);
    _biometricBusy = false;
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
      ApiService.authToken = null;
      setState(() => _canUseBiometric = false);
      showAppSnackBar(context, S.sessionExpiredPleaseEnterPasswordAgain, isError: true);
      return;
    }

    _goHome();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
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
    if (_isLoading) return;
    if (!_validate()) {
      setState(() => _shake++);
      return;
    }
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);
    if (ApiService.currentUser == null) ApiService.authToken = null;
    final outcome = await _apiService.login(email, _passwordController.text);
    if (!mounted) return;

    if (outcome.isSuccess) {
      unawaited(HomeWidgetService.sync(force: true));
      await _rememberEmail(email);
      await _offerBiometric();
      if (!mounted) return;
      _goHome();
      return;
    }
    setState(() => _isLoading = false);

    switch (outcome.code) {
      case 'ACCOUNT_NOT_FOUND':
        setState(() => _emailError = outcome.message);
        await _offerRegistration();
      case 'INVALID_PASSWORD':
        _passwordController.clear();
        setState(() {
          _passwordError = outcome.message.isEmpty ? S.enterPassword : outcome.message;
          _shake++;
        });
      case 'NETWORK':
        showAppSnackBar(context, outcome.message, isError: true);
      default:
        setState(() => _shake++);
        showAppSnackBar(context, outcome.message, isError: true);
    }
  }

  Future<void> _openRegister(String email) async {
    final registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(initialEmail: email)),
    );
    if (registeredEmail == null || !mounted) return;
    _emailController.text = registeredEmail;
    _passwordController.clear();
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    _rememberEmail(registeredEmail);
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
    await _openRegister(email);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final wide = context.isWide;

    return Scaffold(
      backgroundColor: wide ? c.scaffold : c.card,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: wide ? _buildWide(c) : SafeArea(child: _buildScrollable(c, horizontal: 32)),
      ),
    );
  }

  Widget _buildWide(AppColors c) {
    final expanded = context.screenSize == ScreenSize.expanded;
    final card = Container(
      width: 460,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 12))],
      ),
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildFormChildren(c, keyboardOpen: false, showBrand: !expanded),
      ),
    );

    final formSide = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(child: card),
          ),
        ),
      ),
    );

    if (!expanded) return formSide;

    return Row(
      children: [
        Expanded(flex: 5, child: _buildBrandPanel()),
        Expanded(flex: 6, child: formSide),
      ],
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            bottom: -60,
            child: Icon(Icons.menu_book_rounded, size: 360, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Center(
            child: FadeSlideIn(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 12))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(Icons.menu_book_rounded, size: 88, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      kAppName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
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

  Widget _buildScrollable(AppColors c, {required double horizontal}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildFormChildren(c, keyboardOpen: keyboardOpen, showBrand: true),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFormChildren(AppColors c, {required bool keyboardOpen, required bool showBrand}) {
    return [
      if (showBrand) ...[
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
            kAppName,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.accent),
          ),
        ),
        SizedBox(height: keyboardOpen ? 24 : 48),
      ] else ...[
        FadeSlideIn(
          child: Text(
            S.sign,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
        ),
        const SizedBox(height: 28),
      ],
      FadeSlideIn(
        index: 2,
        child: AppTextField(
          controller: _emailController,
          label: S.email,
          hint: 'name@example.com',
          autofillHints: const [AutofillHints.email, AutofillHints.username],
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
        child: ShakeOnError(
          trigger: _shake,
          child: AppTextField(
          controller: _passwordController,
          label: S.password,
          hint: S.enterPassword,
          autofillHints: const [AutofillHints.password],
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
            onPressed: _isLoading || _biometricBusy ? null : _biometricLogin,
          ),
        ),
      ],
      FadeSlideIn(
        index: 5,
        child: PasskeySignInButton(
          disabled: _isLoading || _socialBusy != null,
          onSignedIn: _handlePasskeySignedIn,
        ),
      ),
      if (SocialSignInSection.visibleIds(_providers).isNotEmpty) ...[
        SizedBox(height: keyboardOpen ? 20 : 28),
        FadeSlideIn(
          index: 6,
          child: SocialSignInSection(
            providers: _providers,
            busyProvider: _socialBusy,
            disabled: _isLoading,
            onSelect: _handleSocial,
            // iOS 的 App 內瀏覽器被使用者關閉時不會通知 App，須讓使用者能自行結束等待。
            onCancel: _socialBusy != null && AuthProviders.isOauth(_socialBusy!) ? SocialAuth.cancelOAuthWait : null,
          ),
        ),
      ],
      const SizedBox(height: 8),
      FadeSlideIn(
        index: 5,
        child: TextButton(
          onPressed: _isLoading || _socialBusy != null ? null : () => _openRegister(_emailController.text.trim()),
          child: Text(S.noAccountYetSignUp, style: TextStyle(color: c.accent)),
        ),
      ),
      SizedBox(height: keyboardOpen ? 16 : 0),
    ];
  }
}
