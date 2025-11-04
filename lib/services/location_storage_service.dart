import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';
import '../models/app_settings.dart';
import '../models/group.dart';

/// Service for managing location points and trip state in Hive
class LocationStorageService {
  static const String _locationBoxName = 'location_points';
  static const String _settingsBoxName = 'trip_settings';
  static const String _appSettingsBoxName = 'app_settings';
  static const String _settingsKey = 'current_trip';
  static const String _appSettingsKey = 'app_config';
  static const int _dataRetentionDays = 7;

  Box<LocationPoint>? _locationBox;
  Box<TripSettings>? _settingsBox;
  Box<AppSettings>? _appSettingsBox;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    try {
      await Hive.initFlutter();

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LocationPointAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(TripSettingsAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(GroupAdapter());
      }

      // Open boxes
      _locationBox = await Hive.openBox<LocationPoint>(_locationBoxName);
      _settingsBox = await Hive.openBox<TripSettings>(_settingsBoxName);
      _appSettingsBox = await Hive.openBox<AppSettings>(_appSettingsBoxName);

      debugPrint('[HIVE] Hive initialized successfully');
      debugPrint('   - Location points: ${_locationBox?.length ?? 0}');
      debugPrint('   - Settings box opened');
      debugPrint('   - App settings box opened');

      // Clean up old data on init
      await deleteOldPoints();
    } catch (e) {
      debugPrint('[HIVE ERROR] Error initializing Hive: $e');
      rethrow;
    }
  }

  /// Save a location point to Hive
  Future<bool> saveLocationPoint(LocationPoint point) async {
    try {
      await _locationBox?.add(point);
      debugPrint(
        '[HIVE] Saved location point: ${point.tripId} - ${point.tripEventType}',
      );
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving location point: $e');
      return false; // Continue trip even if Hive save fails
    }
  }

  /// Save or update trip settings
  Future<bool> saveTripSettings(TripSettings settings) async {
    try {
      await _settingsBox?.put(_settingsKey, settings);
      debugPrint('[HIVE] Saved trip settings: $settings');
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving trip settings: $e');
      return false;
    }
  }

  /// Get current trip settings
  TripSettings? getTripSettings() {
    try {
      return _settingsBox?.get(_settingsKey);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting trip settings: $e');
      return null;
    }
  }

  /// Clear trip settings (called when trip finishes)
  Future<bool> clearTripSettings() async {
    try {
      final settings = getTripSettings();
      if (settings != null) {
        settings.clear();
        await _settingsBox?.put(_settingsKey, settings);
      }
      debugPrint('[HIVE] Cleared trip settings');
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error clearing trip settings: $e');
      return false;
    }
  }

  /// Get all location points for a specific trip
  List<LocationPoint> getLocationPointsByTripId(String tripId) {
    try {
      final points =
          _locationBox?.values
              .where((point) => point.tripId == tripId)
              .toList() ??
          [];
      debugPrint('[HIVE] Retrieved ${points.length} points for trip $tripId');
      return points;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting location points: $e');
      return [];
    }
  }

  /// Get all unsynced location points
  List<LocationPoint> getUnsyncedPoints() {
    try {
      final points =
          _locationBox?.values.where((point) => !point.isSynced).toList() ?? [];
      debugPrint('[HIVE] Found ${points.length} unsynced points');
      return points;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting unsynced points: $e');
      return [];
    }
  }

  /// Mark specific points as synced
  Future<bool> markPointsAsSynced(List<LocationPoint> points) async {
    try {
      for (var point in points) {
        if (point.isInBox) {
          // Get the index of the point in the box
          final index = point.key as int;

          // Create a new point with isSynced = true
          final updatedPoint = LocationPoint(
            latitude: point.latitude,
            longitude: point.longitude,
            timestamp: point.timestamp,
            speed: point.speed,
            accuracy: point.accuracy,
            tripId: point.tripId,
            isSynced: true,
            tripEventType: point.tripEventType,
            groupId: point.groupId,
          );

          // Replace the point at the same index
          await _locationBox?.putAt(index, updatedPoint);
        }
      }
      debugPrint('[HIVE] Marked ${points.length} points as synced');
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error marking points as synced: $e');
      return false;
    }
  }

  /// Mark a single point as synced by finding it in the box
  Future<bool> markPointAsSynced(
    String tripId,
    DateTime timestamp,
    String? eventType,
  ) async {
    try {
      final point = _locationBox?.values.firstWhere(
        (p) =>
            p.tripId == tripId &&
            p.timestamp == timestamp &&
            p.tripEventType == eventType,
        orElse: () => throw Exception('Point not found'),
      );

      if (point != null) {
        final index = point.key as int;
        final updatedPoint = LocationPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: point.timestamp,
          speed: point.speed,
          accuracy: point.accuracy,
          tripId: point.tripId,
          isSynced: true,
          tripEventType: point.tripEventType,
          groupId: point.groupId,
        );
        await _locationBox?.putAt(index, updatedPoint);
        debugPrint('[HIVE] Marked point as synced');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error marking point as synced: $e');
      return false;
    }
  }

  /// Delete location points older than retention period (7 days)
  Future<int> deleteOldPoints() async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: _dataRetentionDays),
      );
      final keysToDelete = <dynamic>[];

      _locationBox?.toMap().forEach((key, point) {
        if (point.timestamp.isBefore(cutoffDate)) {
          keysToDelete.add(key);
        }
      });

      for (var key in keysToDelete) {
        await _locationBox?.delete(key);
      }

      debugPrint(
        '[HIVE] Deleted ${keysToDelete.length} old location points (older than $_dataRetentionDays days)',
      );
      return keysToDelete.length;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error deleting old points: $e');
      return 0;
    }
  }

  /// Get statistics for a specific trip
  Map<String, dynamic> getTripStats(String tripId) {
    try {
      final points = getLocationPointsByTripId(tripId);
      final synced = points.where((p) => p.isSynced).length;
      final unsynced = points.where((p) => !p.isSynced).length;

      return {
        'total': points.length,
        'synced': synced,
        'unsynced': unsynced,
        'startTime': points.isNotEmpty ? points.first.timestamp : null,
        'endTime': points.isNotEmpty ? points.last.timestamp : null,
      };
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting trip stats: $e');
      return {'total': 0, 'synced': 0, 'unsynced': 0};
    }
  }

  /// Get all trips (unique trip IDs)
  List<String> getAllTripIds() {
    try {
      final tripIds = <String>{};
      final values = _locationBox?.values ?? [];
      for (var point in values) {
        tripIds.add(point.tripId);
      }
      return tripIds.toList();
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting trip IDs: $e');
      return [];
    }
  }

  /// Close all boxes (call on app dispose)
  Future<void> close() async {
    await _locationBox?.close();
    await _settingsBox?.close();
    await _appSettingsBox?.close();
    debugPrint('[HIVE] Hive boxes closed');
  }

  /// Get total number of stored points
  int get totalPoints => _locationBox?.length ?? 0;

  /// Check if boxes are open
  bool get isInitialized =>
      _locationBox?.isOpen == true &&
      _settingsBox?.isOpen == true &&
      _appSettingsBox?.isOpen == true;

  // -----------------------------
  // App Settings Methods
  // -----------------------------

  /// Save app settings
  Future<bool> saveAppSettings(AppSettings settings) async {
    try {
      await _appSettingsBox?.put(_appSettingsKey, settings);
      debugPrint('[HIVE] Saved app settings: $settings');
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving app settings: $e');
      return false;
    }
  }

  /// Get current app settings
  AppSettings? getAppSettings() {
    try {
      return _appSettingsBox?.get(_appSettingsKey);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting app settings: $e');
      return null;
    }
  }

  /// Save ngrok URL
  Future<bool> saveNgrokUrl(String url) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.ngrokUrl = url;
      return await saveAppSettings(settings);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving ngrok URL: $e');
      return false;
    }
  }

  /// Get ngrok URL
  String? getNgrokUrl() {
    try {
      return getAppSettings()?.ngrokUrl;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting ngrok URL: $e');
      return null;
    }
  }

  /// Save ID token
  Future<bool> saveIdToken(String token) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.idToken = token;
      return await saveAppSettings(settings);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving ID token: $e');
      return false;
    }
  }

  /// Get ID token
  String? getIdToken() {
    try {
      return getAppSettings()?.idToken;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting ID token: $e');
      return null;
    }
  }

  /// Save profile ID
  Future<bool> saveProfId(String profId) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.profId = profId;
      return await saveAppSettings(settings);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving prof ID: $e');
      return false;
    }
  }

  /// Get profile ID
  String? getProfId() {
    try {
      return getAppSettings()?.profId;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting prof ID: $e');
      return null;
    }
  }

  /// Save FCM token
  Future<bool> saveFcmToken(String token) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.fcmToken = token;
      return await saveAppSettings(settings);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving FCM token: $e');
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return getAppSettings()?.fcmToken;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting FCM token: $e');
      return null;
    }
  }

  /// Clear app settings
  Future<bool> clearAppSettings() async {
    try {
      final settings = getAppSettings();
      if (settings != null) {
        settings.clear();
        await _appSettingsBox?.put(_appSettingsKey, settings);
      }
      debugPrint('[HIVE] Cleared app settings');
      return true;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error clearing app settings: $e');
      return false;
    }
  }

  /// Save location permission status
  Future<bool> saveLocationPermission(bool granted) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.locationPermissionGranted = granted;
      return await saveAppSettings(settings);
    } catch (e) {
      debugPrint('[HIVE ERROR] Error saving location permission: $e');
      return false;
    }
  }

  /// Get location permission status
  bool? getLocationPermission() {
    try {
      return getAppSettings()?.locationPermissionGranted;
    } catch (e) {
      debugPrint('[HIVE ERROR] Error getting location permission: $e');
      return null;
    }
  }

  // ==================== GROUP STORAGE ====================

  /// Save a group to Hive
  Future<void> saveGroup(Group group) async {
    final box = await Hive.openBox<Group>('groups');
    await box.put(group.groupId, group); // Use groupId as key
    debugPrint(
      '[HIVE] Saved group to Hive: ${group.groupName} (ID: ${group.groupId})',
    );
  }

  /// Get all groups from Hive
  Future<List<Group>> getAllGroups() async {
    final box = await Hive.openBox<Group>('groups');
    return box.values.toList();
  }

  /// Get a specific group by ID
  Future<Group?> getGroup(int groupId) async {
    final box = await Hive.openBox<Group>('groups');
    return box.get(groupId);
  }

  /// Delete a group from Hive
  Future<void> deleteGroup(int groupId) async {
    final box = await Hive.openBox<Group>('groups');
    await box.delete(groupId);
    debugPrint('[HIVE] Deleted group from Hive: ID $groupId');
  }

  /// Sync groups from backend with local Hive storage
  /// Adds new groups, removes deleted groups, updates existing coordinates
  Future<Map<String, int>> syncGroupsWithBackend(
    List<dynamic>? backendGroupList,
  ) async {
    try {
      int added = 0;
      int removed = 0;
      int updated = 0;

      // Handle null or empty backend response
      final backendGroups = backendGroupList ?? [];
      debugPrint(
        '[SYNC] Starting group sync. Backend groups: ${backendGroups.length}',
      );

      // Get all existing groups from Hive
      final hiveGroups = await getAllGroups();
      final hiveGroupIds = hiveGroups.map((g) => g.groupId).toSet();
      debugPrint('[SYNC] Existing Hive groups: ${hiveGroupIds.length}');

      // Parse backend groups and extract IDs
      final backendGroupIds = <int>{};
      final backendGroupMap = <int, Map<String, dynamic>>{};

      for (var groupData in backendGroups) {
        try {
          if (groupData is Map<String, dynamic>) {
            final groupId = groupData['id'] as int?;
            if (groupId != null) {
              backendGroupIds.add(groupId);
              backendGroupMap[groupId] = groupData;
            } else {
              debugPrint('[SYNC WARNING] Group missing ID: $groupData');
            }
          }
        } catch (e) {
          debugPrint('[SYNC ERROR] Error parsing group data: $e');
        }
      }

      debugPrint('[SYNC] Parsed backend group IDs: $backendGroupIds');

      // STEP 1: Add new groups from backend
      final newGroupIds = backendGroupIds.difference(hiveGroupIds);
      for (var groupId in newGroupIds) {
        try {
          final groupData = backendGroupMap[groupId]!;
          final group = Group.fromJson(groupData);
          await saveGroup(group);
          added++;
          debugPrint(
            '[SYNC] Added new group: ${group.groupName} (ID: $groupId)',
          );
        } catch (e) {
          debugPrint('[SYNC ERROR] Failed to add group $groupId: $e');
        }
      }

      // STEP 2: Remove groups deleted on backend
      final removedGroupIds = hiveGroupIds.difference(backendGroupIds);
      for (var groupId in removedGroupIds) {
        try {
          await deleteGroup(groupId);
          removed++;
          debugPrint('[SYNC] Removed group: ID $groupId');
        } catch (e) {
          debugPrint('[SYNC ERROR] Failed to remove group $groupId: $e');
        }
      }

      // STEP 3: Update existing groups (coordinates may have changed)
      final commonGroupIds = backendGroupIds.intersection(hiveGroupIds);
      for (var groupId in commonGroupIds) {
        try {
          final backendData = backendGroupMap[groupId]!;
          final backendGroup = Group.fromJson(backendData);
          final hiveGroup = await getGroup(groupId);

          if (hiveGroup != null) {
            // Check if coordinates have changed
            final coordsChanged =
                hiveGroup.destinationLatitude !=
                    backendGroup.destinationLatitude ||
                hiveGroup.destinationLongitude !=
                    backendGroup.destinationLongitude;

            // Check if name has changed
            final nameChanged = hiveGroup.groupName != backendGroup.groupName;

            if (coordsChanged || nameChanged) {
              // Update with backend data
              hiveGroup.groupName = backendGroup.groupName;
              hiveGroup.destinationLatitude = backendGroup.destinationLatitude;
              hiveGroup.destinationLongitude =
                  backendGroup.destinationLongitude;
              await saveGroup(hiveGroup);
              updated++;
              debugPrint(
                '[SYNC] Updated group: ${hiveGroup.groupName} (ID: $groupId)',
              );
            }
          }
        } catch (e) {
          debugPrint('[SYNC ERROR] Failed to update group $groupId: $e');
        }
      }

      final summary = {
        'added': added,
        'removed': removed,
        'updated': updated,
        'total': backendGroupIds.length,
      };

      debugPrint(
        '[SYNC] Sync complete: Added=$added, Removed=$removed, Updated=$updated, Total=${summary['total']}',
      );

      return summary;
    } catch (e) {
      debugPrint('[SYNC ERROR] Group sync failed: $e');
      return {'added': 0, 'removed': 0, 'updated': 0, 'total': 0};
    }
  }
}
