import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'cabinet_flow_screen.dart';

class CabinetResume {
  const CabinetResume._();

  static GlobalKey<NavigatorState>? navigatorKey;
  static Future<void>? _running;

  static bool get _signedIn => ApiService.authToken != null && ApiService.currentUser != null;

  static Future<void> check() => _running ??= _check().whenComplete(() => _running = null);

  static Future<void> _check() async {
    if (!_signedIn || CabinetFlowScreen.isShowing || navigatorKey?.currentState == null) return;
    final session = await ApiService().fetchActiveCabinetSession();
    if (session == null || !session.isActive || CabinetFlowScreen.isShowing || !_signedIn) return;
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    unawaited(navigator.push(MaterialPageRoute(builder: (_) => CabinetFlowScreen(resume: session))));
  }

  static void openScanner() {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    if (!_signedIn) {
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      return;
    }
    if (CabinetFlowScreen.isShowing) return;
    unawaited(navigator.push(MaterialPageRoute(builder: (_) => const CabinetFlowScreen())));
  }
}

class CabinetResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(CabinetResume.check());
  }
}
