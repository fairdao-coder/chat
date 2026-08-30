import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/add_friend_page.dart';
import 'pages/chat_page.dart';
import 'pages/contacts_page.dart';
import 'pages/conversations_page.dart';
import 'pages/create_group_page.dart';
import 'pages/discover_page.dart';
import 'pages/friend_requests_page.dart';
import 'pages/login_page.dart';
import 'pages/main_shell.dart';
import 'pages/settings_page.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final loggedIn = auth.user != null;
  return GoRouter(
    initialLocation: loggedIn ? '/' : '/login',
    redirect: (context, state) {
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
      // 微信风格底部导航：信息 / 通讯录 / 发现 / 我
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ConversationsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/contacts',
              builder: (context, state) => const ContactsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/me',
              builder: (context, state) => const SettingsPage(),
            ),
          ]),
        ],
      ),
      // 以下为覆盖在导航之上的全屏页面（无底部栏）
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
    ],
  );
});
