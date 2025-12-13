import 'package:hive/hive.dart';

part 'location_point.g.dart';

@HiveType(typeId: 0)
class LocationPoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double? speed;

  @HiveField(4)
  final double? accuracy;

  @HiveField(5)
  final String tripId;

  @HiveField(6)
  final bool isSynced; // For tracking if sent to server

  @HiveField(7)
  final String? tripEventType;

  @HiveField(8)
  final String? groupId;

  @HiveField(9)
  final String source; // "gps" | "fcm" - tracks data source

  @HiveField(10)
  final DateTime? receivedAt; // When FCM notification was received

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.accuracy,
    required this.tripId,
    this.isSynced = false,
    this.tripEventType,
    this.groupId,
    this.source = 'gps',
    this.receivedAt,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'speed': speed,
    'accuracy': accuracy,
    'tripId': tripId,
    'tripEventType': tripEventType,
    'groupId': groupId,
    'source': source,
    'receivedAt': receivedAt?.toIso8601String(),
  };
}
