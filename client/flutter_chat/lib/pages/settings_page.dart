import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../data/api_client.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ctrl.text = AppConfig.apiBase;
  }

  Future<void> _save() async {
    await AppConfig.set(_ctrl.text.trim());
    if (!mounted) return;
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
          // 賬戶信息
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
                          user?.nickName ?? '未登錄',
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

          // 外觀主題
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
                    subtitle: Text(
                      '${context.tr('亮色')} / ${context.tr('暗色')} / ${context.tr('跟随系统')}',
                    ),
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

          // 語言
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

          // 後端地址
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
                    'Web 端默認 http://localhost:5298；Android 模擬器用 '
                    'http://10.0.2.2:5298；真機用電腦局域網 IP。修改後需重啟應用生效。',
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

          // 賬戶操作
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(context.tr('修改密码')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(context.tr('退出登录')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 彈出修改密碼對話框：舊密碼 + 新密碼 + 確認，提交到後端校驗舊密碼。
  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;
    // 提前捕獲 api 引用，避免在異步閉包中再次 ref.read 觸發
    // Riverpod 在 didChangeDependencies 期間的 assert 異常。
    final api = ref.read(apiProvider);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: Text(context.tr('修改密码')),
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
                    labelText: context.tr('旧密码'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? context.tr('请输入旧密码') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('新密码'),
                    helperText: context.tr('至少6位'),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? context.tr('密码长度至少6位') : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('确认新密码'),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) => v != newCtrl.text
                      ? context.tr('两次输入的新密码不一致')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogCtx),
              child: Text(context.tr('取消')),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!mounted) return;
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => busy = true);
                      try {
                        await api.changePassword(oldCtrl.text, newCtrl.text);
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          _toast(dialogCtx.tr('密码修改成功'));
                        }
                      } on ApiException catch (e) {
                        setDialogState(() => busy = false);
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
                      } catch (_) {
                        setDialogState(() => busy = false);
                        if (dialogCtx.mounted) {
                          ScaffoldMessenger.of(dialogCtx).showSnackBar(
                            SnackBar(content: Text(dialogCtx.tr('网络错误，请重试'))),
                          );
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('确认修改')),
            ),
          ],
        ),
      ),
      );
    } finally {
      // 對話框關閉後控制器已無用，必須釋放——否則每次打開修改密碼都會洩漏三個控制器。
      oldCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }
}
