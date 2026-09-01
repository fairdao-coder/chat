import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary = Color(0xFF3B5BDB);
  static const Color primaryDark = Color(0xFF2B44A8);
  static const Color primarySoft = Color(0xFFEDF0FF);
  static const Color bg = Color(0xFFF5F6FA);
  static const Color textMain = Color(0xFF1F2733);
  static const Color textSub = Color(0xFF8A94A6);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static BoxShadow get cardShadow => const BoxShadow(
        color: Color(0x14000000),
        blurRadius: 16,
        offset: Offset(0, 6),
      );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    primaryColor: primary,
    fontFamilyFallback: const [
      'Microsoft YaHei',
      'PingFang SC',
      'Hiragino Sans GB',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 1,
      // 亮色主題：狀態欄用深色圖標 + 淺色背景，保證安卓端時間/電量清晰可見。
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textMain),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFECEEF3)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFBFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: Color(0xFFD6DBE8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFECEEF3), thickness: 1),
    listTileTheme: const ListTileThemeData(
      iconColor: textSub,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
