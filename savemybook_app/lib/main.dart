import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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
  }

  final isLoggedIn = ApiService.authToken != null;

  runApp(MyApp(initialRoute: isLoggedIn ? const HomeScreen() : const LoginScreen()));
}

class MyApp extends StatelessWidget {
  final Widget initialRoute;

  const MyApp({super.key, required this.initialRoute});

  static const _primaryColor = Color(0xFF627D8D);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'SaveMyBook',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,

          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),

          home: initialRoute,
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
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'NotoSansTC',
      fontFamilyFallback: const ['PingFang TC', 'Heiti TC', 'Noto Sans TC'],
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
      ),
    );
  }
}