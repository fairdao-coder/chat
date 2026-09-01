/// 發現頁欄目類型。
/// link  - 外部鏈接，在 WebView 打開（content 為地址）
/// route - App 內部路由，直接 push（content 為路由）
/// action- 內置動作（content 為動作名：scan/addFriend/createGroup/friendRequests）
/// mini  - 小應用 / H5 本地包，打開 /mini?name=xxx（content 為包名）
/// tab   - 固定到底部導航的 Tab（content 為目標：chat/contacts/discover/me）
enum DiscoverKind { link, route, action, mini, tab }

class DiscoverColumn {
  final String id;
  final String title;
  final String? icon;
  final DiscoverKind kind;
  final String? content;
  final int sort;
  final bool pinned;

  DiscoverColumn({
    required this.id,
    required this.title,
    this.icon,
    this.kind = DiscoverKind.link,
    this.content,
    required this.sort,
    this.pinned = false,
  });

  factory DiscoverColumn.fromJson(Map<String, dynamic> j) {
    final kindStr = j['kind'] ?? 'link';
    final kind = DiscoverKind.values.firstWhere(
      (e) => e.name == kindStr,
      orElse: () => DiscoverKind.link,
    );
    return DiscoverColumn(
      id: j['id'],
      title: j['title'],
      icon: j['icon'],
      kind: kind,
      content: j['content'],
      sort: j['sort'] ?? 0,
      pinned: j['pinned'] ?? false,
    );
  }
}
