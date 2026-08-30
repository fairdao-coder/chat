import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/conversations_provider.dart';

/// 微信风格的底部导航宿主：信息 / 通讯录 / 发现 / 我。
///
/// 由 `router.dart` 的 `StatefulShellRoute.indexedStack` 提供 [navigationShell]，
/// 每个 tab 拥有独立 Navigator，切换时保留各自页面状态（如会话列表滚动位置）。
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({required this.navigationShell, super.key});

  void _onTap(int index) => navigationShell.goBranch(index);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = L10n.of(context);
    final requests = ref.watch(friendRequestsProvider);
    final pending = requests.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    // 通讯录 tab 的未读好友请求红点
    final contactsIcon = pending > 0
        ? Badge(
            label: Text(pending.toString()),
            child: const Icon(Icons.contacts_outlined),
          )
        : const Icon(Icons.contacts_outlined);

    return Scaffold(
      // navigationShell 本身即各分支页面的 IndexedStack
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: loc.t('信息'),
          ),
          NavigationDestination(
            icon: contactsIcon,
            selectedIcon: Badge(
              label: Text(pending.toString()),
              child: const Icon(Icons.contacts),
            ),
            label: loc.t('通讯录'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: loc.t('发现'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: loc.t('我'),
          ),
        ],
      ),
    );
  }
}
