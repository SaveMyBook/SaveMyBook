import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/theme_provider.dart';

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

    ApiService.onUnauthorized = () {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    };

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      ApiService.authToken = token;
      await ApiService().fetchCurrentUser();
      if (ApiService.currentUser != null) {
        _initialRoute = const HomeScreen();
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
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
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: _initialRoute,
        );
      },
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF151E27);
    final scaffoldBg = isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F7);

    return ThemeData(
      brightness: brightness,
      primaryColor: const Color(0xFF627D8D),
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'NotoSansTC',
      fontFamilyFallback: const ['PingFang TC', 'Heiti TC', 'Noto Sans TC', 'sans-serif'],
      splashColor: isDark ? Colors.white12 : Colors.black12,
      highlightColor: isDark ? Colors.white10 : Colors.black12,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        displayLarge: TextStyle(color: textColor),
        displayMedium: TextStyle(color: textColor),
        displaySmall: TextStyle(color: textColor),
        headlineMedium: TextStyle(color: textColor),
        headlineSmall: TextStyle(color: textColor),
        titleLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: textColor),
        titleSmall: TextStyle(color: textColor),
        labelLarge: TextStyle(color: textColor),
        labelMedium: TextStyle(color: textColor),
        labelSmall: TextStyle(color: textColor),
      ).apply(fontFamily: 'NotoSansTC'),
    );
  }
}