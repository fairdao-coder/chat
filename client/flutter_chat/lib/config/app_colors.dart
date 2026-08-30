import 'package:flutter/material.dart';

/// 设计系统 - 颜色 Token（青绿清新 / Fresh Teal）
///
/// 集中管理品牌色、渐变、表面层、文字层级与状态色，供亮色/暗色主题
/// 以及各页面组件共用，保证全应用配色统一、可维护。
class AppColors {
  AppColors._();

  // —— 品牌主色（Teal 系）——
  static const Color brand = Color(0xFF0D9488); // teal-600  主操作（亮色）
  static const Color brandStrong = Color(0xFF0F766E); // teal-700 按压/深色背景
  static const Color brandSoft = Color(0xFF14B8A6); // teal-500
  static const Color brandBright = Color(0xFF2DD4BF); // teal-400 暗色主操作 / 渐变起点

  // —— 品牌渐变 ——
  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );
  static const Gradient brandGradientV = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
  );
  static const Gradient bubbleMine = LinearGradient(
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

  // —— 语义色 ——
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9AA7A5);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // —— 气泡（对方）——
  static const Color bubblePeerLight = Color(0xFFFFFFFF);
  static const Color bubblePeerDark = Color(0xFF1B312F);
  static const Color bubbleTextPeerLight = Color(0xFF10211F);
  static const Color bubbleTextPeerDark = Color(0xFFE7F1EF);

  /// 按亮度取背景色
  static Color bg(bool dark) => dark ? darkBg : lightBg;

  /// 按亮度取表面色
  static Color surface(bool dark) => dark ? darkSurface : lightSurface;
}
