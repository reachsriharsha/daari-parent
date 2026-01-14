import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';
import '../models/app_settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/app_logger.dart';

class BackgroundLocationService {
  static const String _notificationChannelId = 'trip_tracking_channel';
  static const int _notificationId = 888;

  /// Initialize the background service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Trip Tracking',
      description: 'Tracks your location during active trips',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'Trip Tracking',
        initialNotificationContent: 'Tracking is active',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background service
  /// Trip info is read from Hive TripSettings in the background isolate
  static Future<void> startService() async {
    final service = FlutterBackgroundService();

    // Background isolate will read trip info from Hive TripSettings box
    // No parameters needed - TripSettings is the single source of truth

    await service.startService();
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Background entry point (runs in isolate)
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Hive in background isolate
    Hive.init('.');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocationPointAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TripSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    final locationBox = await Hive.openBox<LocationPoint>('location_points');
    final appSettingsBox = await Hive.openBox<AppSettings>('app_settings');
    final tripSettingsBox = await Hive.openBox<TripSettings>('trip_settings');

    // Get trip info from Hive TripSettings (persistent across app restarts)
    // tripName is the single source of truth
    final tripSettings = tripSettingsBox.get('current_trip');
    final tripName = tripSettings?.currentTripName;
    final groupId = tripSettings?.currentGroupId;

    // Read id_token and ngrok_url from Hive
    final appSettings = appSettingsBox.get('app_config');
    final idToken = appSettings?.idToken;
    final backendUrl = appSettings?.ngrokUrl;

    // Validate trip settings
    if (tripSettings == null ||
        !tripSettings.isTripActive ||
        tripName == null ||
        tripName.isEmpty ||
        groupId == null) {
      logger.info(
        '[BACKGROUND] Invalid trip settings: tripName=$tripName, groupId=$groupId, stopping service',
      );
      service.stopSelf();
      return;
    }

    logger.info('[BACKGROUND] Service started for trip $tripName');

    // Setup location tracking
    StreamSubscription<Position>? locationSubscription;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      timeLimit: Duration(seconds: 8),
    );

    locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) async {
          logger.info(
            '[BACKGROUND] Location update: ${position.latitude}, ${position.longitude}',
          );

          // Save to Hive with tripName as identifier
          final locationPoint = LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
            speed: position.speed,
            accuracy: position.accuracy,
            tripName: tripName,
            tripEventType: "update",
            groupId: groupId.toString(),
            isSynced: false,
          );

          try {
            final key = await locationBox.add(locationPoint);
            logger.info('[BACKGROUND] Saved to Hive (key: $key)');

            // Try to sync to backend
            if (idToken != null && backendUrl != null) {
              await _sendLocationToBackend(
                groupId: groupId,
                latitude: position.latitude,
                longitude: position.longitude,
                tripName: tripName,
                idToken: idToken,
                backendUrl: backendUrl,
              );

              // Mark as synced
              final savedPoint = locationBox.get(key);
              if (savedPoint != null) {
                final updatedPoint = LocationPoint(
                  latitude: savedPoint.latitude,
                  longitude: savedPoint.longitude,
                  timestamp: savedPoint.timestamp,
                  speed: savedPoint.speed,
                  accuracy: savedPoint.accuracy,
                  tripName: savedPoint.tripName,
                  tripEventType: savedPoint.tripEventType,
                  groupId: savedPoint.groupId,
                  isSynced: true,
                );
                await locationBox.put(key, updatedPoint);
              }
              logger.info('[BACKGROUND] Synced to backend');
            }
          } catch (e) {
            logger.error('[BACKGROUND ERROR] Error: $e');
          }

          // Update notification
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'Chalaka',
              content: 'Current Trip is active',
            );
          }
        });

    // Listen for stop command
    service.on('stopService').listen((event) {
      logger.info('[BACKGROUND] Stop command received');
      locationSubscription?.cancel();
      service.stopSelf();
    });

    // Keep service alive
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Send location to backend (isolated function for background)
  /// tripName is the single source of truth identifier
  static Future<void> _sendLocationToBackend({
    required int groupId,
    required double latitude,
    required double longitude,
    required String tripName,
    required String idToken,
    required String backendUrl,
  }) async {
    final url = Uri.parse("$backendUrl/api/groups/trip/update");

    final body = {
      "group_id": groupId,
      "trip_name": tripName,
      "trip_event": "update",
      "coordinates": {"latitude": latitude, "longitude": longitude},
    };

    final response = await http
        .post(
          url,
          headers: {
            "Authorization": "Bearer $idToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Backend sync failed: ${response.statusCode}');
    }
  }
}
