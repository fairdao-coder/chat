import 'user_dto.dart';

class AuthResult {
  final String token;
  final UserDto user;

  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        user: UserDto.fromJson(j['user'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
      };
}
