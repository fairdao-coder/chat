import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

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
      if (mounted) setState(() => _error = '${context.read<LocaleProvider>().t[K.loadFailed]}$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search() {
    _page = 1;
    _load();
  }

  Future<void> _edit(ChatUserDto u) async {
    final t = context.read<LocaleProvider>().t;
    final api = context.read<AuthProvider>().api;
    final nickCtrl = TextEditingController(text: u.nickName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t[K.userEditTitle]),
        content: TextField(
          controller: nickCtrl,
          decoration: InputDecoration(labelText: t[K.userNickname]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t[K.cancel]),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t[K.save]),
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
            .showSnackBar(SnackBar(content: Text(t[K.saved])));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _ban(ChatUserDto u, bool ban) async {
    final t = context.read<LocaleProvider>().t;
    final api = context.read<AuthProvider>().api;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ban ? t[K.userBanTitle] : t[K.userUnbanTitle]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ban
                ? t.tr(K.userConfirmBan, {'u': u.userName})
                : t.tr(K.userConfirmUnban, {'u': u.userName})),
            if (ban) const SizedBox(height: 12),
            if (ban)
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(labelText: t[K.userReason]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t[K.cancel]),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ban ? t[K.userBan] : t[K.userUnban]),
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
    final t = context.watch<LocaleProvider>().t;
    final totalPages = (_total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t[K.navUsers],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: t[K.userSearchHint],
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _search, child: Text(t[K.search])),
              const Spacer(),
              Text(t.tr(K.userTotal, {'n': '$_total'})),
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
                        columns: [
                          DataColumn(label: Text(t[K.userUsername])),
                          DataColumn(label: Text(t[K.userNickname])),
                          DataColumn(label: Text(t[K.userStatus])),
                          DataColumn(label: Text(t[K.userCreatedAt])),
                          DataColumn(label: Text(t[K.actions])),
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
                                          Chip(
                                            label: Text(t[K.userOnline]),
                                            backgroundColor: Colors.teal,
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        if (u.isBanned)
                                          Chip(
                                            label: Text(t[K.userBanned]),
                                            backgroundColor: Colors.red,
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        if (!u.isOnline && !u.isBanned)
                                          Text(
                                            t[K.userOffline],
                                            style: const TextStyle(
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
                                            child: Text(t[K.edit]),
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
                                              u.isBanned
                                                  ? t[K.userUnban]
                                                  : t[K.userBan],
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
              Text(t.tr(K.pagerPage, {
                'a': '$_page',
                'b': '${totalPages == 0 ? 1 : totalPages}',
              })),
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
