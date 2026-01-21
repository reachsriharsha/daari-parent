import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to collect device and app information (DES-AUTH001)
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get app version from package info
  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Get phone model name
  Future<String> getPhoneModel() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.utsname.machine;
    }
    return 'Unknown';
  }

  /// Get OS version
  Future<String> getOsVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return 'iOS ${iosInfo.systemVersion}';
    }
    return 'Unknown';
  }

  /// Get platform string
  String getPlatform() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
