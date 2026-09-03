import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discover_column.dart';
import '../providers/core_providers.dart';
import '../providers/features_provider.dart';

/// 底部固定導航欄目（從後臺數據庫拉取，pinned=true 且啟用）。
///
/// 緩存機制：本地持久化上一次的「變更信號（meta）+ 固定欄目列表」。
/// 每次啟動僅請求輕量的 `pinned-meta`（默認欄目 Id + 固定欄目簽名），
/// **只有默認欄目或固定欄目發生變化時**才重新拉取整個固定欄目列表，
/// 否則直接復用本地緩存，以降低網絡開銷、提高啟動性能。
final pinnedColumnsProvider = FutureProvider<List<DiscoverColumn>>((ref) async {
  final api = ref.read(apiProvider);

  final cache = await api.readNavCache();
  final meta = await api.getPinnedMeta();

  // 緩存有效且未變化 → 復用緩存，不重新拉取整個列表。
  if (cache != null && !meta.changedFrom(cache.meta)) {
    return cache.columns;
  }

  final list = await api.getPinnedColumns();
  await api.writeNavCache(meta, list);
  list.sort((a, b) => a.sort.compareTo(b.sort));
  return list;
});

/// 默認打開的欄目（底部固定 Tab）Id。
/// 來源為系統設置（FeatureSettings.DefaultColumnId）；null 表示未配置，
/// 由 router 回落到按 sort 排在最前的固定欄目。
final defaultColumnIdProvider = Provider<String?>((ref) {
  final features = ref.watch(featuresProvider);
  if (features.hasValue) return features.value!.defaultColumnId;
  return null;
});

/// 默認 4 個內置 Tab：僅作為「後臺固定欄目尚未加載完成」時的臨時佔位，
/// 避免首屏路由 '/' 不可達而崩潰。加載完成後底部導航只顯示已固定欄目，
/// 內置 tab 不再強制出現。
/// 註：底部 Tab 由 [DiscoverColumn.pinned] 決定，故佔位欄目標記 pinned=true，
/// kind 僅作展示用途（這裡用 link）。
final List<DiscoverColumn> kDefaultTabs = [
  DiscoverColumn(id: 'chat', title: '信息', kind: DiscoverKind.link, content: 'chat', sort: -4, pinned: true),
  DiscoverColumn(id: 'contacts', title: '通讯录', kind: DiscoverKind.link, content: 'contacts', sort: -3, pinned: true),
  DiscoverColumn(id: 'discover', title: '发现', kind: DiscoverKind.link, content: 'discover', sort: -2, pinned: true),
  DiscoverColumn(id: 'me', title: '我', kind: DiscoverKind.link, content: 'me', sort: -1, pinned: true),
];

/// 底部導航最終生效的欄目列表（router 與 main_shell 共用，保證
/// destinations 與 StatefulShellRoute.branches 一一對應）。
///
/// 規則：**只有後臺 Pinned（固定）的欄目才會出現在底部導航**。
/// - 數據仍在加載（FutureProvider 非 data 態）→ 暫用 kDefaultTabs 佔位，
///   否則首屏無任何 branch、'/' 不可達會崩潰；
/// - 數據加載完成（即使為空）→ 嚴格只返回固定欄目列表。
/// 最終按 sort 升序排列。
final effectiveTabsProvider = Provider<List<DiscoverColumn>>((ref) {
  final pinnedState = ref.watch(pinnedColumnsProvider);

  final List<DiscoverColumn> base;
  if (pinnedState.hasValue) {
    base = pinnedState.value!;
  } else {
    // 加載中：用內置 tab 佔位，加載完成即被固定欄目取代。
    base = kDefaultTabs;
  }

  // 固定欄目（含佔位）按 content 去重，防止重複配置同 content 的 tab。
  final seenTargets = <String>{};
  final result = <DiscoverColumn>[];
  for (final c in base) {
    final t = c.content ?? '';
    if (!seenTargets.add(t)) continue;
    result.add(c);
  }

  result.sort((a, b) => a.sort.compareTo(b.sort));
  return result;
});
