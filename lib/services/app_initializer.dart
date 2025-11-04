import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'location_storage_service.dart';
import 'fcm_service.dart';
import 'fcm_notification_handler.dart';
import '../controllers/trip_controller.dart';

/// Centralized service initializer
/// Handles initialization of all app services in the correct order
class AppInitializer {
  /// Initialize all services
  /// Call this from main() before runApp()
  static Future<void> initializeAllServices({
    required LocationStorageService storageService,
  }) async {
    debugPrint('[APP INIT] Starting service initialization...');

    try {
      // 1. Initialize Hive Storage (highest priority - needed by all other services)
      await _initializeHive(storageService);

      // 2. Initialize Firebase Core (required for FCM and Auth)
      await _initializeFirebase();

      // 3. Initialize FCM Service
      await _initializeFCM();

      // 4. Initialize Background Location Service
      await _initializeBackgroundLocation();

      debugPrint('[APP INIT] ✅ All services initialized successfully');
    } catch (e) {
      debugPrint('[APP INIT ERROR] ❌ Service initialization failed: $e');
      // Don't rethrow - allow app to start even if some services fail
    }
  }

  /// Initialize Hive storage
  static Future<void> _initializeHive(
    LocationStorageService storageService,
  ) async {
    try {
      debugPrint('[APP INIT] Initializing Hive storage...');
      await storageService.init();
      debugPrint('[APP INIT] ✅ Hive storage initialized');
    } catch (e) {
      debugPrint('[APP INIT ERROR] ❌ Hive initialization failed: $e');
      rethrow; // Hive is critical - can't continue without it
    }
  }

  /// Initialize Firebase Core
  static Future<void> _initializeFirebase() async {
    try {
      debugPrint('[APP INIT] Initializing Firebase...');

      // Only initialize if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyAwierriEkBCarzpDCbLLzoBQPoEO_Uiro",
            appId: "1:192909758501:android:0d216829daceeca0caefcc",
            messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
            projectId: "otptest1-cbe83",
          ),
        );
        debugPrint('[APP INIT] ✅ Firebase initialized');
      } else {
        debugPrint('[APP INIT] Firebase already initialized');
      }

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      debugPrint('[APP INIT] ✅ FCM background handler registered');
    } catch (e) {
      debugPrint('[APP INIT ERROR] ❌ Firebase initialization failed: $e');
      // Don't rethrow - app can work without FCM
    }
  }

  /// Initialize FCM Service
  static Future<void> _initializeFCM() async {
    try {
      debugPrint('[APP INIT] Initializing FCM service...');
      final fcmService = FCMService();
      await fcmService.initialize();
      debugPrint('[APP INIT] ✅ FCM service initialized');
    } catch (e) {
      debugPrint('[APP INIT ERROR] ❌ FCM initialization failed: $e');
      // Don't rethrow - app can work without FCM
    }
  }

  /// Initialize Background Location Service
  static Future<void> _initializeBackgroundLocation() async {
    try {
      debugPrint('[APP INIT] Initializing background location service...');
      await TripController.initializeBackgroundService();
      debugPrint('[APP INIT] ✅ Background location service initialized');
    } catch (e) {
      debugPrint(
        '[APP INIT ERROR] ❌ Background location initialization failed: $e',
      );
      // Don't rethrow - app can work without background location
    }
  }
}
