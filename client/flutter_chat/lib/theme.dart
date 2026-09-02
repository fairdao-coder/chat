import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_colors.dart';

/// 中文/多語言字體回退列表。
/// Web 平臺默認字體（Roboto）不含中文字形，中文會顯示為方框/亂碼；
/// 這裡指定系統中文字體，Web 會映射到 CSS font-family。
const List<String> kFontFamilyFallback = <String>[
  'Microsoft YaHei',
  'PingFang SC',
  'Hiragino Sans GB',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'WenQuanYi Micro Hei',
  'Heiti SC',
  'sans-serif',
];

/// 帶中文字體回退的文本樣式構造helper。
TextStyle ts({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFamilyFallback: kIsWeb ? kFontFamilyFallback : null,
    );

/// 亮色主題（青綠清新 / Fresh Teal）
ThemeData get lightTheme => _buildTheme(Brightness.light);

/// 暗色主題（青綠清新 / Fresh Teal）
ThemeData get darkTheme => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
  ).copyWith(
    primary: dark ? AppColors.brandBright : AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: dark ? AppColors.brand : AppColors.brandSoft,
    onPrimaryContainer: dark ? AppColors.darkBg : Colors.white,
    surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    surfaceContainerHighest:
        dark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
    onSurfaceVariant: dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    outline: dark ? AppColors.darkDivider : AppColors.lightDivider,
    outlineVariant: dark ? AppColors.darkDivider : AppColors.lightDivider,
    error: AppColors.danger,
  );

  final textPrimary = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  final textSecondary = dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  final divider = dark ? AppColors.darkDivider : AppColors.lightDivider;
  final inputFill = dark ? AppColors.darkInputFill : AppColors.lightInputFill;
  final scaffoldBg = dark ? AppColors.darkBg : AppColors.lightBg;

  final inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: inputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: ts(color: dark ? AppColors.textHintDark : AppColors.textHintLight),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
    labelStyle: ts(color: textSecondary),
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? Colors.transparent : AppColors.lightSurface,
      foregroundColor: textPrimary,
      titleTextStyle: ts(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: textPrimary),
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          // 亮色：深色圖標 + 淺色狀態欄背景，保證安卓端時間/電量清晰可見。
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: AppColors.lightSurface,
              systemNavigationBarColor: AppColors.lightSurface,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    ),

    inputDecorationTheme: inputTheme,

    cardTheme: CardThemeData(
      color: dark ? AppColors.darkSurface : AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      titleTextStyle: ts(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      subtitleTextStyle: ts(fontSize: 13, color: textSecondary),
      iconColor: textSecondary,
    ),

    dividerTheme: DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: inputFill,
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      labelStyle: ts(color: textPrimary, fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        shape: buttonShape,
        textStyle: ts(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? AppColors.darkSurface : Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        minimumSize: const Size(0, 50),
        shape: buttonShape,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 50),
        shape: buttonShape,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: buttonShape,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: dark ? AppColors.darkSurface : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: ts(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      contentTextStyle: ts(fontSize: 14, color: textSecondary),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF22403C) : const Color(0xFF1F3B37),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: ts(fontSize: 14, color: Colors.white),
      elevation: 6,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: ts(fontWeight: FontWeight.w700, fontSize: 15),
      unselectedLabelStyle: ts(fontWeight: FontWeight.w500, fontSize: 15),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      strokeCap: StrokeCap.round,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: dark ? AppColors.darkSurface : Colors.white,
      selectedItemColor: scheme.primary,
      unselectedItemColor: textSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    textTheme: TextTheme(
      titleLarge: ts(color: textPrimary, fontWeight: FontWeight.w700),
      titleMedium: ts(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: ts(color: textPrimary),
      bodyMedium: ts(color: textSecondary),
      labelLarge: ts(fontWeight: FontWeight.w600),
    ),

    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
