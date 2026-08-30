import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// 後臺管理 API 客戶端：自動攜帶 JWT，統一處理錯誤。401 由調用方決定跳轉登錄。
class ApiClient {
  final http.Client _client = http.Client();
  String? _token;

  Future<void> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(Constants.tokenKey);
  }

  void setToken(String? t) => _token = t;
  String? get token => _token;

  Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json; charset=utf-8'};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<dynamic> get(String path) => _req(() => _client.get(_uri(path), headers: _headers));
  Future<dynamic> post(String path, [dynamic body]) =>
      _req(() => _client.post(_uri(path), headers: _headers, body: _enc(body)));
  Future<dynamic> put(String path, [dynamic body]) =>
      _req(() => _client.put(_uri(path), headers: _headers, body: _enc(body)));
  Future<dynamic> delete(String path) => _req(() => _client.delete(_uri(path), headers: _headers));

  Uri _uri(String path) => Uri.parse('${Constants.apiBaseUrl}$path');
  String? _enc(dynamic body) => body == null ? null : jsonEncode(body);

  Future<dynamic> _req(Future<http.Response> Function() fn) async {
    final res = await fn();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String msg = res.body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      msg = decoded is Map ? (decoded['message'] ?? decoded['title'] ?? res.body) : res.body;
    } catch (_) {}
    if (res.statusCode == 401) throw ApiException(401, '登錄已過期，請重新登錄');
    if (res.statusCode == 403) throw ApiException(403, '權限不足，請聯繫超級管理員');
    throw ApiException(res.statusCode, msg);
  }
}
