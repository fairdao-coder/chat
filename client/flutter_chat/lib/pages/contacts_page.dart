import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/conversations_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

/// 通讯录 tab：列出全部好友，按昵称排序；点击进入私聊。
class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('通讯录')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: context.tr('添加好友'),
            onPressed: () => context.push('/add-friend'),
          ),
        ],
      ),
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.tr('加载失败')}: $e')),
        data: (friends) => friends.isEmpty
            ? EmptyState(
                icon: Icons.contacts_outlined,
                title: context.tr('暂无好友'),
                subtitle: context.tr('还没有好友，添加一个开始聊天'),
                action: FilledButton.icon(
                  onPressed: () => context.push('/add-friend'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(context.tr('添加好友')),
                ),
              )
            : ListView(
                children: [
                  _SectionHeader(title: context.tr('好友')),
                  ...friends.map((f) => _FriendTile(user: f)),
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final dynamic user;
  const _FriendTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push(
        '/chat?friendId=${user.id}&name=${Uri.encodeComponent(user.nickName)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: user.avatarUrl,
              name: user.nickName,
              size: 48,
              online: user.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                user.nickName,
                style: textTheme.titleMedium
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
