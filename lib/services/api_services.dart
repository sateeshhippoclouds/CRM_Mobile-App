import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_model.dart';
import '../models/tenant_model.dart';
import '../models/token_response_model.dart';

class HippoAuthService {
  static const String _baseUrl = 'https://www.hippocx.com';
  static const String _tokenKey = 'hippo_auth_token';
  static const String _userKey = 'hippo_auth_user';
  static const _timeout = Duration(seconds: 15);

  static const String _ceoStaticToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoic2F0ZWVzaCIsImVtYWlsIjoic2F0ZWVzaEBoaXBwb2Nsb3Vkcy5jb20iLCJyb2xlIjoiQ0VPIiwiY29tcGFueWlkIjoiaGlwcG8iLCJhY3Rpdml0eXN0YXR1cyI6dHJ1ZSwicGxhdGZvcm1fb3duZXIiOnRydWUsInVzZXJfdHlwZSI6ImNlb190YWJsZSIsImlhdCI6MTc3NjY4MzI5MCwiZXhwIjoxODA4MjE5MjkwfQ.8vJSu9AGKg8uGurDINA2OdoMeAsBY6s8Ma1FLwu7BuM';

  static const String _companyStaticToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJuYW1lIjoiaGVtYW50aCIsImVtYWlsIjoic2FpcGFybGE0M0BnbWFpbC5jb20iLCJyb2xlIjoiY2VvIiwiY29tcGFueWlkIjoxLCJhY3Rpdml0eXN0YXR1cyI6dHJ1ZSwidXNlcl90eXBlIjoiY29tcGFueSIsImlhdCI6MTc3NjQxODc3NywiZXhwIjoxODA3OTU0Nzc3fQ.'
      'n3VOmrhMGQbsrjH_7xabhklrp7z_cUQ6WeZyLNvJ6qY';

  static const String _employeeStaticToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJuYW1lIjoiUHJpeWEgVmVybWEiLCJlbWFpbCI6InByaXlhLnZlcm1hQGNvbXBhbnkuY29tIiwicm9sZSI6IkFkbWluIiwiY29tcGFueWlkIjoxLCJpZCI6MiwiZW1wbG95ZWVpZCI6MiwiYWN0aXZpdHlzdGF0dXMiOnRydWUsInVzZXJfdHlwZSI6ImVtcGxveWVlIiwiaWF0IjoxNzc2NDE3MTUyLCJleHAiOjE4MDc5NTMxNTJ9.'
      'tgKOyUVbSppWad3aXFFmXjICMj1BUY7azbIGXm9M_0Q';

  static String _staticTokenFor(String message) {
    if (message.contains('CEO')) return _ceoStaticToken;
    if (message.contains('Company')) return _companyStaticToken;
    if (message.contains('Employee')) return _employeeStaticToken;
    return _ceoStaticToken;
  }

  Future<TokenResponseModel> login(String email, String password) async {
    try {
      final trimmedEmail = email.trim();
      final trimmedPassword = password.trim();

      debugPrint('── LOGIN REQUEST ──────────────────────');
      debugPrint('POST $_baseUrl/auth/login');

      final loginRes = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'email': trimmedEmail, 'password': trimmedPassword}),
          )
          .timeout(_timeout);

      debugPrint('Status : ${loginRes.statusCode}');
      debugPrint('Body   : ${loginRes.body}');

      if (loginRes.statusCode == 401 || loginRes.statusCode == 403) {
        throw Exception('Invalid email or password.');
      }
      if (loginRes.statusCode != 200) {
        throw Exception(
            'Server error (${loginRes.statusCode}). Please try again.');
      }

      final loginData = jsonDecode(loginRes.body) as Map<String, dynamic>;
      final message = loginData['message']?.toString() ?? '';
      final token = (loginData['token'] as String?) ?? _staticTokenFor(message);

      debugPrint('token: $token');

      // Build user from login payload if present, else decode JWT locally.
      final user = loginData.containsKey('payload')
          ? TokenResponseModel.fromJson(loginData)
          : _localDecode(token);

      debugPrint('── USER DATA ──────────────────────────');
      debugPrint('name       : ${user.name}');
      debugPrint('email      : ${user.email}');
      debugPrint('role       : ${user.role}');
      debugPrint('companyid  : ${user.companyId}');
      debugPrint('user_type  : ${user.userType}');
      debugPrint('exp        : ${user.exp}');
      debugPrint('platformOwner : ${user.platformOwner}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, user.encode());

      debugPrint('Stored user in SharedPreferences ✓');

      return user;
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on FormatException {
      throw Exception('Unexpected response from server. Please try again.');
    } on Exception {
      rethrow;
    }
  }

  TokenResponseModel _localDecode(String token) {
    return TokenResponseModel.fromJson({
      'token': token,
      'payload': _decodeJwtPayload(token),
    });
  }

  Future<TokenResponseModel?> getStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = TokenResponseModel.decode(prefs.getString(_userKey));
      if (user == null) return null;
      if (user.isExpired) {
        await logout();
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Called from each dashboard init — hits GET /token, stores fresh payload.
  Future<TokenResponseModel?> verifyAndStoreUser() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      debugPrint('── GET /token ─────────────────────────');
      final res = await http.get(
        Uri.parse('$_baseUrl/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = TokenResponseModel.fromJson(data);

        debugPrint('── USER DATA ──────────────────────────');
        debugPrint('name       : ${user.name}');
        debugPrint('email      : ${user.email}');
        debugPrint('role       : ${user.role}');
        debugPrint('companyid  : ${user.companyId}');
        debugPrint('user_type  : ${user.userType}');
        debugPrint('exp        : ${user.exp}');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, user.encode());
        debugPrint('User stored in SharedPreferences ✓');
        return user;
      }
    } catch (e) {
      debugPrint('verifyAndStoreUser error: $e');
    }
    // Fall back to whatever is already stored.
    return getStoredUser();
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async => await getStoredUser() != null;

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_tokenKey),
        prefs.remove(_userKey),
      ]);
    } catch (_) {}
  }

  Future<http.Response> authenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Session expired. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Split inline query params from the path (e.g. "/endpoint?foo=bar")
      final parts = endpoint.split('?');
      final path = parts[0];
      final inlineParams = parts.length > 1
          ? Uri.splitQueryString(parts[1])
          : <String, String>{};
      final mergedParams = {...inlineParams, ...?queryParams};

      // ✅ FIX: derive scheme & host from _baseUrl instead of hardcoding them
      final uri = Uri.parse('$_baseUrl$path').replace(
        queryParameters: mergedParams.isEmpty ? null : mergedParams,
      );

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          response = await http.get(uri, headers: headers).timeout(_timeout);
      }

      if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      }
      return response;
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on Exception {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCeoDashboard() async {
    try {
      debugPrint('── GET /dashboards/ceo ─────────────────────────────────');
      final res = await authenticatedRequest('/dashboards/ceo');
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode != 200) {
        throw Exception('Failed to load dashboard (${res.statusCode}).');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Invalid response from server.');
    } on Exception {
      rethrow;
    }
  }

  Future<List<SubscriptionModel>> getSubscriptions() async {
    try {
      debugPrint('── GET /admin-subscription ─────────────────────────────');
      final res = await authenticatedRequest('/admin-subscription');
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode != 200) {
        throw Exception('Failed to load subscriptions (${res.statusCode}).');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['data'] as List? ?? [])
          .map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw Exception('Invalid data received from server.');
    } on Exception {
      rethrow;
    }
  }

  Future<void> createSubscription(Map<String, dynamic> data) async {
    try {
      debugPrint('── POST /admin-subscription ────────────────────────────');
      debugPrint('Body   : $data');
      final res = await authenticatedRequest(
        '/admin-subscription',
        method: 'POST',
        body: data,
      );
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<void> updateSubscription(int id, Map<String, dynamic> data) async {
    try {
      debugPrint('── PUT /admin-subscriptions?id=$id ─────────────────────');
      debugPrint('Body   : $data');
      final res = await authenticatedRequest(
        '/admin-subscriptions?id=$id',
        method: 'PUT',
        body: data,
      );
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<void> deleteSubscription(int id) async {
    try {
      debugPrint('── DELETE /admin-subscriptions?id=$id ──────────────────');
      final res = await authenticatedRequest(
        '/admin-subscriptions?id=$id',
        method: 'DELETE',
      );
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<List<TenantModel>> getTenants() async {
    try {
      debugPrint('── GET /admin-tenants ───────────────────────────────────');
      final res = await authenticatedRequest('/admin-tenants');
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode != 200) {
        throw Exception(
            'Failed to load tenants (${res.statusCode}): ${res.body}');
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        throw Exception(
            'Response is not JSON. Body: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response shape: $decoded');
      }
      final list = decoded['data'];
      if (list == null) return [];
      if (list is! List) {
        throw Exception('"data" is not a list: $list');
      }
      return list
          .map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Exception {
      rethrow;
    }
  }

  Future<void> createTenant(Map<String, dynamic> data) async {
    try {
      debugPrint('── POST /admin-tenants ──────────────────────────────────');
      debugPrint('Body   : $data');
      final res = await authenticatedRequest('/admin-tenants',
          method: 'POST', body: data);
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<void> updateTenant(int id, Map<String, dynamic> data) async {
    try {
      debugPrint('── PUT /admin-tenants?id=$id ────────────────────────────');
      debugPrint('Body   : $data');
      final res = await authenticatedRequest('/admin-tenants',
          method: 'PUT', body: data, queryParams: {'id': id.toString()});
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<void> createTenantPayment(Map<String, dynamic> data) async {
    try {
      debugPrint('── POST /admin-tenant/payments ─────────────────────────');
      debugPrint('Body   : $data');
      final res = await authenticatedRequest(
        '/admin-tenant/payments',
        method: 'POST',
        body: data,
      );
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_parseMessage(res.body));
      }
    } on Exception {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTenantPayments() async {
    try {
      debugPrint('── GET /admin-tenants/payments/all ─────────────────────');
      final res = await authenticatedRequest('/admin-tenants/payments/all');
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode != 200) {
        throw Exception(
            'Failed to load all payments (${res.statusCode}): ${res.body}');
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        throw Exception(
            'Response is not JSON. Body: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response shape.');
      }
      final list = decoded['data'];
      if (list == null || list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Exception {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTenantPayments(int tenantId) async {
    try {
      debugPrint('── GET /admin-tenant/payments?tenant_id=$tenantId ──');
      final res = await authenticatedRequest(
        '/admin-tenant/payments',
        queryParams: {'tenant_id': tenantId.toString()},
      );
      debugPrint('Status : ${res.statusCode}');
      debugPrint('Body   : ${res.body}');
      if (res.statusCode != 200) {
        throw Exception(
            'Failed to load payments (${res.statusCode}): ${res.body}');
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        throw Exception(
            'Response is not JSON. Body: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
      }
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response shape.');
      }
      final list = decoded['data'];
      if (list == null || list is! List) return [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Exception {
      rethrow;
    }
  }

  String _parseMessage(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['message']
              ?.toString() ??
          'Operation failed.';
    } catch (_) {
      return 'Operation failed.';
    }
  }

  // ── Role Management (/rolesmanagement) ────────────────────────────────────

  Future<dynamic> _getCompanyId() async {
    final user = await getStoredUser();
    return user?.companyId;
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    debugPrint('── GET /rolesmanagement?companyid=$companyId ──');
    final res = await authenticatedRequest(
      '/rolesmanagement',
      queryParams: {'companyid': companyId.toString()},
    );
    debugPrint('Status : ${res.statusCode}');
    debugPrint('Body   : ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(_parseMessage(res.body));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createRole(Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final body = {...data, 'companyid': companyId};
    debugPrint('── POST /rolesmanagement ──');
    debugPrint('Body sent: $body');
    final res = await authenticatedRequest(
      '/rolesmanagement',
      method: 'POST',
      body: body,
    );
    debugPrint('Status : ${res.statusCode}');
    debugPrint('Body   : ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateRole(Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final body = {...data, 'companyid': companyId};
    debugPrint('── PUT /rolesmanagement ──');
    debugPrint('Body sent: $body');
    final res = await authenticatedRequest(
      '/rolesmanagement',
      method: 'PUT',
      body: body,
    );
    debugPrint('Status : ${res.statusCode}');
    debugPrint('Body   : ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> deleteRole(int roleId) async {
    debugPrint('── DELETE /rolesmanagement?roleid=$roleId ──');
    final res = await authenticatedRequest(
      '/rolesmanagement',
      method: 'DELETE',
      queryParams: {'roleid': roleId.toString()},
    );
    debugPrint('Status : ${res.statusCode}');
    debugPrint('Body   : ${res.body}');
    if (res.statusCode != 200) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Invalid token format.');
    try {
      return jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Failed to decode token.');
    }
  }
}
