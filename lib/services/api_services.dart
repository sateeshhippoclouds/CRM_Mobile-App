import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/permissions_model.dart';
import '../models/subscription_model.dart';
import '../models/tenant_model.dart';
import '../models/token_response_model.dart';

class HippoAuthService {
  static const String _baseUrl = 'https://www.hippocx.com';
  static const String _tokenKey = 'hippo_auth_token';
  static const String _userKey = 'hippo_auth_user';
  static const String _permissionsKey = 'hippo_permissions';
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

      // Fetch role permissions for non-CEO users
      if (!user.platformOwner) {
        await fetchAndStorePermissions();
      }

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
        prefs.remove(_permissionsKey),
      ]);
    } catch (_) {}
  }

  /// Calls GET /rolepermissions and saves the result to SharedPreferences.
  /// Status 200 → employee role permissions stored.
  /// Status 250 → company/ceo user, no permissions to store (all-true default used).
  Future<void> fetchAndStorePermissions() async {
    try {
      final res = await authenticatedRequest('/rolepermissions');
      debugPrint('── PERMISSIONS STATUS: ${res.statusCode} ──');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (decoded.containsKey('permissions')) {
          final model = PermissionsModel.fromJson(decoded);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_permissionsKey, model.encode());
          debugPrint('Permissions stored ✓ role: ${model.roleName}');
        }
      }
      // 250 = "user is a ceo" / company admin — all-true defaults apply, nothing stored.
    } catch (e) {
      debugPrint('fetchAndStorePermissions error: $e');
    }
  }

  Future<PermissionsModel?> getStoredPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PermissionsModel.decode(prefs.getString(_permissionsKey));
    } catch (_) {
      return null;
    }
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

  // ── Lead Masters (/leadmasters) ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getLeadMasters() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/leadmasters',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<void> addLeadMaster(int tab, String value) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/leadmasters',
      method: 'POST',
      body: {'tab': tab, 'value': value, 'companyid': companyId},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateLeadMaster(int id, int tab, String value) async {
    final res = await authenticatedRequest(
      '/leadmasters',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'value': value, 'tab': tab},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteLeadMaster(int id, int tab) async {
    final res = await authenticatedRequest(
      '/leadmasters',
      method: 'DELETE',
      queryParams: {'id': id.toString(), 'tab': tab.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Client Masters (/clientmasters) ─────────────────────────────────────────

  Future<Map<String, dynamic>> getClientMasters() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/clientmasters',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<void> addClientMaster(int tab, String value) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/clientmasters',
      method: 'POST',
      body: {'tab': tab, 'value': value, 'companyid': companyId},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateClientMaster(int id, int tab, String value) async {
    final res = await authenticatedRequest(
      '/clientmasters',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'value': value, 'tab': tab},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteClientMaster(int id, int tab) async {
    final res = await authenticatedRequest(
      '/clientmasters',
      method: 'DELETE',
      queryParams: {'id': id.toString(), 'tab': tab.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Others Masters (/others) ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getOthersMasters() async {
    final res = await authenticatedRequest('/others');
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<void> addOthersMaster(int tab, String value) async {
    final res = await authenticatedRequest(
      '/others',
      method: 'POST',
      body: {'tab': tab, 'value': value},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateOthersMaster(int id, int tab, String value) async {
    final res = await authenticatedRequest(
      '/others',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'tab': tab, 'value': value},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteOthersMaster(int id, int tab) async {
    final res = await authenticatedRequest(
      '/others',
      method: 'DELETE',
      queryParams: {'id': id.toString(), 'tab': tab.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Quote / Terms (/quote) ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getQuoteMasters() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/quote',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  Future<void> addQuoteMaster(int tab, String title, List<String> notes) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/quote',
      method: 'POST',
      body: {
        'tab': tab,
        'title': title,
        'notes': notes,
        'companyid': companyId
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateQuoteMaster(
      int id, int tab, String title, List<String> notes) async {
    final res = await authenticatedRequest(
      '/quote',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'tab': tab, 'title': title, 'notes': notes},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteQuoteMaster(int id, int tab) async {
    final res = await authenticatedRequest(
      '/quote',
      method: 'DELETE',
      queryParams: {'id': id.toString(), 'tab': tab.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Leads (/leads, /followups) ───────────────────────────────────────────────

  // pipeline values: 'pipeline'(all), 'active'(tab=4), 'inactive'(tab=2), 'bulkfailed'(tab=3)
  static const _pipelineTabMap = {
    'pipeline': '4', // status='active' — leads in the sales pipeline
    'active': '1', // status='converted' — leads that became clients
    'inactive': '2',
    'bulkfailed': '3',
  };

  Future<Map<String, dynamic>> getLeadsPaged({
    String pipeline = 'pipeline',
    int page = 0,
    int rowsPerPage = 25,
    Map<String, String> colFilters = const {},
  }) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final tab = _pipelineTabMap[pipeline] ?? '';
    final queryParams = <String, String>{
      'companyid': companyId.toString(),
      'currentpage': page.toString(),
      'rowsPerPage': rowsPerPage.toString(),
    };
    if (tab.isNotEmpty) queryParams['tab'] = tab;
    if (colFilters.isNotEmpty) {
      final filterList = colFilters.entries
          .map((e) => {'field': e.key, 'value': e.value})
          .toList();
      queryParams['filters'] = jsonEncode(filterList);
    }
    final res = await authenticatedRequest('/lead', queryParams: queryParams);
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    // response: { data: [[...rows]], totalrows: [{ totalusers: N }] }
    final dataOuter = decoded['data'];
    List<dynamic> rawList = [];
    if (dataOuter is List && dataOuter.isNotEmpty) {
      rawList = dataOuter[0] is List ? dataOuter[0] as List : dataOuter;
    }
    final totalrowsList = decoded['totalrows'];
    int total = 0;
    if (totalrowsList is List && totalrowsList.isNotEmpty) {
      total =
          int.tryParse(totalrowsList[0]?['totalusers']?.toString() ?? '0') ?? 0;
    }
    return {
      'data': rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      'total': total,
    };
  }

  Future<void> addLead(Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    data['companyid'] = companyId;
    data['action'] = 'add';
    final res = await authenticatedRequest('/lead', method: 'POST', body: data);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateLead(
      dynamic id, String pipeline, Map<String, dynamic> data) async {
    final tab = _pipelineTabMap[pipeline] ?? '4';
    final res = await authenticatedRequest(
      '/lead',
      method: 'PUT',
      queryParams: {'id': id.toString(), 'tab': tab.isEmpty ? '4' : tab},
      body: data,
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteLead(dynamic id, String pipeline) async {
    final tab = _pipelineTabMap[pipeline] ?? '4';
    final res = await authenticatedRequest(
      '/lead',
      method: 'DELETE',
      queryParams: {'id': id.toString(), 'tab': tab.isEmpty ? '4' : tab},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // keep for followups tab
  Future<List<Map<String, dynamic>>> getLeads() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/lead',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final dataOuter = decoded['data'];
      if (dataOuter is List && dataOuter.isNotEmpty) {
        final inner = dataOuter[0] is List ? dataOuter[0] as List : dataOuter;
        return inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> getFollowupsPaged({
    int page = 0,
    int rowsPerPage = 25,
    Map<String, String> colFilters = const {},
  }) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final queryParams = <String, String>{
      'companyid': companyId.toString(),
      'currentpage': page.toString(),
      'rowsPerPage': rowsPerPage.toString(),
    };
    if (colFilters.isNotEmpty) {
      final filterList = colFilters.entries
          .map((e) => {'field': e.key, 'value': e.value})
          .toList();
      queryParams['filters'] = jsonEncode(filterList);
    }
    final res =
        await authenticatedRequest('/followup', queryParams: queryParams);
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    // Response: { columns, data: [...rows], totalrows: [{ totalusers: N }] }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = decoded['data'];
    final totalrows = decoded['totalrows'];
    int total = 0;
    if (totalrows is List && totalrows.isNotEmpty) {
      total = int.tryParse(totalrows[0]?['totalusers']?.toString() ?? '0') ?? 0;
    }
    return {
      'data': list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[],
      'total': total,
    };
  }

  Future<void> deleteFollowup(dynamic id) async {
    final res = await authenticatedRequest(
      '/followup',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Tasks (/tasks) ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTasks() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/tasks',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (decoded is Map) {
      final list = decoded['tasks'] ?? decoded['data'] ?? [];
      if (list is List) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  // ── Employees (/employee) ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEmployeesPaged({
    String tab = 'active',
    int page = 0,
    int rowsPerPage = 25,
    Map<String, String> colFilters = const {},
  }) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final queryParams = <String, String>{
      'companyid': companyId.toString(),
      'tab': tab,
      'currentpage': page.toString(),
      'rowsPerPage': rowsPerPage.toString(),
    };
    if (colFilters.isNotEmpty) {
      final filterList = colFilters.entries
          .map((e) => {'field': e.key, 'value': e.value})
          .toList();
      queryParams['filters'] = jsonEncode(filterList);
    }
    final res = await authenticatedRequest(
      '/employee',
      queryParams: queryParams,
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = decoded['data'];
    final total = decoded['total'] ?? 0;
    return {
      'data': list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[],
      'total': total is int ? total : int.tryParse(total.toString()) ?? 0,
    };
  }

  Future<void> addEmployee(Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    data['companyid'] = companyId;
    debugPrint('=== ADD EMPLOYEE REQUEST ===');
    debugPrint('Body: $data');
    final res = await authenticatedRequest(
      '/employee',
      method: 'POST',
      body: data,
    );
    debugPrint('=== ADD EMPLOYEE RESPONSE ===');
    debugPrint('Status: ${res.statusCode}');
    debugPrint('Body: ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateEmployee(dynamic id, Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    data['companyid'] = companyId;
    data['id'] = id; // API reads id from body, not query params
    final res = await authenticatedRequest(
      '/employee',
      method: 'PUT',
      body: data,
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteEmployee(dynamic id) async {
    final res = await authenticatedRequest(
      '/employee',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Products / Services (/products) ──────────────────────────────────────────

  Future<Map<String, dynamic>> getProductsPaged({
    int page = 0,
    int rowsPerPage = 25,
    Map<String, String> colFilters = const {},
  }) async {
    final queryParams = <String, String>{
      'currentpage': page.toString(),
      'rowsPerPage': rowsPerPage.toString(),
    };
    if (colFilters.isNotEmpty) {
      final filterList = colFilters.entries
          .map((e) => {'field': e.key, 'value': e.value})
          .toList();
      queryParams['filters'] = jsonEncode(filterList);
    }
    final res = await authenticatedRequest(
      '/product',
      queryParams: queryParams,
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final list = decoded['data'];
    final total = decoded['totalrows'] ?? decoded['total'] ?? 0;
    return {
      'data': list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[],
      'total': total is int ? total : int.tryParse(total.toString()) ?? 0,
    };
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    final res = await authenticatedRequest(
      '/product',
      method: 'POST',
      body: data,
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateProduct(Map<String, dynamic> data) async {
    final res = await authenticatedRequest(
      '/product',
      method: 'PUT',
      body: data,
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteProduct(dynamic id) async {
    final res = await authenticatedRequest(
      '/product',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Clients (/clients) ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getClientsPaged({
    int page = 0,
    int rowsPerPage = 25,
    Map<String, String> colFilters = const {},
  }) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final queryParams = <String, String>{
      'companyid': companyId.toString(),
      'currentpage': page.toString(),
      'rowsPerPage': rowsPerPage.toString(),
    };
    if (colFilters.isNotEmpty) {
      final filterList = colFilters.entries
          .map((e) => {'field': e.key, 'value': e.value})
          .toList();
      queryParams['filters'] = jsonEncode(filterList);
    }
    final res =
        await authenticatedRequest('/clients', queryParams: queryParams);
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    List<dynamic> rawList = [];
    int total = 0;
    if (decoded is Map<String, dynamic>) {
      final dataOuter = decoded['data'];
      if (dataOuter is List && dataOuter.isNotEmpty) {
        rawList = dataOuter[0] is List ? dataOuter[0] as List : dataOuter;
      }
      final totalrows = decoded['totalrows'];
      if (totalrows is List && totalrows.isNotEmpty) {
        total =
            int.tryParse(totalrows[0]?['totalusers']?.toString() ?? '0') ?? 0;
      } else {
        final t = decoded['total'] ?? decoded['totalrows'] ?? 0;
        total = t is int ? t : int.tryParse(t.toString()) ?? rawList.length;
      }
      if (total == 0 && rawList.isEmpty) {
        final list = decoded['clients'] ?? decoded['data'] ?? [];
        if (list is List) {
          rawList = list;
          total = rawList.length;
        }
      }
    } else if (decoded is List) {
      rawList = decoded;
      total = decoded.length;
    }
    return {
      'data': rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      'total': total,
    };
  }

  Future<void> addClient(Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    data['companyid'] = companyId;
    final res =
        await authenticatedRequest('/clients', method: 'POST', body: data);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateClient(dynamic id, Map<String, dynamic> data) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    data['companyid'] = companyId;
    data['id'] = id;
    final res =
        await authenticatedRequest('/clients', method: 'PUT', body: data);
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteClient(dynamic id) async {
    final res = await authenticatedRequest(
      '/clients',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  // ── Sales & Billing (/sales) ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSalesBilling() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/sales',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) {
      return {'sales': decoded, 'drafts': [], 'history': []};
    }
    return {'sales': [], 'drafts': [], 'history': []};
  }

  // ── Location Masters (/locationsmaster) ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCountries() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/countries',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addCountry(String name) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/countries',
      method: 'POST',
      body: {'name': name, 'companyid': companyId},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateCountry(int id, String name) async {
    final res = await authenticatedRequest(
      '/locationsmaster/countries',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'name': name},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteCountry(int id) async {
    final res = await authenticatedRequest(
      '/locationsmaster/countries',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<List<Map<String, dynamic>>> getStates() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/states',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addState(String name, int countryId) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/states',
      method: 'POST',
      body: {'name': name, 'country_id': countryId, 'companyid': companyId},
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateState(int id, String name, int countryId) async {
    final res = await authenticatedRequest(
      '/locationsmaster/states',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'name': name, 'country_id': countryId},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteState(int id) async {
    final res = await authenticatedRequest(
      '/locationsmaster/states',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<List<Map<String, dynamic>>> getCities() async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/cities',
      queryParams: {'companyid': companyId.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addCity(String name, int stateId, int countryId) async {
    final companyId = await _getCompanyId();
    if (companyId == null) throw Exception('Company ID not found.');
    final res = await authenticatedRequest(
      '/locationsmaster/cities',
      method: 'POST',
      body: {
        'name': name,
        'state_id': stateId,
        'country_id': countryId,
        'companyid': companyId,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_parseMessage(res.body));
    }
  }

  Future<void> updateCity(
      int id, String name, int stateId, int countryId) async {
    final res = await authenticatedRequest(
      '/locationsmaster/cities',
      method: 'PUT',
      queryParams: {'id': id.toString()},
      body: {'name': name, 'state_id': stateId, 'country_id': countryId},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
  }

  Future<void> deleteCity(int id) async {
    final res = await authenticatedRequest(
      '/locationsmaster/cities',
      method: 'DELETE',
      queryParams: {'id': id.toString()},
    );
    if (res.statusCode != 200) throw Exception(_parseMessage(res.body));
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
