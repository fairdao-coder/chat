import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// 主題皮膚（品牌色）持久化到 SharedPreferences，並同步到 [AppTheme]。
class ThemeSkinProvider extends ChangeNotifier {
  ThemeSkinProvider() {
    _load();
  }

  ThemeSkin _skin = ThemeSkin.sage;
  ThemeSkin get skin => _skin;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString('theme_skin');
      _skin = v == 'sage' ? ThemeSkin.sage : ThemeSkin.blue;
      AppTheme.skin = _skin;
    } catch (_) {
      // 讀取失敗保持默認
    }
    notifyListeners();
  }

  Future<void> set(ThemeSkin skin) async {
    _skin = skin;
    AppTheme.skin = skin;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_skin', skin.name);
    } catch (_) {
      // 持久化失敗不影響本次切換
    }
  }
}
