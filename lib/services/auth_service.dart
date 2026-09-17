import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  static const currentTermsVersion = '1.0';
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _roleKey = 'user_role';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decode(response.body);
      if (response.statusCode == 200 && data['token'] is String) {
        final user = Map<String, dynamic>.from(data['user'] as Map);
        await saveSession(
          token: data['token'] as String,
          userId: user['id'].toString(),
          role: user['role']?.toString() ?? 'user',
        );
        return {'success': true, ...data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to connect to the server. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': firstName,
              'lastName': lastName,
              'username': username,
              'email': email,
              'password': password,
              'acceptTerms': true,
              'termsVersion': currentTermsVersion,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = _decode(response.body);
      if (response.statusCode == 201 && data['token'] is String) {
        final user = Map<String, dynamic>.from(data['user'] as Map);
        await saveSession(
          token: data['token'] as String,
          userId: user['id'].toString(),
          role: user['role']?.toString() ?? 'user',
        );
      }
      return {
        ...data,
        'success': response.statusCode == 201,
        'statusCode': response.statusCode,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to connect to the server. Please try again.',
      };
    }
  }

  static Future<void> saveSession({
    required String token,
    required String userId,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _roleKey, value: role);
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _roleKey);
  }

  static Future<Map<String, dynamic>?> validateSession() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        await clearSession();
        return null;
      }
      final data = _decode(response.body);
      final user = Map<String, dynamic>.from(data['user'] as Map);
      if (user['role'] != 'user') {
        await clearSession();
        return null;
      }
      await _storage.write(key: _userIdKey, value: user['id'].toString());
      await _storage.write(key: _roleKey, value: user['role'].toString());
      return user;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final value = jsonDecode(body);
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }
}
