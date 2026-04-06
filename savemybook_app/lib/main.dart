import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveMyBook 救『舊』我的書',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF627D8D),
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        fontFamily: 'PingFang TC',
        fontFamilyFallback: const [
          '.SF Pro Text',
          'PingFang TC',
          'Heiti TC',
          'Noto Sans TC',
          'Microsoft JhengHei'
        ],
      ),
      home: const HomeScreen(),
    );
  }
}