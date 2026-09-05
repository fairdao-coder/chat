import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'roles_screen.dart';
import 'audit_screen.dart';
import 'accounts_screen.dart';
import 'discover_columns_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Dest> _dests;

  @override
  void initState() {
    super.initState();
    _dests = const [
      Dest('儀表盤', Icons.dashboard, 'dashboard.view', DashboardScreen()),
      Dest('用戶管理', Icons.people, 'users.read', UsersScreen()),
      Dest('角色管理', Icons.badge, 'roles.read', RolesScreen()),
      Dest('審計日誌', Icons.history, 'audit.read', AuditScreen()),
      Dest('管理員', Icons.manage_accounts, 'admins.read', AccountsScreen()),
      Dest('發現頁欄目', Icons.explore, 'discover.read', DiscoverColumnsScreen()),
      Dest('系統配置', Icons.tune, 'settings.read', SettingsScreen()),
    ];
  }

  List<Dest> get _visible {
    final auth = context.read<AuthProvider>();
    return _dests.where((d) => auth.hasPerm(d.perm)).toList();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
  }

  /// 當前管理員自助修改密碼：舊密碼 + 新密碼 + 確認，提交到後端校驗。
  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('修改密碼'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '舊密碼',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? '請輸入舊密碼' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密碼',
                    helperText: '至少6位',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? '密碼長度至少6位' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '確認新密碼',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v != newCtrl.text ? '兩次輸入的新密碼不一致' : null,
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogCtx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        busy = true;
                        errorMsg = null;
                      });
                      try {
                        await context.read<AuthProvider>().api.post(
                              '/api/admin/auth/change-password',
                              {
                                'oldPassword': oldCtrl.text,
                                'newPassword': newCtrl.text,
                              },
                            );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('密碼修改成功'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          busy = false;
                          errorMsg = e.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          busy = false;
                          errorMsg = '網絡錯誤，請重試';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('確認修改'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final visible = _visible;
    if (_index >= visible.length) _index = 0;
    final current = visible.isEmpty ? null : visible[_index];

    // 頂部工具欄（寬屏嵌在右側區域頂部，窄屏為 Scaffold.appBar）。
    final appBar = AppBar(
      title: Row(
        children: [
          if (current != null) Icon(current.icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(current?.title ?? '後臺管理'),
        ],
      ),
      elevation: 0,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                '${auth.admin?.displayName ?? ''} · ${auth.admin?.roleName ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
              ),
            ],
          ),
        ),
        IconButton(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_outline),
            tooltip: '修改密碼'),
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: '退出登錄'),
        const SizedBox(width: 8),
      ],
    );

    final content = current?.screen ?? const Center(child: Text('無可用模塊'));
    void onSelect(int i) => setState(() => _index = i);

    // 寬屏（≥900）：側欄常駐左側佔位，不再懸浮遮擋內容；
    // 窄屏：保留懸浮抽屜（小屏空間有限，需要時再拉出）。
    if (MediaQuery.of(context).size.width >= 900) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 240,
              child: AppSideNav(
                dests: visible,
                currentIndex: _index,
                onSelect: onSelect,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  appBar,
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: AppDrawer(
        dests: visible,
        currentIndex: _index,
        onSelect: onSelect,
      ),
      body: content,
    );
  }
}
