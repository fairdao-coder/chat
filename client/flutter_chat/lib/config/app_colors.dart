import 'package:flutter/material.dart';

/// 設計系統 - 顏色 Token
///
/// 品牌主色支持多套皮膚（teal / sage）。表面層、文字層級與語義色為中性，
/// 跨皮膚復用。切換皮膚時調用 [AppColors.apply] 重設品牌相關字段。
class AppColors {
  AppColors._();

  // —— 當前激活皮膚的品牌色（運行時可變）——
  static Color brand = const Color(0xFF0D9488); // 主操作（亮色）
  static Color brandStrong = const Color(0xFF0F766E); // 按壓/深色背景
  static Color brandSoft = const Color(0xFF14B8A6); // 淺色強調
  static Color brandBright = const Color(0xFF2DD4BF); // 暗色主操作 / 漸變起點

  // —— 品牌漸變（運行時可變）——
  static Gradient brandGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );
  static Gradient brandGradientV = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );
  static Gradient bubbleMine = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );

  // —— 亮色表面 ——
  static const Color lightBg = Color(0xFFF4F8F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEDF4F2);
  static const Color lightDivider = Color(0xFFE2ECEA);
  static const Color lightInputFill = Color(0xFFEDF4F2);
  static const Color textPrimaryLight = Color(0xFF0F2A28);
  static const Color textSecondaryLight = Color(0xFF5C726F);
  static const Color textHintLight = Color(0xFF94A6A3);

  // —— 暗色表面 ——
  static const Color darkBg = Color(0xFF0B1517);
  static const Color darkSurface = Color(0xFF13242A);
  static const Color darkSurfaceVariant = Color(0xFF1A2E33);
  static const Color darkDivider = Color(0xFF22393C);
  static const Color darkInputFill = Color(0xFF1C3135);
  static const Color textPrimaryDark = Color(0xFFE7F1EF);
  static const Color textSecondaryDark = Color(0xFF93ABA7);
  static const Color textHintDark = Color(0xFF6E8581);

  // —— 語義色 ——
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9AA7A5);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // —— 氣泡（對方）——
  static const Color bubblePeerLight = Color(0xFFFFFFFF);
  static const Color bubblePeerDark = Color(0xFF1B312F);
  static const Color bubbleTextPeerLight = Color(0xFF10211F);
  static const Color bubbleTextPeerDark = Color(0xFFE7F1EF);

  /// 按皮膚重設品牌色（teal 默認，sage 鼠尾草綠）。
  static void apply(ThemeSkin skin) {
    if (skin == ThemeSkin.sage) {
      brand = const Color(0xFF5F7A52); // 深鼠尾草，主操作（亮色）
      brandStrong = const Color(0xFF4A6240);
      brandSoft = const Color(0xFF7C9A78);
      brandBright = const Color(0xFF9DBB8F); // 暗色主操作 / 漸變起點
      brandGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9DBB8F), Color(0xFF5F7A52)],
      );
      brandGradientV = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9DBB8F), Color(0xFF5F7A52)],
      );
      bubbleMine = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9DBB8F), Color(0xFF5F7A52)],
      );
    } else {
      brand = const Color(0xFF0D9488);
      brandStrong = const Color(0xFF0F766E);
      brandSoft = const Color(0xFF14B8A6);
      brandBright = const Color(0xFF2DD4BF);
      brandGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
      );
      brandGradientV = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
      );
      bubbleMine = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
      );
    }
  }

  /// 按亮度取背景色
  static Color bg(bool dark) => dark ? darkBg : lightBg;

  /// 按亮度取表面色
  static Color surface(bool dark) => dark ? darkSurface : lightSurface;
}

/// 主題皮膚：青綠（默認）/ 鼠尾草綠。
enum ThemeSkin { teal, sage }
