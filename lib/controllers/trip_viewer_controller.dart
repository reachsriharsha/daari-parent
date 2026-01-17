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

  /// Load active trip on app restart
  /// Queries LocationPoints directly to support multiple simultaneous trips across groups
  Future<void> loadActiveTrip() async {
    try {
      logger.info('[VIEWER] Loading active trip for group $groupId...');

      // Query LocationPoints directly to find active trip for THIS group
      // This supports multiple simultaneous trips across different groups
      final activeTripData = _storageService.findActiveTripForGroup(groupId);

      if (activeTripData == null) {
        logger.info('[VIEWER] No active trip found for group $groupId');
        return;
      }

      final tripName = activeTripData['tripName'] as String;
      final fcmPoints = activeTripData['points'] as List<LocationPoint>;

      logger.info(
        '[VIEWER] Found active trip: $tripName with ${fcmPoints.length} points for group $groupId',
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
        isTripActive: true, // We only get here if trip is active
        currentLocation: pathPoints.last,
        lastEventType: lastPoint.tripEventType ?? 'trip_updated',
        lastEventDetails: 'Loaded ${pathPoints.length} points from storage',
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

      // Position camera to show current state
      _moveCameraToLocation(pathPoints.last, zoom: 15);
      // Enable wakelock for active trip
      await WakelockPlus.enable();
      logger.info(
        '[WAKELOCK] Screen wakelock enabled for loaded active trip',
      );

      notifyListeners();

      logger.info('[VIEWER] Active trip loaded successfully');
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to load active trip: $e');
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
        await announcementService.announce('$groupLabel: 1 kilometer from home');
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
        await announcementService.announce('$groupLabel: 1 kilometer from destination');
        _announcedDest1km = true;
        logger.info('[PROXIMITY] ✅ Announced 1km from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_500M && !_announcedDest500m) {
        await announcementService.announce('$groupLabel: 500 meters from destination');
        _announcedDest500m = true;
        logger.info('[PROXIMITY] ✅ Announced 500m from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_200M && !_announcedDest200m) {
        await announcementService.announce('$groupLabel: 200 meters from destination');
        _announcedDest200m = true;
        logger.info('[PROXIMITY] ✅ Announced 200m from destination');
      }

      if (distance <= PROXIMITY_THRESHOLD_100M && !_announcedDest100m) {
        await announcementService.announce('$groupLabel: 100 meters from destination');
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
