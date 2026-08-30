import 'dart:io';
import 'dart:typed_data';

/// Native：錄音被寫到本地臨時文件，直接讀字節即可。
Future<Uint8List> readRecordingBytes(String path) => File(path).readAsBytes();

/// Native：生成臨時目錄下的錄音文件路徑（擴展名按平臺默認編解碼器）。
String nativeTempVoicePath() =>
    '${Directory.systemTemp.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
