import 'package:hive/hive.dart';

part 'trip_settings.g.dart';

@HiveType(typeId: 1)
class TripSettings extends HiveObject {
  @HiveField(0)
  bool isTripActive;

  // @HiveField(1) - DEPRECATED: currentTripId removed
  // Keep field index reserved to maintain Hive compatibility
  // DO NOT reuse index 1 for new fields

  @HiveField(2)
  int? currentGroupId;

  @HiveField(3)
  String? currentTripName; // PRIMARY IDENTIFIER - Single source of truth

  @HiveField(4)
  DateTime? tripStartTime;

  @HiveField(5)
  String? watchingTripName; // RENAMED: Remote trip being watched (parent app)

  @HiveField(6)
  int? watchingGroupId; // Group ID for watched trip

  TripSettings({
    this.isTripActive = false,
    this.currentGroupId,
    this.currentTripName,
    this.tripStartTime,
    this.watchingTripName,
    this.watchingGroupId,
  });

  // Helper method to clear trip data
  void clear() {
    isTripActive = false;
    currentGroupId = null;
    currentTripName = null;
    tripStartTime = null;
    watchingTripName = null;
    watchingGroupId = null;
  }

  // Helper method to clear only watching data
  void clearWatching() {
    watchingTripName = null;
    watchingGroupId = null;
  }

  @override
  String toString() {
    return 'TripSettings(active: $isTripActive, groupId: $currentGroupId, name: $currentTripName, watching: $watchingTripName)';
  }
}
