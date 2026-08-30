import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_mode_provider.dart';
import '../widgets/app_avatar.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = AppConfig.apiBase;
  }

  Future<void> _save() async {
    await AppConfig.set(_ctrl.text.trim());
    _toast(context.tr('已保存，重启应用后生效'));
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final cs = Theme.of(context).colorScheme;
    final loc = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('我'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 账户信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl,
                    name: user?.nickName ?? '?',
                    size: 56,
                    online: (user?.isOnline ?? false) ? true : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickName ?? '未登录',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user?.userName ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 外观主题
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(context.tr('外观主题')),
                    subtitle: Text(context.tr('亮色 / 暗色 / 跟随系统')),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    selected: {mode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.tr('亮色')),
                        icon: const Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.tr('暗色')),
                        icon: const Icon(Icons.dark_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.tr('系统')),
                        icon: const Icon(Icons.settings_brightness),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 语言
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_outlined),
                    title: Text(context.tr('语言')),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Locale?>(
                    initialValue: locale,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.tr('跟随系统')),
                      ),
                      ...L10n.supportedLocales.map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(L10n.languageName(l, loc)),
                          )),
                    ],
                    onChanged: (l) => ref.read(localeProvider.notifier).set(l),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 后端地址
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('后端地址 (API Base)'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'http://localhost:5298',
                      prefixIcon: Icon(Icons.dns),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Web 端默认 http://localhost:5298；Android 模拟器用 '
                    'http://10.0.2.2:5298；真机用电脑局域网 IP。修改后需重启应用生效。',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(context.tr('保存')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 退出登录
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: Text(context.tr('退出登录')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _logout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
