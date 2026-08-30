import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'roles_screen.dart';
import 'audit_screen.dart';
import 'accounts_screen.dart';

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
      Dest('仪表盘', Icons.dashboard, 'dashboard.view', DashboardScreen()),
      Dest('用户管理', Icons.people, 'users.read', UsersScreen()),
      Dest('角色管理', Icons.badge, 'roles.read', RolesScreen()),
      Dest('审计日志', Icons.history, 'audit.read', AuditScreen()),
      Dest('管理员', Icons.manage_accounts, 'admins.read', AccountsScreen()),
    ];
  }

  List<Dest> get _visible {
    final auth = context.read<AuthProvider>();
    return _dests.where((d) => auth.hasPerm(d.perm)).toList();
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final visible = _visible;
    if (_index >= visible.length) _index = 0;
    final current = visible.isEmpty ? null : visible[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current?.title ?? '后台管理'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${auth.admin?.displayName ?? ''}（${auth.admin?.roleName ?? ''}）',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSub),
              ),
            ),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: '退出登录'),
        ],
      ),
      drawer: AppDrawer(
        dests: visible,
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
      body: current?.screen ?? const Center(child: Text('无可用模块')),
    );
  }
}
