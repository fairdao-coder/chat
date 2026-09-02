import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主題皮膚：藍（默認）/ 鼠尾草綠。
enum ThemeSkin { blue, sage }

class AppTheme {
  // —— 默認（藍）品牌色，保持 const 以兼容 const 上下文 ——
  static const Color primary = Color(0xFF3B5BDB);
  static const Color primaryDark = Color(0xFF2B44A8);
  static const Color primarySoft = Color(0xFFEDF0FF);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5BDB), Color(0xFF2B44A8)],
  );

  static const Color bg = Color(0xFFF5F6FA);
  static const Color textMain = Color(0xFF1F2733);
  static const Color textSub = Color(0xFF8A94A6);

  // —— 鼠尾草綠皮膚品牌色 ——
  static const Color sagePrimary = Color(0xFF5F7A52);
  static const Color sagePrimaryDark = Color(0xFF4A6240);
  static const Color sagePrimarySoft = Color(0xFFEDF2E9);
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5F7A52), Color(0xFF4A6240)],
  );

  /// 當前激活皮膚（由 ThemeSkinProvider 設置）。
  static ThemeSkin skin = ThemeSkin.sage;

  /// 當前激活主題。
  static ThemeData get active => skin == ThemeSkin.sage ? sage : light;

  /// 跟隨皮膚的運行時品牌色 / 漸變（用於非 const 上下文）。
  static Color get activePrimary => skin == ThemeSkin.sage ? sagePrimary : primary;
  static Color get activePrimaryDark => skin == ThemeSkin.sage ? sagePrimaryDark : primaryDark;
  static LinearGradient get activeGradient => skin == ThemeSkin.sage ? sageGradient : brandGradient;

  static final ThemeData light = _build(
    primary: primary,
    primaryDark: primaryDark,
    primarySoft: primarySoft,
  );

  static final ThemeData sage = _build(
    primary: sagePrimary,
    primaryDark: sagePrimaryDark,
    primarySoft: sagePrimarySoft,
  );

  static ThemeData _build({
    required Color primary,
    required Color primaryDark,
    required Color primarySoft,
  }) {
    return ThemeData(
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
          borderSide: BorderSide(color: primary, width: 1.6),
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
}
