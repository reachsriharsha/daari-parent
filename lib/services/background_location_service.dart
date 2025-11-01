import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_point.dart';
import '../models/trip_settings.dart';
import '../models/app_settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  static Future<void> startService({
    required int tripId,
    required int groupId,
    required String tripName,
  }) async {
    final service = FlutterBackgroundService();

    // Store trip info in SharedPreferences for background access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bg_trip_id', tripId);
    await prefs.setInt('bg_group_id', groupId);
    await prefs.setString('bg_trip_name', tripName);

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

    // Get trip info from SharedPreferences (only temporary trip data)
    final prefs = await SharedPreferences.getInstance();
    final tripId = prefs.getInt('bg_trip_id');
    final groupId = prefs.getInt('bg_group_id');
    final tripName = prefs.getString('bg_trip_name');

    // Read id_token and ngrok_url from Hive
    final appSettings = appSettingsBox.get('app_config');
    final idToken = appSettings?.idToken;
    final backendUrl = appSettings?.ngrokUrl;

    if (tripId == null || groupId == null) {
      service.stopSelf();
      return;
    }

    debugPrint('[BACKGROUND] Service started for trip $tripId');

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
          debugPrint(
            '[BACKGROUND] Location update: ${position.latitude}, ${position.longitude}',
          );

          // Save to Hive
          final locationPoint = LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
            speed: position.speed,
            accuracy: position.accuracy,
            tripId: tripId.toString(),
            tripEventType: "update",
            groupId: groupId.toString(),
            isSynced: false,
          );

          try {
            await locationBox.add(locationPoint);
            debugPrint('[BACKGROUND] Saved to Hive');

            // Try to sync to backend
            if (idToken != null && backendUrl != null && tripName != null) {
              await _sendLocationToBackend(
                tripId: tripId,
                groupId: groupId,
                latitude: position.latitude,
                longitude: position.longitude,
                tripName: tripName,
                idToken: idToken,
                backendUrl: backendUrl,
              );

              // Mark as synced
              final key = locationPoint.key;
              if (key != null) {
                final savedPoint = locationBox.get(key);
                if (savedPoint != null) {
                  final updatedPoint = LocationPoint(
                    latitude: savedPoint.latitude,
                    longitude: savedPoint.longitude,
                    timestamp: savedPoint.timestamp,
                    speed: savedPoint.speed,
                    accuracy: savedPoint.accuracy,
                    tripId: savedPoint.tripId,
                    tripEventType: savedPoint.tripEventType,
                    groupId: savedPoint.groupId,
                    isSynced: true,
                  );
                  await locationBox.put(key, updatedPoint);
                }
              }
              debugPrint('[BACKGROUND] Synced to backend');
            }
          } catch (e) {
            debugPrint('[BACKGROUND ERROR] Error: $e');
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
      debugPrint('[BACKGROUND] Stop command received');
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
  static Future<void> _sendLocationToBackend({
    required int tripId,
    required int groupId,
    required double latitude,
    required double longitude,
    required String tripName,
    required String idToken,
    required String backendUrl,
  }) async {
    final url = Uri.parse("$backendUrl/api/groups/trip/update");

    final body = {
      "trip_id": tripId,
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
