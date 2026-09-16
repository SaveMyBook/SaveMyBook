import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/auth_social.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../account/legal_doc_screen.dart';
import '../../i18n/strings.dart';

class SocialProfile {
  final String email;
  final String nickname;

  const SocialProfile({required this.email, required this.nickname});
}

/// 伺服器回 EMAIL_REQUIRED 時補齊建立帳號所需的資料。
class SocialProfileScreen extends StatefulWidget {
  final String provider;

  const SocialProfileScreen({super.key, required this.provider});

  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _agreed = false;
  int _termsShake = 0;
  String? _emailError;
  String? _nicknameError;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final nickname = _nicknameController.text.trim();

    String? emailError;
    String? nicknameError;

    if (email.isEmpty) {
      emailError = S.enterEmail;
    } else if (!Validators.isEmail(email)) {
      emailError = S.emailAddressNotValid;
    }

    if (nickname.isEmpty) {
      nicknameError = S.enterDisplayName;
    } else if (nickname.length < 2) {
      nicknameError = S.displayNameNeedsLeast2Characters;
    } else if (nickname.length > 50) {
      nicknameError = S.displayNameLimited50Characters;
    }

    setState(() {
      _emailError = emailError;
      _nicknameError = nicknameError;
    });
    if (emailError != null || nicknameError != null) return;

    if (!_agreed) {
      setState(() => _termsShake++);
      showAppSnackBar(context, S.pleaseReadAcceptTermsServicePrivacy, isError: true);
      return;
    }

    Navigator.pop(context, SocialProfile(email: email, nickname: nickname));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final providerName = AuthProviders.labelOf(widget.provider);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.completeAccountDetails, icon: Icons.person_add_alt_1_rounded),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: responsiveListPadding(constraints,
                      maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 20, bottom: 40),
                  children: [
                    FadeSlideIn(
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.badge_outlined, color: c.accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                S.p0DidNotProvideEmailAddress(providerName),
                                style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: _field(
                        c,
                        icon: Icons.alternate_email_rounded,
                        label: S.email,
                        hint: 'name@example.com',
                        controller: _emailController,
                        errorText: _emailError,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 255,
                        onChanged: () {
                          if (_emailError != null) setState(() => _emailError = null);
                        },
                      ),
                    ),
                    FadeSlideIn(
                      index: 2,
                      child: _field(
                        c,
                        icon: Icons.badge_outlined,
                        label: S.displayName,
                        hint: S.nameOthersSee,
                        controller: _nicknameController,
                        errorText: _nicknameError,
                        maxLength: 50,
                        isLast: true,
                        onChanged: () {
                          if (_nicknameError != null) setState(() => _nicknameError = null);
                        },
                      ),
                    ),
                    FadeSlideIn(index: 3, child: ShakeOnError(trigger: _termsShake, child: _terms(c))),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 4,
                      child: PrimaryButton(label: S.createAccount, height: 50, onPressed: _submit),
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

  Widget _field(
    AppColors c, {
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onChanged,
    String? errorText,
    TextInputType? keyboardType,
    int? maxLength,
    bool isLast = false,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller,
            hint: hint,
            errorText: errorText,
            keyboardType: keyboardType,
            maxLength: maxLength,
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onChanged: (_) => onChanged(),
            onSubmitted: isLast ? (_) => _submit() : null,
          ),
        ],
      ),
    );
  }

  Widget _terms(AppColors c) {
    final linkStyle = TextStyle(
      color: c.accent,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.accent,
    );

    void open(String key, String title, IconData icon) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LegalDocScreen(docKey: key, fallbackTitle: title, icon: icon)),
        );

    return AppCard(
      onTap: () => setState(() => _agreed = !_agreed),
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreed,
              activeColor: c.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (value) => setState(() => _agreed = value ?? false),
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
                        ..onTap = () => open('terms', S.termsService, Icons.description_outlined),
                    ),
                    TextSpan(text: S.and),
                    TextSpan(
                      text: S.privacyPolicy,
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => open('privacy', S.privacyPolicy, Icons.privacy_tip_outlined),
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
}
