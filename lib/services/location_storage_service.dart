import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';
import '../models/app_settings.dart';
import '../models/group.dart';
import '../utils/app_logger.dart';

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

      logger.info('[HIVE] Hive initialized successfully');
      logger.info('   - Location points: ${_locationBox?.length ?? 0}');
      logger.info('   - Settings box opened');
      logger.info('   - App settings box opened');

      // Clean up old data on init
      await deleteOldPoints();
    } catch (e) {
      logger.error('[HIVE ERROR] Error initializing Hive: $e');
      rethrow;
    }
  }

  /// Save a location point to Hive
  Future<bool> saveLocationPoint(LocationPoint point) async {
    try {
      await _locationBox?.add(point);
      logger.info(
        '[HIVE] Saved location point: ${point.tripName} - ${point.tripEventType}',
      );
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error saving location point: $e');
      return false; // Continue trip even if Hive save fails
    }
  }

  /// Save or update trip settings
  Future<bool> saveTripSettings(TripSettings settings) async {
    try {
      await _settingsBox?.put(_settingsKey, settings);
      logger.info('[HIVE] Saved trip settings: $settings');
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error saving trip settings: $e');
      return false;
    }
  }

  /// Get current trip settings
  TripSettings? getTripSettings() {
    try {
      return _settingsBox?.get(_settingsKey);
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting trip settings: $e');
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
      logger.info('[HIVE] Cleared trip settings');
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error clearing trip settings: $e');
      return false;
    }
  }

  /// Get all location points for a specific trip by tripName
  /// tripName is the single source of truth identifier
  List<LocationPoint> getLocationPointsByTripName(String tripName) {
    try {
      final points =
          _locationBox?.values
              .where((point) => point.tripName == tripName)
              .toList() ??
          [];
      logger.info(
        '[HIVE] Retrieved ${points.length} points for trip $tripName',
      );
      return points;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting location points: $e');
      return [];
    }
  }

  /// Get all unsynced location points
  List<LocationPoint> getUnsyncedPoints() {
    try {
      final points =
          _locationBox?.values.where((point) => !point.isSynced).toList() ?? [];
      logger.info('[HIVE] Found ${points.length} unsynced points');
      return points;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting unsynced points: $e');
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
            tripName: point.tripName,
            isSynced: true,
            tripEventType: point.tripEventType,
            groupId: point.groupId,
          );

          // Replace the point at the same index
          await _locationBox?.putAt(index, updatedPoint);
        }
      }
      logger.info('[HIVE] Marked ${points.length} points as synced');
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error marking points as synced: $e');
      return false;
    }
  }

  /// Mark a single point as synced by finding it in the box
  /// Uses tripName as the identifier
  Future<bool> markPointAsSynced(
    String tripName,
    DateTime timestamp,
    String? eventType,
  ) async {
    try {
      final point = _locationBox?.values.firstWhere(
        (p) =>
            p.tripName == tripName &&
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
          tripName: point.tripName,
          isSynced: true,
          tripEventType: point.tripEventType,
          groupId: point.groupId,
        );
        await _locationBox?.putAt(index, updatedPoint);
        logger.info('[HIVE] Marked point as synced');
        return true;
      }
      return false;
    } catch (e) {
      logger.error('[HIVE ERROR] Error marking point as synced: $e');
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

      logger.info(
        '[HIVE] Deleted ${keysToDelete.length} old location points (older than $_dataRetentionDays days)',
      );
      return keysToDelete.length;
    } catch (e) {
      logger.error('[HIVE ERROR] Error deleting old points: $e');
      return 0;
    }
  }

  /// Get statistics for a specific trip by tripName
  Map<String, dynamic> getTripStats(String tripName) {
    try {
      final points = getLocationPointsByTripName(tripName);
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
      logger.error('[HIVE ERROR] Error getting trip stats: $e');
      return {'total': 0, 'synced': 0, 'unsynced': 0};
    }
  }

  /// Get all trips (unique trip names)
  List<String> getAllTripNames() {
    try {
      final tripNames = <String>{};
      final values = _locationBox?.values ?? [];
      for (var point in values) {
        tripNames.add(point.tripName);
      }
      return tripNames.toList();
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting trip names: $e');
      return [];
    }
  }

  /// Get all FCM-received points for a specific trip
  /// Used by TripViewerController to reconstruct remote trips
  List<LocationPoint> getFCMPointsForTrip(String tripName) {
    try {
      final points =
          _locationBox?.values
              .where((p) => p.tripName == tripName && p.source == 'fcm')
              .toList()
            ?..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      logger.info(
        '[HIVE] Retrieved ${points?.length ?? 0} FCM points for trip $tripName',
      );
      return points ?? [];
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting FCM points: $e');
      return [];
    }
  }

  /// Get all GPS-tracked points for a specific trip
  /// Used to differentiate own trips from watched trips
  List<LocationPoint> getGPSPointsForTrip(String tripName) {
    try {
      final points =
          _locationBox?.values
              .where((p) => p.tripName == tripName && p.source == 'gps')
              .toList()
            ?..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      logger.info(
        '[HIVE] Retrieved ${points?.length ?? 0} GPS points for trip $tripName',
      );
      return points ?? [];
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting GPS points: $e');
      return [];
    }
  }

  /// Get points by source type
  List<LocationPoint> getPointsBySource(String source) {
    try {
      final points = _locationBox?.values
          .where((p) => p.source == source)
          .toList();

      logger.info(
        '[HIVE] Retrieved ${points?.length ?? 0} points with source=$source',
      );
      return points ?? [];
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting points by source: $e');
      return [];
    }
  }

  /// Find active trip for a specific group by querying FCM points
  /// Returns tripName if there's an active trip, null otherwise
  /// This supports multiple simultaneous trips across different groups
  Map<String, dynamic>? findActiveTripForGroup(int groupId) {
    try {
      final groupIdStr = groupId.toString();

      // Get all FCM points for this group
      final groupPoints = _locationBox?.values
          .where((p) => p.source == 'fcm' && p.groupId == groupIdStr)
          .toList();

      if (groupPoints == null || groupPoints.isEmpty) {
        logger.debug('[HIVE] No FCM points found for group $groupId');
        return null;
      }

      // Sort by timestamp to find the most recent
      groupPoints.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Get the most recent trip name
      final mostRecentPoint = groupPoints.first;
      final tripName = mostRecentPoint.tripName;

      // Get all points for this specific trip
      final tripPoints =
          groupPoints.where((p) => p.tripName == tripName).toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Check if the last event was trip_finished
      final lastEvent = tripPoints.last.tripEventType;
      final isActive = lastEvent != 'trip_finished';

      if (!isActive) {
        logger.debug(
          '[HIVE] Most recent trip for group $groupId is finished: $tripName',
        );
        return null;
      }

      logger.info(
        '[HIVE] Found active trip for group $groupId: $tripName with ${tripPoints.length} points',
      );

      return {'tripName': tripName, 'points': tripPoints, 'isActive': true};
    } catch (e) {
      logger.error('[HIVE ERROR] Error finding active trip for group: $e');
      return null;
    }
  }

  /// Close all boxes (call on app dispose)
  Future<void> close() async {
    await _locationBox?.close();
    await _settingsBox?.close();
    await _appSettingsBox?.close();
    logger.info('[HIVE] Hive boxes closed');
  }

  /// Get total number of stored points
  int get totalPoints => _locationBox?.length ?? 0;

  /// Get all location points (for diagnostics)
  List<LocationPoint> getAllLocationPoints() {
    return _locationBox?.values.toList() ?? [];
  }

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
      logger.info('[HIVE] Saved app settings: $settings');
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error saving app settings: $e');
      return false;
    }
  }

  /// Get current app settings
  AppSettings? getAppSettings() {
    try {
      return _appSettingsBox?.get(_appSettingsKey);
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting app settings: $e');
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
      logger.error('[HIVE ERROR] Error saving ngrok URL: $e');
      return false;
    }
  }

  /// Get ngrok URL
  String? getNgrokUrl() {
    try {
      return getAppSettings()?.ngrokUrl;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting ngrok URL: $e');
      return null;
    }
  }

  /// Get ID token (fresh from Firebase, auto-refreshes if expired)
  Future<String?> getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firebase SDK handles refresh automatically if expired
        final token = await user.getIdToken();
        return token;
      }
      // Fallback: user not logged in
      logger.warning('[AUTH] No Firebase user - cannot get token');
      return null;
    } catch (e) {
      logger.error('[AUTH ERROR] Error getting fresh ID token: $e');
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
      logger.error('[HIVE ERROR] Error saving prof ID: $e');
      return false;
    }
  }

  /// Get profile ID
  String? getProfId() {
    try {
      return getAppSettings()?.profId;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting prof ID: $e');
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
      logger.error('[HIVE ERROR] Error saving FCM token: $e');
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return getAppSettings()?.fcmToken;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting FCM token: $e');
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
      logger.info('[HIVE] Cleared app settings');
      return true;
    } catch (e) {
      logger.error('[HIVE ERROR] Error clearing app settings: $e');
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
      logger.error('[HIVE ERROR] Error saving location permission: $e');
      return false;
    }
  }

  /// Get location permission status
  bool? getLocationPermission() {
    try {
      return getAppSettings()?.locationPermissionGranted;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting location permission: $e');
      return null;
    }
  }

  // -----------------------------
  // Session Management Methods
  // -----------------------------

  /// Save login timestamp
  Future<bool> saveLoginTimestamp(DateTime timestamp) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.lastLoginTimestamp = timestamp;
      return await saveAppSettings(settings);
    } catch (e) {
      logger.error('[HIVE ERROR] Error saving login timestamp: $e');
      return false;
    }
  }

  /// Get login timestamp
  DateTime? getLoginTimestamp() {
    try {
      return getAppSettings()?.lastLoginTimestamp;
    } catch (e) {
      logger.error('[HIVE ERROR] Error getting login timestamp: $e');
      return null;
    }
  }

  /// Check if current session is valid (within 24 hours)
  Future<bool> isSessionValid() async {
    try {
      // Check 1: Firebase user must be logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logger.debug('[SESSION] No Firebase user logged in');
        return false;
      }

      // Check 2: Profile ID must exist
      final profId = getProfId();
      if (profId == null || profId.isEmpty) {
        logger.debug('[SESSION] Missing profile ID');
        return false;
      }

      // Check 3: Verify timestamp is within 24 hours
      final timestamp = getLoginTimestamp();
      if (timestamp == null) {
        logger.debug('[SESSION] No login timestamp found');
        return false;
      }

      final now = DateTime.now();
      final difference = now.difference(timestamp);
      final isWithin24Hours = difference.inHours < 24;

      if (!isWithin24Hours) {
        logger.debug(
          '[SESSION] Session expired: ${difference.inHours} hours old',
        );
        return false;
      }

      logger.debug(
        '[SESSION] Session valid: ${24 - difference.inHours} hours remaining',
      );
      return true;
    } catch (e) {
      logger.error('[SESSION ERROR] Error validating session: $e');
      return false;
    }
  }

  /// Clear session data (for logout)
  Future<bool> clearSession() async {
    try {
      var settings = getAppSettings() ?? AppSettings();

      // Clear authentication-related fields
      settings.profId = null;
      settings.lastLoginTimestamp = null;

      // Keep backend URL and other settings for convenience

      await saveAppSettings(settings);
      logger.info('[SESSION] Session data cleared');
      return true;
    } catch (e) {
      logger.error('[SESSION ERROR] Error clearing session: $e');
      return false;
    }
  }

  // -----------------------------
  // Home Coordinates Methods
  // -----------------------------

  /// Save home coordinates, address, and place name to Hive
  Future<bool> saveHomeCoordinates({
    required double latitude,
    required double longitude,
    String? address,
    String? placeName,
  }) async {
    try {
      var settings = getAppSettings() ?? AppSettings();
      settings.homeLatitude = latitude;
      settings.homeLongitude = longitude;
      settings.homeAddress = address;
      settings.homePlaceName = placeName;
      final success = await saveAppSettings(settings);
      if (success) {
        logger.debug(
          '[STORAGE] Home saved: $placeName at ($latitude, $longitude) - $address',
        );
      }
      return success;
    } catch (e) {
      logger.error('[STORAGE ERROR] Failed to save home data: $e');
      return false;
    }
  }

  /// Retrieve home coordinates from Hive
  /// Returns null if not set
  Map<String, double>? getHomeCoordinates() {
    try {
      final settings = getAppSettings();
      final latitude = settings?.homeLatitude;
      final longitude = settings?.homeLongitude;

      if (latitude != null && longitude != null) {
        return {'latitude': latitude, 'longitude': longitude};
      }
      return null;
    } catch (e) {
      logger.error('[STORAGE ERROR] Failed to get home coordinates: $e');
      return null;
    }
  }

  /// Check if home coordinates exist
  bool hasHomeCoordinates() {
    final coords = getHomeCoordinates();
    return coords != null;
  }

  /// Get home address
  String? getHomeAddress() {
    try {
      final settings = getAppSettings();
      return settings?.homeAddress;
    } catch (e) {
      logger.error('[STORAGE ERROR] Failed to get home address: $e');
      return null;
    }
  }

  /// Get home place name
  String? getHomePlaceName() {
    try {
      final settings = getAppSettings();
      return settings?.homePlaceName;
    } catch (e) {
      logger.error('[STORAGE ERROR] Failed to get home place name: $e');
      return null;
    }
  }

  /// Get complete home data (coordinates + address + place name)
  Map<String, dynamic>? getHomeData() {
    try {
      final settings = getAppSettings();
      final latitude = settings?.homeLatitude;
      final longitude = settings?.homeLongitude;
      final address = settings?.homeAddress;
      final placeName = settings?.homePlaceName;

      if (latitude != null && longitude != null) {
        return {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'place_name': placeName,
        };
      }
      return null;
    } catch (e) {
      logger.error('[STORAGE ERROR] Failed to get home data: $e');
      return null;
    }
  }

  // ==================== GROUP STORAGE ====================

  /// Save a group to Hive
  Future<void> saveGroup(Group group) async {
    final box = await Hive.openBox<Group>('groups');
    await box.put(group.groupId, group); // Use groupId as key
    logger.info(
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
    logger.info('[HIVE] Deleted group from Hive: ID $groupId');
  }

  /// Remove a group from Hive (alias for deleteGroup)
  Future<void> removeGroup(int groupId) async {
    await deleteGroup(groupId);
  }

  /// Create a group from JSON data and save it to Hive
  Future<Group> createGroupFromJson(Map<String, dynamic> json) async {
    final group = Group.fromJson(json);
    await saveGroup(group);
    logger.info(
      '[HIVE] Created group from JSON: ${group.groupName} (ID: ${group.groupId})',
    );
    return group;
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
      logger.info(
        '[SYNC] Starting group sync. Backend groups: ${backendGroups.length}',
      );

      // Get all existing groups from Hive
      final hiveGroups = await getAllGroups();
      final hiveGroupIds = hiveGroups.map((g) => g.groupId).toSet();
      logger.info('[SYNC] Existing Hive groups: ${hiveGroupIds.length}');

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
              logger.warning('[SYNC WARNING] Group missing ID: $groupData');
            }
          }
        } catch (e) {
          logger.error('[SYNC ERROR] Error parsing group data: $e');
        }
      }

      logger.info('[SYNC] Parsed backend group IDs: $backendGroupIds');

      // STEP 1: Add new groups from backend
      final newGroupIds = backendGroupIds.difference(hiveGroupIds);
      for (var groupId in newGroupIds) {
        try {
          final groupData = backendGroupMap[groupId]!;
          final group = Group.fromJson(groupData);
          await saveGroup(group);
          added++;
          logger.info(
            '[SYNC] Added new group: ${group.groupName} (ID: $groupId)',
          );
        } catch (e) {
          logger.error('[SYNC ERROR] Failed to add group $groupId: $e');
        }
      }

      // STEP 2: Remove groups deleted on backend
      final removedGroupIds = hiveGroupIds.difference(backendGroupIds);
      for (var groupId in removedGroupIds) {
        try {
          await deleteGroup(groupId);
          removed++;
          logger.info('[SYNC] Removed group: ID $groupId');
        } catch (e) {
          logger.error('[SYNC ERROR] Failed to remove group $groupId: $e');
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

            // Check if address or placeName have changed
            final addressChanged = hiveGroup.address != backendGroup.address;
            final placeNameChanged =
                hiveGroup.placeName != backendGroup.placeName;

            // Check if admin or driver phone numbers have changed
            final adminPhoneChanged =
                hiveGroup.adminPhoneNumber != backendGroup.adminPhoneNumber;
            final driverPhoneChanged =
                hiveGroup.driverPhoneNumber != backendGroup.driverPhoneNumber;

            if (coordsChanged ||
                nameChanged ||
                addressChanged ||
                placeNameChanged ||
                adminPhoneChanged ||
                driverPhoneChanged) {
              // Update with backend data
              hiveGroup.groupName = backendGroup.groupName;
              hiveGroup.destinationLatitude = backendGroup.destinationLatitude;
              hiveGroup.destinationLongitude =
                  backendGroup.destinationLongitude;
              hiveGroup.address = backendGroup.address;
              hiveGroup.placeName = backendGroup.placeName;
              hiveGroup.adminPhoneNumber = backendGroup.adminPhoneNumber;
              hiveGroup.driverPhoneNumber = backendGroup.driverPhoneNumber;
              await saveGroup(hiveGroup);
              updated++;
              logger.info(
                '[SYNC] Updated group: ${hiveGroup.groupName} (ID: $groupId)',
              );
            }
          }
        } catch (e) {
          logger.error('[SYNC ERROR] Failed to update group $groupId: $e');
        }
      }

      final summary = {
        'added': added,
        'removed': removed,
        'updated': updated,
        'total': backendGroupIds.length,
      };

      logger.info(
        '[SYNC] Sync complete: Added=$added, Removed=$removed, Updated=$updated, Total=${summary['total']}',
      );

      return summary;
    } catch (e) {
      logger.error('[SYNC ERROR] Group sync failed: $e');
      return {'added': 0, 'removed': 0, 'updated': 0, 'total': 0};
    }
  }
}
