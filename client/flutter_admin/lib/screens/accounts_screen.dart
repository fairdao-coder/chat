import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<AdminUserDto> _admins = [];
  List<RoleDto> _roles = [];
  bool _loading = false;
  String? _error;

  bool get _canWrite => context.read<AuthProvider>().hasPerm('admins.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final admins = await api.get('/api/admin/accounts');
      List<RoleDto> roles = [];
      if (context.read<AuthProvider>().hasPerm('roles.read')) {
        final r = await api.get('/api/admin/roles');
        roles = (r as List).map((e) => RoleDto.fromJson(e)).toList();
      }
      if (mounted) {
        setState(() {
          _admins = (admins as List)
              .map((e) => AdminUserDto.fromJson(e))
              .toList();
          _roles = roles;
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

  Future<void> _create() async {
    final userCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? roleId = _roles.isNotEmpty ? _roles.first.id : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('新建管理員'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: '登錄賬號'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '顯示名稱'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密碼'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: roleId,
                  decoration: const InputDecoration(labelText: '角色'),
                  items: _roles
                      .map(
                        (r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => roleId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('創建'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await context.read<AuthProvider>().api.post('/api/admin/accounts', {
        'userName': userCtrl.text.trim(),
        'displayName': nameCtrl.text.trim(),
        'password': passCtrl.text,
        'roleId': roleId,
      });
      _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggle(AdminUserDto a) async {
    try {
      await context.read<AuthProvider>().api.post(
        '/api/admin/accounts/${a.id}/toggle?active=${!a.isActive}',
        null,
      );
      _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '管理員賬號',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_canWrite)
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('新建管理員'),
                ),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _admins.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final a = _admins[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primarySoft,
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: Text('${a.displayName}（@${a.userName}）'),
                        subtitle: Text(
                          '角色：${a.roleName}  ·  創建於 ${a.createdAt.toLocal().toString().split(' ')[0]}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(a.isActive ? '啟用' : '停用'),
                              backgroundColor: a.isActive
                                  ? Colors.green.shade100
                                  : Colors.grey.shade300,
                            ),
                            if (_canWrite) const SizedBox(width: 8),
                            if (_canWrite)
                              TextButton(
                                onPressed: () => _toggle(a),
                                child: Text(a.isActive ? '停用' : '啟用'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
