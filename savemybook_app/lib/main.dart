import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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

  @override
  Widget build(BuildContext context) {
    const Color darkTextColor = Color(0xFF151E27);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SaveMyBook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF627D8D),
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        fontFamily: 'NotoSansTC',
        fontFamilyFallback: const ['PingFang TC', 'Heiti TC', 'Noto Sans TC'],
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: darkTextColor),
          bodyMedium: TextStyle(color: darkTextColor),
          displayLarge: TextStyle(color: darkTextColor),
          displayMedium: TextStyle(color: darkTextColor),
          displaySmall: TextStyle(color: darkTextColor),
          headlineMedium: TextStyle(color: darkTextColor),
          headlineSmall: TextStyle(color: darkTextColor),
          titleLarge: TextStyle(color: darkTextColor),
          titleMedium: TextStyle(color: darkTextColor),
          titleSmall: TextStyle(color: darkTextColor),
        ),
      ),
      home: initialRoute,
    );
  }
}