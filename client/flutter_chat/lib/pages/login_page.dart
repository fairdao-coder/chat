import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
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
  final _apiCtrl = TextEditingController();
  final _appLinks = AppLinks();
  bool _isRegister = false;
  // 登錄表單可見性：頁面打開時先檢查配置鏈接，確認期間隱藏表單——
  // 避免用戶在鏈接指向的新地址生效前，把憑據輸進舊地址的界面。
  bool _formVisible = false;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _apiCtrl.text = AppConfig.apiBase;
    // 配置链接入口：冷启动链接（web 取页面 URL）+ 运行中的深链。
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialLink());
    if (!kIsWeb) {
      _linkSub = _appLinks.uriLinkStream.listen(
        _offerLinkConfig,
        onError: (_) {},
      );
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nickCtrl.dispose();
    _apiCtrl.dispose();
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialLink() async {
    Uri? uri;
    if (kIsWeb) {
      // web 无深链插件回调，页面 URL 的 query 就是配置来源。
      uri = Uri.base;
    } else {
      try {
        uri = await _appLinks.getInitialLink();
      } catch (_) {}
    }
    if (uri != null) {
      // web 上 Uri.base 總是存在，因此先解析：無配置時直接顯示表單，
      // 避免每次普通啟動都閃一幀加載圈。
      final cfg = AppConfig.parseLink(uri);
      if (cfg == null) {
        if (mounted) setState(() => _formVisible = true);
        return;
      }
      await _showConfigDialog(cfg);
      return;
    }
    if (mounted) setState(() => _formVisible = true);
  }

  /// 運行中收到的深鏈。攜帶配置時彈確認框，否則保證表單可見。
  Future<void> _offerLinkConfig(Uri uri) async {
    final cfg = AppConfig.parseLink(uri);
    if (cfg == null) {
      if (mounted) setState(() => _formVisible = true);
      return;
    }
    if (mounted) setState(() => _formVisible = false);
    await _showConfigDialog(cfg);
  }

  /// 彈出配置確認框並應用結果。應用前必須讓用戶確認——api 地址會被用於
  /// 提交登錄憑據，靜默接受相當於允許任意鏈接把用戶重定向到釣魚服務器。
  Future<void> _showConfigDialog(
      ({String? name, String? api, String? logo}) cfg) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('检测到配置链接')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cfg.name != null)
              _cfgRow(c, c.tr('应用名'), cfg.name!),
            if (cfg.api != null)
              _cfgRow(c, c.tr('服务器地址'), cfg.api!),
            if (cfg.logo != null)
              _cfgRow(c, 'Logo', cfg.logo!, isLogo: true),
            const SizedBox(height: 10),
            Text(
              c.tr('确定要应用这些配置吗？'),
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('应用')),
          ),
        ],
      ),
    );
    // 對話框關閉後一律恢復表單：用戶選擇「取消」也要能繼續使用登錄頁。
    if (apply == true) {
      final apiChanged = await AppConfig.applyLink(cfg);
      // 地址变化后，指向旧服务器的客户端实例必须重建。
      if (apiChanged) ref.invalidate(authProvider);
      if (!mounted) return;
      setState(() => _apiCtrl.text = AppConfig.apiBase);
    }
    if (!mounted) return;
    setState(() => _formVisible = true);
    if (apply == true) _toast(context.tr('配置已应用'));
  }

  Widget _cfgRow(BuildContext c, String label, String value,
      {bool isLogo = false}) {
    // 重置为默认 Logo 时 value 为空串，值列显示占位符。
    final valueWidget = isLogo && value.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: value,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          )
        : Expanded(
            child: Text(
              (isLogo && value.isEmpty) ? '—' : value,
              style: const TextStyle(fontSize: 13.5),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(c).colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ),
          if (!isLogo || value.isEmpty) ...[
            valueWidget,
          ] else ...[
            valueWidget,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(c).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 服務器地址有改動時保存，並使依賴舊地址的 provider 失效。
  ///
  /// invalidate(authProvider) 讓新 AuthNotifier 拿到指向新地址的 ApiClient；
  /// hub 連接由 ChatHubClient.connect() 內部的 URL 變更檢測自動重建。
  Future<void> _applyApiBaseIfChanged() async {
    final v = _apiCtrl.text.trim();
    if (v == AppConfig.apiBase) return;
    await AppConfig.set(v);
    ref.invalidate(authProvider);
  }

  Future<void> _saveApiBase() async {
    await _applyApiBaseIfChanged();
    if (!mounted) return;
    _toast(context.tr('服务器地址已保存'));
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
    // 鏈接托管的地址不由本地輸入框覆蓋；僅在地址框顯示時同步用戶手改。
    if (!AppConfig.apiFromLink) await _applyApiBaseIfChanged();
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

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        // 語言切換入口：localeProvider 響應式，選擇後立即重建界面。
        // 配置確認期間不提供任何交互入口。
        actions: [
          if (_formVisible)
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
                  // 表單在配置確認流程期間隱藏：用戶不應在地址尚未確認時
                  // 面對登錄界面（也防止把憑據輸進指向舊地址的會話）。
                  // 品牌區保持顯示，避免確認框後是空屏。
                  if (!_formVisible)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_formVisible)
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
                              // 地址框隱藏時這裡就是最後一項。
                              textInputAction: AppConfig.apiFromLink
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                            ),
                          ],
                          // 地址由配置鏈接托管時不顯示輸入框——受控分發場景下
                          // 用戶不應（也無需）自行修改服務器地址。
                          if (!AppConfig.apiFromLink) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _apiCtrl,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: context.tr('服务器地址'),
                                hintText: 'https://api.example.com',
                                prefixIcon: const Icon(Icons.dns_outlined),
                                helperText: context.tr('修改后随登录自动生效'),
                                suffixIcon: IconButton(
                                  tooltip: context.tr('保存'),
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: loading ? null : _saveApiBase,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveApiBase(),
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
                        ],
                      ),
                    ),
                  ),
                  if (_formVisible)
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
