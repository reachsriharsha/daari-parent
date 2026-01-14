import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/group_service.dart';
import '../utils/app_logger.dart';
import '../route_service.dart';
import '../services/location_storage_service.dart';
import '../services/background_location_service.dart';
import '../services/notification_service.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';

/// Controller managing trip state and business logic
class TripController extends ChangeNotifier {
  // Location state
  LatLng? _pickedLocation;
  LatLng? _currentLocation;

  // Trip state - tripName is the single source of truth
  bool _tripActive = false;
  String? _tripName;
  int? _currentGroupId;

  // Route state - Enhanced with path tracking
  List<LatLng> _pathPoints = []; // Stores entire traveled path
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  RouteInfo? _routeInfo;

  // Timers and subscriptions
  Timer? _updateTimer;
  StreamSubscription<Position>? _locationSubscription;

  // Hive storage service
  final LocationStorageService _storageService;

  // Constructor accepting storage service
  TripController(this._storageService);

  // Getters
  LatLng? get pickedLocation => _pickedLocation;
  LatLng? get currentLocation => _currentLocation;
  bool get tripActive => _tripActive;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers;
  RouteInfo? get routeInfo => _routeInfo;
  List<LatLng> get pathPoints => _pathPoints; // Expose path points

  @override
  void dispose() {
    _updateTimer?.cancel();
    _locationSubscription?.cancel();
    _stopBackgroundSync();
    super.dispose();
  }

  // -----------------------------
  // Trip Recovery Methods
  // -----------------------------

  /// Check for incomplete trip and ask user to resume
  /// Returns true if there's a trip to resume
  bool hasIncompleteTrip() {
    final settings = _storageService.getTripSettings();
    return settings?.isTripActive == true;
  }

  /// Get incomplete trip info
  Map<String, dynamic>? getIncompleteTripInfo() {
    final settings = _storageService.getTripSettings();
    if (settings?.isTripActive == true) {
      return {
        'groupId': settings?.currentGroupId,
        'tripName': settings?.currentTripName,
        'startTime': settings?.tripStartTime,
      };
    }
    return null;
  }

  /// Resume incomplete trip
  Future<void> resumeTrip() async {
    final settings = _storageService.getTripSettings();
    if (settings?.isTripActive == true) {
      _currentGroupId = settings?.currentGroupId;
      _tripName = settings?.currentTripName;
      _tripActive = true;

      logger.info('[RESUME] Resuming trip: Name=$_tripName');

      // Load previous path points from Hive using tripName
      if (_tripName != null) {
        final savedPoints = _storageService.getLocationPointsByTripName(
          _tripName!,
        );
        _pathPoints = savedPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        logger.info(
          '[RESUME] Loaded ${_pathPoints.length} path points from storage',
        );
      }

      // Get current location
      await getCurrentLocation();

      // Restart location tracking
      _startLocationTracking();

      // Update map display
      await updateMapDisplay();

      notifyListeners();
    }
  }

  /// Discard incomplete trip (user chose not to resume)
  Future<void> discardIncompleteTrip() async {
    await _storageService.clearTripSettings();
    logger.info('[RESUME] Discarded incomplete trip');
  }

  // -----------------------------
  // Sync Methods
  // -----------------------------

  /// Check and sync unsynced points (called when app comes to foreground)
  Future<void> checkAndSyncUnsyncedPoints() async {
    try {
      final unsyncedPoints = _storageService.getUnsyncedPoints();

      if (unsyncedPoints.isEmpty) {
        logger.info('[SYNC] No unsynced points to upload');
        return;
      }

      logger.info(
        '[SYNC] Found ${unsyncedPoints.length} unsynced points, attempting bulk sync...',
      );

      // Group by tripName (single source of truth)
      final Map<String, List<LocationPoint>> pointsByTrip = {};
      for (var point in unsyncedPoints) {
        pointsByTrip.putIfAbsent(point.tripName, () => []).add(point);
      }

      // Sync each trip's points
      for (var entry in pointsByTrip.entries) {
        await _bulkSyncPoints(entry.value);
      }
    } catch (e) {
      logger.error('[SYNC ERROR] Error during bulk sync: $e');
    }
  }

  /// Bulk sync a list of points
  Future<void> _bulkSyncPoints(List<LocationPoint> points) async {
    if (points.isEmpty) return;

    final syncedPoints = <LocationPoint>[];

    for (var point in points) {
      try {
        // Attempt to send to backend
        final groupId = point.groupId != null
            ? int.tryParse(point.groupId!)
            : null;

        if (point.tripName.isNotEmpty && groupId != null) {
          await sendUpdateTripMsg(
            groupId: groupId,
            latitude: point.latitude,
            longitude: point.longitude,
            tripEvent: point.tripEventType ?? "update",
            tripName: point.tripName,
            onLog: (log) => logger.debug('[SYNC] Bulk sync log: $log'),
          );

          syncedPoints.add(point);
        }
      } catch (e) {
        logger.error('[SYNC ERROR] Failed to sync point: $e');
        // Continue with next point
      }
    }

    // Mark successfully synced points
    if (syncedPoints.isNotEmpty) {
      await _storageService.markPointsAsSynced(syncedPoints);
      logger.info('[SYNC] Bulk synced ${syncedPoints.length} points');
    }
  }

  // -----------------------------
  // Trip Message APIs
  // -----------------------------

  // Send start trip message to backend
  Future<Map<String, dynamic>> sendStartTripMsg({
    required int groupId,
    required double latitude,
    required double longitude,
    void Function(String log)? onLog,
  }) async {
    final idToken = _storageService.getIdToken();
    final backendUrl =
        _storageService.getNgrokUrl() ?? ""; // Read from Hive instead
    final url = Uri.parse("$backendUrl/api/groups/trip/create");

    final body = {
      "group_id": groupId,
      "coordinates": {"latitude": latitude, "longitude": longitude},
      "trip_event": "start",
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
      throw Exception(
        "Failed sendStartTripMsg: ${response.statusCode} ${response.body}",
      );
    }
  }

  // Send update trip message to backend (update/finish event)
  // tripName is the single source of truth identifier
  Future<Map<String, dynamic>> sendUpdateTripMsg({
    required int groupId,
    required double latitude,
    required double longitude,
    required String tripEvent, // "update" or "finish"
    required String tripName,
    void Function(String log)? onLog,
  }) async {
    final idToken = _storageService.getIdToken();
    final backendUrl =
        _storageService.getNgrokUrl() ?? ""; // Read from Hive instead
    final url = Uri.parse("$backendUrl/api/groups/trip/update");

    final body = {
      "group_id": groupId,
      "trip_name": tripName,
      "trip_event": tripEvent,
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
      throw Exception(
        "Failed sendUpdateTripMsg: ${response.statusCode} ${response.body}",
      );
    }
  }

  /// Initialize background service (call this in main.dart)
  static Future<void> initializeBackgroundService() async {
    await BackgroundLocationService.initializeService();
    logger.info('[BACKGROUND] Background location service initialized');
  }

  /// Get current location
  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
      await updateMapDisplay();
    } catch (e) {
      logger.error('Error getting current location: $e');
      rethrow;
    }
  }

  /// Set picked location
  void setPickedLocation(LatLng location) {
    _pickedLocation = location;
    notifyListeners();
  }

  /// Update map display including markers and polylines
  Future<void> updateMapDisplay() async {
    // Update markers
    _markers = RouteService.createRouteMarkers(
      currentLocation: _currentLocation,
      destination: _pickedLocation,
    );

    // If trip is active, show the traveled path as a polyline
    if (_tripActive && _pathPoints.isNotEmpty) {
      _updatePathPolyline();
    } else {
      // Clear any existing route polylines when trip is not active
      _polylines.clear();
      _routeInfo = null;
    }

    logger.debug(
      '[MAP] Map display updated: current=${_currentLocation != null}, destination=${_pickedLocation != null}, path points=${_pathPoints.length}',
    );
    notifyListeners();
  }

  /// Update markers and route (alias for updateMapDisplay for compatibility)
  Future<void> updateMarkersAndRoute() async {
    await updateMapDisplay();
  }

  /// Update the polyline showing the traveled path
  void _updatePathPolyline() {
    if (_pathPoints.isEmpty) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('traveled_path'),
        points: _pathPoints,
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ),
    );

    logger.debug(
      '[PATH] Path polyline updated with ${_pathPoints.length} points',
    );
  }

  /// Start live location tracking with enhanced path recording
  /// Automatically sends location updates to backend every 5 meters or 8 seconds
  void _startLocationTracking() {
    _locationSubscription?.cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update when moved 5 meters
      timeLimit: Duration(
        seconds: 8,
      ), // Or every 8 seconds (whichever comes first)
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            final latLng = LatLng(position.latitude, position.longitude);

            // Update current location
            _currentLocation = latLng;

            // Add to path points (traveled route)
            _pathPoints.add(latLng);

            logger.info(
              '[LOCATION] Location update: ${position.latitude}, ${position.longitude} (Path points: ${_pathPoints.length})',
            );

            // Update map display
            notifyListeners();
            await updateMapDisplay();

            // Send location update to backend
            if (_currentGroupId != null && _tripName != null) {
              await _sendLocationUpdate(position);
            }
          },
          onError: (error) {
            logger.error('[LOCATION ERROR] Location stream error: $error');
          },
          cancelOnError: false,
        );
  }

  /// Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    try {
      // Save to Hive first (fast, local storage)
      // tripName is the single source of truth identifier
      final locationPoint = LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
        accuracy: position.accuracy,
        tripName: _tripName!,
        tripEventType: "update",
        groupId: _currentGroupId.toString(),
        isSynced: false, // Mark as not synced initially
      );

      await _storageService.saveLocationPoint(locationPoint);

      // Then attempt to send to backend
      await sendUpdateTripMsg(
        groupId: _currentGroupId!,
        latitude: position.latitude,
        longitude: position.longitude,
        tripEvent: "update",
        tripName: _tripName!,
        onLog: (log) => logger.debug('[LOCATION] Location update log: $log'),
      );

      // Mark as synced after successful backend upload
      await _storageService.markPointAsSynced(
        _tripName!,
        locationPoint.timestamp,
        "update",
      );

      logger.info('[LOCATION] Location sent to backend and marked as synced');
    } catch (e) {
      logger.error(
        '[LOCATION ERROR] Error sending location (saved locally): $e',
      );
      // Point remains in Hive with isSynced=false for later retry
    }
  }

  /// Stop live location tracking
  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    logger.info('[LOCATION] Location tracking stopped');
  }

  /// Stop background location sync
  Future<void> _stopBackgroundSync() async {
    await BackgroundLocationService.stopService();
    logger.info('[BACKGROUND] Background service stopped');
  }

  /// Start a trip with enhanced tracking
  Future<Map<String, dynamic>> startTrip({
    required int groupId,
    required Function(String) onLog,
    VoidCallback? onTripStarted,
  }) async {
    // Validate location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // Request notification permission (Android 13+)
    final notificationGranted =
        await NotificationService.requestNotificationPermission();
    if (!notificationGranted) {
      logger.warning(
        '[NOTIFICATION WARNING] Notification permission denied - background service may not work optimally',
      );
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentLocation = LatLng(position.latitude, position.longitude);
    _currentGroupId = groupId; // Store group ID for tracking

    // Clear previous path points
    _pathPoints.clear();
    // Add starting position to path
    _pathPoints.add(_currentLocation!);

    notifyListeners();

    // Start trip via API
    String logs = "";

    try {
      final resp = await sendStartTripMsg(
        groupId: groupId,
        latitude: position.latitude,
        longitude: position.longitude,
        onLog: (log) {
          logs = log;
          onLog(log);
        },
      );

      _tripActive = true;
      // tripName is the single source of truth - ignore trip_id from response
      _tripName = resp["trip_name"];

      logger.info('[TRIP] Trip started: Name=$_tripName');

      // Save trip settings to Hive - only tripName, no tripId
      final tripSettings = TripSettings(
        isTripActive: true,
        currentGroupId: groupId,
        currentTripName: _tripName,
        tripStartTime: DateTime.now(),
      );
      await _storageService.saveTripSettings(tripSettings);

      // Save starting location point to Hive with tripName
      final startPoint = LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
        accuracy: position.accuracy,
        tripName: _tripName!,
        tripEventType: "start",
        groupId: groupId.toString(),
        isSynced: true, // Already sent to backend
      );
      await _storageService.saveLocationPoint(startPoint);

      notifyListeners();

      // Start background service for continuous tracking
      await BackgroundLocationService.startService();
      logger.info(
        '[BACKGROUND] Background service started for trip $_tripName',
      );

      // Start live location tracking (foreground) - handles location updates and backend sync
      _startLocationTracking();

      // Update initial map display
      await updateMapDisplay();

      // Notify that trip has started (for map animation)
      if (onTripStarted != null) {
        onTripStarted();
      }

      return {'success': true, 'logs': logs};
    } catch (e) {
      throw Exception(logs.isNotEmpty ? logs : e.toString());
    }
  }

  /// Send trip finish event to backend
  /// Uses tripName as the single source of truth identifier
  Future<void> _sendTripFinish(int groupId, Function(String) onLog) async {
    if (_tripName == null) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    try {
      // Save finish point to Hive first with tripName
      final finishPoint = LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        speed: position.speed,
        accuracy: position.accuracy,
        tripName: _tripName!,
        tripEventType: "finish",
        groupId: groupId.toString(),
        isSynced: false,
      );
      await _storageService.saveLocationPoint(finishPoint);

      // Send to backend using tripName
      final resp = await sendUpdateTripMsg(
        groupId: groupId,
        latitude: position.latitude,
        longitude: position.longitude,
        tripEvent: "finish",
        tripName: _tripName!,
        onLog: onLog,
      );

      // Mark finish point as synced using tripName
      await _storageService.markPointAsSynced(
        _tripName!,
        finishPoint.timestamp,
        "finish",
      );

      // Clear trip settings in Hive
      await _storageService.clearTripSettings();

      _tripActive = false;
      _stopLocationTracking();

      // Stop background service
      await BackgroundLocationService.stopService();
      logger.info('[BACKGROUND] Background service stopped');

      await _stopBackgroundSync();

      // Clear route display
      _polylines.clear();
      _routeInfo = null;

      // Log trip statistics using tripName
      final stats = _storageService.getTripStats(_tripName!);
      logger.info('[TRIP] Trip finished:');
      logger.info('   - Total points recorded: ${stats['total']}');
      logger.info('   - Synced: ${stats['synced']}');
      logger.info('   - Unsynced: ${stats['unsynced']}');

      notifyListeners();

      logger.info("[TRIP] Trip finished response: $resp");
    } catch (e) {
      logger.error("[TRIP ERROR] Trip finish failed: $e");
      // Even if backend fails, keep the finish point in Hive for later sync
      rethrow;
    }
  }

  /// Finish the current trip with complete path data
  Future<String> finishTrip(int groupId, Function(String) onLog) async {
    try {
      // Send final finish event
      await _sendTripFinish(groupId, onLog);

      // Send complete trip summary with all path points
      await _sendTripSummary(groupId, onLog);

      return "Trip finished successfully with ${_pathPoints.length} path points";
    } catch (e) {
      rethrow;
    }
  }

  /// Send complete trip summary with all collected path points
  Future<void> _sendTripSummary(int groupId, Function(String) onLog) async {
    if (_tripName == null) return;

    try {
      // Prepare trip summary data - tripName is the single source of truth
      final tripSummaryData = {
        'group_id': groupId,
        'trip_name': _tripName,
        'total_points': _pathPoints.length,
        'start_time': _pathPoints.isNotEmpty
            ? _pathPoints.first.toString()
            : 'unknown',
        'end_time': DateTime.now().toIso8601String(),
        'path': _pathPoints
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
      };

      logger.info('[SUMMARY] Trip Summary:');
      logger.info('   - Total path points: ${_pathPoints.length}');
      logger.info('   - Trip Name: $_tripName');
      logger.info(
        '   - Path data prepared: ${tripSummaryData['path'].toString().substring(0, 100)}...',
      );

      // TODO: Implement backend endpoint to receive complete path
      // When ready, uncomment and create sendTripSummary method in GroupService:
      // final backendUrl = await SharedPrefs.getString("ngrok_url") ?? "";
      // final groupService = GroupService(baseUrl: backendUrl);
      // await groupService.sendTripSummary(tripSummaryData);

      onLog('Trip summary prepared with ${_pathPoints.length} points');
    } catch (e) {
      logger.error('[SUMMARY ERROR] Error sending trip summary: $e');
    }
  }

  /// Update group address
  Future<Map<String, dynamic>> updateGroupAddress({
    required int groupId,
    required Function(String) onLog,
    VoidCallback? onSuccess,
  }) async {
    if (_pickedLocation == null) {
      throw Exception('No location picked');
    }

    final double lat = _pickedLocation!.latitude;
    final double lng = _pickedLocation!.longitude;
    final backendUrl =
        _storageService.getNgrokUrl() ?? ""; // Read from Hive instead
    final groupService = GroupService(baseUrl: backendUrl);

    try {
      final resp = await groupService.updateGroup(
        groupId: groupId,
        latitude: lat,
        longitude: lng,
        onLog: onLog,
      );

      // Notify caller of successful update
      onSuccess?.call();

      return {'success': true, 'message': resp['message']};
    } catch (e) {
      rethrow;
    }
  }

  // -----------------------------
  // FCM Driver Location Update Methods
  // -----------------------------

  /// Update driver location from FCM notification
  /// Called when receiving trip_start or trip_update notifications
  void updateDriverLocation(double latitude, double longitude) {
    try {
      final driverLocation = LatLng(latitude, longitude);

      logger.info(
        '[FCM] Updating driver location: lat=$latitude, lng=$longitude',
      );

      // Add driver marker to map
      _addDriverMarker(driverLocation);

      // If we have path points, draw polyline from path to driver
      if (_pathPoints.isNotEmpty) {
        _updateDriverPathPolyline(driverLocation);
      }

      notifyListeners();
    } catch (e) {
      logger.error('[FCM ERROR] Failed to update driver location: $e');
    }
  }

  /// Add or update driver marker on map
  void _addDriverMarker(LatLng location) {
    // Remove existing driver marker if any
    _markers.removeWhere((m) => m.markerId.value == 'driver_marker');

    // Add new driver marker
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_marker'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Driver Location',
          snippet: 'Current driver position',
        ),
      ),
    );

    logger.info('[FCM] Driver marker added at: $location');
  }

  /// Update polyline showing driver's traveled path
  void _updateDriverPathPolyline(LatLng driverLocation) {
    // Add driver location to path (optional - only if tracking driver path)
    // For now, just update the polyline to show connection

    // Create polyline showing driver's path
    final driverPathPolyline = Polyline(
      polylineId: const PolylineId('driver_path'),
      points: [..._pathPoints, driverLocation],
      color: Colors.green,
      width: 4,
      geodesic: true,
    );

    // Remove old driver path polyline
    _polylines.removeWhere((p) => p.polylineId.value == 'driver_path');

    // Add updated driver path
    _polylines.add(driverPathPolyline);

    logger.info('[FCM] Driver path polyline updated with driver location');
  }
}
