import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// 界面語言切換：持久化到 SharedPreferences，並通過 [t] 暴露文案讀取器。
class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    _load();
  }

  static const _prefKey = 'ui_locale';

  AppLocale _locale = AppLocale.zhHant;
  AppLocale get locale => _locale;

  /// 供 MaterialApp 使用。
  Locale get flutterLocale => _locale.toLocale();

  /// 當前語言的文案讀取器。
  Strings get t => Strings(_locale);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefKey);
      if (v != null) {
        _locale = AppLocale.values.firstWhere(
          (e) => e.name == v,
          orElse: () => AppLocale.zhHant,
        );
      }
    } catch (_) {
      // 讀取失敗保持默認（繁體中文）
    }
    notifyListeners();
  }

  Future<void> set(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locale.name);
    } catch (_) {
      // 持久化失敗不影響本次切換
    }
  }
}
