import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/conversations_provider.dart';
import '../providers/presence_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

/// 通訊錄 tab：列出全部好友，按暱稱排序；支援搜尋；點擊進入私聊。
class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  final _queryCtl = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _queryCtl.dispose();
    super.dispose();
  }

  List<dynamic> _filter(List<dynamic> friends) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return friends;
    return friends.where((f) {
      final name = (f.nickName ?? '').toString().toLowerCase();
      final userName = (f.userName ?? '').toString().toLowerCase();
      return name.contains(q) || userName.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final onlineIds = ref.watch(presenceProvider);

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _queryCtl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('搜索'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                filled: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${context.tr('加载失败')}: $e')),
              data: (friends) {
                final list = _filter(friends);
                if (friends.isEmpty) {
                  return EmptyState(
                    icon: Icons.contacts_outlined,
                    title: context.tr('暂无好友'),
                    subtitle: context.tr('还没有好友，添加一个开始聊天'),
                    action: FilledButton.icon(
                      onPressed: () => context.push('/add-friend'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(context.tr('添加好友')),
                    ),
                  );
                }
                if (list.isEmpty) {
                  return Center(
                    child: Text(context.tr('未找到匹配的好友')),
                  );
                }
                return ListView(
                  children: [
                    _SectionHeader(
                        title: '${context.tr('好友')} (${list.length})'),
                    ...list.map(
                      (f) => _FriendTile(
                        user: f,
                        online: onlineIds.contains(f.id),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
  final bool online;
  const _FriendTile({required this.user, required this.online});

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
              online: online,
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
