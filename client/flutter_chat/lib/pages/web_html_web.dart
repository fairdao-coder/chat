// Web 端實現：用 dart:html 把內聯 HTML 註冊為 platform view。
// 此文件僅在 Web 平臺編譯（通過條件導入），dart:html 的棄用與 web 庫提示在此需要忽略。
// ignore_for_file: deprecated_member_use
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// 元素允許的通用屬性（不含任何事件處理器，如 onclick/onload）。
const List<String> _commonAttrs = <String>[
  'id', 'class', 'style', 'name', 'title', 'hidden',
];

/// 事件處理器屬性，僅在允許腳本（`script:` 前綴）時放行。
const List<String> _eventAttrs = <String>[
  'onclick', 'ondblclick', 'onchange', 'oninput', 'onsubmit', 'onreset',
  'onfocus', 'onblur', 'onmouseover', 'onmouseout', 'onkeydown', 'onkeyup',
  'onkeypress', 'onselect', 'onload',
];

/// 構建內聯 HTML 的節點校驗器。
///
/// 策略：允許靜態內容與原生表單（form 提交不需要 JavaScript），
/// 但**不允許** script / iframe / 事件處理器，避免內聯內容成為 XSS 入口。
/// [allowEvents] 為 true 時額外放行事件處理器（配合 `script:` 前綴使用）。
html.NodeValidator _buildValidator({bool allowEvents = false}) {
  final v = html.NodeValidatorBuilder.common()..allowInlineStyles();
  final ev = allowEvents ? _eventAttrs : const <String>[];
  final attrs = <String>[..._commonAttrs, ...ev];

  // ---- 表單元素（原生 form 提交，無需腳本）----
  v.allowElement('form', attributes: <String>[
    ...attrs, 'action', 'method', 'target', 'enctype', 'autocomplete',
    'accept-charset', 'novalidate',
  ]);
  v.allowElement('input', attributes: <String>[
    ...attrs, 'type', 'value', 'placeholder', 'required', 'disabled',
    'readonly', 'checked', 'min', 'max', 'minlength', 'maxlength', 'step',
    'pattern', 'multiple', 'accept', 'size', 'autocomplete', 'autofocus',
  ]);
  v.allowElement('button', attributes: <String>[
    ...attrs, 'type', 'value', 'disabled', 'form', 'formaction',
    'formmethod', 'formtarget', 'autofocus',
  ]);
  v.allowElement('textarea', attributes: <String>[
    ...attrs, 'rows', 'cols', 'placeholder', 'required', 'disabled',
    'readonly', 'maxlength', 'minlength', 'autofocus', 'wrap',
  ]);
  v.allowElement('select', attributes: <String>[
    ...attrs, 'multiple', 'size', 'required', 'disabled', 'autofocus',
  ]);
  v.allowElement('option', attributes: <String>[
    ..._commonAttrs, 'value', 'selected', 'disabled', 'label',
  ]);
  v.allowElement('optgroup', attributes: <String>[
    ..._commonAttrs, 'label', 'disabled',
  ]);
  v.allowElement('label', attributes: <String>[
    ..._commonAttrs, 'for', 'form',
  ]);
  v.allowElement('fieldset', attributes: <String>[
    ..._commonAttrs, 'disabled', 'form', 'name',
  ]);
  v.allowElement('legend', attributes: _commonAttrs);
  v.allowElement('datalist', attributes: _commonAttrs);
  v.allowElement('output', attributes: <String>[..._commonAttrs, 'for', 'form']);
  v.allowElement('progress', attributes: <String>[..._commonAttrs, 'value', 'max']);
  v.allowElement('meter', attributes: <String>[
    ..._commonAttrs, 'value', 'min', 'max', 'low', 'high', 'optimum',
  ]);

  return v;
}

/// 將 [markup] 註冊為 viewId 對應的 platform view（僅 Web 有效）。
///
/// [allowScript] 為 true 時會執行內聯 `<script>`（需 `script:` 前綴顯式開啟）；
/// 為 false（默認）時腳本會被剔除，只渲染靜態內容。
void registerInlineHtml(String viewId, String markup,
    {bool allowScript = false}) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    final div = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'auto'
      ..style.padding = '12px'
      ..style.boxSizing = 'border-box'
      ..setInnerHtml(markup, validator: _buildValidator(allowEvents: allowScript));

    if (allowScript) {
      // setInnerHtml 插入的 <script> 按 HTML 規範不會執行，
      // 因此需手動建立 ScriptElement 並 append，腳本才會被執行。
      final scriptRe =
          RegExp(r'<script\b([^>]*)>(.*?)</script>', dotAll: true, caseSensitive: false);
      for (final m in scriptRe.allMatches(markup)) {
        final attrs = m.group(1) ?? '';
        final body = m.group(2) ?? '';
        final s = html.ScriptElement();
        final srcMatch = RegExp(r'''src\s*=\s*["']([^"']+)["']''').firstMatch(attrs);
        if (srcMatch != null) {
          s.src = srcMatch.group(1)!;
        } else {
          s.text = body;
        }
        div.append(s);
      }
    }

    // 表單提交若在同一 document 內跳轉，會把整個 Flutter 應用導航走。
    // 強制新開標籤，保證 App 不被替換。
    for (final form in div.querySelectorAll('form')) {
      form.setAttribute('target', '_blank');
    }

    return div;
  });
}

/// 返回渲染內聯 HTML 的 widget（僅 Web）。
Widget inlineHtmlView(String viewId) => HtmlElementView(viewType: viewId);
