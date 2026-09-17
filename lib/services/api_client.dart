import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiClient {
  static const requestTimeout = Duration(seconds: 15);
  static const uploadTimeout = Duration(minutes: 5);
  static Future<void> Function()? onAuthenticationExpired;
  static bool _handlingAuthenticationFailure = false;

  static Future<Map<String, String>> headers({bool json = false}) async {
    final token = await AuthService.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(Uri url) async => _handle(
        await http.get(url, headers: await headers()).timeout(requestTimeout),
      );

  static Future<http.Response> post(Uri url, {Object? body}) async => _handle(
        await http
            .post(url, headers: await headers(json: true), body: body)
            .timeout(requestTimeout),
      );

  static Future<http.Response> put(Uri url, {Object? body}) async => _handle(
        await http
            .put(url, headers: await headers(json: true), body: body)
            .timeout(requestTimeout),
      );

  static Future<http.Response> patch(Uri url, {Object? body}) async => _handle(
        await http
            .patch(url, headers: await headers(json: true), body: body)
            .timeout(requestTimeout),
      );

  static Future<http.Response> delete(Uri url) async => _handle(
        await http.delete(url, headers: await headers()).timeout(requestTimeout),
      );

  static Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    request.headers.addAll(await headers());
    final streamed = await request.send().timeout(uploadTimeout);
    return _handle(await http.Response.fromStream(streamed));
  }

  static Future<http.Response> _handle(http.Response response) async {
    if (response.statusCode == 401 || _isInactiveAccount(response)) {
      await AuthService.clearSession();
      if (!_handlingAuthenticationFailure && onAuthenticationExpired != null) {
        _handlingAuthenticationFailure = true;
        try {
          await onAuthenticationExpired!();
        } finally {
          _handlingAuthenticationFailure = false;
        }
      }
    }
    return response;
  }

  static bool _isInactiveAccount(http.Response response) {
    if (response.statusCode != 403) return false;
    try {
      final data = jsonDecode(response.body);
      return data is Map && data['message'] == 'This account is not active';
    } catch (_) {
      return false;
    }
  }
}
