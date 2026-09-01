import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feature_settings.dart';
import 'core_providers.dart';

/// 系統功能開關。
///
/// 拉取失敗時回退到全開（[FeatureSettings.allEnabled]），
/// 保證接口異常不會連帶禁用所有功能。
final featuresProvider = FutureProvider<FeatureSettings>((ref) async {
  try {
    return await ref.read(apiProvider).getFeatures();
  } catch (_) {
    return FeatureSettings.allEnabled();
  }
});
