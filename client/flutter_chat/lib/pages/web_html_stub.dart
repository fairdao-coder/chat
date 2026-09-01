// 非 Web 端空實現（webview_flutter 在移動/桌面端直接渲染，無需 dart:html）。
import 'package:flutter/widgets.dart';

void registerInlineHtml(String viewId, String markup,
    {bool allowScript = false}) {
  // no-op on non-web platforms.
}

Widget inlineHtmlView(String viewId) => const SizedBox.shrink();
