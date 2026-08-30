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
    throw StateError('document.body 不可用，无法选择文件');
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
    dialogShown = true; // 用户至少触发了一次真实的 change 事件（点选了文件）。
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
          completer.completeError('文件内容为空');
        } else {
          completer.complete((bytes: bytes, name: file.name));
        }
      } catch (e) {
        cleanup();
        completer.completeError('读取文件出错: $e');
      }
    });
    reader.readAsArrayBuffer(file);
  });

  // Safety net: 在弹窗未自动弹出 (例如：iframe 焦点丢失 / 浏览器策略阻止)
  // 而用户也未点选任何文件时，input.click() 之后的 change 事件永远不会到达，
  // 直到用户在 60 秒超时过去。原实现"静默 complete(null)"会让上层吞掉异常，
  // 用户体验就是"点了图片按钮，聊天窗口什么都没有" + "控制台没错误" —
  // 与本工单报告的 bug 完全一致。改为抛错让调用方在 UI 上给出反馈。
  Future.delayed(const Duration(seconds: 60)).then((_) {
    if (completer.isCompleted) return;
    cleanup();
    if (dialogShown) {
      // dialog 已经弹出过，但用户最终取消了选择 — 这是正常路径。
      completer.complete(null);
    } else {
      // dialog 从未弹出：把 60s 的等待视作"无法弹出"，让上层给出明确提示。
      completer.completeError(
          '未能弹出文件选择窗口（可能是浏览器被嵌入/受限制、或本窗口未获得焦点），请把此页面切到前台后再试。');
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
