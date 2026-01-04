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

  @HiveField(4)
  String? address;

  @HiveField(5)
  String? placeName;

  @HiveField(6)
  bool isAdmin;

  @HiveField(7)
  List<String>? memberPhoneNumbers;

  @HiveField(8)
  String? adminPhoneNumber;

  @HiveField(9)
  String? driverPhoneNumber;

  Group({
    required this.groupId,
    required this.groupName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.address,
    this.placeName,
    this.isAdmin = false,
    this.memberPhoneNumbers,
    this.adminPhoneNumber,
    this.driverPhoneNumber,
  });

  // Convenience getter for coordinates map
  Map<String, double> get coordinates => {
    'latitude': destinationLatitude,
    'longitude': destinationLongitude,
  };

  // Helper to check if destination is set
  bool get hasDestination =>
      (destinationLatitude != 0.0 || destinationLongitude != 0.0) &&
      placeName != null;

  // Factory constructor to create from JSON (backend response)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['id'] ?? 0,
      groupName: json['name'] ?? '',
      destinationLatitude: json['dest_coordinates']?['latitude'] ?? 0.0,
      destinationLongitude: json['dest_coordinates']?['longitude'] ?? 0.0,
      address: json['address'],
      placeName: json['place_name'],
      isAdmin: json['is_admin'] ?? false,
      memberPhoneNumbers: json['member_phone_numbers'] != null
          ? List<String>.from(json['member_phone_numbers'])
          : null,
      adminPhoneNumber: json['admin_phone_number'],
      driverPhoneNumber: json['driver_phone_number'],
    );
  }

  // Convert to JSON for display/debugging
  Map<String, dynamic> toJson() => {
    'id': groupId,
    'name': groupName,
    'dest_coordinates': {
      'latitude': destinationLatitude,
      'longitude': destinationLongitude,
    },
    if (address != null) 'address': address,
    if (placeName != null) 'place_name': placeName,
    'is_admin': isAdmin,
    if (memberPhoneNumbers != null) 'member_phone_numbers': memberPhoneNumbers,
    if (adminPhoneNumber != null) 'admin_phone_number': adminPhoneNumber,
    if (driverPhoneNumber != null) 'driver_phone_number': driverPhoneNumber,
  };
}
