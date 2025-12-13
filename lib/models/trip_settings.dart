import 'package:hive/hive.dart';

part 'trip_settings.g.dart';

@HiveType(typeId: 1)
class TripSettings extends HiveObject {
  @HiveField(0)
  bool isTripActive;

  @HiveField(1)
  int? currentTripId;

  @HiveField(2)
  int? currentGroupId;

  @HiveField(3)
  String? currentTripName;

  @HiveField(4)
  DateTime? tripStartTime;

  @HiveField(5)
  String? watchingTripId; // Remote trip being watched (parent app)

  @HiveField(6)
  int? watchingGroupId; // Group ID for watched trip

  TripSettings({
    this.isTripActive = false,
    this.currentTripId,
    this.currentGroupId,
    this.currentTripName,
    this.tripStartTime,
    this.watchingTripId,
    this.watchingGroupId,
  });

  // Helper method to clear trip data
  void clear() {
    isTripActive = false;
    currentTripId = null;
    currentGroupId = null;
    currentTripName = null;
    tripStartTime = null;
    watchingTripId = null;
    watchingGroupId = null;
  }

  // Helper method to clear only watching data
  void clearWatching() {
    watchingTripId = null;
    watchingGroupId = null;
  }

  @override
  String toString() {
    return 'TripSettings(active: $isTripActive, tripId: $currentTripId, groupId: $currentGroupId, name: $currentTripName, watching: $watchingTripId)';
  }
}
