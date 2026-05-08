import 'package:flutter/material.dart';
import 'package:trading_app/screens/home_screen.dart';
import 'package:trading_app/themes/app_theme.dart';

void main() {
  runApp(const TradeMentorApp());
}

class TradeMentorApp extends StatelessWidget {
  const TradeMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trade Mentor',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
