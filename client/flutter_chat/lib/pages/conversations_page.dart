import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/contact_dto.dart';
import '../providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import '../utils/format.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convAsync = ref.watch(conversationsProvider);
    final user = ref.watch(authProvider).user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.nickName ?? 'FairChat'),
            if (user != null)
              Text(
                '@${user.userName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: context.tr('添加好友'),
            onPressed: () => context.push('/add-friend'),
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: context.tr('创建群'),
            onPressed: () => context.push('/create-group'),
          ),
          IconButton(
            icon: const Icon(Icons.mark_email_unread_outlined),
            tooltip: context.tr('好友请求'),
            onPressed: () => context.push('/friend-requests'),
          ),
        ],
      ),
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.tr('加载失败')}: $e')),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.forum_outlined,
                title: context.tr('还没有会话'),
                subtitle: context.tr('添加一个好友，开启你的第一段对话'),
                action: FilledButton.icon(
                  onPressed: () => context.push('/add-friend'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(context.tr('添加好友')),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(
                  indent: 86,
                  endIndent: 16,
                  height: 1,
                ),
                itemBuilder: (c, i) => _ContactTile(ct: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.tr('刷新会话'),
        onPressed: () {
          ref.invalidate(conversationsProvider);
          ref.invalidate(friendRequestsProvider);
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactDto ct;
  const _ContactTile({required this.ct});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.push(
        '/chat?${ct.isGroup ? 'groupId' : 'friendId'}=${ct.id}'
        '&name=${Uri.encodeComponent(ct.name)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: ct.avatarUrl,
              name: ct.name,
              size: 56,
              online: ct.isGroup ? null : ct.isOnline,
              isGroup: ct.isGroup,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ct.name,
                          style: textTheme.titleMedium
                              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ct.isGroup) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.group,
                            size: 15, color: cs.onSurfaceVariant),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        formatConvTime(ct.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ct.lastMessage ??
                        (ct.isGroup
                            ? context.tr('群聊')
                            : context.tr('你们还没有成为好友')),
                    style: textStyleSubtle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle textStyleSubtle(BuildContext context) => TextStyle(
        fontSize: 13.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}
