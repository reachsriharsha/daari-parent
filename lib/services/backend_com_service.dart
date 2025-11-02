import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

/// Service class to handle all backend API communications
class BackendComService {
  final String baseUrl;

  BackendComService({required this.baseUrl});

  /// Send Firebase ID token to backend for authentication
  Future<Map<String, dynamic>> sendIdTokenToBackend(String idToken) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          'Backend error: ${response.statusCode} ${response.body}';
      developer.log(
        errorMessage,
        name: 'BackendComService',
        level: 1000, // Error level
      );
      throw Exception(errorMessage);
    }
  }
}
