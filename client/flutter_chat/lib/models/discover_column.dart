import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 發現頁欄目類型（打開方式）。
/// link  - 外部鏈接，在 WebView 打開（content 為地址）
/// route - App 內部路由，直接 push（content 為路由）
/// action- 內置動作（content 為動作名：scan/addFriend/createGroup/friendRequests）
/// mini  - 小應用 / H5 本地包，打開 /mini?name=xxx（content 為包名）
///
/// 注意：底部固定 Tab 不再由獨立的 `tab` 類型表示，而是由
/// [DiscoverColumn.pinned] 決定——`pinned` 為 true 即為底部 Tab。
/// 其 content 若為內置標識（chat/contacts/discover/me）則對應內置頁，
/// 否則按上述類型打開。
enum DiscoverKind { link, route, action, mini }

/// 內置 Tab 標識（對應底部導航的內置頁）。
/// 固定欄目（pinned=true）的 content 若為其中之一，則在底部導航中
/// 對應到內置頁面，而非獨立路由分支。
const Set<String> builtinTabIds = {'chat', 'contacts', 'discover', 'me'};

/// 是否為內置 Tab 標識（固定欄目的 content 若是這些值即對應內置頁）。
bool isBuiltinTab(String? content) =>
    content != null && builtinTabIds.contains(content);

/// 多語言譯文的最終回退語言鍵（繁體中文），與 [L10n] 的預設語言一致。
const String kDefaultI18nKey = 'zh-TW';

/// 內置欄目標識 -> 內置譯文 key（簡體中文作 key，與 L10n 約定一致）。
/// 後台未配置多語言譯文時，內置欄目靠它隨界面語言自動切換。
const Map<String, String> kBuiltinTitleKeys = {
  'chat': '信息',
  'contacts': '通讯录',
  'discover': '发现',
  'me': '我',
};

/// 語言 -> 多語言鍵（BCP47 風格，如 zh-TW / zh-CN / en / es）。
String i18nKeyOf(Locale l) =>
    (l.countryCode == null || l.countryCode!.isEmpty)
        ? l.languageCode
        : '${l.languageCode}-${l.countryCode}';

/// 解析後台下發的多語言譯文。
///
/// 兼容兩種形態：JSON 字符串（後端 string 字段的常規產物）與已解碼的 Map。
/// 髒數據或空值一律返回 null，由調用方回退到默認標題，避免界面出現空白或原文。
Map<String, String>? parseTitleI18n(dynamic raw) {
  Map<dynamic, dynamic>? src;
  if (raw is Map) {
    src = raw;
  } else if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) src = decoded;
    } catch (_) {
      return null;
    }
  }

  if (src == null) return null;
  final cleaned = <String, String>{};
  src.forEach((k, v) {
    final value = v?.toString().trim() ?? '';
    if (k != null && value.isNotEmpty) cleaned[k.toString()] = value;
  });
  return cleaned.isEmpty ? null : cleaned;
}

class DiscoverColumn {
  final String id;
  /// 默認 / 回退標題（後台填寫）。找不到當前語言譯文時使用。
  final String title;
  /// 多語言譯文，鍵為 BCP47 風格語言鍵（zh-TW / zh-CN / en / es）。
  /// null 表示該欄目未配置譯文。
  final Map<String, String>? titleI18n;
  final String? icon;
  final DiscoverKind kind;
  final String? content;
  final int sort;
  final bool pinned;

  DiscoverColumn({
    required this.id,
    required this.title,
    this.titleI18n,
    this.icon,
    this.kind = DiscoverKind.link,
    this.content,
    required this.sort,
    this.pinned = false,
  });

  /// 取指定語言的譯文；無譯文（或未配置多語言）時返回 null，交由 UI 回退。
  ///
  /// 回退順序：精確語言鍵（zh-TW）→ 僅語言碼（zh）→ 默認語言鍵（zh-TW）。
  String? titleFor(Locale locale) {
    final m = titleI18n;
    if (m == null || m.isEmpty) return null;

    final exact = m[i18nKeyOf(locale)];
    if (exact != null && exact.isNotEmpty) return exact;

    // 系統語言可能只帶語言碼（如 zh），再做一次寬鬆匹配。
    final loose = m[locale.languageCode];
    if (loose != null && loose.isNotEmpty) return loose;

    final fallback = m[kDefaultI18nKey];
    if (fallback != null && fallback.isNotEmpty) return fallback;

    return null;
  }

  factory DiscoverColumn.fromJson(Map<String, dynamic> j) {
    final kindStr = j['kind'] ?? 'link';
    final kind = DiscoverKind.values.firstWhere(
      (e) => e.name == kindStr,
      orElse: () => DiscoverKind.link,
    );
    return DiscoverColumn(
      id: j['id'],
      title: j['title'],
      titleI18n: parseTitleI18n(j['titleI18n']),
      icon: j['icon'],
      kind: kind,
      content: j['content'],
      sort: j['sort'] ?? 0,
      pinned: j['pinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        // 底部導航緩存需原樣保留譯文，否則從緩存恢復後多語言失效。
        'titleI18n': titleI18n,
        'icon': icon,
        'kind': kind.name,
        'content': content,
        'sort': sort,
        'pinned': pinned,
      };
}

/// 欄目在當前界面語言下的顯示標題。
///
/// 完整回退鏈：後台多語言譯文 → 內置欄目譯文（信息/通訊錄/發現/我）
/// → 默認標題 [DiscoverColumn.title]。任何一層缺失都不會出現空白。
String resolvedColumnTitle(BuildContext context, DiscoverColumn c) {
  final translated = c.titleFor(Localizations.localeOf(context));
  if (translated != null) return translated;

  final builtinKey = kBuiltinTitleKeys[c.content];
  if (builtinKey != null) return context.tr(builtinKey);

  return c.title;
}
