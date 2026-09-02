import 'package:flutter/material.dart';

/// 欄目類型的展示元數據。
///
/// 集中於此，讓列表項、編輯對話框與後續可能的預覽共用同一份定義，
/// 避免新增類型時漏改一處導致 UI 顯示原始 key。
const Map<String, String> kColumnKinds = {
  'tab': '底部固定 Tab',
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

/// 底部 Tab 跳轉目標選項。
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
    case 'tab':
      return Icons.push_pin_outlined;
    default:
      return Icons.link;
  }
}

/// 不同類型下 Content 欄位的輸入提示（action / tab 用下拉選擇，故返回 null）。
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
    case 'tab':
      return 'Tab 目標';
    case 'mini':
      return '小應用 / 包名';
    default:
      return '鏈接地址';
  }
}
