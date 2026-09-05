import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../providers/auth_provider.dart';
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
          title: const Text('新增客服帳號'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: userNameCtl,
                  decoration: const InputDecoration(
                    labelText: '用戶名',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.length < 3 ? '至少3個字元' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nickCtl,
                  decoration: const InputDecoration(
                    labelText: '顯示名稱',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) => v == null || v.isEmpty ? '請填寫顯示名稱' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pwdCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '登錄密碼',
                    prefixIcon: Icon(Icons.lock),
                    helperText: '至少6位',
                  ),
                  validator: (v) => v == null || v.length < 6 ? '密碼至少6位' : null,
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
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('取消')),
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
                            const SnackBar(content: Text('客服帳號已創建'), backgroundColor: AppTheme.primary),
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
                          err = '網絡錯誤，請重試';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('創建'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(ServiceAccountDto a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除客服帳號'),
        content: Text('確定將「${a.nickName}」移出客服？該帳號將保留為普通用戶，歷史會話不會丟失。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移除'),
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
          const SnackBar(content: Text('已移出客服'), backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移除失敗: $e'), backgroundColor: Colors.red),
        );
      }
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('客服帳號', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('創建多個客服帳號，用戶「聯繫客服」時可選擇在線客服直接對話（免好友關係）。',
                        style: TextStyle(color: AppTheme.textSub, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('新增客服'),
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
                              TextButton(onPressed: _load, child: const Text('重試')),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(child: Text('暫無客服帳號，點擊右上角新增'))
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
                                          a.isOnline ? '在線' : '離線',
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
                                        tooltip: '移除客服',
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
