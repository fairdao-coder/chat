import 'dart:async';

// 此文件中的確認對話框必須在 await 之後使用 BuildContext（等 root navigator 就緒），
// 且每次使用前都已經過 ctx.mounted 檢查，使用者仍需手動點擊確認，不會靜默應用配置。
// 因此全局忽略該 lint。
// ignore_for_file: use_build_context_synchronously

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../router.dart';
import '../widgets/brand.dart';
import 'auth_provider.dart';
import 'presence_provider.dart';

/// 配置鏈接監聽：App 級別常駐，任何頁面都能接收配置深鏈。
///
/// 原先監聽只掛在登錄頁，用戶登錄後（登錄頁已銷毀）收到的配置鏈接會被
/// 丟棄——後期更換服務器地址時配置推不進去。改為 App 啟動時建立一次監聽，
/// 彈窗用 root navigator 展示，不依賴任何具體頁面。
///
/// state == true 表示「有待確認的配置」，登錄頁據此隱藏表單。
final configLinkProvider =
    StateNotifierProvider<ConfigLinkController, bool>((ref) {
  return ConfigLinkController(ref);
});

/// 配置項，與 AppConfig.parseLink 的返回一致。
typedef LinkConfig = ({String? name, String? api, String? logo, String? download});

class ConfigLinkController extends StateNotifier<bool> {
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  ConfigLinkController(this._ref) : super(false) {
    // web 上 Uri.base 同步可用：構造時就能確定是否有待確認配置，
    // 讓登錄頁首幀渲染正確，避免「表單 → 加載圈」的閃爍。
    if (kIsWeb) {
      final uri = _webUri();
      // 優先處理「發起對話」深鏈（可攜帶在配置鏈接中）。
      final chatId = AppConfig.parseChatLink(uri);
      if (chatId != null) {
        unawaited(_openChat(chatId));
        return;
      }
      final cfg = AppConfig.parseLink(uri);
      if (cfg != null) {
        state = true;
        unawaited(_confirm(cfg));
      }
      return; // web 沒有「運行中深鏈」回調，頁面 URL 即配置來源。
    }
    unawaited(_startMobile());
  }

  /// Web 下的當前頁面 Uri。兼容兩種鏈接形態：
  ///   - 標準查詢：https://host/?chat=xxx   （queryParameters 直接可讀）
  ///   - Hash 路由：https://host/#/?chat=xxx （參數在 fragment 中）
  Uri _webUri() {
    final base = Uri.base;
    // 若主 URL 已含 chat/config 參數，直接使用。
    if (base.queryParameters.containsKey('chat') ||
        base.queryParameters.containsKey('name') ||
        base.queryParameters.containsKey('api')) {
      return base;
    }
    final frag = base.fragment;
    if (frag.isEmpty) return base;
    // fragment 形如 "/?chat=xxx" 或 "?chat=xxx"，補全 host 以便統一解析。
    final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: fragUri.path,
      queryParameters: fragUri.queryParameters.isEmpty
          ? base.queryParameters
          : fragUri.queryParameters,
    );
  }

  Future<void> _startMobile() async {
    // 1) 冷啟動鏈接
    Uri? initial;
    try {
      initial = await _appLinks.getInitialLink();
    } catch (_) {}
    if (initial != null) await _handleUri(initial);
    // 2) 運行中的深鏈
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async => _handleUri(uri),
      onError: (_) {},
    );
  }

  /// 分流：配置鏈接 vs「發起對話」深鏈。
  Future<void> _handleUri(Uri uri) async {
    final chatId = AppConfig.parseChatLink(uri);
    if (chatId != null) {
      await _openChat(chatId);
      return;
    }
    final cfg = AppConfig.parseLink(uri);
    if (cfg != null) {
      state = true;
      await _confirm(cfg);
    }
  }

  /// 等待 root navigator 可用。App 剛起步時可能還沒完成首幀構建，
  /// 直接取 currentContext 會拿到 null 而丟掉整個配置流程。
  Future<BuildContext?> _waitForContext() async {
    for (var i = 0; i < 50; i++) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) return ctx;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }

  /// 供掃一掃等場景顯式提交一條鏈接。依鏈接類型分流：
  ///   - 發起對話鏈接 -> 直接跳轉私聊頁（非好友會提示先加好友）；
  ///   - 配置鏈接     -> 彈出確認框應用。
  /// 返回 true 表示成功處理；false 表示該鏈接無法識別。
  Future<bool> handleLink(Uri uri) async {
    final chatId = AppConfig.parseChatLink(uri);
    if (chatId != null) {
      await _openChat(chatId);
      return true;
    }
    final cfg = AppConfig.parseLink(uri);
    if (cfg == null) return false;
    state = true;
    await _confirm(cfg);
    return true;
  }

  /// 跳轉到與 [userId] 的私聊頁。若當前頁面為登錄頁（未登錄）則先提示登錄；
  /// 若與對方尚未成為好友，由 ChatPage 自身處理「先加好友」的提示，這裡不預判。
  Future<void> _openChat(String userId) async {
    final ctx = await _waitForContext();
    if (ctx == null || !ctx.mounted) return;
    final auth = _ref.read(authProvider);
    if (auth.user == null) {
      // 未登錄：跳轉登錄，登錄後用戶需重新打開鏈接。
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(ctx.tr('请先登录后再发起对话'))),
      );
      ctx.go('/login');
      return;
    }
    ctx.push('/chat?friendId=$userId');
  }

  /// 彈出確認框並應用。應用前必須讓用戶確認——api 地址會被用於提交登錄
  /// 憑據，靜默接受相當於允許任意鏈接把用戶重定向到釣魚服務器。
  Future<void> _confirm(LinkConfig cfg) async {
    final ctx = await _waitForContext();
    if (ctx == null) {
      state = false; // 拿不到 context，放棄本次配置（不能靜默應用）。
      return;
    }

    final apply = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => _ConfigDialog(cfg: cfg),
    );

    // 對話框已關閉，清除「待確認」標記（用戶選取消也要能繼續使用 App）。
    state = false;

    if (apply == true && ctx.mounted) {
      final apiChanged = await AppConfig.applyLink(cfg);
      if (apiChanged) {
        // 地址變化：指向舊服務器的客戶端實例必須重建。
        _ref.invalidate(authProvider);
        _ref.invalidate(presenceProvider);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class _ConfigDialog extends StatelessWidget {
  final LinkConfig cfg;
  const _ConfigDialog({required this.cfg});

  @override
  Widget build(BuildContext c) {
    return AlertDialog(
      title: Text(c.tr('检测到配置链接')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cfg.name != null) _cfgRow(c, c.tr('应用名'), cfg.name!),
          if (cfg.api != null) _cfgRow(c, c.tr('服务器地址'), cfg.api!),
          if (cfg.logo != null) _cfgRow(c, 'Logo', cfg.logo!, isLogo: true),
          if (cfg.download != null) _cfgRow(c, c.tr('下载页地址'), cfg.download!),
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
    );
  }

  Widget _cfgRow(BuildContext c, String label, String value,
      {bool isLogo = false}) {
    final valueWidget = isLogo && value.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BrandMark(size: 40, imageUrl: value),
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
          valueWidget,
          if (isLogo && value.isNotEmpty) ...[
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
}
