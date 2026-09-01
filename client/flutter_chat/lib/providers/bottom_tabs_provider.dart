import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discover_column.dart';
import '../providers/core_providers.dart';

/// 底部固定導航欄目（從後臺數據庫拉取，pinned=true 且啟用）。
/// 順序按 sort 升序。
final pinnedColumnsProvider = FutureProvider<List<DiscoverColumn>>((ref) async {
  final api = ref.read(apiProvider);
  final list = await api.getPinnedColumns();
  list.sort((a, b) => a.sort.compareTo(b.sort));
  return list;
});

/// 默認 4 個內置 Tab（數據未加載或為空時回退，避免底部空白）。
final List<DiscoverColumn> kDefaultTabs = [
  DiscoverColumn(id: 'chat', title: '信息', kind: DiscoverKind.tab, content: 'chat', sort: -4),
  DiscoverColumn(id: 'contacts', title: '通讯录', kind: DiscoverKind.tab, content: 'contacts', sort: -3),
  DiscoverColumn(id: 'discover', title: '发现', kind: DiscoverKind.tab, content: 'discover', sort: -2),
  DiscoverColumn(id: 'me', title: '我', kind: DiscoverKind.tab, content: 'me', sort: -1),
];

/// 底部導航最終生效的欄目列表（router 與 main_shell 共用，保證
/// destinations 與 StatefulShellRoute.branches 一一對應）：
/// 1. 數據未加載或為空 -> [kDefaultTabs]；
/// 2. tab 類型按 content 去重（保留第一個），避免重複路由；
/// 3. 任何類型（link/route/action/mini/tab）都可出現在底部導航。
final effectiveTabsProvider = Provider<List<DiscoverColumn>>((ref) {
  final pinned = ref.watch(pinnedColumnsProvider).maybeWhen(
        data: (l) => l,
        orElse: () => const <DiscoverColumn>[],
      );
  if (pinned.isEmpty) return kDefaultTabs;
  final seen = <String>{};
  final result = <DiscoverColumn>[];
  for (final c in pinned) {
    if (c.kind == DiscoverKind.tab) {
      final t = c.content ?? 'chat';
      if (!seen.add(t)) continue;
    }
    result.add(c);
  }
  return result;
});
