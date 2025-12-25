import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  // Proximity announcement state
  bool _announced1km = false;
  bool _announced500m = false;
  bool _announced200m = false;
  bool _announced100m = false;

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
      logger.info('[VIEWER] Handling trip start: ${data.tripId}');

      // Reset proximity announcement flags for new trip
      _announced1km = false;
      _announced500m = false;
      _announced200m = false;
      _announced100m = false;

      final startLocation = LatLng(data.latitude, data.longitude);

      // Create new viewing state
      _viewingState = TripViewingState.initial(
        tripId: data.tripId,
        groupId: data.groupId,
        startLocation: startLocation,
        startTime: data.timestamp,
      );

      // Save to Hive
      await _saveTripPoint(data, isStartPoint: true);

      // Save watching trip to TripSettings
      await _saveWatchingTrip(data.tripId, data.groupId);

      // Update map markers
      _updateMarkers();
      _polylines.clear();
      _updatePolyline();

      // Update status widget
      _updateStatusWidget(data);

      // Move camera to start location
      _moveCameraToLocation(startLocation, zoom: 15);

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
      if (_viewingState.tripId != data.tripId) {
        logger.info(
          '[VIEWER] Ignoring update for different trip: ${data.tripId}',
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
      logger.info('[VIEWER] Handling trip finish: ${data.tripId}');

      // Ignore finish for different trip
      if (_viewingState.tripId != data.tripId) {
        logger.info(
          '[VIEWER] Ignoring finish for different trip: ${data.tripId}',
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

      notifyListeners();

      logger.info(
        '[VIEWER] Trip finish handled: ${_viewingState.totalPoints} total points',
      );
    } catch (e) {
      logger.error('[VIEWER ERROR] Failed to handle trip finish: $e');
    }
  }

  /// Load active trip on app restart
  Future<void> loadActiveTrip() async {
    try {
      logger.info('[VIEWER] Loading active trip...');

      // Check TripSettings for watching trip
      final tripSettings = _storageService.getTripSettings();
      final watchingTripId = tripSettings?.watchingTripId;

      if (watchingTripId == null) {
        logger.info('[VIEWER] No active watching trip found');
        return;
      }

      logger.info('[VIEWER] Found watching trip: $watchingTripId');

      // Load all FCM-received points for this trip
      final allPoints = _storageService.getLocationPointsByTripId(
        watchingTripId,
      );
      final fcmPoints = allPoints.where((p) => p.source == 'fcm').toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (fcmPoints.isEmpty) {
        logger.info('[VIEWER] No FCM points found for trip');
        await _clearWatchingTrip();
        return;
      }

      logger.info('[VIEWER] Loaded ${fcmPoints.length} FCM points');

      // Rebuild viewing state
      final pathPoints = fcmPoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      final lastPoint = fcmPoints.last;

      _viewingState = TripViewingState(
        tripId: watchingTripId,
        groupId: tripSettings?.watchingGroupId ?? groupId,
        pathPoints: pathPoints,
        tripStartTime: fcmPoints.first.timestamp,
        lastUpdateTime: lastPoint.timestamp,
        isTripActive: tripSettings?.isTripActive ?? false,
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
      if (_viewingState.isTripActive) {
        _moveCameraToLocation(pathPoints.last, zoom: 15);
      } else {
        _fitCameraToPath();
      }

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
        polylineId: PolylineId('trip_path_${_viewingState.tripId}'),
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
        tripId: data.tripId,
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
  Future<void> _saveWatchingTrip(String tripId, int groupId) async {
    try {
      final settings = _storageService.getTripSettings() ?? TripSettings();
      settings.watchingTripId = tripId;
      settings.watchingGroupId = groupId;
      await _storageService.saveTripSettings(settings);

      logger.info('[VIEWER] Saved watching trip: $tripId');
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
  void clearTrip() {
    _viewingState = TripViewingState.empty();
    _markers.clear();
    _polylines.clear();
    statusNotifier.value = null;
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

      if (distance <= PROXIMITY_THRESHOLD_1KM && !_announced1km) {
        await announcementService.announce('1 kilometer from home');
        _announced1km = true;
        logger.info('[PROXIMITY] ✅ Announced 1km threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_500M && !_announced500m) {
        await announcementService.announce('500 meters from home');
        _announced500m = true;
        logger.info('[PROXIMITY] ✅ Announced 500m threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_200M && !_announced200m) {
        await announcementService.announce('200 meters from home');
        _announced200m = true;
        logger.info('[PROXIMITY] ✅ Announced 200m threshold');
      }

      if (distance <= PROXIMITY_THRESHOLD_100M && !_announced100m) {
        await announcementService.announce('100 meters from home');
        _announced100m = true;
        logger.info('[PROXIMITY] ✅ Announced 100m threshold');
      }
    } catch (e) {
      logger.error('[PROXIMITY ERROR] Failed to check proximity: $e');
    }
  }

  @override
  void dispose() {
    statusNotifier.dispose();
    super.dispose();
  }
}
