// 條件導入封裝：Web 端用 dart:html 注入內聯 HTML，非 Web 端提供空實現。
export 'web_html_stub.dart'
    if (dart.library.html) 'web_html_web.dart';
