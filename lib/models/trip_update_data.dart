import '../utils/app_logger.dart';

/// Model for trip update data received from FCM notifications
/// Provides type-safe parsing and validation of FCM payload
class TripUpdateData {
  final String eventType; // "trip_started" | "trip_updated" | "trip_finished"
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String tripName;
  final int groupId;
  final String? driverName;

  TripUpdateData({
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.tripName,
    required this.groupId,
    this.driverName,
  });

  /// Parse FCM notification data into TripUpdateData
  /// Throws FormatException if data is invalid
  factory TripUpdateData.fromFCM(Map<String, dynamic> data) {
    try {
      // Validate required fields
      if (!data.containsKey('type') || !data.containsKey('trip_name')) {
        throw FormatException('Missing required fields in FCM data');
      }

      // Parse and validate coordinates
      final latStr = data['latitude'] as String?;
      final lngStr = data['longitude'] as String?;

      if (latStr == null || lngStr == null) {
        throw FormatException('Missing latitude or longitude');
      }

      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);

      if (lat == null || lng == null) {
        throw FormatException(
          'Invalid coordinate format: lat=$latStr, lng=$lngStr',
        );
      }

      // Validate coordinate ranges
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        throw FormatException('Coordinates out of range: lat=$lat, lng=$lng');
      }

      // Parse timestamp
      DateTime timestamp;
      if (data.containsKey('timestamp')) {
        try {
          timestamp = DateTime.parse(data['timestamp'] as String);
        } catch (e, stackTrace) {
          logger.error(
            '[FCM] Invalid timestamp format, using current time: $e stack trace: $stackTrace',
          );
          timestamp = DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }

      // Parse group_id
      int groupId;
      final groupIdValue = data['group_id'];
      if (groupIdValue is int) {
        groupId = groupIdValue;
      } else if (groupIdValue is String) {
        groupId = int.tryParse(groupIdValue) ?? 0;
      } else {
        throw FormatException('Invalid or missing group_id');
      }

      return TripUpdateData(
        eventType: data['type'] as String,
        latitude: lat,
        longitude: lng,
        timestamp: timestamp,
        tripName: data['trip_name'] as String,
        groupId: groupId,
        driverName: data['driver_name'] as String?,
      );
    } catch (e, stackTrace) {
      logger.error(
        '[FCM ERROR] Failed to parse trip update data: $e, stack trace: $stackTrace',
      );
      rethrow;
    }
  }

  /// Get user-friendly event name for display
  String get displayEventType {
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

  /// Check if this is a trip start event
  bool get isStartEvent => eventType == 'trip_started';

  /// Check if this is a trip update event
  bool get isUpdateEvent => eventType == 'trip_updated';

  /// Check if this is a trip finish event
  bool get isFinishEvent => eventType == 'trip_finished';

  @override
  String toString() {
    return 'TripUpdateData(event: $eventType, tripName: $tripName, groupId: $groupId, lat: $latitude, lng: $longitude)';
  }
}
