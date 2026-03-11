import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  // Login Method
  Future<Map<String, dynamic>> login(String email, String password) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        'token': data['token'],
        'user': data['user'],
        'message': data['message'],
      };
    } else {
      return {
        'success': false,
        'message': data['message'],
      };
    }

  } catch (e) {
    return {
      'success': false,
      'message': 'Connection Error: $e',
    };
  }
}

  // Signup Method
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }
}