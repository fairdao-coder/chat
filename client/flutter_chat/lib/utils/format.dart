import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// 會話列表時間：今天顯示 HH:mm，今年顯示 MM/dd，更早顯示 yyyy/MM/dd。
String formatConvTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return DateFormat('HH:mm').format(t);
  }
  if (t.year == now.year) return DateFormat('MM/dd').format(t);
  return DateFormat('yyyy/MM/dd').format(t);
}

/// 聊天內氣泡時間：HH:mm
String formatMsgTime(DateTime t) => DateFormat('HH:mm').format(t);

/// 日期分隔標籤：今天 / 昨天 / yyyy/MM/dd（按當前語言返回）
String formatDayLabel(DateTime t, [AppLocalizations? loc]) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return loc?.t('今天') ?? '今天';
  }
  final y = now.subtract(const Duration(days: 1));
  if (t.year == y.year && t.month == y.month && t.day == y.day) {
    return loc?.t('昨天') ?? '昨天';
  }
  return DateFormat('yyyy/MM/dd').format(t);
}
