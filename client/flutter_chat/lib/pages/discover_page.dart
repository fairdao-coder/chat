import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models/discover_column.dart';
import '../providers/conversations_provider.dart';

/// 發現 tab：聚合應用的次級入口（添加好友 / 好友請求 / 創建群聊）
/// 以及由管理後臺維護的欄目列表（點擊在 WebView 打開鏈接）。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  List<DiscoverColumn> _columns = [];
  bool _loadingColumns = false;

  @override
  void initState() {
    super.initState();
    _loadColumns();
  }

  Future<void> _loadColumns() async {
    setState(() => _loadingColumns = true);
    try {
      final list = await ApiClient().getDiscoverColumns();
      if (mounted) setState(() => _columns = list);
    } catch (_) {
      // 欄目加載失敗不影響內置入口，靜默忽略。
    } finally {
      if (mounted) setState(() => _loadingColumns = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final requests = ref.watch(friendRequestsProvider);
    final pending = requests.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final children = <Widget>[
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
      _Entry(
        icon: Icons.qr_code_scanner_outlined,
        color: Colors.teal,
        title: context.tr('扫一扫'),
        onTap: () => context.push('/scan'),
      ),
    ];

    // 管理後臺配置的欄目。
    if (_loadingColumns) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (_columns.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      for (final col in _columns) {
        children.add(_Entry(
          icon: Icons.link,
          color: Colors.purple,
          leadingText: col.icon,
          title: col.title,
          onTap: () {
            if (col.link?.isNotEmpty == true) {
              context.push('/webview?url=${Uri.encodeComponent(col.link!)}'
                  '&title=${Uri.encodeComponent(col.title)}');
            }
          },
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('发现'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: children,
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
  final String? leadingText;

  const _Entry({
    required this.icon,
    required this.color,
    required this.title,
    this.badge = 0,
    required this.onTap,
    this.leadingText,
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
                child: leadingText?.isNotEmpty == true
                    ? Center(
                        child: Text(
                          leadingText!,
                          style: TextStyle(fontSize: 18, color: color),
                        ),
                      )
                    : Icon(icon, color: color, size: 21),
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
