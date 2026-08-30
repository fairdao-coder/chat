import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 当前界面语言。`null` 表示跟随系统（用设备语言，若不在支持列表则回退简体中文）。
/// 持久化到 SharedPreferences 的 `app_locale`（形如 "zh_CN" / "en"）。
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('app_locale');
      if (s == null || s.isEmpty) {
        state = null; // 跟随系统
        return;
      }
      final parts = s.split('_');
      state = parts.length == 2
          ? Locale(parts[0], parts[1])
          : Locale(parts[0]);
    } catch (_) {
      // 读取失败则保持跟随系统
    }
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove('app_locale');
      } else {
        final key = locale.countryCode == null
            ? locale.languageCode
            : '${locale.languageCode}_${locale.countryCode}';
        await prefs.setString('app_locale', key);
      }
    } catch (_) {
      // 持久化失败不影响本次切换
    }
  }
}
