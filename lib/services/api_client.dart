import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiClient {
  static String errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } catch (_) {
      // Non-JSON gateway errors must not be shown as raw HTML or diagnostics.
    }
    return 'The recording could not be analyzed. Please try again.';
  }

  static const requestTimeout = Duration(seconds: 15);
  static const uploadTimeout = Duration(minutes: 6);
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

  static Future<http.Response> sendMultipart(
    http.MultipartRequest request,
  ) async {
    request.headers.addAll(await headers());
    // Bound the complete exchange, including reading the response body.
    final response = await (() async {
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    })().timeout(uploadTimeout);
    return _handle(response);
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
