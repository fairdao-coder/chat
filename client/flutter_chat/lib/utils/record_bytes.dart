/// 读取录音文件字节。
///
/// 不同平台实现不同（native 用 dart:io 读文件，web 用 fetch 拉 blob URL），
/// 通过条件导入隔离，避免 web 编译期引入 dart:io。
library record_bytes;

export 'record_bytes_io.dart' if (dart.library.html) 'record_bytes_web.dart';
