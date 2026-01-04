import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'location_storage_service.dart';
import 'backend_com_service.dart';
import 'fcm_service.dart';
import 'fcm_notification_handler.dart';
import 'announcement_service.dart';
import '../controllers/trip_controller.dart';
import '../utils/app_logger.dart';

/// Centralized service initializer
/// Handles initialization of all app services in the correct order
class AppInitializer {
  /// Initialize all services
  /// Call this from main() before runApp()
  static Future<void> initializeAllServices({
    required LocationStorageService storageService,
  }) async {
    logger.info('[APP INIT] Starting service initialization...');

    try {
      // 1. Initialize Hive Storage (highest priority - needed by all other services)
      await _initializeHive(storageService);

      // 2. Initialize BackendComService (needs Hive for URL storage)
      await _initializeBackendComService();

      // 3. Initialize Firebase Core (required for FCM and Auth)
      await _initializeFirebase();

      // 3. Initialize FCM Service
      await _initializeFCM();

      // 4. Initialize Background Location Service
      await _initializeBackgroundLocation();

      // 5. Initialize TTS Announcement Service
      await _initializeAnnouncement();

      logger.info('[APP INIT] All services initialized successfully');
    } catch (e) {
      logger.error('[APP INIT ERROR] Service initialization failed: $e');
      // Don't rethrow - allow app to start even if some services fail
    }
  }

  /// Initialize Hive storage
  static Future<void> _initializeHive(
    LocationStorageService storageService,
  ) async {
    try {
      logger.info('[APP INIT] Initializing Hive storage...');
      await storageService.init();
      logger.info('[APP INIT] Hive storage initialized');
    } catch (e) {
      logger.error('[APP INIT ERROR] Hive initialization failed: $e');
      rethrow; // Hive is critical - can't continue without it
    }
  }

  /// Initialize BackendComService
  static Future<void> _initializeBackendComService() async {
    try {
      logger.info('[APP INIT] Initializing BackendComService...');
      await BackendComService.instance.init();
      logger.info('[APP INIT] BackendComService initialized');
    } catch (e) {
      logger.error(
        '[APP INIT ERROR] BackendComService initialization failed: $e',
      );
      // Don't rethrow - app can work with default URL
    }
  }

  /// Initialize Firebase Core
  static Future<void> _initializeFirebase() async {
    try {
      logger.info('[APP INIT] Initializing Firebase...');

      // Only initialize if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyAwierriEkBCarzpDCbLLzoBQPoEO_Uiro",
            appId: "1:192909758501:android:0d216829daceeca0caefcc",
            messagingSenderId: "192909758501",
            projectId: "otptest1-cbe83",
          ),
        );
        logger.info('[APP INIT] Firebase initialized');
      } else {
        logger.info('[APP INIT] Firebase already initialized');
      }

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      logger.info('[APP INIT] FCM background handler registered');
    } catch (e) {
      logger.error('[APP INIT ERROR] Firebase initialization failed: $e');
      // Don't rethrow - app can work without FCM
    }
  }

  /// Initialize FCM Service
  static Future<void> _initializeFCM() async {
    try {
      logger.info('[APP INIT] Initializing FCM service...');
      final fcmService = FCMService();
      await fcmService.initialize();
      logger.info('[APP INIT] FCM service initialized');
    } catch (e) {
      logger.error('[APP INIT ERROR] FCM initialization failed: $e');
      // Don't rethrow - app can work without FCM
    }
  }

  /// Initialize Background Location Service
  static Future<void> _initializeBackgroundLocation() async {
    try {
      logger.info('[APP INIT] Initializing background location service...');
      await TripController.initializeBackgroundService();
      logger.info('[APP INIT] Background location service initialized');
    } catch (e) {
      logger.error(
        '[APP INIT ERROR] Background location initialization failed: $e',
      );
      // Don't rethrow - app can work without background location
    }
  }

  /// Initialize TTS Announcement Service
  static Future<void> _initializeAnnouncement() async {
    try {
      logger.info('[APP INIT] Initializing TTS announcement service...');
      await announcementService.initialize();
      logger.info('[APP INIT] TTS announcement service initialized');
    } catch (e) {
      logger.error(
        '[APP INIT ERROR] TTS announcement initialization failed: $e',
      );
      // Don't rethrow - app can work without TTS announcements
    }
  }
}
