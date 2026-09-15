import 'package:flutter/material.dart';
import '../../models/support.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_info.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import 'login_screen.dart';
import '../../i18n/strings.dart';

class LegalConsentGate {
  static bool _showing = false;

  static Future<void> check(BuildContext context) async {
    if (_showing || ApiService.authToken == null) return;
    final pending = await ApiService().fetchPendingConsents();
    if (pending == null || pending.isEmpty || !context.mounted || _showing) return;

    _showing = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => LegalConsentScreen(documents: pending)),
      );
    } finally {
      _showing = false;
    }
  }
}

class LegalConsentScreen extends StatefulWidget {
  final List<LegalDoc> documents;

  const LegalConsentScreen({super.key, required this.documents});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  late List<LegalDoc> _docs = widget.documents;
  int _index = 0;
  bool _read = false;
  bool _isSubmitting = false;
  final ScrollController _scroll = ScrollController();

  LegalDoc get _current => _docs[_index];

  @override
  void initState() {
    super.initState();
    _checkShortContent();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkShortContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _read || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 40) setState(() => _read = true);
    });
  }

  Future<void> _accept() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final error = await ApiService().acceptLegalDoc(_current);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      final latest = await ApiService().fetchPendingConsents();
      if (!mounted || latest == null) return;
      if (latest.isEmpty) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _docs = latest;
        _index = 0;
        _read = false;
      });
      _checkShortContent();
      return;
    }

    if (_index + 1 >= _docs.length) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _index += 1;
      _read = false;
    });
    _checkShortContent();
  }

  Future<void> _decline() async {
    final ok = await showConfirmDialog(
      context,
      title: S.canTContinueWithoutAccepting,
      message: S.needAcceptLatestP0UseP1(_current.title, kAppName),
      confirmLabel: S.signOut,
      cancelLabel: S.goBack,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    await ApiService().logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final doc = _current;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: SafeArea(
          child: ResponsiveCenter(
          maxWidth: Breakpoints.readingMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_docs.length > 1)
                      Text(
                        '${_index + 1} / ${_docs.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
                      ),
                    const SizedBox(height: 4),
                    SwitchIn(
                      child: Text(
                      S.p0BeenUpdated(doc.title),
                      key: ValueKey(doc.key),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.readLatestVersionUpdatedP0Accept(formatDate(doc.updatedAt)),
                      style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (!_read && n.metrics.extentAfter < 40) setState(() => _read = true);
                      return false;
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(doc.key + doc.version.toString()),
                      controller: _scroll,
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        doc.content,
                        style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _read ? 0 : 1,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          S.scrollEndContinue,
                          style: TextStyle(fontSize: 12, color: c.textHint),
                        ),
                      ),
                    ),
                    PrimaryButton(
                      label: S.iVeReadAccept,
                      isLoading: _isSubmitting,
                      onPressed: _read ? _accept : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isSubmitting ? null : _decline,
                      child: Text(S.decline, style: TextStyle(color: c.textSecondary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
