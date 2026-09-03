import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/discover_column.dart';
import '../providers/bottom_tabs_provider.dart';
import '../providers/conversations_provider.dart';

/// 底部導航宿主：Tab 來自數據庫固定欄目（任何類型均可固定），
/// 順序與 `router.dart` 中動態生成的 branches 一一對應。
///
/// 由 `router.dart` 的 `StatefulShellRoute.indexedStack` 提供 [navigationShell]，
/// 每個 tab 擁有獨立 Navigator，切換時保留各自頁面狀態。
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(effectiveTabsProvider);
    final requests = ref.watch(friendRequestsProvider);
    final pending = requests.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    // tabs 可能為空（後臺未固定任何欄目），clamp 防止 NavigationBar 越界。
    final index = navigationShell.currentIndex;
    final maxIndex = tabs.length - 1;

    return Scaffold(
      // navigationShell 本身即各分支頁面的 IndexedStack
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index > maxIndex ? maxIndex : index,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        destinations: [
          for (final c in tabs)
            NavigationDestination(
              icon: _tabIcon(c, selected: false, pending: pending),
              selectedIcon: _tabIcon(c, selected: true, pending: pending),
              label: resolvedColumnTitle(context, c),
            ),
        ],
      ),
    );
  }

  /// 構建 tab 圖標：內置標識（chat/contacts/discover/me）用固定映射；
  /// 其它固定欄目優先顯示 emoji 圖標，無圖標時按類型回退。
  Widget _tabIcon(DiscoverColumn c,
      {required bool selected, required int pending}) {
    Widget base;
    final content = c.content ?? 'chat';
    if (isBuiltinTab(content)) {
      base = Icon(_tabIconData(content, selected: selected));
    } else if ((c.icon ?? '').isNotEmpty) {
      base = Text(c.icon!, style: const TextStyle(fontSize: 22));
    } else {
      base = Icon(_kindIconData(c.kind));
    }
    // 通訊錄 tab 的未讀好友請求紅點
    if (content == 'contacts' && pending > 0) {
      base = Badge(label: Text(pending.toString()), child: base);
    }
    return base;
  }

  IconData _tabIconData(String content, {required bool selected}) {
    switch (content) {
      case 'contacts':
        return selected ? Icons.contacts : Icons.contacts_outlined;
      case 'discover':
        return selected ? Icons.explore : Icons.explore_outlined;
      case 'me':
        return selected ? Icons.person : Icons.person_outline;
      default:
        return selected ? Icons.chat_bubble : Icons.chat_bubble_outline;
    }
  }

  IconData _kindIconData(DiscoverKind kind) {
    switch (kind) {
      case DiscoverKind.link:
        return Icons.public;
      case DiscoverKind.route:
        return Icons.open_in_new;
      case DiscoverKind.action:
        return Icons.flash_on_outlined;
      case DiscoverKind.mini:
        return Icons.apps_outlined;
    }
  }
}
