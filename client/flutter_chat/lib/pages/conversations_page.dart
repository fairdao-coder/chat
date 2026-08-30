import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/contact_dto.dart';
import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../providers/conversations_provider.dart';
import '../providers/core_providers.dart';
import '../providers/presence_provider.dart';
import '../utils/format.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    // 收到好友/群的實時消息時自動刷新會話列表，無需手動點刷新按鈕。
    final hub = ref.read(hubProvider);
    _msgSub = hub.onMessage.listen((_) {
      ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(conversationsProvider);
    final onlineIds = ref.watch(presenceProvider);
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
                itemBuilder: (c, i) => _ContactTile(
                  ct: list[i],
                  online: onlineIds.contains(list[i].id),
                ),
              ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactDto ct;
  final bool online;
  const _ContactTile({required this.ct, required this.online});

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
              online: ct.isGroup ? null : online,
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
                  _LastMessagePreview(ct: ct),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 會話列表的消息摘要。
///
/// 圖片 / 文件 / 語音消息的 Content 是空的（真正內容在 mediaUrl 裡），
/// 直接渲染會得到一片空白，因此按類型回退成「圖標 + 文案」佔位。
class _LastMessagePreview extends StatelessWidget {
  final ContactDto ct;
  const _LastMessagePreview({required this.ct});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtle =
        TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant);

    IconData? icon;
    String? label;

    switch (ct.lastMessageType) {
      case MessageType.image:
        icon = Icons.image_outlined;
        label = '[${context.tr('图片')}]';
        break;
      case MessageType.file:
        icon = Icons.insert_drive_file_outlined;
        label = '[${context.tr('文件')}]';
        break;
      case MessageType.voice:
        icon = Icons.mic_none_rounded;
        label = '[${context.tr('语音消息')}]';
        break;
      case MessageType.text:
        break;
    }

    // 媒體消息：圖標 + 文案，沒有正文也不顯示空白。
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label!,
              style: subtle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // 文本消息（或無消息）：沿用原來的純文本展示。
    return Text(
      (ct.lastMessage != null && ct.lastMessage!.isNotEmpty)
          ? ct.lastMessage!
          : (ct.isGroup ? context.tr('群聊') : context.tr('你们还没有成为好友')),
      style: subtle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
