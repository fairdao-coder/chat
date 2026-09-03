import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../bridges/chat_bridge.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import 'mini_default_template.dart';
import 'web_html.dart';

/// 小應用 / H5 本地包容器。
///
/// [name] 為小應用標識。解析規則：
///   - 若 [name] 以 `html:` 開頭，其後為內聯 HTML 文本，**禁止執行腳本**（安全默認）；
///   - 若 [name] 以 `script:` 開頭，其後為內聯 HTML，且**允許執行 JavaScript**
///     （需管理員顯式書寫，用於需要腳本交互的場景）；
///   - 若 [name] 以 http(s):// 開頭，直接當作遠程 H5 地址在 WebView 打開；
///   - 否則當作本地包名，加載 assets 中的 H5 包 `assets/mini/<name>/index.html`
///     （需在 pubspec.yaml 的 flutter.assets 中註冊對應目錄）。
///
/// Web 平臺 webview_flutter 沒有內置實現，改為外部瀏覽器打開（內聯 HTML 不支支持）。
class MiniAppPage extends ConsumerStatefulWidget {
  final String name;
  final String? title;

  const MiniAppPage({super.key, required this.name, this.title});

  @override
  ConsumerState<MiniAppPage> createState() => _MiniAppPageState();
}

class _MiniAppPageState extends ConsumerState<MiniAppPage> {
  late final bool _isInlineHtml;
  late final bool _allowScript;
  late final String _inlineHtml;
  late final String _resolvedUrl;
  late final String _webViewId;
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  /// 移除所有 <script>...</script> 片段（用於 `html:` 前綴的禁腳本模式）。
  static String _stripScripts(String markup) => markup
      .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true, caseSensitive: false), '')
      .replaceAll(RegExp(r'</?script\b[^>]*>', caseSensitive: false), '');

  @override
  void initState() {
    super.initState();

    if (widget.name.isEmpty) {
      // 欄目未配置內容：展示默認模板（當前用戶 / Token / Bridge 調用示例）。
      // 需要讀取登錄態，故放在最前面單獨處理。
      final auth = ref.read(authProvider);
      final u = auth.user;
      _isInlineHtml = true;
      _allowScript = true;
      _inlineHtml = buildDefaultMiniAppHtml(
        columnTitle: widget.title,
        userId: u?.id,
        nickName: u?.nickName,
        userName: u?.userName,
        token: auth.token,
      );
      _resolvedUrl = '';
    } else if (widget.name.startsWith('html:')) {
      // 內聯 HTML 文本，禁止執行腳本。
      _isInlineHtml = true;
      _allowScript = false;
      _inlineHtml = _stripScripts(widget.name.substring('html:'.length));
      _resolvedUrl = '';
    } else if (widget.name.startsWith('script:')) {
      // 內聯 HTML 文本，顯式允許執行腳本。
      _isInlineHtml = true;
      _allowScript = true;
      _inlineHtml = widget.name.substring('script:'.length);
      _resolvedUrl = '';
    } else if (widget.name.startsWith('http://') || widget.name.startsWith('https://')) {
      _isInlineHtml = false;
      _allowScript = false;
      _inlineHtml = '';
      _resolvedUrl = widget.name;
    } else {
      _isInlineHtml = false;
      _allowScript = false;
      _inlineHtml = '';
      _resolvedUrl = 'assets/mini/${widget.name}/index.html';
    }

    if (kIsWeb) {
      _loading = false;
      if (_isInlineHtml) {
        // Web 端用 dart:html 直接注入內聯 HTML（webview_flutter 無 web 實現）。
        _webViewId = 'inline-html-${DateTime.now().microsecondsSinceEpoch}';
        registerInlineHtml(_webViewId, _inlineHtml, allowScript: _allowScript);
        return;
      }
      Future.microtask(() async {
        final uri = widget.name.startsWith('http')
            ? Uri.parse(widget.name)
            : Uri.parse('http://localhost/');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    if (_isInlineHtml) {
      // 預註入小應用 Bridge 客戶端（定義 window.ChatBridge），讓頁面內腳本
      // 可在加載時直接調用宿主能力。
      final htmlWithBridge = '${chatBridgeBootstrap()}\n$_inlineHtml';
      _controller = _applyBridge(WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _loading = true),
            onPageFinished: (_) => setState(() => _loading = false),
            onWebResourceError: (_) => setState(() => _failed = true),
          ),
        )
        ..loadHtmlString(htmlWithBridge));
    } else if (widget.name.startsWith('http')) {
      _controller = _applyBridge(WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _loading = true),
            onPageFinished: (_) => setState(() => _loading = false),
            onWebResourceError: (_) => setState(() => _loading = false),
          ),
        )
        ..loadRequest(Uri.parse(_resolvedUrl)));
    } else {
      // 本地 H5 包：加載 assets 中的 index.html。
      _controller = _applyBridge(WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _loading = true),
            onPageFinished: (_) => setState(() => _loading = false),
            onWebResourceError: (_) => setState(() => _failed = true),
          ),
        )
        ..loadFlutterAsset(_resolvedUrl));
    }
  }

  /// 為 [WebViewController] 註冊小應用 JS Bridge（移動端）。
  ///
  /// - 預註入 `window.ChatBridge` 包装腳本（頁面加載前執行）；
  /// - 註冊 [kChatBridgeChannel] javascriptChannel 接收 H5 調用，分發到
  ///   宿主能力並把結果回傳。
  WebViewController _applyBridge(WebViewController c) {
    return c
      ..addJavaScriptChannel(
        kChatBridgeChannel,
        onMessageReceived: (message) async {
          final req = parseBridgeRequest(message.message);
          if (req == null) return;
          final id = req['id'] as String;
          try {
            final result = await handleBridgeCall(ref, req);
            await c.runJavaScript(
              mobileBridgeResponseScript(id, ok: true, result: result),
            );
          } catch (e) {
            await c.runJavaScript(
              mobileBridgeResponseScript(id, ok: false, error: e.toString()),
            );
          }
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tr = context.tr;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? widget.name)),
      body: kIsWeb
          ? (_isInlineHtml
              ? HtmlElementViewShim(viewId: _webViewId)
              : Center(child: Text(tr('请在手机端打开小应用'))))
          : _failed
              ? Center(
                  child: Text(tr('小应用加载失败'),
                      style: TextStyle(color: cs.error)),
                )
              : Stack(
                  children: [
                    if (_controller != null) WebViewWidget(controller: _controller!),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
    );
  }
}

/// Web 端內聯 HTML 渲染（條件導入）。非 Web 端不會被構建到該分支。
class HtmlElementViewShim extends StatelessWidget {
  final String viewId;
  const HtmlElementViewShim({super.key, required this.viewId});

  @override
  Widget build(BuildContext context) => inlineHtmlView(viewId);
}
