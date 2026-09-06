import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<RoleDto> _roles = [];
  bool _loading = false;
  String? _error;

  static const List<Map<String, String>> _allPerms = [
    {'k': 'dashboard.view', 'label': K.permViewDashboard},
    {'k': 'users.read', 'label': K.permViewUsers},
    {'k': 'users.write', 'label': K.permManageUsers},
    {'k': 'roles.read', 'label': K.permViewRoles},
    {'k': 'roles.write', 'label': K.permManageRoles},
    {'k': 'audit.read', 'label': K.permViewAudit},
    {'k': 'admins.read', 'label': K.permViewAdmins},
    {'k': 'admins.write', 'label': K.permManageAdmins},
  ];

  bool get _canWrite => context.read<AuthProvider>().hasPerm('roles.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AuthProvider>().api.get(
        '/api/admin/roles',
      );
      if (mounted) {
        setState(() {
          _roles = (data as List).map((e) => RoleDto.fromJson(e)).toList();
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

  Future<void> _save(RoleDto? existing) async {
    final t = context.read<LocaleProvider>().t;
    final api = context.read<AuthProvider>().api;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final selected = <String>{...?existing?.perms};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? t[K.roleNewTitle] : t[K.roleEditTitle]),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: t[K.roleName]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(labelText: t[K.roleDesc]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t[K.rolePerms],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ..._allPerms.map(
                    (p) => CheckboxListTile(
                      title: Text(t[p['label']!]),
                      subtitle: Text(
                        p['k']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSub,
                        ),
                      ),
                      value: selected.contains(p['k']),
                      onChanged: (v) => setSt(
                        () => v == true
                            ? selected.add(p['k']!)
                            : selected.remove(p['k']!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      ),
    );
    if (ok != true) return;
    final perms = selected.join(',');
    try {
      if (existing == null) {
        await api.post('/api/admin/roles', {
          'name': nameCtrl.text.trim(),
          'permissions': perms,
          'description': descCtrl.text.trim(),
        });
      } else {
        await api.put(
          '/api/admin/roles/${existing.id}',
          {
            'name': nameCtrl.text.trim(),
            'permissions': perms,
            'description': descCtrl.text.trim(),
          },
        );
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(RoleDto r) async {
    final t = context.read<LocaleProvider>().t;
    final api = context.read<AuthProvider>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t[K.roleDeleteTitle]),
        content: Text(t.tr(K.roleConfirmDelete, {'n': r.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t[K.cancel]),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t[K.delete]),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/api/admin/roles/${r.id}');
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t[K.navRoles],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_canWrite)
                FilledButton.icon(
                  onPressed: () => _save(null),
                  icon: const Icon(Icons.add),
                  label: Text(t[K.roleNewTitle]),
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
                    itemCount: _roles.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final r = _roles[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.badge,
                          color: AppTheme.primary,
                        ),
                        title: Text(r.name),
                        subtitle: Text(
                          r.perms.isEmpty ? t[K.roleNoPerm] : r.perms.join('  '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _canWrite
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _save(r),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(r),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
