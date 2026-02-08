import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';
import '../models/trip_status_data.dart';
import '../models/trip_update_data.dart';
import '../models/trip_viewing_state.dart';
import '../services/announcement_service.dart';
import '../services/backend_com_service.dart';
import '../services/location_storage_service.dart';
import '../utils/app_logger.dart';
import '../utils/distance_calculator.dart';

/// Controller for viewing remote trips (parent app functionality)
/// Manages state, map visualization, and persistence for FCM-received trip updates
class TripViewerController extends ChangeNotifier {
  final LocationStorageService _storageService;
  final int groupId;

  // Current viewing state
  TripViewingState _viewingState = TripViewingState.empty();

  // Map visualization
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Status for UI display
  final ValueNotifier<TripStatusData?> statusNotifier = ValueNotifier(null);

  // Map controller for camera control
  GoogleMapController? _mapController;

  // Proximity announcement state (Home)
  bool _announced1km = false;
  bool _announced500m = false;
  bool _announced200m = false;
  bool _announced100m = false;

  // Proximity announcement state (Destination)
  bool _announcedDest1km = false;
  bool _announcedDest500m = false;
  bool _announcedDest200m = false;
  bool _announcedDest100m = false;
  bool _announcedDestReached = false; // < 50m

  // Cached destination for the current group
  LatLng? _groupDestination;

  // Cached group name for announcements
  String? _groupName;

  TripViewerController({
    required LocationStorageService storageService,
    required this.groupId,
  }) : _storageService = storageService;

  // Getters
  TripViewingState get viewingState => _viewingState;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  bool get isTripActive => _viewingState.isTripActive;
  bool get hasActiveTrip => _viewingState.hasData && _viewingState.isTripActive;

  /// Set map controller for camera operations
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Handle trip start event
  Future<void> handleTripStart(TripUpdateData data) async {
    try {
      logger.info('[VIEWER] Handling trip start: ${data.tripName}');

      // Load group name from Hive storage (FCM doesn't include it to reduce payload)
      await _loadGroupName(data.groupId);

      // Reset proximity announcement flags for new trip
      _announced1km = false;
      _announced500m = false;
      _announced200m = false;
      _announced100m = false;

      // Reset destination proximity flags
      _announcedDest1km = false;
      _announcedDest500m = false;
      _announcedDest200m = false;
      _announcedDest100m = false;
      _announcedDestReached = false;
      _groupDestination = null;

      final startLocation = LatLng(data.latitude, data.longitude);

      // Create new viewing state
      _viewingState = TripViewingState.initial(
        tripName: data.tripName,
        groupId: data.groupId,
        startLocation: startLocation,
        startTime: data.timestamp,
      );

      // Save to Hive
      await _saveTripPoint(data, isStartPoint: true);

      // Save watching trip to TripSettings
      await _saveWatchingTrip(data.tripName, data.groupId);

      // Load group destination
      await _loadGroupDestination(data.groupId);

      // Update map markers
      _updateMarkers();
      _polylines.clear();
      _updatePolyline();

      // Update status widget
      _updateStatusWidget(data);

      // Move camera to start location
      _moveCameraToLocation(startLocation, zoom: 15);

      // Enable wakelock to keep screen on while tracking trip
      await WakelockPlus.enable();
      logger.info('[WAKELOCK] Screen wakelock enabled for trip tracking');

      notifyListeners();

      logger.info(
        '[VIEWER] Trip start handled: ${_viewingState.totalPoints} points',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to handle trip start: $e');
    }
  }

  /// Handle trip update event
  Future<void> handleTripUpdate(TripUpdateData data) async {
    try {
      logger.info(
        '[VIEWER] Handling trip update: ${data.latitude}, ${data.longitude}',
      );

      // Ignore updates for different trip
      if (_viewingState.tripName != data.tripName) {
        logger.info(
          '[VIEWER] Ignoring update for different trip: ${data.tripName}',
        );
        return;
      }

      final newLocation = LatLng(data.latitude, data.longitude);

      // Add point to viewing state
      _viewingState = _viewingState.addPoint(
        newLocation,
        eventType: data.eventType,
      );

      // Save to Hive
      await _saveTripPoint(data);

      // Update map visualization
      _updateMarkers();
      // Check proximity to destination
      await _checkProximityToDestination(data.latitude, data.longitude);

      _updatePolyline();

      // Update status widget
      _updateStatusWidget(data);

      // Follow current location
      _moveCameraToLocation(newLocation);

      // Check proximity to home after processing location update
      await _checkProximityToHome(data.latitude, data.longitude);

      notifyListeners();

      logger.info(
        '[VIEWER] Trip update handled: ${_viewingState.totalPoints} points',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to handle trip update: $e');
    }
  }

  /// Handle trip finish event
  Future<void> handleTripFinish(TripUpdateData data) async {
    try {
      logger.info('[VIEWER] Handling trip finish: ${data.tripName}');

      // Ignore finish for different trip
      if (_viewingState.tripName != data.tripName) {
        logger.info(
          '[VIEWER] Ignoring finish for different trip: ${data.tripName}',
        );
        return;
      }

      final finalLocation = LatLng(data.latitude, data.longitude);

      // Add final point and mark as finished
      _viewingState = _viewingState.addPoint(
        finalLocation,
        eventType: data.eventType,
      );
      _viewingState = _viewingState.finish(finalLocation: finalLocation);

      // Save final point to Hive
      await _saveTripPoint(data, isEndPoint: true);

      // Clear watching trip from TripSettings
      await _clearWatchingTrip();

      // Update map visualization
      _updateMarkers();
      _updatePolyline();

      // Update status widget
      _updateStatusWidget(data);

      // Fit camera to show entire path
      _fitCameraToPath();

      // Disable wakelock - allow screen to lock normally
      await WakelockPlus.disable();
      logger.info('[WAKELOCK] Screen wakelock disabled');

      notifyListeners();

      logger.info(
        '[VIEWER] Trip finish handled: ${_viewingState.totalPoints} total points',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to handle trip finish: $e');
    }
  }

  /// DES-TRP001: Load active trip with 3-tier optimization
  /// Tier 1: In-memory check (0ms) - Return immediately if trip already loaded
  /// Tier 2: Hive cache (<50ms) - Check local storage with freshness validation
  /// Tier 3: Backend API (<500ms) - Fetch from backend if cache stale/missing
  Future<void> loadActiveTrip() async {
    try {
      logger.info('[VIEWER] Loading active trip for group $groupId...');

      // Tier 1: In-memory check - Already loaded?
      if (_viewingState.isTripActive && _viewingState.groupId == groupId) {
        logger.debug(
          '[VIEWER] Tier 1: Trip already loaded in memory (${_viewingState.tripName}, ${_viewingState.totalPoints} points)',
        );
        return; // 0ms - instant return
      }

      // Tier 2: Hive cache check with freshness validation
      final activeTripData = _storageService.findActiveTripForGroup(groupId);

      if (activeTripData != null && !alwaysRefreshFromBackend) {
        final fcmPoints = activeTripData['points'] as List<LocationPoint>;

        if (fcmPoints.isNotEmpty) {
          final lastPointTime = fcmPoints.last.timestamp;
          final ageMinutes = DateTime.now().difference(lastPointTime).inMinutes;

          if (ageMinutes < tripCacheFreshnessMinutes) {
            // Cache is fresh - load from Hive
            logger.info(
              '[VIEWER] Tier 2: Loading from fresh Hive cache (age: ${ageMinutes}min)',
            );
            await _loadFromHiveData(activeTripData);
            return; // <50ms
          } else {
            logger.info(
              '[VIEWER] Tier 2: Hive cache stale (age: ${ageMinutes}min), trying backend...',
            );
          }
        }
      }

      // Tier 3: Backend sync - either cache missing, stale, or forced refresh
      try {
        logger.info('[VIEWER] Tier 3: Querying backend for active trip...');
        await _loadFromBackend();

        // Clear stale cache if backend had no active trip
        if (!_viewingState.isTripActive && activeTripData != null) {
          logger.info(
            '[VIEWER] Clearing stale cache (backend has no active trip)',
          );
          await _clearStaleCache();
        }

        return; // <500ms
      } catch (e) {
        logger.error('[VIEWER ERROR] Backend sync failed: $e');

        // Graceful degradation: Fall back to stale cache if backend fails
        if (activeTripData != null) {
          logger.info(
            '[VIEWER] Falling back to stale Hive cache due to backend error',
          );
          await _loadFromHiveData(activeTripData);
        } else {
          logger.info('[VIEWER] No fallback data available');
        }
      }
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load active trip: $e');
    }
  }

  /// DES-TRP001: Load trip data from Hive cache
  Future<void> _loadFromHiveData(Map<String, dynamic> activeTripData) async {
    try {
      final tripName = activeTripData['tripName'] as String;
      final fcmPoints = activeTripData['points'] as List<LocationPoint>;

      logger.info(
        '[VIEWER] Loading from Hive: $tripName with ${fcmPoints.length} points',
      );

      // Load group destination and name
      await _loadGroupDestination(groupId);
      await _loadGroupName(groupId);

      // Rebuild viewing state
      final pathPoints = fcmPoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      final lastPoint = fcmPoints.last;

      _viewingState = TripViewingState(
        tripName: tripName,
        groupId: groupId,
        pathPoints: pathPoints,
        tripStartTime: fcmPoints.first.timestamp,
        lastUpdateTime: lastPoint.timestamp,
        isTripActive: true,
        currentLocation: pathPoints.last,
        lastEventType: lastPoint.tripEventType ?? 'trip_updated',
        lastEventDetails:
            'Loaded ${pathPoints.length} points from Hive (source: ${tripSourceHiveCache})',
      );

      // Rebuild map visualization
      _updateMarkers();
      _updatePolyline();

      // Update status widget
      statusNotifier.value = TripStatusData.fromTripUpdate(
        eventType: lastPoint.tripEventType ?? 'trip_updated',
        latitude: lastPoint.latitude,
        longitude: lastPoint.longitude,
        timestamp: lastPoint.timestamp,
      );

      // Position camera to driver's current location
      _moveCameraToLocation(pathPoints.last, zoom: 15);

      // Enable wakelock for active trip
      await WakelockPlus.enable();
      logger.info('[WAKELOCK] Screen wakelock enabled for loaded active trip');

      notifyListeners();
      logger.info('[VIEWER] Successfully loaded trip from Hive cache');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load from Hive data: $e');
      rethrow;
    }
  }

  /// DES-TRP001: Load trip data from backend API
  Future<void> _loadFromBackend() async {
    try {
      final backendService = BackendComService.instance;
      final response = await backendService.getActiveTrip(groupId);

      if (response['has_active_trip'] != true) {
        logger.info(
          '[VIEWER] Backend reports no active trip for group $groupId',
        );
        _viewingState = TripViewingState.empty();
        notifyListeners();
        return;
      }

      // Extract trip data from backend response
      final tripName = response['trip_name'] as String;
      final tripRoute = response['trip_route'] as List<dynamic>;

      if (tripRoute.isEmpty) {
        logger.warning(
          '[VIEWER] Backend returned active trip but route is empty',
        );
        return;
      }

      logger.info(
        '[VIEWER] Loading from backend: $tripName with ${tripRoute.length} points',
      );

      // Load group destination and name
      await _loadGroupDestination(groupId);
      await _loadGroupName(groupId);

      // Build path points from backend route
      final pathPoints = tripRoute
          .map(
            (point) => LatLng(
              point['latitude'] as double,
              point['longitude'] as double,
            ),
          )
          .toList();

      // Parse timestamps
      final startedAt = DateTime.parse(response['started_at'] as String);
      final lastUpdate = DateTime.parse(response['last_update'] as String);
      final lastEvent = (tripRoute.last['event'] ?? 'trip_updated') as String;

      // Create viewing state
      _viewingState = TripViewingState(
        tripName: tripName,
        groupId: groupId,
        pathPoints: pathPoints,
        tripStartTime: startedAt,
        lastUpdateTime: lastUpdate,
        isTripActive: true,
        currentLocation: pathPoints.last,
        lastEventType: lastEvent,
        lastEventDetails:
            'Loaded ${pathPoints.length} points from backend (source: $tripSourceBackend)',
      );

      // Rebuild map visualization
      _updateMarkers();
      _updatePolyline();

      // Update status widget
      final lastPoint = tripRoute.last;
      statusNotifier.value = TripStatusData(
        eventType: lastEvent,
        latitude: lastPoint['latitude'] as double,
        longitude: lastPoint['longitude'] as double,
        timestamp: lastUpdate,
      );

      // Position camera to driver's current location
      _moveCameraToLocation(pathPoints.last, zoom: 15);

      // Persist to Hive for offline access
      await _persistBackendDataToHive(tripRoute, tripName);

      // Enable wakelock for active trip
      await WakelockPlus.enable();
      logger.info('[WAKELOCK] Screen wakelock enabled for backend-loaded trip');

      notifyListeners();
      logger.info('[VIEWER] Successfully loaded trip from backend');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load from backend: $e');
      rethrow;
    }
  }

  /// DES-TRP001: Persist backend trip data to Hive for offline access
  Future<void> _persistBackendDataToHive(
    List<dynamic> tripRoute,
    String tripName,
  ) async {
    try {
      for (final point in tripRoute) {
        final locationPoint = LocationPoint(
          source: 'fcm', // Mark as FCM to maintain compatibility
          tripName: tripName,
          groupId: groupId.toString(),
          latitude: point['latitude'] as double,
          longitude: point['longitude'] as double,
          timestamp: DateTime.parse(point['timestamp'] as String),
          tripEventType: point['event'] as String?,
          receivedAt: DateTime.now(),
        );
        await _storageService.saveLocationPoint(locationPoint);
      }
      logger.debug(
        '[VIEWER] Persisted ${tripRoute.length} backend points to Hive for offline access',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to persist backend data to Hive: $e');
      // Don't rethrow - persistence failure shouldn't block trip display
    }
  }

  /// DES-TRP001: Clear stale cache when backend has no active trip
  Future<void> _clearStaleCache() async {
    try {
      // Note: LocationStorageService doesn't have a direct "clear trip" method
      // The natural cleanup happens via markTripFinished or 7-day auto-cleanup
      // No action needed here - stale data will be ignored on next load
      logger.debug('[VIEWER] Stale cache will be ignored (marked inactive)');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to clear stale cache: $e');
    }
  }

  /// Update map markers based on current state
  void _updateMarkers() {
    _markers.clear();

    if (_viewingState.isEmpty) return;

    final points = _viewingState.pathPoints;

    // Start marker (black/violet)
    if (points.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: const MarkerId('trip_start'),
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
    }

    // Current location marker (red) - only if trip is active
    if (_viewingState.isTripActive && points.length > 1) {
      _markers.add(
        Marker(
          markerId: const MarkerId('trip_current'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    }

    // End marker (green) - only if trip is finished
    if (!_viewingState.isTripActive && points.length > 1) {
      _markers.add(
        Marker(
          markerId: const MarkerId('trip_end'),
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );
    }
  }

  /// Update polyline based on current path
  void _updatePolyline() {
    //_polylines.clear();

    if (_viewingState.pathPoints.length < 2) return;

    _polylines.add(
      Polyline(
        polylineId: PolylineId('trip_path_${_viewingState.tripName}'),
        points: _viewingState.pathPoints,
        color: Colors.blue,
        width: 6,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  /// Update status widget with trip data
  void _updateStatusWidget(TripUpdateData data) {
    statusNotifier.value = TripStatusData.fromTripUpdate(
      eventType: data.eventType,
      latitude: data.latitude,
      longitude: data.longitude,
      timestamp: data.timestamp,
      driverName: data.driverName,
    );
  }

  /// Save trip point to Hive
  Future<void> _saveTripPoint(
    TripUpdateData data, {
    bool isStartPoint = false,
    bool isEndPoint = false,
  }) async {
    try {
      final point = LocationPoint(
        latitude: data.latitude,
        longitude: data.longitude,
        timestamp: data.timestamp,
        tripName: data.tripName,
        groupId: data.groupId.toString(),
        tripEventType: data.eventType,
        source: 'fcm',
        receivedAt: DateTime.now(),
        isSynced: true, // FCM points are already from server
      );

      await _storageService.saveLocationPoint(point);

      logger.info(
        '[VIEWER] Saved FCM point: ${data.eventType} at ${data.latitude}, ${data.longitude}',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to save trip point: $e');
    }
  }

  /// Save watching trip to TripSettings
  Future<void> _saveWatchingTrip(String tripName, int groupId) async {
    try {
      final settings = _storageService.getTripSettings() ?? TripSettings();
      settings.watchingTripName = tripName;
      settings.watchingGroupId = groupId;
      await _storageService.saveTripSettings(settings);

      logger.info('[VIEWER] Saved watching trip: $tripName');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to save watching trip: $e');
    }
  }

  /// Clear watching trip from TripSettings
  Future<void> _clearWatchingTrip() async {
    try {
      final settings = _storageService.getTripSettings();
      if (settings != null) {
        settings.clearWatching();
        await _storageService.saveTripSettings(settings);
      }

      logger.info('[VIEWER] Cleared watching trip');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to clear watching trip: $e');
    }
  }

  /// Move camera to specific location
  void _moveCameraToLocation(LatLng location, {double zoom = 16}) {
    if (_mapController == null) return;

    try {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, zoom));
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to move camera: $e');
    }
  }

  /// Fit camera to show entire path
  void _fitCameraToPath() {
    if (_mapController == null || _viewingState.pathPoints.length < 2) return;

    try {
      final bounds = _calculateBounds(_viewingState.pathPoints);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50), // 50px padding
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to fit camera: $e');
    }
  }

  /// Calculate bounds for a list of points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Clear all trip data and reset state
  Future<void> clearTrip() async {
    _viewingState = TripViewingState.empty();
    _markers.clear();
    _polylines.clear();
    statusNotifier.value = null;
    // Disable wakelock when clearing trip
    await WakelockPlus.disable();
    notifyListeners();
    logger.info('[VIEWER] Trip data cleared');
  }

  /// Position camera based on current trip state
  /// If no active trip -> zoom to group destination
  /// If active trip -> zoom to driver's current location
  Future<void> positionCameraByTripState() async {
    if (_mapController == null) {
      logger.debug(
        '[VIEWER] Map controller not set, skipping camera positioning',
      );
      return;
    }

    try {
      // Check if there's an active trip with data
      if (_viewingState.isTripActive && _viewingState.pathPoints.isNotEmpty) {
        // Active trip exists - zoom to driver's current location (last point)
        final currentLocation = _viewingState.pathPoints.last;
        logger.info(
          '[VIEWER] Positioning camera to driver location: ${currentLocation.latitude}, ${currentLocation.longitude}',
        );
        _moveCameraToLocation(currentLocation, zoom: 15);
      } else if (_groupDestination != null) {
        // No active trip - zoom to group destination
        logger.info(
          '[VIEWER] No active trip, positioning camera to destination: ${_groupDestination!.latitude}, ${_groupDestination!.longitude}',
        );
        _moveCameraToLocation(_groupDestination!, zoom: 15);
      } else {
        logger.debug(
          '[VIEWER] No active trip and no destination set - skipping camera positioning',
        );
      }
    } catch (e) {
      logger.error(
        '[VIEWER ERROR] Failed to position camera by trip state: $e',
      );
    }
  }

  /// Check proximity to home and announce when crossing thresholds
  Future<void> _checkProximityToHome(
    double currentLat,
    double currentLon,
  ) async {
    try {
      // 1. Get home coordinates from Hive
      final homeCoords = _storageService.getHomeCoordinates();
      if (homeCoords == null) {
        // No home address set - skip proximity check
        logger.debug('[PROXIMITY] No home coordinates set - skipping check');
        return;
      }

      // 2. Calculate distance using Haversine formula
      final distance = calculateDistance(
        lat1: currentLat,
        lon1: currentLon,
        lat2: homeCoords['latitude']!,
        lon2: homeCoords['longitude']!,
      );

      logger.debug(
        '[PROXIMITY] Distance to home: ${distance.toStringAsFixed(0)}m',
      );

      // 3. Check thresholds (descending order - larger first)
      // This ensures all applicable announcements trigger if driver goes from >1km to <100m in one update
      final groupLabel = _groupName ?? 'your group';

      if (distance <= PROXIMITY_THRESHOLD_1KM && !_announced1km) {
        await announcementService.announce(
          '$groupLabel: 1 kilometer from home',
        );
        _announced1km = true;
        logger.info('[PROXIMITY] ✅ Announced 1km threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_500M && !_announced500m) {
        await announcementService.announce('$groupLabel: 500 meters from home');
        _announced500m = true;
        logger.info('[PROXIMITY] ✅ Announced 500m threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_200M && !_announced200m) {
        await announcementService.announce('$groupLabel: 200 meters from home');
        _announced200m = true;
        logger.info('[PROXIMITY] ✅ Announced 200m threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_100M && !_announced100m) {
        await announcementService.announce('$groupLabel: 100 meters from home');
        _announced100m = true;
        logger.info('[PROXIMITY] ✅ Announced 100m threshold');
      }
    } catch (e) {
      logger.error('[PROXIMITY ERROR] Failed to check proximity: $e');
    }
  }

  /// Check proximity to destination and announce when crossing thresholds
  Future<void> _checkProximityToDestination(
    double currentLat,
    double currentLon,
  ) async {
    try {
      // 1. Check if destination is available
      if (_groupDestination == null) return;

      // 2. Calculate distance using Haversine formula
      final distance = calculateDistance(
        lat1: currentLat,
        lon1: currentLon,
        lat2: _groupDestination!.latitude,
        lon2: _groupDestination!.longitude,
      );

      logger.debug(
        '[PROXIMITY] Distance to destination: ${distance.toStringAsFixed(0)}m',
      );

      // 3. Check thresholds (descending order)
      final groupLabel = _groupName ?? 'your group';

      if (distance <= PROXIMITY_THRESHOLD_1KM && !_announcedDest1km) {
        await announcementService.announce(
          '$groupLabel: 1 kilometer from destination',
        );
        _announcedDest1km = true;
        logger.info('[PROXIMITY] ✅ Announced 1km from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_500M && !_announcedDest500m) {
        await announcementService.announce(
          '$groupLabel: 500 meters from destination',
        );
        _announcedDest500m = true;
        logger.info('[PROXIMITY] ✅ Announced 500m from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_200M && !_announcedDest200m) {
        await announcementService.announce(
          '$groupLabel: 200 meters from destination',
        );
        _announcedDest200m = true;
        logger.info('[PROXIMITY] ✅ Announced 200m from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_100M && !_announcedDest100m) {
        await announcementService.announce(
          '$groupLabel: 100 meters from destination',
        );
        _announcedDest100m = true;
        logger.info('[PROXIMITY] ✅ Announced 100m from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_50M && !_announcedDestReached) {
        await announcementService.announce('$groupLabel: Destination reached');
        _announcedDestReached = true;
        logger.info('[PROXIMITY] ✅ Announced destination reached');
      }
    } catch (e) {
      logger.error(
        '[PROXIMITY ERROR] Failed to check destination proximity: $e',
      );
    }
  }

  /// Load group destination coordinates
  Future<void> _loadGroupDestination(int groupId) async {
    try {
      final group = await _storageService.getGroup(groupId);
      if (group != null &&
          group.destinationLatitude != 0.0 &&
          group.destinationLongitude != 0.0) {
        _groupDestination = LatLng(
          group.destinationLatitude,
          group.destinationLongitude,
        );
        logger.info('[VIEWER] Loaded group destination: $_groupDestination');
      } else {
        _groupDestination = null;
      }
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load group destination: $e');
    }
  }

  /// Load group name for announcements
  Future<void> _loadGroupName(int groupId) async {
    try {
      final group = await _storageService.getGroup(groupId);
      if (group != null) {
        _groupName = group.groupName;
        logger.info('[VIEWER] Loaded group name: $_groupName');
      }
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load group name: $e');
    }
  }

  @override
  void dispose() {
    statusNotifier.dispose();
    super.dispose();
  }
}
