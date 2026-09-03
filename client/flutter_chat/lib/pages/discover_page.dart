import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models/discover_column.dart';
import '../providers/conversations_provider.dart';
import '../theme.dart';

/// 發現 tab：展示由管理後臺維護的欄目列表（鏈接 / 路由 / 動作 / 小應用）。
/// 內置固化入口已移除，入口統一由數據庫驅動（後臺可增刪改、固定到底部）。
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
      // 已固定在底部的欄目（Pinned）已經在底部 Tab 出現，不在發現頁重複展示。
      // 發現頁只展示「未固定」的欄目（其打開方式由 kind 決定）。
      if (mounted) {
        setState(() => _columns = list.where((c) => !c.pinned).toList());
      }
    } catch (_) {
      // 欄目加載失敗不影響內置入口，靜默忽略。
    } finally {
      if (mounted) setState(() => _loadingColumns = false);
    }
  }

  void _openColumn(DiscoverColumn col) {
    final content = col.content ?? '';
    switch (col.kind) {
      case DiscoverKind.link:
        if (content.isNotEmpty) {
          context.push('/webview?url=${Uri.encodeComponent(content)}'
              '&title=${Uri.encodeComponent(resolvedColumnTitle(context, col))}');
        }
        break;
      case DiscoverKind.route:
        if (content.isNotEmpty) {
          context.push(content);
        }
        break;
      case DiscoverKind.action:
        _runAction(content.isEmpty ? 'scan' : content);
        break;
      case DiscoverKind.mini:
        // content 可為空：交由 MiniAppPage 展示默認模板（未配置內容時）。
        context.push('/mini?name=${Uri.encodeComponent(content)}'
            '&title=${Uri.encodeComponent(resolvedColumnTitle(context, col))}');
        break;
    }
  }

  void _runAction(String action) {
    switch (action) {
      case 'addFriend':
        context.push('/add-friend');
        break;
      case 'createGroup':
        context.push('/create-group');
        break;
      case 'friendRequests':
        context.push('/friend-requests');
        break;
      case 'scan':
        context.push('/scan');
        break;
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

    // 僅展示管理後臺配置的欄目（固化內置入口已移除，統一由數據庫驅動）。
    Widget body;
    if (_loadingColumns && _columns.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_columns.isEmpty) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_outlined,
                size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              context.tr('暂无栏目'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontFamilyFallback: kIsWeb ? kFontFamilyFallback : null,
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final col in _columns)
            _Entry(
              icon: _columnIcon(col.kind),
              color: _kindColor(col.kind),
              leadingText: col.icon ?? _kindChar(col.kind),
              title: resolvedColumnTitle(context, col),
              // 好友邀請欄目顯示未處理請求數角標
              badge:
                  col.kind == DiscoverKind.action && col.content == 'friendRequests'
                      ? pending
                      : 0,
              onTap: () => _openColumn(col),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('发现'))),
      body: body,
    );
  }
}

/// 欄目類型對應的圖標底色。
Color _kindColor(DiscoverKind kind) {
  switch (kind) {
    case DiscoverKind.route:
      return Colors.blue;
    case DiscoverKind.action:
      return Colors.green;
    case DiscoverKind.mini:
      return Colors.purple;
    case DiscoverKind.link:
      return Colors.teal;
  }
}

IconData _columnIcon(DiscoverKind kind) {
  switch (kind) {
    case DiscoverKind.route:
      return Icons.open_in_new;
    case DiscoverKind.action:
      return Icons.flash_on_outlined;
    case DiscoverKind.mini:
      return Icons.apps_outlined;
    case DiscoverKind.link:
      return Icons.link;
  }
}

String _kindChar(DiscoverKind kind) {
  switch (kind) {
    case DiscoverKind.route:
      return '↗';
    case DiscoverKind.action:
      return '⚡';
    case DiscoverKind.mini:
      return '▦';
    case DiscoverKind.link:
      return '🔗';
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamilyFallback: kFontFamilyFallback,
                  ),
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
