import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  String? ngrokUrl;

  @HiveField(2)
  String? profId;

  @HiveField(3)
  bool? locationPermissionGranted;

  @HiveField(4)
  String? fcmToken;

  @HiveField(5)
  double? homeLatitude;

  @HiveField(6)
  double? homeLongitude;

  @HiveField(7)
  String? homeAddress;

  @HiveField(8)
  String? homePlaceName;

  @HiveField(9)
  DateTime? lastLoginTimestamp;

  @HiveField(10)
  String? firstName;

  @HiveField(11)
  String? lastName;

  @HiveField(12)
  String? email;

  AppSettings({
    this.ngrokUrl,
    this.profId,
    this.locationPermissionGranted,
    this.fcmToken,
    this.homeLatitude,
    this.homeLongitude,
    this.homeAddress,
    this.homePlaceName,
    this.lastLoginTimestamp,
    this.firstName,
    this.lastName,
    this.email,
  });

  // Helper method to clear all settings
  void clear() {
    ngrokUrl = null;
    profId = null;
    locationPermissionGranted = null;
    fcmToken = null;
    homeLatitude = null;
    homeLongitude = null;
    homeAddress = null;
    homePlaceName = null;
    lastLoginTimestamp = null;
    firstName = null;
    lastName = null;
    email = null;
  }

  @override
  String toString() {
    return 'AppSettings(ngrokUrl: $ngrokUrl, profId: $profId, locationPermission: $locationPermissionGranted, hasFcmToken: ${fcmToken != null}, homeCoords: ${homeLatitude != null && homeLongitude != null ? "($homeLatitude, $homeLongitude)" : "null"}, homeAddress: $homeAddress, homePlaceName: $homePlaceName, lastLogin: $lastLoginTimestamp)';
  }
}
