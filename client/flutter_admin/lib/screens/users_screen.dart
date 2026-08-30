import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<ChatUserDto> _items = [];
  int _total = 0;
  int _page = 1;
  final int _pageSize = 15;
  final String _q = '';
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  bool get _canWrite => context.read<AuthProvider>().hasPerm('users.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AuthProvider>().api.get(
        '/api/admin/users?q=${Uri.encodeComponent(_q)}&page=$_page&pageSize=$_pageSize',
      );
      final paged = PagedResult<ChatUserDto>(
        (data['items'] as List).map((e) => ChatUserDto.fromJson(e)).toList(),
        data['total'],
        data['page'],
        data['pageSize'],
      );
      if (mounted) {
        setState(() {
          _items = paged.items;
          _total = paged.total;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '加載失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search() {
    _page = 1;
    _load();
  }

  Future<void> _edit(ChatUserDto u) async {
    final api = context.read<AuthProvider>().api;
    final nickCtrl = TextEditingController(text: u.nickName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編輯用戶資料'),
        content: TextField(
          controller: nickCtrl,
          decoration: const InputDecoration(labelText: '暱稱'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.put('/api/admin/users/${u.id}', {
        'nickName': nickCtrl.text.trim(),
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _ban(ChatUserDto u, bool ban) async {
    final api = context.read<AuthProvider>().api;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ban ? '封禁用戶' : '解封用戶'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ban ? '確認封禁 @${u.userName}？' : '確認解封 @${u.userName}？'),
            if (ban) const SizedBox(height: 12),
            if (ban)
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: '原因（可選）'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ban ? '封禁' : '解封'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.post(
        '/api/admin/users/${u.id}/ban',
        {'banned': ban, 'reason': reasonCtrl.text.trim()},
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '用戶管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: '搜索用戶名 / 暱稱',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _search, child: const Text('搜索')),
              const Spacer(),
              Text('共 $_total 個用戶'),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          Expanded(
            child: Card(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('用戶名')),
                          DataColumn(label: Text('暱稱')),
                          DataColumn(label: Text('狀態')),
                          DataColumn(label: Text('註冊時間')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items
                            .map(
                              (u) => DataRow(
                                cells: [
                                  DataCell(Text(u.userName)),
                                  DataCell(Text(u.nickName)),
                                  DataCell(
                                    Row(
                                      children: [
                                        if (u.isOnline)
                                          const Chip(
                                            label: Text('在線'),
                                            backgroundColor: Colors.teal,
                                            labelStyle: TextStyle(
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        if (u.isBanned)
                                          const Chip(
                                            label: Text('已封禁'),
                                            backgroundColor: Colors.red,
                                            labelStyle: TextStyle(
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        if (!u.isOnline && !u.isBanned)
                                          const Text(
                                            '離線',
                                            style: TextStyle(
                                              color: AppTheme.textSub,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      u.createdAt.toLocal().toString().split(
                                        '.',
                                      )[0],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        if (_canWrite)
                                          TextButton(
                                            onPressed: () => _edit(u),
                                            child: const Text('編輯'),
                                          )
                                        else
                                          const Text(
                                            '-',
                                            style: TextStyle(
                                              color: AppTheme.textSub,
                                            ),
                                          ),
                                        if (_canWrite)
                                          TextButton(
                                            onPressed: () =>
                                                _ban(u, !u.isBanned),
                                            child: Text(
                                              u.isBanned ? '解封' : '封禁',
                                              style: TextStyle(
                                                color: u.isBanned
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('第 $_page / ${totalPages == 0 ? 1 : totalPages} 頁'),
              IconButton(
                onPressed: _page < totalPages
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
