import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../main.dart'; // To access storageService
import '../models/group_member_input.dart';
import '../utils/app_logger.dart';
import '../widgets/status_widget.dart';
import '../utils/phone_number_utils.dart';
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
        logger.warning(
          '[AUTH] App update recommended - current version: $appVersion',
        );
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

  /// Send group create request to backend (DES-GRP002: with optional member names)
  ///
  /// [members] can be either a List<String> (phone numbers only, backward compatible)
  /// or a List<GroupMemberInput> (with optional names)
  Future<Map<String, dynamic>> sendGroupCreateRequestToBackEnd({
    required String idToken,
    required String name,
    required String profId,
    required List<dynamic> members,
    void Function(String log)? onLog,
  }) async {
    final url = Uri.parse("$baseUrl/api/groups/create");

    // DES-GRP002: Build member_list supporting both formats
    final memberList = members.map((m) {
      if (m is GroupMemberInput) {
        return m.toJson();
      } else if (m is String) {
        return {'member_phone_number': m};
      }
      return {'member_phone_number': m.toString()};
    }).toList();

    final body = {
      "name": name,
      "prof_id": profId,
      "coordinates": {"latitude": 12.91, "longitude": 77.64},
      "member_list": memberList,
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
    final idToken = await storageService.getIdToken();
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
          filename: path.basename(zipFile.path),
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

    // Normalize driver phone number
    String normalizedDriverPhone;
    try {
      normalizedDriverPhone = PhoneNumberUtils.normalizePhoneNumber(
        driverPhoneNumber,
      );
      logger.debug(
        '[ASSIGN_DRIVER] Normalized phone: $driverPhoneNumber → $normalizedDriverPhone',
      );
    } catch (e) {
      logger.error(
        '[ASSIGN_DRIVER] Invalid phone number: $driverPhoneNumber - $e',
      );
      showMessageInStatus("error", "Invalid driver phone number format");
      throw ArgumentError('Invalid driver phone number: $e');
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      showMessageInStatus("error", "Session expired. Please login again.");
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/update");

    final body = {"group_id": groupId, "driver_assign": normalizedDriverPhone};

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

  /// Add members to an existing group (DES-GRP003)
  ///
  /// [groupId] - ID of the group to add members to
  /// [groupName] - Name of the group (for validation)
  /// [members] - List of members to add (1-20)
  ///
  /// Returns success/failure response
  Future<Map<String, dynamic>> addGroupMembers({
    required int groupId,
    required String groupName,
    required List<GroupMemberInput> members,
  }) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      showMessageInStatus("error", "Backend URL is not set");
      throw Exception("Backend URL is not set");
    }

    // Client-side validation
    if (members.isEmpty) {
      showMessageInStatus("error", "At least one member is required");
      throw ArgumentError('At least one member is required');
    }
    if (members.length > 20) {
      showMessageInStatus("error", "Maximum 20 members can be added at once");
      throw ArgumentError('Maximum 20 members can be added at once');
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      showMessageInStatus("error", "Session expired. Please login again.");
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/members/add/");

    final body = {
      "group_id": groupId,
      "group_name": groupName,
      "member_entries": members.map((m) => m.toJson()).toList(),
    };

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
        // Update Hive storage with new members
        await _updateMembersInHive(groupId, members);

        showMessageInStatus("success", "Members added successfully");
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        showMessageInStatus("error", "Only group admins can add members");
        throw Exception('Only group admins can add members');
      } else if (response.statusCode == 404) {
        showMessageInStatus("error", "Group not found");
        throw Exception('Group not found');
      } else {
        showMessageInStatus("error", "Failed to add members");
        logger.error(
          "Failed to add members: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to add members: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception during member addition: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is! ArgumentError) {
        showMessageInStatus("error", "Failed to add members");
      }
      rethrow;
    }
  }

  /// Update members in Hive (private helper for DES-GRP003)
  Future<void> _updateMembersInHive(
    int groupId,
    List<GroupMemberInput> members,
  ) async {
    try {
      final group = await storageService.getGroup(groupId);
      if (group != null) {
        // Add new member phone numbers to existing list
        final existingMembers = List<String>.from(
          group.memberPhoneNumbers ?? [],
        );
        for (final member in members) {
          if (!existingMembers.contains(member.phoneNumber)) {
            existingMembers.add(member.phoneNumber);
          }
        }
        group.memberPhoneNumbers = existingMembers;
        await storageService.saveGroup(group);
        logger.debug(
          '[HIVE] Updated members in Hive: ${group.groupName} - ${members.length} members added',
        );
      } else {
        logger.warning(
          '[WARNING] Group $groupId not found in Hive, skipping member update',
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Failed to update members in Hive: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - Hive update failure shouldn't block the operation
    }
  }

  /// Remove members from an existing group (DES-GRP004)
  ///
  /// [groupId] - ID of the group to remove members from
  /// [groupName] - Name of the group (for validation)
  /// [memberPhoneNumbers] - List of phone numbers to remove (1-20)
  ///
  /// Returns success/failure response with status and message
  Future<Map<String, dynamic>> removeGroupMembers({
    required int groupId,
    required String groupName,
    required List<String> memberPhoneNumbers,
  }) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      showMessageInStatus("error", "Backend URL is not set");
      throw Exception("Backend URL is not set");
    }

    // Client-side validation
    if (memberPhoneNumbers.isEmpty) {
      showMessageInStatus("error", "At least one member is required");
      throw ArgumentError('At least one member is required');
    }
    if (memberPhoneNumbers.length > 20) {
      showMessageInStatus("error", "Maximum 20 members can be removed at once");
      throw ArgumentError('Maximum 20 members can be removed at once');
    }

    // Normalize all phone numbers
    final normalizedPhones = <String>[];
    for (final phone in memberPhoneNumbers) {
      try {
        final normalized = PhoneNumberUtils.normalizePhoneNumber(phone);
        normalizedPhones.add(normalized);
      } catch (e) {
        logger.error('[REMOVE_MEMBERS] Invalid phone number: $phone - $e');
        // Add original if normalization fails, backend will handle
        normalizedPhones.add(phone);
      }
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      showMessageInStatus("error", "Session expired. Please login again.");
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/members/remove/");

    final memberEntries = normalizedPhones
        .map((phone) => {'member_phone_number': phone})
        .toList();

    final body = {
      "group_id": groupId,
      "group_name": groupName,
      "member_entries": memberEntries,
    };

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

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if response indicates an error (e.g., self-removal, last member)
        if (responseData['status'] == 'error') {
          showMessageInStatus(
            "error",
            responseData['message'] ?? 'Operation failed',
          );
          return responseData;
        }

        // Update Hive storage - remove members
        await _removeMembersFromHive(groupId, memberPhoneNumbers);

        showMessageInStatus("success", "Members removed successfully");
        return responseData;
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        showMessageInStatus("error", "Only group admins can remove members");
        throw Exception('Only group admins can remove members');
      } else if (response.statusCode == 404) {
        showMessageInStatus("error", "Group not found");
        throw Exception('Group not found');
      } else {
        showMessageInStatus("error", "Failed to remove members");
        logger.error(
          "Failed to remove members: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to remove members: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception during member removal: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is! ArgumentError) {
        showMessageInStatus("error", "Failed to remove members");
      }
      rethrow;
    }
  }

  /// Remove members from Hive (private helper for DES-GRP004)
  Future<void> _removeMembersFromHive(
    int groupId,
    List<String> phoneNumbers,
  ) async {
    try {
      final group = await storageService.getGroup(groupId);
      if (group != null) {
        // Remove phone numbers from existing list
        final existingMembers = List<String>.from(
          group.memberPhoneNumbers ?? [],
        );
        existingMembers.removeWhere((phone) => phoneNumbers.contains(phone));
        group.memberPhoneNumbers = existingMembers;
        await storageService.saveGroup(group);
        logger.debug(
          '[HIVE] Removed members from Hive: ${group.groupName} - ${phoneNumbers.length} members removed',
        );
      } else {
        logger.warning(
          '[WARNING] Group $groupId not found in Hive, skipping member removal',
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Failed to remove members from Hive: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - Hive update failure shouldn't block the operation
    }
  }

  /// Delete a group (DES-GRP005)
  ///
  /// [groupId] - ID of the group to delete
  /// [groupName] - Name of the group (for verification)
  ///
  /// Returns success/failure response with status and message
  Future<Map<String, dynamic>> deleteGroup({
    required int groupId,
    required String groupName,
  }) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      showMessageInStatus("error", "Backend URL is not set");
      throw Exception("Backend URL is not set");
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      showMessageInStatus("error", "Session expired. Please login again.");
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/delete");

    final body = {"group_id": groupId, "group_name": groupName};

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

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if response indicates an error (e.g., active trip)
        if (responseData['status'] == 'error') {
          showMessageInStatus(
            "error",
            responseData['message'] ?? 'Operation failed',
          );
          return responseData;
        }

        // Remove group from Hive storage
        await _removeGroupFromHive(groupId);

        showMessageInStatus("success", "Group deleted successfully");
        return responseData;
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        showMessageInStatus("error", "Only group admins can delete group");
        throw Exception('Only group admins can delete group');
      } else if (response.statusCode == 404) {
        showMessageInStatus("error", "Group not found");
        throw Exception('Group not found');
      } else {
        showMessageInStatus("error", "Failed to delete group");
        logger.error(
          "Failed to delete group: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to delete group: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception during group deletion: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is! ArgumentError) {
        showMessageInStatus("error", "Failed to delete group");
      }
      rethrow;
    }
  }

  /// Remove group from Hive (private helper for DES-GRP005)
  Future<void> _removeGroupFromHive(int groupId) async {
    try {
      await storageService.removeGroup(groupId);
      logger.debug('[HIVE] Removed group from Hive: $groupId');
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Failed to remove group from Hive: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - Hive update failure shouldn't block the operation
    }
  }

  /// Refresh all group data from backend (DES-GRP006)
  ///
  /// Called in response to group_refresh FCM notification
  /// or when manual refresh is needed
  ///
  /// Returns the response with status and updated group_list
  Future<Map<String, dynamic>> refreshGroups() async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      logger.error('[ERROR] Backend URL is not set for refreshGroups');
      throw Exception("Backend URL is not set");
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/refresh");

    logger.debug("[API Request] POST $url (group refresh)");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({}),
      );

      logger.debug(
        "[API Response Status] ${response.statusCode} Body: ${response.body}",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['group_list'] != null) {
          // Update Hive storage with fresh group data
          await _syncGroupsToHive(responseData['group_list']);
          logger.debug(
            '[GROUP REFRESH] Successfully refreshed ${(responseData['group_list'] as List).length} groups',
          );
        }

        return responseData;
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        throw Exception('Session expired. Please login again.');
      } else {
        logger.error(
          "Failed to refresh groups: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to refresh groups: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception during group refresh: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sync groups to Hive storage (private helper for DES-GRP006)
  Future<void> _syncGroupsToHive(List<dynamic> groupList) async {
    try {
      // Get existing group IDs
      final existingGroups = await storageService.getAllGroups();
      final existingGroupIds = existingGroups.map((g) => g.groupId).toSet();

      // Track which groups are in the new list
      final newGroupIds = <int>{};

      for (final groupData in groupList) {
        final groupId = groupData['id'] as int;
        newGroupIds.add(groupId);

        // Get or create group model
        var group = await storageService.getGroup(groupId);
        if (group == null) {
          // Create new group
          group = await storageService.createGroupFromJson(groupData);
        } else {
          // Update existing group
          group.groupName = groupData['name'] ?? group.groupName;
          group.memberPhoneNumbers = List<String>.from(
            groupData['member_phone_numbers'] ?? [],
          );
          group.adminPhoneNumber = groupData['admin_phone_number'];
          group.driverPhoneNumber = groupData['driver_phone_number'];
          group.isAdmin = groupData['is_admin'] ?? false;

          if (groupData['dest_coordinates'] != null) {
            group.destinationLatitude =
                groupData['dest_coordinates']['latitude'];
            group.destinationLongitude =
                groupData['dest_coordinates']['longitude'];
          }
          if (groupData['address'] != null) {
            group.address = groupData['address'];
          }
          if (groupData['place_name'] != null) {
            group.placeName = groupData['place_name'];
          }

          await storageService.saveGroup(group);
        }
      }

      // Remove groups that are no longer in the list
      for (final groupId in existingGroupIds) {
        if (!newGroupIds.contains(groupId)) {
          await storageService.removeGroup(groupId);
          logger.debug('[HIVE] Removed group $groupId (no longer member)');
        }
      }

      logger.debug('[HIVE] Synced ${groupList.length} groups to Hive storage');
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Error syncing groups to Hive: $e',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't throw - we still want to return the response
    }
  }

  /// DES-TRP001: Get active trip for a group
  ///
  /// Queries backend for active trip details if one exists for the group.
  /// Used for backend sync when parent app opens group details.
  ///
  /// [groupId] - ID of the group to check for active trips
  ///
  /// Returns:
  /// - status: "success"
  /// - has_active_trip: bool
  /// - trip_name: string (if active trip exists)
  /// - started_at: ISO timestamp (if active trip exists)
  /// - last_update: ISO timestamp (if active trip exists)
  /// - trip_route: array of {latitude, longitude, timestamp, event}
  Future<Map<String, dynamic>> getActiveTrip(int groupId) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      logger.error('[ERROR] Backend URL is not set for getActiveTrip');
      throw Exception("Backend URL is not set");
    }

    final idToken = await storageService.getIdToken();
    if (idToken == null) {
      throw Exception("Session expired. Please login again.");
    }

    final url = Uri.parse("$_baseUrl/api/groups/$groupId/active-trip");

    logger.debug("[API Request] GET $url (active trip sync)");

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      logger.debug(
        "[API Response Status] ${response.statusCode} Body: ${response.body}",
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['has_active_trip'] == true) {
          logger.debug(
            '[ACTIVE TRIP] Found active trip for group $groupId: ${responseData['trip_name']}',
          );
        } else {
          logger.debug('[ACTIVE TRIP] No active trip for group $groupId');
        }

        return responseData;
      } else if (response.statusCode == 401) {
        logger.error('[ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        logger.error('[ERROR] Forbidden (403) - Not authorized for this group');
        throw Exception('Not authorized to view this group');
      } else {
        logger.error(
          "Failed to get active trip: ${response.statusCode} ${response.body}",
        );
        throw Exception(
          "Failed to get active trip: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ERROR] Exception getting active trip: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
