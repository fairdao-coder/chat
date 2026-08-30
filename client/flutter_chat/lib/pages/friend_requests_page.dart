import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../providers/conversations_provider.dart';
import '../providers/core_providers.dart';
import '../widgets/app_avatar.dart';
import '../widgets/empty_state.dart';

class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendRequestsProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('好友请求'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.mark_email_unread_outlined,
                title: context.tr('暂无好友请求'),
                subtitle: context.tr('有人添加你为好友时会显示在这里'),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (c, i) {
                  final r = list[i];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          AppAvatar(
                            imageUrl: r.avatarUrl,
                            name: r.nickName,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.nickName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '@${r.userName}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(apiProvider)
                                    .acceptFriendRequest(r.userId);
                                // 這裡是 onPressed 閉包，沒有 State.mounted，改用 context.mounted。
                                if (!context.mounted) return;
                                ref.invalidate(friendRequestsProvider);
                                ref.invalidate(conversationsProvider);
                                messenger.showSnackBar(SnackBar(
                                    content: Text(
                                        '${context.tr('已添加')} ${r.nickName}')));
                              } on ApiException catch (e) {
                                messenger.showSnackBar(
                                    SnackBar(content: Text(e.message)));
                              } catch (e) {
                                messenger.showSnackBar(
                                    SnackBar(content: Text(e.toString())));
                              }
                            },
                            child: Text(context.tr('接受')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
