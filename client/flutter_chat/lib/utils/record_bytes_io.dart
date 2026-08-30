import 'dart:io';
import 'dart:typed_data';

/// Native：录音被写到本地临时文件，直接读字节即可。
Future<Uint8List> readRecordingBytes(String path) => File(path).readAsBytes();

/// Native：生成临时目录下的录音文件路径（扩展名按平台默认编解码器）。
String nativeTempVoicePath() =>
    '${Directory.systemTemp.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
