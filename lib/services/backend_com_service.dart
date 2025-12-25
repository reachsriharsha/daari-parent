import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/app_logger.dart';

/// Service class to handle all backend API communications
class BackendComService {
  final String baseUrl;

  BackendComService({required this.baseUrl});

  /// Send Firebase ID token to backend for authentication
  /// Optionally includes FCM token for push notifications
  Future<Map<String, dynamic>> loginToBackEnd(
    String idToken, {
    String? fcmToken,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    // Build request body
    final body = <String, dynamic>{'id_token': idToken};
    if (fcmToken != null) {
      body['fcm_token'] = fcmToken;
      body['platform'] = 'android'; // TODO: Detect platform dynamically
    }

    logger.debug(
      '[BackendComService] Logging in to backend with body: ${jsonEncode(body)}',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          'Backend error: ${response.statusCode} ${response.body}';
      logger.error('[BackendComService] $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// Refresh FCM token on backend
  Future<Map<String, dynamic>> refreshFcmToken({
    required String idToken,
    required String fcmToken,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/refreshfcmtoken');

    final body = {
      'fcm_token': fcmToken,
      'platform': 'android', // TODO: Detect platform dynamically
    };

    logger.debug(
      '[BackendComService] Refreshing FCM token: ${fcmToken.substring(0, 20)}...',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      logger.debug('[BackendComService] FCM token refreshed successfully');
      return jsonDecode(response.body);
    } else {
      final errorMessage =
          'Failed to refresh FCM token: ${response.statusCode} ${response.body}';
      logger.error('[BackendComService] $errorMessage');
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
      logger.error('[BackendComService] $errorMessage');
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
    final url = Uri.parse("$baseUrl/apireate");

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
      logger.error('[BackendComService] $errorMessage');
      throw Exception(errorMessage);
    }
  }

  /// Send user home coordinates, address, and place name to backend
  Future<Map<String, dynamic>> sendUserHomeCoordinatesToBackEnd({
    required String idToken,
    required String profId,
    required double latitude,
    required double longitude,
    String? homeAddress,
    String? homePlaceName,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/users/update/");

    final body = {
      "prof_id": profId,
      "home_coordinates": {"latitude": latitude, "longitude": longitude},
      if (homeAddress != null) "home_address": homeAddress,
      if (homePlaceName != null) "home_place_name": homePlaceName,
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
      logger.error('[BackendComService] $errorMessage');
      throw Exception(errorMessage);
    }
  }
}
