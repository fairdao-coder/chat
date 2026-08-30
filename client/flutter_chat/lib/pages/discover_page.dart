import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/conversations_provider.dart';

/// 發現 tab：聚合應用的次級入口（添加好友 / 好友請求 / 創建群聊）。
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);
    final pending = requests.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('发现'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _Entry(
            icon: Icons.person_add_alt_1,
            color: Colors.green,
            title: context.tr('添加好友'),
            onTap: () => context.push('/add-friend'),
          ),
          _Entry(
            icon: Icons.mark_email_unread_outlined,
            color: Colors.orange,
            title: context.tr('好友请求'),
            badge: pending,
            onTap: () => context.push('/friend-requests'),
          ),
          _Entry(
            icon: Icons.group_add,
            color: Colors.blue,
            title: context.tr('创建群聊'),
            onTap: () => context.push('/create-group'),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int badge;
  final VoidCallback onTap;

  const _Entry({
    required this.icon,
    required this.color,
    required this.title,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (badge > 0)
                Badge(label: Text(badge.toString()))
              else
                const SizedBox.shrink(),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
