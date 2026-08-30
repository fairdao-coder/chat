import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF3B5BDB);
  static const Color primarySoft = Color(0xFFEDF0FF);
  static const Color bg = Color(0xFFF5F6FA);
  static const Color textMain = Color(0xFF1F2733);
  static const Color textSub = Color(0xFF8A94A6);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    primaryColor: primary,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textMain,
      elevation: 1,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}
