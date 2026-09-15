import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../models/security.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../auth/login_screen.dart';

class LoginDevicesScreen extends StatefulWidget {
  const LoginDevicesScreen({super.key});

  @override
  State<LoginDevicesScreen> createState() => _LoginDevicesScreenState();
}

class _LoginDevicesScreenState extends State<LoginDevicesScreen> {
  final _api = ApiService();
  List<LoginSession>? _sessions;
  bool _loading = true;
  bool _bulkBusy = false;
  final Set<int> _busyIds = {};
  final Set<int> _leaving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _api.fetchLoginSessions();
    if (!mounted) return;
    sessions?.sort((a, b) {
      if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
      final at = a.lastSeenAt ?? a.createdAt ?? DateTime(0);
      final bt = b.lastSeenAt ?? b.createdAt ?? DateTime(0);
      return bt.compareTo(at);
    });
    setState(() {
      _sessions = sessions;
      _leaving.clear();
      _loading = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _signOutToLogin() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _revoke(LoginSession session) async {
    if (_busyIds.contains(session.sessionId) || _bulkBusy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: session.isCurrent ? S.signOutDevice : S.signOutP0(_nameOf(session)),
      message: session.isCurrent ? S.llNeedSignAgainUseApp : S.deviceSignedOutRightAwayStop,
      confirmLabel: S.signOut,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(session.sessionId));
    final (signedOutCurrent, error) = await _api.revokeLoginSession(session.sessionId);
    if (!mounted) return;
    setState(() => _busyIds.remove(session.sessionId));

    if (error != null) {
      if (error.isNotEmpty) showAppSnackBar(context, error, isError: true);
      return;
    }
    if (signedOutCurrent) return _signOutToLogin();

    setState(() => _leaving.add(session.sessionId));
    showAppSnackBar(context, S.deviceSignedOut);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      _sessions?.removeWhere((s) => s.sessionId == session.sessionId);
      _leaving.remove(session.sessionId);
    });
  }

  Future<void> _revokeAll({required bool includeCurrent}) async {
    if (_bulkBusy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: includeCurrent ? S.signOutAllDevicesIncludingOne : S.signOutAllOtherDevices,
      message: includeCurrent ? S.everyDeviceIncludingOneSignedOut : S.everyDeviceExceptOneSignedOut,
      confirmLabel: S.signOut,
      isDestructive: true,
      icon: Icons.devices_other_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _bulkBusy = true);
    final result = await runBusy(context, () => _api.revokeAllLoginSessions(includeCurrent: includeCurrent));
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    if (result == null) return;
    final (count, error) = result;
    if (error != null) {
      if (error.isNotEmpty) showAppSnackBar(context, error, isError: true);
      return;
    }
    if (includeCurrent) return _signOutToLogin();
    showAppSnackBar(context, S.signedOutP0OtherDevices(count));
    _load();
  }

  String _nameOf(LoginSession s) {
    if (s.deviceName.isNotEmpty) return s.deviceName;
    if (s.platform == 'ios') return 'iPhone';
    if (s.platform == 'android') return 'Android';
    return S.unknownDevice;
  }

  IconData _iconOf(LoginSession s) {
    final name = s.deviceName.toLowerCase();
    if (name.contains('ipad') || name.contains('tab')) return Icons.tablet_mac_rounded;
    if (s.platform == 'ios') return Icons.phone_iphone_rounded;
    if (s.platform == 'android') return Icons.phone_android_rounded;
    return Icons.devices_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sessions = _sessions;

    final Widget body;
    if (_loading) {
      body = context.isWide
          ? const ResponsiveCenter(key: ValueKey('loading'), child: LoadingView.menu())
          : const LoadingView.menu(key: ValueKey('loading'));
    } else if (sessions == null) {
      body = RefreshableCenter(
        key: const ValueKey('error'),
        onRefresh: _load,
        child: ErrorView(message: S.couldnTLoadDevices, onRetry: _retry),
      );
    } else {
      final current = sessions.where((s) => s.isCurrent).toList();
      final others = sessions.where((s) => !s.isCurrent).toList();
      var index = 0;

      body = RefreshIndicator(
        key: const ValueKey('list'),
        color: c.accent,
        onRefresh: _load,
        child: LayoutBuilder(builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: responsiveListPadding(constraints, bottom: 40),
          children: [
            FadeSlideIn(
              index: index++,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        S.theseDevicesSignedAccountIfDon,
                        style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (current.isNotEmpty) ...[
              _sectionTitle(c, S.device),
              for (final s in current) FadeSlideIn(index: index++, child: _tile(c, s)),
            ],
            _sectionTitle(c, others.isEmpty ? S.otherDevices : S.otherDevicesP0(others.length)),
            if (others.isEmpty)
              FadeSlideIn(
                index: index++,
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: c.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          S.noOtherDevicesSigned,
                          style: TextStyle(fontSize: 14, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final s in others) FadeSlideIn(index: index++, child: _tile(c, s)),
            const SizedBox(height: 24),
            if (others.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _bulkBusy ? null : () => _revokeAll(includeCurrent: false),
                icon: const Icon(Icons.logout_rounded),
                label: Text(S.signOutAllOtherDevices),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.danger,
                  side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _bulkBusy ? null : () => _revokeAll(includeCurrent: true),
              child: Text(S.signOutAllDevicesIncludingOne, style: TextStyle(color: c.danger)),
            ),
          ],
        )),
      );
    }

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.signedDevices, icon: Icons.devices_rounded),
          Expanded(child: SwitchIn(child: body)),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
    );
  }

  Widget _tile(AppColors c, LoginSession s) {
    final busy = _busyIds.contains(s.sessionId);
    final lastSeen = s.isCurrent ? S.activeNow : S.lastActiveP0(formatRelative(s.lastSeenAt));
    final details = [
      lastSeen,
      if (s.ipAddress != null && s.ipAddress!.isNotEmpty) 'IP ${s.ipAddress}',
      if (s.createdAt != null) S.signedP0(formatDate(s.createdAt)),
    ].join(' · ');
    final version = s.appVersion;

    return Reveal(
      visible: !_leaving.contains(s.sessionId),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (s.isCurrent ? c.success : c.accent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconOf(s), color: s.isCurrent ? c.success : c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _nameOf(s),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                          ),
                        ),
                        if (s.isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              S.device,
                              maxLines: 1,
                              style: TextStyle(fontSize: 11, color: c.success, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                    ),
                    if (s.biometricPay || (version != null && version.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (s.biometricPay)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fingerprint_rounded, size: 14, color: c.textHint),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    S.biometricPayment,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: c.textHint),
                                  ),
                                ),
                              ],
                            ),
                          if (version != null && version.isNotEmpty)
                            Text('App v$version', style: TextStyle(fontSize: 11.5, color: c.textHint)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: SwitchIn(
                  duration: const Duration(milliseconds: 180),
                  child: busy
                      ? Center(
                          key: const ValueKey('busy'),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('action'),
                          tooltip: S.signOut,
                          icon: Icon(Icons.logout_rounded, color: c.danger),
                          onPressed: _bulkBusy ? null : () => _revoke(s),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
