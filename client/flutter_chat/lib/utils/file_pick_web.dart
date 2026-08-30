import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

/// Web implementation of file picking using a directly controlled
/// <input type="file"> element. The element is kept in the DOM until the
/// `change` event has fired so that `input.files` stays valid.
///
/// We deliberately position the element off-screen instead of using
/// `display: none`: several browsers / webviews / sandboxed iframes refuse to
/// open the native file dialog for a `display:none` input, which would make
/// `input.click()` a silent no-op ("nothing happens" when tapping the button).
Future<({Uint8List bytes, String name})?> pickImageFile() => _pick('image/*');

Future<({Uint8List bytes, String name})?> pickAnyFile() => _pick('');

Future<({Uint8List bytes, String name})?> _pick(String accept) async {
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.position = 'fixed'
    ..style.top = '-10000px'
    ..style.left = '-10000px'
    ..style.width = '1px'
    ..style.height = '1px'
    ..style.opacity = '0.01';

  final host = document.body ?? document.documentElement;
  if (host == null) {
    throw StateError('document.body 不可用，無法選擇文件');
  }
  host.append(input);

  final completer = Completer<({Uint8List bytes, String name})?>();
  late final StreamSubscription<Event> sub;
  bool dialogShown = false;

  void cleanup() {
    if (!sub.isPaused) sub.cancel();
    // `Element.remove()` is a no-op when the node has no parent, so no
    // `parentNode != null` guard is needed (and `parent` doesn't even exist
    // on `HTMLInputElement` in `package:web`).
    input.remove();
  }

  sub = input.onChange.listen((_) {
    dialogShown = true; // 用戶至少觸發了一次真實的 change 事件（點選了文件）。
    final files = input.files;
    if (files == null || files.length == 0) {
      cleanup();
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = FileReader();
    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      try {
        final buf = reader.result as JSArrayBuffer?;
        final bytes = buf?.toDart.asUint8List();
        cleanup();
        if (bytes == null || bytes.isEmpty) {
          completer.completeError('文件內容為空');
        } else {
          completer.complete((bytes: bytes, name: file.name));
        }
      } catch (e) {
        cleanup();
        completer.completeError('讀取文件出錯: $e');
      }
    });
    reader.readAsArrayBuffer(file);
  });

  // Safety net: 在彈窗未自動彈出 (例如：iframe 焦點丟失 / 瀏覽器策略阻止)
  // 而用戶也未點選任何文件時，input.click() 之後的 change 事件永遠不會到達，
  // 直到用戶在 60 秒超時過去。原實現"靜默 complete(null)"會讓上層吞掉異常，
  // 用戶體驗就是"點了圖片按鈕，聊天窗口什麼都沒有" + "控制台沒錯誤" —
  // 與本工單報告的 bug 完全一致。改為拋錯讓調用方在 UI 上給出反饋。
  Future.delayed(const Duration(seconds: 60)).then((_) {
    if (completer.isCompleted) return;
    cleanup();
    if (dialogShown) {
      // dialog 已經彈出過，但用戶最終取消了選擇 — 這是正常路徑。
      completer.complete(null);
    } else {
      // dialog 從未彈出：把 60s 的等待視作"無法彈出"，讓上層給出明確提示。
      completer.completeError(
          '未能彈出文件選擇窗口（可能是瀏覽器被嵌入/受限制、或本窗口未獲得焦點），請把此頁面切到前臺後再試。');
    }
  });

  input.click();
  try {
    return await completer.future;
  } catch (e, st) {
    debugPrint('file_pick_web._pick error: $e\n$st');
    rethrow;
  }
}
