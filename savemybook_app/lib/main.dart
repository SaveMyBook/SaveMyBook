import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat_room_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';
import 'services/chat_prefs.dart';
import 'services/deep_link_service.dart';
import 'services/theme_provider.dart';
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
    await ChatPrefs.load();
    await BiometricService.load();

    ApiService.onUnauthorized = (reason) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

      // 帳號被停權／列入黑名單時要明確告知，不然使用者只會看到莫名其妙被登出。
      if (reason == null || reason.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) showAppSnackBar(ctx, reason, isError: true);
      });
    };

    // 先 init 再掛 handler：冷啟動時 navigatorKey 還沒有 currentState，
    // 連結會先被存起來，等第一個 frame 之後才 flush 出來。
    await DeepLinkService.init();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      // 開了快速登入就先過生物辨識，沒過就停在登入頁（token 保留，可以再試一次）。
      final unlocked = !BiometricService.isEnabled ||
          await BiometricService.authenticate(reason: '驗證身分以登入 SaveMyBook');

      if (unlocked) {
        ApiService.authToken = token;
        await ApiService().fetchCurrentUser();
        if (ApiService.currentUser != null) {
          _initialRoute = const HomeScreen();
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.onProfileLink = _openProfileLink;
      DeepLinkService.flushPending();
    });
  }

  /// 外部掃到別人的 QR、從網頁按「在 App 中開啟」之後，直接幫他開聊天室。
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
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'SaveMyBook',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          themeMode: mode,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          home: _initialRoute,
        );
      },
    );
  }
}
