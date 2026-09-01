/// 平臺能力檢測。
///
/// 通過條件導入隔離，避免 web 編譯期引入 dart:io
/// （web 上調用 Platform.isXxx 會拋出 Unsupported operation）。
library platform_check;

export 'platform_check_io.dart' if (dart.library.html) 'platform_check_web.dart';
