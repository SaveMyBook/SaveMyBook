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
      title: '二手書市集',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF627D8D),
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
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