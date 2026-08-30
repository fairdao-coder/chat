import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Native (Android/iOS/Windows/Linux/macOS) implementation of file picking,
/// delegating to the `file_picker` plugin with `withData: true` so the bytes
/// are immediately available for upload.
Future<({Uint8List bytes, String name})?> pickImageFile() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  return _toResult(res);
}

Future<({Uint8List bytes, String name})?> pickAnyFile() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: false,
    withData: true,
  );
  return _toResult(res);
}

/// 一些 host 平臺在 `withData: true` 下仍可能讀不出 bytes（比如 Windows 上文件被獨佔、
/// Android scoped storage 拒絕直接讀、iOS 上選了 iCloud 但本機未下載），
/// 此時 f.bytes 是 null，調用方看到 null 就會"靜默不響應"。
/// 退化路徑：嘗試用 readStream 把數據流式讀回來；再不行才返回 null。
Future<({Uint8List bytes, String name})?> _toResult(FilePickerResult? res) async {
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  Uint8List? bytes = f.bytes;
  if (bytes == null) {
    final stream = f.readStream;
    if (stream != null) {
      try {
        final chunks = <int>[];
        await for (final chunk in stream) {
          chunks.addAll(chunk);
        }
        bytes = Uint8List.fromList(chunks);
      } catch (e, st) {
        debugPrint('file_pick_native: readStream fallback failed: $e\n$st');
      }
    }
  }
  if (bytes == null || bytes.isEmpty) {
    debugPrint('file_pick_native: cannot read bytes for ${f.name}');
    return null;
  }
  return (bytes: bytes, name: f.name);
}
