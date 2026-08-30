import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 未顯式設置時的默認界面語言：繁體中文。
const Locale defaultLocale = Locale('zh', 'TW');

/// 持久化鍵，取值形如 "zh_TW" / "en"；特例 "system" 表示跟隨系統。
const String _prefKey = 'app_locale';
const String _systemValue = 'system';

/// 當前界面語言。`null` 表示跟隨系統（用設備語言，若不在支持列表則回退繁體中文）。
/// 持久化到 SharedPreferences 的 `app_locale`（形如 "zh_TW" / "en" / "system"）。
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(defaultLocale) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefKey);
      if (s == null || s.isEmpty) {
        // 從未設置過：使用預設的繁體中文（而不是跟隨系統）。
        state = defaultLocale;
        return;
      }
      if (s == _systemValue) {
        state = null; // 跟隨系統
        return;
      }
      final parts = s.split('_');
      state = parts.length == 2
          ? Locale(parts[0], parts[1])
          : Locale(parts[0]);
    } catch (_) {
      // 讀取失敗則保持預設的繁體中文
    }
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        // 顯式「跟隨系統」需要落一個哨兵值，否則下次啟動又會被預設值覆蓋。
        await prefs.setString(_prefKey, _systemValue);
      } else {
        final key = locale.countryCode == null
            ? locale.languageCode
            : '${locale.languageCode}_${locale.countryCode}';
        await prefs.setString(_prefKey, key);
      }
    } catch (_) {
      // 持久化失敗不影響本次切換
    }
  }
}
