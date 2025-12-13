import 'package:intl/intl.dart';

/// Data model for displaying trip status in UI
/// Contains formatted information for status widget
class TripStatusData {
  final String
  eventType; // Display name: "Trip Started", "Location Update", etc.
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String?
  additionalInfo; // Optional extra info (e.g., driver name, speed)

  TripStatusData({
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.additionalInfo,
  });

  /// Get formatted time string (HH:mm:ss)
  String get formattedTime {
    return DateFormat('HH:mm:ss').format(timestamp);
  }

  /// Get formatted date and time string
  String get formattedDateTime {
    return DateFormat('MMM dd, HH:mm:ss').format(timestamp);
  }

  /// Get formatted location string
  String get formattedLocation {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Get short formatted location string (4 decimals)
  String get shortLocation {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Create from trip update data
  factory TripStatusData.fromTripUpdate({
    required String eventType,
    required double latitude,
    required double longitude,
    DateTime? timestamp,
    String? driverName,
    double? speed,
  }) {
    // Build additional info string
    final List<String> infoParts = [];
    if (driverName != null) {
      infoParts.add('Driver: $driverName');
    }
    if (speed != null) {
      infoParts.add('Speed: ${speed.toStringAsFixed(1)} km/h');
    }

    return TripStatusData(
      eventType: _getDisplayEventType(eventType),
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp ?? DateTime.now(),
      additionalInfo: infoParts.isNotEmpty ? infoParts.join(' • ') : null,
    );
  }

  /// Convert event type to display name
  static String _getDisplayEventType(String eventType) {
    switch (eventType) {
      case 'trip_started':
        return 'Trip Started';
      case 'trip_updated':
        return 'Location Update';
      case 'trip_finished':
        return 'Trip Finished';
      default:
        return eventType;
    }
  }

  /// Check if this is a start event
  bool get isStartEvent => eventType == 'Trip Started';

  /// Check if this is an update event
  bool get isUpdateEvent => eventType == 'Location Update';

  /// Check if this is a finish event
  bool get isFinishEvent => eventType == 'Trip Finished';

  @override
  String toString() {
    return 'TripStatusData(event: $eventType, time: $formattedTime, location: $shortLocation)';
  }
}
