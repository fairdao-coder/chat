import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_result.dart';
import '../models/contact_dto.dart';
import '../models/file_upload_result.dart';
import '../models/friend_request_dto.dart';
import '../models/group_dto.dart';
import '../models/message_dto.dart';
import '../models/user_dto.dart';

/// Thrown for any non-2xx HTTP response. [statusCode] is null for network errors.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const String _tokenKey = 'auth_token';
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // ---------- internals ----------

  Future<dynamic> _req(Future<Response<dynamic>> Function() call) async {
    try {
      final r = await call();
      return r.data;
    } on DioException catch (e) {
      if (e.response != null) {
        final msg = _extractMessage(e.response!.data) ?? e.message ?? '請求失敗';
        throw ApiException(e.response!.statusCode, msg);
      }
      throw ApiException(null, e.message ?? '網絡錯誤');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      return (data['title'] as String?) ??
          (data['detail'] as String?) ??
          (data['message'] as String?);
    }
    return null;
  }

  // ---------- Auth ----------

  Future<AuthResult> login(String userName, String password) async {
    final data = await _req(() => _dio.post('/api/auth/login',
        data: {'userName': userName, 'password': password}));
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> register(
      String userName, String password, String nickName) async {
    final data = await _req(() => _dio.post('/api/auth/register',
        data: {'userName': userName, 'password': password, 'nickName': nickName}));
    return AuthResult.fromJson(data);
  }

  // ---------- Conversations / Contacts ----------

  Future<List<ContactDto>> getConversations() async {
    final data = await _req(() => _dio.get('/api/conversations'));
    return (data as List).map((e) => ContactDto.fromJson(e)).toList();
  }

  // ---------- Users ----------

  Future<List<UserDto>> searchUsers(String q) async {
    final data =
        await _req(() => _dio.get('/api/users/search', queryParameters: {'q': q}));
    return (data as List).map((e) => UserDto.fromJson(e)).toList();
  }

  Future<UserDto> me() async {
    final data = await _req(() => _dio.get('/api/users/me'));
    return UserDto.fromJson(data);
  }

  /// 在線好友 ID 集合。用於給 SignalR 的上下線推送做兜底校正。
  Future<Set<String>> getOnlineFriends() async {
    final data = await _req(() => _dio.get('/api/users/online'));
    return (data as List).map((e) => e.toString()).toSet();
  }

  // ---------- Friends ----------

  /// POST /api/friends/request  body = raw JSON string "<friendId>"
  Future<void> sendFriendRequest(String friendId) async {
    await _req(() => _dio.post('/api/friends/request',
        data: '"$friendId"', options: Options(contentType: 'application/json')));
  }

  Future<List<FriendRequestDto>> getFriendRequests() async {
    final data = await _req(() => _dio.get('/api/friends/requests'));
    return (data as List).map((e) => FriendRequestDto.fromJson(e)).toList();
  }

  /// POST /api/friends/accept  body = raw JSON string "<requesterId>"
  Future<void> acceptFriendRequest(String requesterId) async {
    await _req(() => _dio.post('/api/friends/accept',
        data: '"$requesterId"',
        options: Options(contentType: 'application/json')));
  }

  /// 接受好友后向对方发送一条系统欢迎语（REST 兜底，即使 SignalR 未连也尽量送达）。
  /// 对应服务端 POST /api/messages/private  body = {to, content}。
  Future<void> sendPrivateText(String to, String content) async {
    await _req(() => _dio.post('/api/messages/private', data: {
          'to': to,
          'content': content,
        }));
  }

  Future<List<UserDto>> getFriends() async {
    final data = await _req(() => _dio.get('/api/friends'));
    return (data as List).map((e) => UserDto.fromJson(e)).toList();
  }

  Future<void> removeFriend(String friendId) async {
    await _req(() => _dio.delete('/api/friends/$friendId'));
  }

  // ---------- Groups ----------

  Future<GroupDto> createGroup(String name, List<String> memberIds) async {
    final data = await _req(() =>
        _dio.post('/api/groups', data: {'name': name, 'memberIds': memberIds}));
    return GroupDto.fromJson(data);
  }

  Future<List<GroupDto>> getGroups() async {
    final data = await _req(() => _dio.get('/api/groups'));
    return (data as List).map((e) => GroupDto.fromJson(e)).toList();
  }

  Future<GroupDto> getGroup(String id) async {
    final data = await _req(() => _dio.get('/api/groups/$id'));
    return GroupDto.fromJson(data);
  }

  // ---------- Messages ----------

  Future<List<MessageDto>> getPrivateHistory(String friendId,
      {DateTime? before, int count = 30}) async {
    final qp = <String, dynamic>{'count': count};
    if (before != null) qp['before'] = before.toIso8601String();
    final data = await _req(
        () => _dio.get('/api/messages/private/$friendId', queryParameters: qp));
    return (data as List).map((e) => MessageDto.fromJson(e)).toList();
  }

  Future<List<MessageDto>> getGroupHistory(String groupId,
      {DateTime? before, int count = 30}) async {
    final qp = <String, dynamic>{'count': count};
    if (before != null) qp['before'] = before.toIso8601String();
    final data = await _req(
        () => _dio.get('/api/messages/group/$groupId', queryParameters: qp));
    return (data as List).map((e) => MessageDto.fromJson(e)).toList();
  }

  // ---------- Files ----------

  static String _fileNameFromPath(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  /// POST /api/files/upload  multipart/form-data, field name "file".
  /// Either [filePath] or [bytes] must be provided.
  Future<FileUploadResult> uploadFile({
    String? filePath,
    Uint8List? bytes,
    String? filename,
    String? contentType,
  }) async {
    assert(filePath != null || bytes != null,
        'uploadFile requires filePath or bytes');
    final name = filename ??
        (bytes != null && filename != null
            ? filename
            : (filePath != null ? _fileNameFromPath(filePath) : 'file'));
    late final MultipartFile file;
    if (bytes != null) {
      file = MultipartFile.fromBytes(bytes,
          filename: name,
          contentType: contentType == null ? null : DioMediaType.parse(contentType));
    } else {
      file = await MultipartFile.fromFile(filePath!,
          filename: name,
          contentType: contentType == null ? null : DioMediaType.parse(contentType));
    }
    final form = FormData.fromMap({'file': file});
    final data = await _req(() => _dio.post('/api/files/upload', data: form));
    return FileUploadResult.fromJson(data);
  }

  /// 下载图片/文件字节（自动带 Bearer token，适用于需鉴权的私有资源）。
  /// [url] 必须是完整绝对地址。
  Future<Uint8List> downloadBytes(String url) async {
    final r = await _dio.get<dynamic>(url,
        options: Options(responseType: ResponseType.bytes));
    if (r.data is Uint8List) return r.data as Uint8List;
    return Uint8List.fromList(r.data as List<int>);
  }
}
