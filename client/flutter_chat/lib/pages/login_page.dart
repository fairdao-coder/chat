import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/config_link_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/brand.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  bool _isRegister = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _toast(context.tr('请输入用户名和密码'));
      return;
    }
    if (_isRegister && _nickCtrl.text.trim().isEmpty) {
      _toast(context.tr('请输入昵称'));
      return;
    }
    final auth = ref.read(authProvider.notifier);
    final ok = _isRegister
        ? await auth.register(user, pass, _nickCtrl.text.trim())
        : await auth.login(user, pass);
    if (!ok && mounted) {
      _toast(ref.read(authProvider).error ?? context.tr('操作失败'));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDownload() async {
    final url = Uri.parse(AppConfig.downloadUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _toast(context.tr('无法打开下载页'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // 有待確認的配置鏈接時隱藏表單：用戶不應在地址尚未確認前
    // 面對登錄界面（也防止把憑據輸進指向舊地址的會話）。
    // 監聽與彈窗由 App 級別的 configLinkProvider 統一處理。
    final formVisible = !ref.watch(configLinkProvider);

    return Scaffold(
      appBar: AppBar(
        // 語言切換入口：localeProvider 響應式，選擇後立即重建界面。
        // 配置確認期間不提供任何交互入口。
        actions: [
          if (formVisible)
          PopupMenuButton<Locale?>(
            tooltip: context.tr('语言'),
            icon: const Icon(Icons.language),
            onSelected: (l) => ref.read(localeProvider.notifier).set(l),
            itemBuilder: (c) => [
              PopupMenuItem<Locale?>(
                value: null,
                child: Text(c.tr('跟随系统')),
              ),
              ...L10n.supportedLocales.map(
                (l) => PopupMenuItem<Locale?>(
                  value: l,
                  child: Text(L10n.languageName(l, L10n.of(c))),
                ),
              ),
            ],
          ),
          if (formVisible)
            IconButton(
              tooltip: context.tr('扫一扫'),
              icon: const Icon(Icons.qr_code_scanner_outlined),
              onPressed: () => context.go('/scan'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  BrandMark(
                    size: 76,
                    imageUrl:
                        AppConfig.logoUrl.isEmpty ? null : AppConfig.logoUrl,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppConfig.brandName,
                    style: textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('连接每一次对话'),
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  // 品牌區保持顯示，避免確認框後是空屏。
                  if (!formVisible)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (formVisible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            selected: {_isRegister},
                            onSelectionChanged: (s) =>
                                setState(() => _isRegister = s.first),
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(context.tr('登录')),
                                icon: const Icon(Icons.login),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(context.tr('注册')),
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _userCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr('用户名'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passCtrl,
                            decoration: InputDecoration(
                              labelText: context.tr('密码'),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nickCtrl,
                              decoration: InputDecoration(
                                labelText: context.tr('昵称'),
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isRegister
                                    ? context.tr('注册并登录')
                                    : context.tr('登录')),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => context.go('/scan'),
                            icon: const Icon(Icons.qr_code_scanner_outlined),
                            label: Text(context.tr('扫一扫导入配置')),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openDownload,
                            icon: const Icon(Icons.download_outlined),
                            label: Text(context.tr('下载客户端')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (formVisible)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister
                            ? context.tr('已有账号？去登录')
                            : context.tr('还没有账号？去注册'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
