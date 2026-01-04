import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart'; // To access storageService
import '../utils/app_logger.dart';

/// Service for creating diagnostic ZIP files
class DiagnosticService {
  /// Create a diagnostics ZIP file containing Hive data and logs
  /// Returns the ZIP file ready for upload
  static Future<File> createDiagnosticsZip() async {
    try {
      logger.info('[DIAGNOSTICS] Starting diagnostic ZIP creation...');

      // Create temp directory for diagnostic files
      final tempDir = await getTemporaryDirectory();
      final diagnosticsDir = Directory('${tempDir.path}/diagnostics');
      if (await diagnosticsDir.exists()) {
        await diagnosticsDir.delete(recursive: true);
      }
      await diagnosticsDir.create(recursive: true);

      // 1. Collect Hive data as JSON
      await _collectHiveData(diagnosticsDir);

      // 2. Collect log files
      await _collectLogFiles(diagnosticsDir);

      // 3. Collect device and app info
      await _collectDeviceInfo(diagnosticsDir);

      // 4. Create ZIP archive
      final zipFile = await _createZipArchive(diagnosticsDir);

      // 5. Clean up temp directory
      await diagnosticsDir.delete(recursive: true);

      logger.info(
        '[DIAGNOSTICS] ZIP created successfully: ${zipFile.path} (${await zipFile.length()} bytes)',
      );

      return zipFile;
    } catch (e, stackTrace) {
      logger.error(
        '[DIAGNOSTICS ERROR] Failed to create diagnostics ZIP: $e\nStack trace: $stackTrace',
      );
      rethrow;
    }
  }

  /// Collect Hive data as JSON files (without tokens)
  static Future<void> _collectHiveData(Directory outputDir) async {
    try {
      logger.debug('[DIAGNOSTICS] Collecting Hive data...');

      // 1. Collect groups data
      final groups = await storageService.getAllGroups();
      final groupsJson = groups.map((g) {
        final json = g.toJson();
        // Remove any sensitive data if needed
        return json;
      }).toList();

      final groupsFile = File('${outputDir.path}/groups.json');
      await groupsFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(groupsJson),
      );
      logger.debug('[DIAGNOSTICS] Collected ${groups.length} groups');

      // 2. Collect app settings (sanitized - no tokens)
      final settings = storageService.getAppSettings();
      final settingsJson = {
        'ngrokUrl': settings?.ngrokUrl,
        'profId': settings?.profId,
        'locationPermissionGranted': settings?.locationPermissionGranted,
        'hasFcmToken': settings?.fcmToken != null,
        'homeLatitude': settings?.homeLatitude,
        'homeLongitude': settings?.homeLongitude,
        'homeAddress': settings?.homeAddress,
        'homePlaceName': settings?.homePlaceName,
        // NOTE: idToken and fcmToken are excluded for security
      };

      final settingsFile = File('${outputDir.path}/app_settings.json');
      await settingsFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(settingsJson),
      );
      logger.debug('[DIAGNOSTICS] Collected app settings');

      // 3. Collect location points (recent only - last 100)
      final allPoints = storageService.getAllLocationPoints();
      final recentPoints = allPoints.length > 100
          ? allPoints.sublist(allPoints.length - 100)
          : allPoints;

      final pointsJson = recentPoints
          .map(
            (p) => {
              'timestamp': p.timestamp,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'tripId': p.tripId,
              'tripEventType': p.tripEventType,
              'isSynced': p.isSynced,
            },
          )
          .toList();

      final pointsFile = File('${outputDir.path}/location_points.json');
      await pointsFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(pointsJson),
      );
      logger.debug(
        '[DIAGNOSTICS] Collected ${pointsJson.length} location points',
      );
    } catch (e, stackTrace) {
      logger.error(
        '[DIAGNOSTICS ERROR] Error collecting Hive data: $e\n$stackTrace',
      );
    }
  }

  /// Collect recent log files
  static Future<void> _collectLogFiles(Directory outputDir) async {
    try {
      logger.debug('[DIAGNOSTICS] Collecting log files...');

      final logFiles = await logger.getLogFiles();

      if (logFiles.isEmpty) {
        logger.debug('[DIAGNOSTICS] No log files found');
        return;
      }

      // Sort by modification time (newest first) and take last 3
      logFiles.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      final logsToInclude = logFiles.take(3).toList();

      for (var i = 0; i < logsToInclude.length; i++) {
        final logFile = logsToInclude[i];
        final fileName = 'log_${i + 1}.log';
        final destFile = File('${outputDir.path}/$fileName');
        await logFile.copy(destFile.path);
      }

      logger.debug('[DIAGNOSTICS] Collected ${logsToInclude.length} log files');
    } catch (e, stackTrace) {
      logger.error(
        '[DIAGNOSTICS ERROR] Error collecting log files: $e\n$stackTrace',
      );
    }
  }

  /// Collect device and app information
  static Future<void> _collectDeviceInfo(Directory outputDir) async {
    try {
      logger.debug('[DIAGNOSTICS] Collecting device info...');

      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      final deviceInfo = <String, dynamic>{
        'app': {
          'name': packageInfo.appName,
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
          'packageName': packageInfo.packageName,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add platform-specific device info
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo['device'] = {
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo['device'] = {
          'platform': 'ios',
          'model': iosInfo.model,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
        };
      }

      final infoFile = File('${outputDir.path}/device_info.json');
      await infoFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(deviceInfo),
      );

      logger.debug('[DIAGNOSTICS] Collected device info');
    } catch (e, stackTrace) {
      logger.error(
        '[DIAGNOSTICS ERROR] Error collecting device info: $e\n$stackTrace',
      );
    }
  }

  /// Create ZIP archive from diagnostics directory
  static Future<File> _createZipArchive(Directory sourceDir) async {
    try {
      logger.debug('[DIAGNOSTICS] Creating ZIP archive...');

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final zipFilePath = '${tempDir.path}/diagnostics_$timestamp.zip';

      // Create encoder
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      // Add all files from diagnostics directory
      final files = sourceDir.listSync(recursive: true).whereType<File>();
      for (var file in files) {
        final relativePath = file.path.replaceFirst('${sourceDir.path}/', '');
        encoder.addFile(file, relativePath);
      }

      encoder.close();

      logger.debug('[DIAGNOSTICS] ZIP archive created at: $zipFilePath');

      return File(zipFilePath);
    } catch (e, stackTrace) {
      logger.error('[DIAGNOSTICS ERROR] Error creating ZIP: $e\n$stackTrace');
      rethrow;
    }
  }
}
