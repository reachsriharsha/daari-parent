import 'package:hive/hive.dart';

part 'group.g.dart';

@HiveType(typeId: 3)
class Group extends HiveObject {
  @HiveField(0)
  int groupId;

  @HiveField(1)
  String groupName;

  @HiveField(2)
  double destinationLatitude;

  @HiveField(3)
  double destinationLongitude;

  Group({
    required this.groupId,
    required this.groupName,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  // Convenience getter for coordinates map
  Map<String, double> get coordinates => {
    'latitude': destinationLatitude,
    'longitude': destinationLongitude,
  };

  // Factory constructor to create from JSON (backend response)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['id'] ?? 0,
      groupName: json['name'] ?? '',
      destinationLatitude: json['coordinates']?['latitude'] ?? 0.0,
      destinationLongitude: json['coordinates']?['longitude'] ?? 0.0,
    );
  }

  // Convert to JSON for display/debugging
  Map<String, dynamic> toJson() => {
    'id': groupId,
    'name': groupName,
    'coordinates': {
      'latitude': destinationLatitude,
      'longitude': destinationLongitude,
    },
  };
}
