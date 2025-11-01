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

  TripSettings({
    this.isTripActive = false,
    this.currentTripId,
    this.currentGroupId,
    this.currentTripName,
    this.tripStartTime,
  });

  // Helper method to clear trip data
  void clear() {
    isTripActive = false;
    currentTripId = null;
    currentGroupId = null;
    currentTripName = null;
    tripStartTime = null;
  }

  @override
  String toString() {
    return 'TripSettings(active: $isTripActive, tripId: $currentTripId, groupId: $currentGroupId, name: $currentTripName)';
  }
}
