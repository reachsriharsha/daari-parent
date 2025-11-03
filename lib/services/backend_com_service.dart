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

  /// Send group destination coordinates to backend
  Future<Map<String, dynamic>> sendGroupDestCoordsToBackEnd({
    required String idToken,
    required int groupId,
    required double latitude,
    required double longitude,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/groups/update");

    final body = {
      "group_id": groupId,
      "coordinates": {"latitude": latitude, "longitude": longitude},
    };

    final logBuffer = StringBuffer()
      ..writeln("Request URL: $url")
      ..writeln("Request Body: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    logBuffer
      ..writeln("Response Status: ${response.statusCode}")
      ..writeln("Response Body: ${response.body}");

    if (onLog != null) onLog(logBuffer.toString());

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          "Failed to update group coordinates: ${response.statusCode} ${response.body}";
      developer.log(
        errorMessage,
        name: 'BackendComService',
        level: 1000, // Error level
      );
      throw Exception(errorMessage);
    }
  }

  /// Send group create request to backend
  Future<Map<String, dynamic>> sendGroupCreateRequestToBackEnd({
    required String idToken,
    required String name,
    required int profId,
    required List<String> members,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/groups/create");

    final body = {
      "name": name,
      "prof_id": profId,
      "coordinates": {"latitude": 12.91, "longitude": 77.64},
      "member_list": members.map((m) => {"member_phone_number": m}).toList(),
    };

    final logBuffer = StringBuffer()
      ..writeln("Request URL: $url")
      ..writeln("Request Body: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    logBuffer
      ..writeln("Response Status: ${response.statusCode}")
      ..writeln("Response Body: ${response.body}");

    if (onLog != null) onLog(logBuffer.toString());

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          "Failed to create group: ${response.statusCode} ${response.body}";
      developer.log(
        errorMessage,
        name: 'BackendComService',
        level: 1000, // Error level
      );
      throw Exception(errorMessage);
    }
  }

  /// Send user home coordinates to backend
  Future<Map<String, dynamic>> sendUserHomeCoordinatesToBackEnd({
    required String idToken,
    required String profId,
    required double latitude,
    required double longitude,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/users/update/");

    final body = {
      "prof_id": profId,
      "home_coordinates": {"latitude": latitude, "longitude": longitude},
    };

    final logBuffer = StringBuffer()
      ..writeln("Request URL: $url")
      ..writeln("Request Body: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    logBuffer
      ..writeln("Response Status: ${response.statusCode}")
      ..writeln("Response Body: ${response.body}");

    if (onLog != null) onLog(logBuffer.toString());

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          "Failed to update user home coordinates: ${response.statusCode} ${response.body}";
      developer.log(
        errorMessage,
        name: 'BackendComService',
        level: 1000, // Error level
      );
      throw Exception(errorMessage);
    }
  }
}
