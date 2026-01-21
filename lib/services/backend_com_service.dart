import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../main.dart'; // To access storageService
import '../utils/app_logger.dart';
import '../widgets/status_widget.dart';
import 'device_info_service.dart';

/// Service class to handle all backend API communications
class BackendComService {
  // Singleton instance
  static final BackendComService instance = BackendComService._internal();

  factory BackendComService() {
    return instance;
  }

  BackendComService._internal();

  // Global variable for the backend URL
  String? _baseUrl;

  // Getter for base URL with default fallback
  String get baseUrl => _baseUrl ?? 'https://api.lusidlogix.com';

  /// Initialize from storage on app start
  Future<void> init() async {
    final storedUrl = storageService.getNgrokUrl();
    if (storedUrl != null && storedUrl.isNotEmpty) {
      _baseUrl = storedUrl;
      logger.debug('[BACKEND] Initialized with URL: $_baseUrl');
    } else {
      logger.debug('[BACKEND] No stored URL found during initialization');
    }
  }

  /// Set the base URL (called after login or from settings)
  void setBaseUrl(String url) {
    _baseUrl = url;
    logger.debug('[BACKEND] Base URL set to: $_baseUrl');
  }

  /// Send Firebase ID token to backend for authentication
  /// Optionally includes FCM token for push notifications
  /// Includes app info for version tracking (DES-AUTH001)
  Future<Map<String, dynamic>> loginToBackEnd(
    String idToken, {
    String? fcmToken,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    // DES-AUTH001: Collect device and app info
    final deviceInfo = DeviceInfoService();
    final appVersion = await deviceInfo.getAppVersion();
    final phoneModel = await deviceInfo.getPhoneModel();
    final osVersion = await deviceInfo.getOsVersion();
    final platform = deviceInfo.getPlatform();

    // Build request body with app info (DES-AUTH001)
    final body = <String, dynamic>{
      'id_token': idToken,
      'app_version': appVersion,
      'phone_model': phoneModel,
      'os_version': osVersion,
      'platform': platform,
    };
    if (fcmToken != null) {
      body['fcm_token'] = fcmToken;
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
      final responseData = jsonDecode(response.body);
      // DES-AUTH001: Handle update_required flag
      if (responseData['update_required'] == true) {
        logger.warning('[AUTH] App update recommended - current version: $appVersion');
      }
      return responseData;
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
    String? placeName,
    String? address,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/groups/update");

    final body = {
      "group_id": groupId,
      "coordinates": {"latitude": latitude, "longitude": longitude},
      if (placeName != null) "place_name": placeName,
      if (address != null) "address": address,
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
    required String profId,
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

  /// Upload diagnostics ZIP file
  Future<Map<String, dynamic>> uploadDiagnostics(File zipFile) async {
    final idToken = storageService.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      showMessageInStatus("error", "Not authenticated");
      throw Exception("Not authenticated");
    }

    final url = Uri.parse("$baseUrl/api/diagnostics");

    logger.debug(
      "[API Request] POST $url - Uploading diagnostics (${await zipFile.length()} bytes)",
    );

    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $idToken';

      // Add file to request
      final fileStream = http.ByteStream(zipFile.openRead());
      final fileLength = await zipFile.length();

      request.files.add(
        http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: 'diagnostics.zip',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      logger.debug(
        "[API Response Status] ${response.statusCode} Body: ${response.body}",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showMessageInStatus("success", "Diagnostics uploaded successfully");
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        // Session expired
        logger.error('[ERROR] Unauthorized (401) - Session expired');
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else {
        showMessageInStatus("error", "Failed to upload diagnostics");
        logger.error(
          "Failed uploadDiagnostics: ${response.statusCode} ${response.body}",
        );
        throw Exception("Failed to upload diagnostics: ${response.statusCode}");
      }
    } catch (e) {
      logger.error("[ERROR] Error uploading diagnostics: $e");
      rethrow;
    }
  }

  /// Assign driver to a group
  Future<Map<String, dynamic>> assignDriver({
    required int groupId,
    required String driverPhoneNumber,
  }) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      showMessageInStatus("error", "Backend URL is not set");
      throw Exception("Backend URL is not set");
    }

    final idToken = storageService.getIdToken();
    if (idToken == null) {
      showMessageInStatus("error", "Session expired. Please login again.");
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/update");

    final body = {"group_id": groupId, "driver_assign": driverPhoneNumber};

    logger.debug("[API Request] POST $url Body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      logger.debug(
        "[API Response Status] ${response.statusCode} Body: ${response.body}",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update Hive storage to keep it in sync
        await _updateDriverInHive(groupId, driverPhoneNumber);

        showMessageInStatus("success", "Driver assigned successfully");
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else {
        showMessageInStatus("error", "Failed to assign driver");
        logger.error(
          "Failed to assign driver: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to assign driver: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception during driver assignment: $e',
        error: e,
        stackTrace: stackTrace,
      );
      showMessageInStatus("error", "Failed to assign driver");
      rethrow;
    }
  }

  /// Update driver in Hive (private helper)
  Future<void> _updateDriverInHive(int groupId, String driverPhone) async {
    try {
      final group = await storageService.getGroup(groupId);
      if (group != null) {
        group.driverPhoneNumber = driverPhone;
        await storageService.saveGroup(group);
        logger.debug(
          '[HIVE] Updated driver in Hive: ${group.groupName} - Driver: $driverPhone',
        );
      } else {
        logger.warning(
          '[WARNING] Group $groupId not found in Hive, skipping driver update',
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Failed to update driver in Hive: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - Hive update failure shouldn't block the operation
    }
  }
}
