import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  String? ngrokUrl;

  @HiveField(1)
  String? idToken;

  @HiveField(2)
  String? profId;

  @HiveField(3)
  bool? locationPermissionGranted;

  AppSettings({
    this.ngrokUrl,
    this.idToken,
    this.profId,
    this.locationPermissionGranted,
  });

  // Helper method to clear all settings
  void clear() {
    ngrokUrl = null;
    idToken = null;
    profId = null;
    locationPermissionGranted = null;
  }

  @override
  String toString() {
    return 'AppSettings(ngrokUrl: $ngrokUrl, profId: $profId, hasToken: ${idToken != null}, locationPermission: $locationPermissionGranted)';
  }
}
