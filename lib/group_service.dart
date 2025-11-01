import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'main.dart'; // To access storageService
import 'models/group.dart';

class GroupService {
  final String baseUrl;
  GroupService({required this.baseUrl});

  // -----------------------------
  // Group APIs
  // -----------------------------

  // Update group address in backend
  Future<Map<String, dynamic>> updateGroup({
    required int groupId,
    required double latitude,
    required double longitude,
    void Function(String log)? onLog,
  }) async {
    final idToken = storageService.getIdToken();
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
      // Update Hive storage after successful backend update
      await _updateGroupInHive(groupId, latitude, longitude);

      return jsonDecode(response.body);
    } else {
      throw Exception(
        "Failed updateGroup: ${response.statusCode} ${response.body}",
      );
    }
  }

  // Store group both in backend and locally
  Future<Map<String, dynamic>> createGroup(
    String name,
    List<String> members,
  ) async {
    final idToken = storageService.getIdToken();
    final profId = storageService.getProfId();
    final url = Uri.parse("$baseUrl/api/groups/create");

    final body = {
      "name": name,
      "prof_id": profId,
      "coordinates": {"latitude": 12.91, "longitude": 77.64},
      "member_list": members.map((m) => {"member_phone_number": m}).toList(),
    };

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);

      // Save to Hive using Group model
      final group = Group(
        groupId: responseData["id"] ?? 0,
        groupName: name,
        destinationLatitude: 12.91,
        destinationLongitude: 77.64,
      );

      await storageService.saveGroup(group);

      return responseData;
    } else {
      throw Exception(
        "Failed createGroup: ${response.statusCode} ${response.body}",
      );
    }
  }

  // Fetch all groups from local storage
  static Future<List<Map<String, dynamic>>> getLocalGroups() async {
    // Get groups from Hive
    final groups = await storageService.getAllGroups();
    return groups.map((g) => g.toJson()).toList();
  }

  // -----------------------------
  // Private Helpers
  // -----------------------------

  /// Update group coordinates in Hive after successful backend update
  Future<void> _updateGroupInHive(
    int groupId,
    double latitude,
    double longitude,
  ) async {
    try {
      // Get existing group from Hive
      final existingGroup = await storageService.getGroup(groupId);

      if (existingGroup != null) {
        // Update coordinates
        existingGroup.destinationLatitude = latitude;
        existingGroup.destinationLongitude = longitude;

        // Save back to Hive (same key = groupId)
        await storageService.saveGroup(existingGroup);

        debugPrint(
          '[HIVE] Updated group in Hive: ${existingGroup.groupName} '
          '(Lat: $latitude, Lng: $longitude)',
        );
      } else {
        debugPrint(
          '[WARNING] Group $groupId not found in Hive, skipping local update',
        );
      }
    } catch (e) {
      debugPrint('[ERROR] Error updating group in Hive: $e');
      // Don't throw - backend update succeeded, local cache can be stale
    }
  }
}
