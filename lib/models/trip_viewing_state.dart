import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Immutable state for viewing a remote trip
/// Contains all data needed to render trip on map and UI
class TripViewingState {
  final String tripName; // RENAMED: Use tripName as primary identifier
  final int groupId;
  final List<LatLng> pathPoints;
  final DateTime? tripStartTime;
  final DateTime? lastUpdateTime;
  final bool isTripActive;
  final LatLng? currentLocation;
  final String lastEventType;
  final String lastEventDetails;

  TripViewingState({
    required this.tripName,
    required this.groupId,
    required this.pathPoints,
    this.tripStartTime,
    this.lastUpdateTime,
    this.isTripActive = true,
    this.currentLocation,
    this.lastEventType = '',
    this.lastEventDetails = '',
  });

  /// Create initial state when trip starts
  factory TripViewingState.initial({
    required String tripName,
    required int groupId,
    required LatLng startLocation,
    DateTime? startTime,
  }) {
    return TripViewingState(
      tripName: tripName,
      groupId: groupId,
      pathPoints: [startLocation],
      tripStartTime: startTime ?? DateTime.now(),
      lastUpdateTime: DateTime.now(),
      isTripActive: true,
      currentLocation: startLocation,
      lastEventType: 'trip_started',
      lastEventDetails: 'Trip started',
    );
  }

  /// Create empty state
  factory TripViewingState.empty() {
    return TripViewingState(
      tripName: '',
      groupId: 0,
      pathPoints: [],
      isTripActive: false,
    );
  }

  /// Total number of location points received
  int get totalPoints => pathPoints.length;

  /// Trip duration (if started)
  Duration? get tripDuration {
    if (tripStartTime != null && lastUpdateTime != null) {
      return lastUpdateTime!.difference(tripStartTime!);
    }
    return null;
  }

  /// Start location (first point)
  LatLng? get startLocation => pathPoints.isNotEmpty ? pathPoints.first : null;

  /// End location (last point)
  LatLng? get endLocation => pathPoints.isNotEmpty ? pathPoints.last : null;

  /// Check if trip has any data
  bool get hasData => pathPoints.isNotEmpty;

  /// Check if trip is empty
  bool get isEmpty => pathPoints.isEmpty;

  /// Create a copy with updated fields
  TripViewingState copyWith({
    String? tripName,
    int? groupId,
    List<LatLng>? pathPoints,
    DateTime? tripStartTime,
    DateTime? lastUpdateTime,
    bool? isTripActive,
    LatLng? currentLocation,
    String? lastEventType,
    String? lastEventDetails,
  }) {
    return TripViewingState(
      tripName: tripName ?? this.tripName,
      groupId: groupId ?? this.groupId,
      pathPoints: pathPoints ?? this.pathPoints,
      tripStartTime: tripStartTime ?? this.tripStartTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      isTripActive: isTripActive ?? this.isTripActive,
      currentLocation: currentLocation ?? this.currentLocation,
      lastEventType: lastEventType ?? this.lastEventType,
      lastEventDetails: lastEventDetails ?? this.lastEventDetails,
    );
  }

  /// Add a new location point to the path
  TripViewingState addPoint(LatLng point, {String? eventType}) {
    return copyWith(
      pathPoints: [...pathPoints, point],
      currentLocation: point,
      lastUpdateTime: DateTime.now(),
      lastEventType: eventType ?? 'trip_updated',
      lastEventDetails: 'Location updated',
    );
  }

  /// Mark trip as finished
  TripViewingState finish({LatLng? finalLocation}) {
    return copyWith(
      isTripActive: false,
      currentLocation: finalLocation ?? currentLocation,
      lastEventType: 'trip_finished',
      lastEventDetails: 'Trip completed with ${totalPoints} location updates',
    );
  }

  @override
  String toString() {
    return 'TripViewingState(tripName: $tripName, points: ${pathPoints.length}, active: $isTripActive)';
  }
}
