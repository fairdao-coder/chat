class Constants {
  // 後臺管理 API 基地址，需與 server/AdminServer 的 Urls（默認 http://localhost:5299）一致。
  //
  // 可用構建期參數覆蓋，CI 靠它把已發布的站點指向真實服務器：
  //   flutter build web --dart-define=ADMIN_API_BASE=https://api.example.com
  // 否則部署出去的頁面仍會去連 http://localhost:5299。
  static const String apiBaseUrl = String.fromEnvironment(
    'ADMIN_API_BASE',
    defaultValue: 'http://localhost:5299',
  );

  static const String tokenKey = 'admin_jwt';
}
