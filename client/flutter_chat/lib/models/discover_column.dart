class DiscoverColumn {
  final String id;
  final String title;
  final String? icon;
  final String? link;
  final int sort;

  DiscoverColumn({
    required this.id,
    required this.title,
    this.icon,
    this.link,
    required this.sort,
  });

  factory DiscoverColumn.fromJson(Map<String, dynamic> j) => DiscoverColumn(
        id: j['id'],
        title: j['title'],
        icon: j['icon'],
        link: j['link'],
        sort: j['sort'] ?? 0,
      );
}
