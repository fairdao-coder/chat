import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';

/// 主題皮膚（品牌色）持久化到 SharedPreferences，並同步到 [AppColors]。
final themeSkinProvider =
    StateNotifierProvider<ThemeSkinNotifier, ThemeSkin>((ref) => ThemeSkinNotifier());

class ThemeSkinNotifier extends StateNotifier<ThemeSkin> {
  ThemeSkinNotifier() : super(ThemeSkin.sage) {
    AppColors.apply(ThemeSkin.sage);
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString('theme_skin');
      final skin = v == 'sage' ? ThemeSkin.sage : ThemeSkin.teal;
      AppColors.apply(skin);
      state = skin;
    } catch (_) {
      // 讀取失敗保持默認
    }
  }

  Future<void> set(ThemeSkin skin) async {
    AppColors.apply(skin);
    state = skin;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_skin', skin.name);
    } catch (_) {
      // 持久化失敗不影響本次切換
    }
  }
}
