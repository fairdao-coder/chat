// 小應用 JS Bridge —— 讓輸入的 `script:` HTML 能安全調用宿主能力。
//
// 設計：白名單 + 協議化。H5 側只能調用下列 method，且全部走異步
// Promise（移動端走 WebView javascriptChannel，Web 端走 window.postMessage）。
//
// 支持的 method：
//   auth.token            -> 返回當前 JWT（僅返回，不泄露私鑰）
//   auth.user             -> 返回 {id,nickName,userName,avatar}
//   chat.send             -> 參數 {to, isGroup, text, type?} 發送消息
//   ui.toast              -> 參數 {message} 彈出提示
//   ui.open               -> 參數 {url} 外部打開鏈接
//
// 協議（H5 -> 宿主）：{ method, id, params }
// 協議（宿主 -> H5）：{ __chatBridge:true, id, ok:true, result } 或
//                    { __chatBridge:true, id, ok:false, error }
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';

/// JS 通道名（與 H5 側 window.ChatBridge 保持一致）。
const String kChatBridgeChannel = 'ChatBridge';

/// 宿主 -> H5 回傳消息的標記字段。
const String kChatBridgeFlag = '__chatBridge';

/// 解析 H5 發來的原始字符串 / Map 為請求，返回 null 表示非法格式。
Map<String, dynamic>? parseBridgeRequest(dynamic payload) {
  dynamic raw = payload;
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  if (raw is! Map) return null;
  final method = raw['method'];
  final id = raw['id'];
  if (method is! String || id == null) return null;
  final params = raw['params'];
  return <String, dynamic>{
    'method': method,
    'id': id,
    'params': params is Map ? Map<String, dynamic>.from(params) : <String, dynamic>{},
  };
}

/// 構造回傳包。
String encodeBridgeResponse(String id, {required bool ok, dynamic result, String? error}) {
  final m = <String, dynamic>{
    kChatBridgeFlag: true,
    'id': id,
    'ok': ok,
  };
  if (ok) {
    m['result'] = result;
  } else {
    m['error'] = error ?? 'unknown error';
  }
  return jsonEncode(m);
}

/// 平臺無關的宿主處理邏輯：根據請求調用對應能力，返回 result（可為 Future）。
///
/// 同步能力直接返回結果；異步能力返回 Future，由調用方 await 後再回傳。
Future<dynamic> handleBridgeCall(WidgetRef ref, Map<String, dynamic> req) async {
  final method = req['method'] as String;
  final params = (req['params'] as Map).cast<String, dynamic>();

  switch (method) {
    case 'auth.token':
      return ref.read(authProvider).token ?? '';

    case 'auth.user':
      final u = ref.read(authProvider).user;
      if (u == null) return null;
      return <String, dynamic>{
        'id': u.id,
        'nickName': u.nickName,
        'userName': u.userName,
        'avatar': u.avatarUrl,
      };

    case 'chat.send':
      final to = params['to']?.toString();
      final text = params['text']?.toString() ?? '';
      final isGroup = params['isGroup'] == true;
      final type = params['type']?.toString() ?? 'Text';
      if (to == null || to.isEmpty) {
        throw Exception('chat.send 缺少 to 參數');
      }
      if (text.isEmpty) return <String, dynamic>{'messageId': null};
      final hub = ref.read(hubProvider);
      if (isGroup) {
        await hub.sendGroupMessage(to, text, type, null);
      } else {
        await hub.sendPrivateMessage(to, text, type, null);
      }
      return <String, dynamic>{'sent': true};

    case 'ui.toast':
      final message = params['message']?.toString() ?? '';
      if (message.isNotEmpty) {
        _bridgeToast?.call(message);
      }
      return <String, dynamic>{'shown': true};

    case 'ui.open':
      final url = params['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return <String, dynamic>{'opened': true};

    default:
      throw Exception('不支持的 bridge method: $method');
  }
}

/// 移動端預註入腳本：在 WebView 加載前定義 `window.ChatBridge` 對象。
///
/// H5 調用示例：
///   const r = await ChatBridge.call('auth.user');
///   await ChatBridge.call('chat.send', { to: 'xxx', text: 'hi' });
String chatBridgeBootstrap() => '''
(function(){
  if (window.ChatBridge) return;
  window.ChatBridge = {
    call: function(method, params) {
      return new Promise(function(resolve, reject) {
        var id = 'cb_' + Date.now() + '_' + Math.random().toString(36).slice(2);
        var pending = window.__chatBridgePending || (window.__chatBridgePending = {});
        pending[id] = { resolve: resolve, reject: reject };
        var msg = JSON.stringify({ method: method, id: id, params: params || {} });
        // 移動端：通過 WebView javascriptChannel 發送。
        if (typeof $kChatBridgeChannel !== 'undefined') {
          $kChatBridgeChannel.postMessage(msg);
        } else {
          reject(new Error('ChatBridge 未就緒'));
        }
      });
    }
  };
  // 接收宿主回傳。
  window.__chatBridgeOnResponse = function(str) {
    try {
      var data = JSON.parse(str);
      if (!data || data['$kChatBridgeFlag'] !== true) return;
      var p = window.__chatBridgePending && window.__chatBridgePending[data.id];
      if (!p) return;
      delete window.__chatBridgePending[data.id];
      if (data.ok) p.resolve(data.result);
      else p.reject(new Error(data.error || 'bridge error'));
    } catch (e) {}
  };
})();
''';

/// 移動端：把宿主回傳發給 H5（在 javascriptChannel 回調中調用）。
String mobileBridgeResponseScript(String id, {required bool ok, dynamic result, String? error}) {
  final resp = encodeBridgeResponse(id, ok: ok, result: result, error: error);
  return 'window.__chatBridgeOnResponse && window.__chatBridgeOnResponse(${jsonEncode(resp)});';
}

// ---------------------------------------------------------------------------
// Web 端橋：dart:html 監聽 H5 的 postMessage，處理後回傳。
// ---------------------------------------------------------------------------

/// Web 端 H5 側監聽宿主回傳的腳本片段（註入到 markup 頂部）。
String get webBridgeClientScript => '''
<script>
(function(){
  if (window.ChatBridge) return;
  window.ChatBridge = {
    call: function(method, params) {
      return new Promise(function(resolve, reject) {
        var id = 'cb_' + Date.now() + '_' + Math.random().toString(36).slice(2);
        var pending = window.__chatBridgePending || (window.__chatBridgePending = {});
        pending[id] = { resolve: resolve, reject: reject };
        var msg = JSON.stringify({ method: method, id: id, params: params || {} });
        // Web 端：發給宿主（Flutter Dart）。
        window.parent.postMessage({ $kChatBridgeFlag: true, payload: msg }, '*');
      });
    }
  };
})();
</script>
''';

/// Web 端宿主側：註冊 message 監聽並處理 bridge 請求。
///
/// 需要在應用啟動時調用一次（僅 Web 生效）。[onHandled] 用於測試或調試。
void installWebBridge(WidgetRef ref, {void Function(String id, dynamic result, Object? err)? onHandled}) {
  if (!kIsWeb) return;
  // 延遲到 window 可用。
  Future.microtask(() {
    // ignore: avoid_web_libraries_in_flutter
    final window = _htmlWindow;
    if (window == null) return;
    window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map || data[kChatBridgeFlag] != true) return;
      final payload = data['payload'];
      final req = parseBridgeRequest(payload);
      if (req == null) return;
      final id = req['id'] as String;
      handleBridgeCall(ref, req).then((result) {
        _postToWindow(encodeBridgeResponse(id, ok: true, result: result));
        onHandled?.call(id, result, null);
      }).catchError((Object e) {
        _postToWindow(encodeBridgeResponse(id, ok: false, error: e.toString()));
        onHandled?.call(id, null, e);
      });
    });
  });
}

// dart:html 訪問點（Web 端實現，非 Web 端為 null）。
// 放在分離文件避免非 Web 端編譯引入 dart:html。
final dynamic _htmlWindow = _resolveHtmlWindow();

dynamic _resolveHtmlWindow() {
  // 非 Web 平臺下 dart:html 不存在，返回 null。
  return _htmlWindowResolver?.call();
}

/// 由 web 條件導入文件賦值（web_html_web.dart），非 Web 為 null。
dynamic Function()? _htmlWindowResolver;

void _postToWindow(String message) {
  final w = _htmlWindow;
  if (w == null) return;
  w.postMessage(message, '*');
}

/// 供 web_html_web.dart 註冊 dart:html window 解析器。
void registerHtmlWindowResolver(dynamic Function() resolver) {
  _htmlWindowResolver = resolver;
}

// ---------------------------------------------------------------------------
// UI 鉤子：宿主側的 toast 由調用方注入（避免循環導入 main.dart）。
// ---------------------------------------------------------------------------

void Function(String)? _bridgeToast;

/// 由應用入口（main.dart）注入全局 toast 實現。
void setBridgeToastHandler(void Function(String) fn) {
  _bridgeToast = fn;
}
