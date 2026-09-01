import 'dart:io';

/// 是否為移動端（Android / iOS）——僅這些平臺支持相機掃碼。
bool get kIsMobilePlatform => Platform.isAndroid || Platform.isIOS;
