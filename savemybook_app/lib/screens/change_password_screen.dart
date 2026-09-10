import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ApiService _api = ApiService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscure = true;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    String? currentError;
    String? newError;
    String? confirmError;

    if (current.isEmpty) currentError = '請輸入目前密碼';

    if (next.isEmpty) {
      newError = '請輸入新密碼';
    } else {
      newError = Validators.password(next);
      if (newError == null && next == current) newError = '新密碼不可與目前密碼相同';
    }

    if (confirm.isEmpty) {
      confirmError = '請再輸入一次新密碼';
    } else if (confirm != next) {
      confirmError = '兩次輸入的新密碼不一致';
    }

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });

    return currentError == null && newError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (_isSaving || !_validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final error = await _api.changePassword(_currentController.text, _newController.text);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      setState(() => _currentError = error);
      showAppSnackBar(context, error, isError: true);
      return;
    }

    showAppSnackBar(context, '密碼已更新');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '更改密碼', icon: Icons.key_outlined),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    FadeSlideIn(
                      child: FormRowCard(
                        label: '目前密碼',
                        labelWidth: 104,
                        alignTop: _currentError != null,
                        child: AppTextField(
                          controller: _currentController,
                          errorText: _currentError,
                          obscureText: _obscure,
                          maxLength: 64,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_currentError != null) setState(() => _currentError = null);
                          },
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: FormRowCard(
                        label: '新密碼',
                        labelWidth: 104,
                        alignTop: _newError != null,
                        child: AppTextField(
                          controller: _newController,
                          hint: '至少 8 碼，含英文與數字',
                          errorText: _newError,
                          obscureText: _obscure,
                          maxLength: 64,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_newError != null) setState(() => _newError = null);
                          },
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 2,
                      child: FormRowCard(
                        label: '重新輸入新密碼',
                        labelWidth: 104,
                        alignTop: _confirmError != null,
                        child: AppTextField(
                          controller: _confirmController,
                          errorText: _confirmError,
                          obscureText: _obscure,
                          maxLength: 64,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) {
                            if (_confirmError != null) setState(() => _confirmError = null);
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        label: Text(_obscure ? '顯示密碼' : '隱藏密碼'),
                        style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      index: 3,
                      child: PrimaryButton(
                        label: '確認更改',
                        isLoading: _isSaving,
                        onPressed: _submit,
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
}
