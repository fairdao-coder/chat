import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'roles_screen.dart';
import 'audit_screen.dart';
import 'accounts_screen.dart';
import 'discover_columns_screen.dart';
import 'settings_screen.dart';
import 'service_accounts_screen.dart';

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
      Dest(K.navDashboard, Icons.dashboard, 'dashboard.view', DashboardScreen()),
      Dest(K.navUsers, Icons.people, 'users.read', UsersScreen()),
      Dest(K.navService, Icons.support_agent_rounded, 'users.read', ServiceAccountsScreen()),
      Dest(K.navRoles, Icons.badge, 'roles.read', RolesScreen()),
      Dest(K.navAudit, Icons.history, 'audit.read', AuditScreen()),
      Dest(K.navAdmins, Icons.manage_accounts, 'admins.read', AccountsScreen()),
      Dest(K.navDiscover, Icons.explore, 'discover.read', DiscoverColumnsScreen()),
      Dest(K.navSettings, Icons.tune, 'settings.read', SettingsScreen()),
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
    final t = context.read<LocaleProvider>().t;
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
          title: Text(t[K.changePwd]),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t[K.pwdOld],
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? t[K.pwdRequired] : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t[K.pwdNew],
                    helperText: t[K.pwdNewHint],
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? t[K.pwdTooShort] : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t[K.pwdConfirm],
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v != newCtrl.text ? t[K.pwdMismatch] : null,
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
              child: Text(t[K.cancel]),
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
                            SnackBar(
                              content: Text(t[K.pwdSuccess]),
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
                          errorMsg = t[K.errorNetworkRetry];
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t[K.confirm]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = context.watch<LocaleProvider>().t;
    final visible = _visible;
    if (_index >= visible.length) _index = 0;
    final current = visible.isEmpty ? null : visible[_index];

    // 頂部工具欄（寬屏嵌在右側區域頂部，窄屏為 Scaffold.appBar）。
    final appBar = AppBar(
      title: Row(
        children: [
          if (current != null) Icon(current.icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(t[current?.title ?? K.adminConsole]),
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
            tooltip: t[K.changePwd]),
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: t[K.logout]),
        const SizedBox(width: 8),
      ],
    );

    final content = current?.screen ?? Center(child: Text(t[K.noModule]));
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
