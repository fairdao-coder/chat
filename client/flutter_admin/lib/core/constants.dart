class Constants {
  // 后台管理 API 基地址，需与 server/AdminServer 的 Urls（默认 http://localhost:5299）一致。
  // 部署到服务器或真机调试时改这里（或读环境变量）。
  static const String apiBaseUrl = 'http://localhost:5299';

  static const String tokenKey = 'admin_jwt';
}
