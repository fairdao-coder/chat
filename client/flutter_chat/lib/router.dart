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

/// 根據欄目構建底部 branch 根頁面。
///
/// 固定（pinned）欄目若 content 為內置標識（chat/contacts/discover/me），
/// 直接對應內置頁；否則按 [DiscoverKind] 決定打開方式。
/// 需傳入 context：標題依賴當前界面語言做本地化解析。
Widget _buildColumnPage(BuildContext context, DiscoverColumn col) {
  final content = col.content ?? '';
  if (isBuiltinTab(content)) {
    return _builtTabPage(content);
  }
  final title = resolvedColumnTitle(context, col);
  switch (col.kind) {
    case DiscoverKind.link:
      return WebViewPage(url: content, title: title);
    case DiscoverKind.mini:
      return MiniAppPage(name: content, title: title);
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

  final branches = <StatefulShellBranch>[];
  for (final col in tabs) {
    final isBuiltin = isBuiltinTab(col.content);
    branches.add(StatefulShellBranch(routes: [
      GoRoute(
        // 內置標識（chat/contacts/discover/me）沿用內置路徑（保證 '/' 等始終可達），
        // 其它固定欄目用唯一路徑 /pinned-<id> 承載對應頁面。
        path: isBuiltin ? _builtinPath(col.content) : '/pinned-${col.id}',
        builder: (context, state) => _buildColumnPage(context, col),
      ),
    ]));
  }
  // 註：底部導航僅包含後臺 Pinned 的固定欄目，不再保底註冊內置 tab；
  // 固定欄目若 content 為內置標識（chat/contacts/discover/me）走內置路徑，
  // 僅當它們確實被固定時才會出現。

  // 默認打開的欄目：管理後臺配置（DefaultColumnId），必須是已固定欄目。
  // 未配置或配置的欄目不存在時，回落到按 sort 排在最前的固定欄目。
  String initial = '/';
  if (tabs.isNotEmpty) {
    final defaultId = ref.watch(defaultColumnIdProvider);
    DiscoverColumn? def;
    if (defaultId != null) {
      for (final c in tabs) {
        if (c.id == defaultId) {
          def = c;
          break;
        }
      }
    }
    final target = def ?? tabs.first;
    initial = isBuiltinTab(target.content)
        ? _builtinPath(target.content)
        : '/pinned-${target.id}';
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: loggedIn ? initial : '/login',
    redirect: (context, state) {
      // 掃一掃（導入配置 / 掃碼）無需登錄，放行。
      if (state.matchedLocation == '/scan') return null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return initial;
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
          // name 為空表示欄目未配置內容，由 MiniAppPage 展示默認模板。
          return MiniAppPage(name: name, title: title);
        },
      ),
    ],
  );
});
