// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web 不使用本地文件路徑（錄音包內部生成 blob URL），僅作為佔位以保證跨平臺
/// 符號可用；實際路徑取自 record 包 stop() 的返回值，且 web 分支永遠不會調用它。
String nativeTempVoicePath() =>
    'voice_${DateTime.now().microsecondsSinceEpoch}.webm';

/// Web：錄音包調用 stop() 返回的是 blob: URL，直接 fetch 拉取後讀為字節，
/// 避免引入 dart:io（web 不支持）。
Future<Uint8List> readRecordingBytes(String path) async {
  final response = await html.window.fetch(path);
  final blob = await response.blob();
  final reader = html.FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is Uint8List) return result;
  throw StateError('無法讀取錄音字節');
}
