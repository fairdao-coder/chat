import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';

/// 客服帳號管理：創建/列出/移除客服帳號。客服帳號本質是普通聊天用戶，僅當其 Id 出現在 ServiceAgents 表時才被視為客服，
/// 用戶在前端「聯繫客服」時可免好友關係直接私聊。
class ServiceAccountsScreen extends StatefulWidget {
  const ServiceAccountsScreen({super.key});

  @override
  State<ServiceAccountsScreen> createState() => _ServiceAccountsScreenState();
}

class _ServiceAccountsScreenState extends State<ServiceAccountsScreen> {
  List<ServiceAccountDto> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ApiClient get _api => context.read<AuthProvider>().api;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.listServiceAccounts();
      final list = (data['items'] as List? ?? const [])
          .map((e) => ServiceAccountDto.fromJson(e))
          .toList();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final t = context.read<LocaleProvider>().t;
    final userNameCtl = TextEditingController();
    final nickCtl = TextEditingController();
    final pwdCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(t[K.svcNewTitle]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userNameCtl,
                  decoration: InputDecoration(
                    labelText: t[K.userUsername],
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.length < 3 ? t[K.svcMinChars3] : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nickCtl,
                  decoration: InputDecoration(
                    labelText: t[K.adminDisplayName],
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  validator: (v) => v == null || v.isEmpty ? t[K.svcNameRequired] : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pwdCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t[K.svcLoginPwd],
                    prefixIcon: const Icon(Icons.lock),
                    helperText: t[K.pwdNewHint],
                  ),
                  validator: (v) => v == null || v.length < 6 ? t[K.pwdTooShort] : null,
                ),
                if (err != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(err!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: Text(t[K.cancel])),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setD(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        await _api.createServiceAccount({
                          'userName': userNameCtl.text.trim(),
                          'nickName': nickCtl.text.trim(),
                          'password': pwdCtl.text,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t[K.svcCreated]), backgroundColor: AppTheme.primary),
                          );
                        }
                      } on ApiException catch (e) {
                        setD(() {
                          busy = false;
                          err = e.message;
                        });
                      } catch (_) {
                        setD(() {
                          busy = false;
                          err = t[K.errorNetworkRetry];
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t[K.create]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(ServiceAccountDto a) async {
    final t = context.read<LocaleProvider>().t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t[K.svcRemoveTitle]),
        content: Text(t.tr(K.svcRemoveConfirm, {'n': a.nickName})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t[K.cancel])),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(t[K.svcRemove]),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteServiceAccount(a.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t[K.svcRemoved]), backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t[K.svcRemoveFailed]}$e'), backgroundColor: Colors.red),
        );
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t[K.svcTitle],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(t[K.svcDesc],
                        style: const TextStyle(color: AppTheme.textSub, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(t[K.svcAdd]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              TextButton(onPressed: _load, child: Text(t[K.retry])),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(child: Text(t[K.svcEmpty]))
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final a = _items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primarySoft,
                                    child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary),
                                  ),
                                  title: Text(a.nickName),
                                  subtitle: Text('@${a.userName}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: a.isOnline
                                              ? Colors.green.withValues(alpha: 0.12)
                                              : Colors.grey.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          a.isOnline ? t[K.userOnline] : t[K.userOffline],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: a.isOnline ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (a.isBanned)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(Icons.block, color: Colors.red, size: 18),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: t[K.svcRemoveAgent],
                                        onPressed: () => _remove(a),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
