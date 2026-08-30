/// 讀取錄音文件字節。
///
/// 不同平臺實現不同（native 用 dart:io 讀文件，web 用 fetch 拉 blob URL），
/// 通過條件導入隔離，避免 web 編譯期引入 dart:io。
library record_bytes;

export 'record_bytes_io.dart' if (dart.library.html) 'record_bytes_web.dart';
