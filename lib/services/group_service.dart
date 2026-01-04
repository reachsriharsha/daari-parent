import 'package:flutter/material.dart';
import '../main.dart'; // To access storageService
import '../models/group.dart';
import 'backend_com_service.dart';
import '../utils/app_logger.dart';

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
    if (idToken == null) {
      throw Exception('ID token not found. Please login again.');
    }

    // Use backend service for communication
    final responseData = await BackendComService.instance
        .sendGroupDestCoordsToBackEnd(
          idToken: idToken,
          groupId: groupId,
          latitude: latitude,
          longitude: longitude,
          onLog: onLog,
        );

    // Update Hive storage after successful backend update
    await _updateGroupInHive(groupId, latitude, longitude);

    return responseData;
  }

  // Store group both in backend and locally
  Future<Map<String, dynamic>> createGroup(
    String name,
    List<String> members,
  ) async {
    final idToken = storageService.getIdToken();
    final profIdString = storageService.getProfId();

    if (idToken == null) {
      throw Exception('ID token not found. Please login again.');
    }
    if (profIdString == null) {
      throw Exception('Profile ID not found. Please login again.');
    }

    final profId = int.tryParse(profIdString);
    if (profId == null) {
      throw Exception('Invalid profile ID format. Please login again.');
    }

    // Use backend service for communication
    final responseData = await BackendComService.instance
        .sendGroupCreateRequestToBackEnd(
          idToken: idToken,
          name: name,
          profId: profId,
          members: members,
        );

    // Save to Hive using Group model (keeping Hive update in group service)
    final group = Group(
      groupId: responseData["id"] ?? 0,
      groupName: name,
      destinationLatitude: 12.91,
      destinationLongitude: 77.64,
      memberPhoneNumbers: members,
      isAdmin: true,
      address: null, // Initially null for new groups
      placeName: null,
    );

    await storageService.saveGroup(group);

    return responseData;
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
    double longitude, {
    String? address,
    String? placeName,
  }) async {
    try {
      // Get existing group from Hive
      final existingGroup = await storageService.getGroup(groupId);

      if (existingGroup != null) {
        // Update coordinates
        existingGroup.destinationLatitude = latitude;
        existingGroup.destinationLongitude = longitude;

        // Update address and placeName if provided
        if (address != null) existingGroup.address = address;
        if (placeName != null) existingGroup.placeName = placeName;

        // Save back to Hive (same key = groupId)
        await storageService.saveGroup(existingGroup);

        logger.info(
          '[HIVE] Updated group in Hive: ${existingGroup.groupName} '
          '(Lat: $latitude, Lng: $longitude, Address: $address, Place: $placeName)',
        );
      } else {
        logger.warning(
          '[WARNING] Group $groupId not found in Hive, skipping local update',
        );
      }
    } catch (e) {
      logger.error('[ERROR] Error updating group in Hive: $e');
      // Don't throw - backend update succeeded, local cache can be stale
    }
  }
}
