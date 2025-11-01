import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  /// Request notification permission (required for Android 13+ / API 33+)
  static Future<bool> requestNotificationPermission() async {
    // For Android 13+ (API 33+)
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
