import 'package:flutter/material.dart';

/// 欄目類型的展示元數據。
///
/// 集中於此，讓列表項、編輯對話框與後續可能的預覽共用同一份定義，
/// 避免新增類型時漏改一處導致 UI 顯示原始 key。
///
/// 註：底部固定 Tab 不再由獨立的 `tab` 類型表示，而是由欄目的
/// `pinned`（固定到底部導航）決定。此處的類型只描述「打開方式」。
const Map<String, String> kColumnKinds = {
  'link': '外部鏈接（WebView）',
  'route': '內部路由',
  'action': '內置動作',
  'mini': '小應用 / H5 本地包',
};

/// 內置動作選項。
const Map<String, String> kColumnActions = {
  'scan': '掃一掃',
  'addFriend': '添加好友',
  'createGroup': '創建群聊',
  'friendRequests': '好友請求',
};

/// 固定到底部導航時的「內置目標」選項。
/// 選中後其標識會寫入 content，客戶端會據此對應到內置頁。
const Map<String, String> kTabTargets = {
  'chat': '信息（會話列表）',
  'contacts': '通訊錄',
  'discover': '發現',
  'me': '我',
};

String columnKindLabel(String k) => kColumnKinds[k] ?? k;

IconData columnKindIcon(String k) {
  switch (k) {
    case 'route':
      return Icons.open_in_new;
    case 'action':
      return Icons.flash_on_outlined;
    case 'mini':
      return Icons.apps_outlined;
    default:
      return Icons.link;
  }
}

/// 不同類型下 Content 欄位的輸入提示（action 用下拉選擇，故返回 null）。
String? columnContentHint(String kind) {
  switch (kind) {
    case 'route':
      return '/add-friend';
    case 'mini':
      return '可直接粘贴 HTML 代码：html: 開頭=內聯 HTML（禁腳本）；'
          'script: 開頭=內聯 HTML 且允許 JS 調用宿主（window.ChatBridge.call）。'
          '也可填包名（如 vote）或 https:// 遠程 H5。';
    default:
      return 'https://example.com';
  }
}

String columnContentLabel(String kind) {
  switch (kind) {
    case 'route':
      return '內部路由';
    case 'action':
      return '內置動作';
    case 'mini':
      return '小應用 / 包名';
    default:
      return '鏈接地址';
  }
}
