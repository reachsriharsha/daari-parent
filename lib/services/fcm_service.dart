import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'location_storage_service.dart';
import 'fcm_notification_handler.dart';

/// FCM Service for handling Firebase Cloud Messaging
/// Manages token retrieval, refresh, and message handler registration
class FCMService {
  // Singleton pattern
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocationStorageService _storageService = LocationStorageService();
  String? _fcmToken;

  /// Initialize FCM service
  /// - Requests notification permissions
  /// - Gets FCM token
  /// - Sets up message handlers
  /// - Listens for token refresh
  Future<void> initialize() async {
    try {
      debugPrint('[FCM] Initializing FCM service...');

      // Request notification permissions
      await requestPermissions();

      // Get FCM token
      await getToken();

      // Setup message handlers
      setupMessageHandlers();

      // Setup token refresh listener
      setupTokenRefreshListener();

      debugPrint('[FCM] FCM service initialized successfully');
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to initialize FCM: $e');
      // Don't throw - allow app to continue without FCM
    }
  }

  /// Request notification permissions from user
  Future<void> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted notification permissions');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('[FCM] User granted provisional notification permissions');
      } else {
        debugPrint('[FCM] User declined notification permissions');
      }
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to request permissions: $e');
    }
  }

  /// Get FCM token and save to Hive
  /// Returns the token or null if failed
  Future<String?> getToken() async {
    try {
      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        debugPrint('[FCM] Token retrieved: ${_fcmToken!.substring(0, 20)}...');
        await saveTokenToHive(_fcmToken!);
        return _fcmToken;
      } else {
        debugPrint('[FCM ERROR] Failed to get token - returned null');
        return null;
      }
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to get token: $e');
      return null;
    }
  }

  /// Setup listener for token refresh
  /// When token changes, save to Hive and notify backend
  void setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (String newToken) async {
        debugPrint('[FCM] Token refreshed: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        await saveTokenToHive(newToken);

        // Note: Backend update will be handled by OtpService.refreshFcmToken()
        // Call it here if you want automatic backend sync on refresh
        debugPrint(
          '[FCM] Token saved to Hive. Call OtpService.refreshFcmToken() to sync with backend.',
        );
      },
      onError: (error) {
        debugPrint('[FCM ERROR] Token refresh error: $error');
      },
    );
  }

  /// Register message handlers for foreground, background, and terminated states
  void setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] Foreground message received: ${message.notification?.title}',
      );
      FCMNotificationHandler.handleForegroundMessage(message);
    });

    // Background message handler (when app is in background but not terminated)
    // Note: Background handler is registered in main.dart as a top-level function
    debugPrint('[FCM] Message handlers registered');

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification tapped (background): ${message.data}');
      FCMNotificationHandler.handleNotificationTap(message);
    });

    // Handle notification tap when app was terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM] Notification tapped (terminated): ${message.data}');
        FCMNotificationHandler.handleNotificationTap(message);
      }
    });
  }

  /// Save FCM token to Hive
  Future<void> saveTokenToHive(String token) async {
    try {
      await _storageService.saveFcmToken(token);
      debugPrint('[FCM] Token saved to Hive');
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to save token to Hive: $e');
    }
  }

  /// Get saved FCM token from Hive
  Future<String?> getSavedToken() async {
    try {
      final token = await _storageService.getFcmToken();
      if (token != null) {
        debugPrint('[FCM] Retrieved saved token: ${token.substring(0, 20)}...');
      } else {
        debugPrint('[FCM] No saved token found in Hive');
      }
      return token;
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to get saved token: $e');
      return null;
    }
  }

  /// Get current FCM token (from memory or retrieve new)
  String? get currentToken => _fcmToken;

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM ERROR] Failed to unsubscribe from topic $topic: $e');
    }
  }
}
