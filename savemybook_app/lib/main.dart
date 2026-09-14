import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'i18n/app_localizations.dart';
import 'i18n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/book_detail_screen.dart';
import 'screens/chat_room_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';
import 'services/chat_prefs.dart';
import 'services/deep_link_service.dart';
import 'services/home_widget_service.dart';
import 'services/locale_provider.dart';
import 'services/push_service.dart';
import 'services/theme_provider.dart';
import 'services/verification_service.dart';
import 'utils/app_info.dart';
import 'utils/app_theme.dart';
import 'widgets/state_views.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SaveMyBookApp());
}

class SaveMyBookApp extends StatefulWidget {
  const SaveMyBookApp({super.key});

  @override
  State<SaveMyBookApp> createState() => _SaveMyBookAppState();
}

class _SaveMyBookAppState extends State<SaveMyBookApp> {
  bool _isLoading = true;
  Widget _initialRoute = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    await ChatPrefs.load();
    await BiometricService.load();

    PushService.navigatorKey = navigatorKey;
    ApiService.onSigningOut = ({required bool canReachServer}) async {
      unawaited(HomeWidgetService.clear());
      await PushService.onSigningOut(canReachServer: canReachServer);
    };
    ApiService.onPasswordChanged = PushService.registerCurrentDevice;
    VerificationService.navigatorKey = navigatorKey;
    ApiService.onVerificationRequired = VerificationService.handle;
    await PushService.init();
    await HomeWidgetService.init();

    ApiService.onUnauthorized = (reason) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

      if (reason == null || reason.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) showAppSnackBar(ctx, reason, isError: true);
      });
    };

    // 先 init 再掛 handler：冷啟動時 navigatorKey 還沒有 currentState，連結要等第一個 frame 後才送出。
    await DeepLinkService.init();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      final unlocked = !BiometricService.isEnabled ||
          await BiometricService.authenticate(reason: S.verifySignSavemybook);

      if (unlocked) {
        ApiService.authToken = token;
        await ApiService().fetchCurrentUser();
        if (ApiService.currentUser != null) {
          _initialRoute = const HomeScreen();
        }
      }
    }

    unawaited(HomeWidgetService.sync(force: true));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.onProfileLink = _openProfileLink;
      DeepLinkService.onBookLink = _openBookLink;
      DeepLinkService.flushPending();
    });
  }

  Future<void> _openProfileLink(int userId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (ApiService.authToken == null || ApiService.currentUser == null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }
    if (userId == ApiService.currentUser?.userId) return;

    final roomId = await ApiService().openChatRoom(userId: userId);
    if (roomId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId)),
    );
  }

  Future<void> _openBookLink(int bookId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    if (ApiService.authToken == null || ApiService.currentUser == null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    final book = await ApiService().fetchBookDetail(bookId);
    if (book == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        home: const SplashScreen(),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: localeProvider,
          builder: (context, locale, _) {
            return MaterialApp(
              title: kAppName,
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              themeMode: mode,
              theme: AppTheme.build(Brightness.light),
              darkTheme: AppTheme.build(Brightness.dark),
              locale: locale,
              supportedLocales: LocaleProvider.supported,
              localeResolutionCallback: (device, supported) =>
                  locale ?? LocaleProvider.resolve(device == null ? null : [device], supported),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // 模型與服務層沒有 context，全域的 S 只能在這裡指派。
              builder: (context, child) {
                S = AppLocalizations.of(context);
                return child ?? const SizedBox.shrink();
              },
              home: _initialRoute,
            );
          },
        );
      },
    );
  }
}
