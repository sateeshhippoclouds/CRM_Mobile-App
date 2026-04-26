import 'dart:convert';

class TokenResponseModel {
  final String token;
  final String name;
  final String email;
  final String role;
  final dynamic companyId;
  final bool activityStatus;
  final bool platformOwner;
  final String userType;
  final int iat;
  final int exp;

  TokenResponseModel({
    required this.token,
    required this.name,
    required this.email,
    required this.role,
    required this.companyId,
    required this.activityStatus,
    required this.platformOwner,
    required this.userType,
    required this.iat,
    required this.exp,
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > exp;

  factory TokenResponseModel.fromJson(Map<String, dynamic> json) {
    final payload =
        json['payload'] as Map<String, dynamic>? ?? json;
    final token = json['token'] as String? ?? '';
    return TokenResponseModel(
      token: token,
      name: payload['name'] as String? ?? '',
      email: payload['email'] as String? ?? '',
      role: payload['role'] as String? ?? '',
      companyId: payload['companyid'],
      activityStatus: payload['activitystatus'] as bool? ?? false,
      platformOwner: payload['platform_owner'] as bool? ?? false,
      userType: payload['user_type'] as String? ?? '',
      iat: payload['iat'] as int? ?? 0,
      exp: payload['exp'] as int? ?? 0,
    );
  }

  String encode() => jsonEncode({
        'token': token,
        'name': name,
        'email': email,
        'role': role,
        'companyid': companyId,
        'activitystatus': activityStatus,
        'platform_owner': platformOwner,
        'user_type': userType,
        'iat': iat,
        'exp': exp,
      });

  static TokenResponseModel? decode(String? encoded) {
    if (encoded == null) return null;
    try {
      return TokenResponseModel.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
