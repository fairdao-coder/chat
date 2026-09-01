import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/discover_column.dart';
import 'pages/add_friend_page.dart';
import 'pages/chat_page.dart';
import 'pages/contacts_page.dart';
import 'pages/conversations_page.dart';
import 'pages/create_group_page.dart';
import 'pages/discover_page.dart';
import 'pages/friend_requests_page.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'pages/scan_page.dart';
import 'pages/settings_page.dart';
import 'pages/webview_page.dart';
import 'pages/mini_app_page.dart';
import 'providers/auth_provider.dart';
import 'providers/bottom_tabs_provider.dart';
import 'providers/chat_provider.dart';

/// Root navigator key. Lets app-level services (e.g. the config-link dialog)
/// show dialogs without depending on a specific page being mounted.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 內置 tab 目標 -> 路由路徑。
String _builtinPath(String? content) {
  switch (content) {
    case 'contacts':
      return '/contacts';
    case 'discover':
      return '/discover';
    case 'me':
      return '/me';
    default:
      return '/';
  }
}

/// 內置 tab 目標 -> 對應頁面。
Widget _builtTabPage(String content) {
  switch (content) {
    case 'contacts':
      return const ContactsPage();
    case 'discover':
      return const DiscoverPage();
    case 'me':
      return const SettingsPage();
    default:
      return const ConversationsPage();
  }
}

/// action / route 類型的內容 -> 對應頁面。
Widget _actionPage(String content) {
  switch (content) {
    case 'addFriend':
    case '/add-friend':
      return const AddFriendPage();
    case 'friendRequests':
    case '/friend-requests':
      return const FriendRequestsPage();
    case 'createGroup':
    case '/create-group':
      return const CreateGroupPage();
    case 'scan':
    case '/scan':
      return const ScanPage();
    default:
      return const _NotSupportedPage();
  }
}

/// 根據欄目類型構建底部 branch 根頁面。
Widget _buildColumnPage(DiscoverColumn col) {
  final content = col.content ?? '';
  switch (col.kind) {
    case DiscoverKind.tab:
      return _builtTabPage(content);
    case DiscoverKind.link:
      return WebViewPage(url: content, title: col.title);
    case DiscoverKind.mini:
      return MiniAppPage(name: content, title: col.title);
    case DiscoverKind.route:
    case DiscoverKind.action:
      return _actionPage(content);
  }
}

class _NotSupportedPage extends StatelessWidget {
  const _NotSupportedPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('欄目')),
        body: const Center(
          child: Text('該欄目暫不支持作為底部導航顯示'),
        ),
      );
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final loggedIn = auth.user != null;
  // 底部固定欄目：任何類型都可固定。destinations 與 branches 一一對應。
  final tabs = ref.watch(effectiveTabsProvider);

  final seenBuiltins = <String>{};
  final branches = <StatefulShellBranch>[];
  for (final col in tabs) {
    final isTab = col.kind == DiscoverKind.tab;
    if (isTab) seenBuiltins.add(col.content ?? 'chat');
    branches.add(StatefulShellBranch(routes: [
      GoRoute(
        // tab 類型沿用內置路徑（保證 '/' 等始終可達），
        // 其它類型用唯一路徑 /pinned-<id> 承載對應頁面。
        path: isTab ? _builtinPath(col.content) : '/pinned-${col.id}',
        builder: (context, state) => _buildColumnPage(col),
      ),
    ]));
  }
  // 保底：未固定的內置目標仍註冊路由（不出現在底部導航，但路徑可達、避免 404）。
  const builtinPaths = {
    'chat': '/',
    'contacts': '/contacts',
    'discover': '/discover',
    'me': '/me',
  };
  for (final e in builtinPaths.entries) {
    if (!seenBuiltins.contains(e.key)) {
      branches.add(StatefulShellBranch(routes: [
        GoRoute(
          path: e.value,
          builder: (context, state) => _builtTabPage(e.key),
        ),
      ]));
    }
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: loggedIn ? '/' : '/login',
    redirect: (context, state) {
      // 掃一掃（導入配置 / 掃碼）無需登錄，放行。
      if (state.matchedLocation == '/scan') return null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      // 微信風格底部導航：信息 / 通訊錄 / 發現 / 我 + 其它固定欄目（動態）
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: branches,
      ),
      // 以下為覆蓋在導航之上的全屏頁面（無底部欄）
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final friendId = state.uri.queryParameters['friendId'];
          final groupId = state.uri.queryParameters['groupId'];
          final isGroup = groupId != null;
          final name = state.uri.queryParameters['name'];
          final String id = isGroup ? groupId : (friendId ?? '');
          return ChatPage(
            target: ChatTarget(
              id: id,
              isGroup: isGroup,
            ),
            title: name,
          );
        },
      ),
      GoRoute(
        path: '/add-friend',
        builder: (context, state) => const AddFriendPage(),
      ),
      GoRoute(
        path: '/friend-requests',
        builder: (context, state) => const FriendRequestsPage(),
      ),
      GoRoute(
        path: '/create-group',
        builder: (context, state) => const CreateGroupPage(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final title = state.uri.queryParameters['title'];
          if (url.isEmpty) {
            return const SizedBox.shrink();
          }
          return WebViewPage(url: url, title: title);
        },
      ),
      GoRoute(
        path: '/mini',
        builder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? '';
          final title = state.uri.queryParameters['title'];
          if (name.isEmpty) {
            return const SizedBox.shrink();
          }
          return MiniAppPage(name: name, title: title);
        },
      ),
    ],
  );
});
