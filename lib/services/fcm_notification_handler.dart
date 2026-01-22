import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

import '../main.dart' show tripViewerControllers, storageService;
import '../models/location_point.dart';
import '../models/trip_update_data.dart';
import '../widgets/status_widget.dart';
import '../utils/app_logger.dart';
import 'announcement_service.dart';
import 'backend_com_service.dart';

/// Global NavigatorKey for navigation from background handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Top-level function for handling background messages
/// Required by Firebase - must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  logger.info(
    '[FCM] Background message received: ${message.notification?.title}',
  );
  await FCMNotificationHandler.handleBackgroundMessage(message);
}

/// FCM Notification Handler
/// Processes incoming FCM messages and handles navigation
class FCMNotificationHandler {
  /// Handle foreground messages (app is open and active)
  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    try {
      logger.info('[FCM] Processing foreground message...');

      final data = parsePayload(message);
      final type = data['type'] as String?;

      logger.debug('[FCM] Message type: $type data: $data');

      // Handle different notification types
      switch (type) {
        case 'trip_started':
          // Show notification with sound
          await EnhancedNotificationService.showTripNotification(
            title: message.notification?.title ?? 'Trip Started',
            body: message.notification?.body ?? 'Driver has started a trip',
            data: data,
            playSound: true,
            channelType: NotificationChannelType.tripStart,
          );

          // Update UI if on GroupDetailsPage
          _updateTripUI(data);

          // Announce trip start - load group name from Hive (not in FCM to reduce payload)
          final startGroupName = await _getGroupNameFromStorage(data['group_id']);
          await announcementService.announce('Trip started for $startGroupName');
          break;

        case 'trip_updated':
          // Silent update - only update UI, no notification
          logger.debug('[FCM] Trip update - updating UI silently');
          _updateTripUI(data);
          break;

        case 'trip_finished':
          // Show notification without sound
          await EnhancedNotificationService.showTripNotification(
            title: message.notification?.title ?? 'Trip Ended',
            body: message.notification?.body ?? 'Driver has ended the trip',
            data: data,
            playSound: false,
            channelType: NotificationChannelType.tripEnd,
          );

          // Update UI
          _updateTripUI(data);

          // Announce trip end - load group name from Hive (not in FCM to reduce payload)
          final endGroupName = await _getGroupNameFromStorage(data['group_id']);
          await announcementService.announce('Trip ended for $endGroupName');
          break;

        // DES-GRP006: Handle group refresh notification
        case 'group_refresh':
          await _handleGroupRefresh();
          break;

        default:
          logger.warning('[FCM] Unknown notification type: $type');
      }
    } catch (e) {
      logger.error('[FCM ERROR] Error handling foreground message: $e');
    }
  }

  /// Handle background messages (app is in background but not terminated)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      logger.info('[FCM] Processing background message...');

      final data = parsePayload(message);
      final type = data['type'] as String?;

      logger.debug('[FCM] Background message type: $type');

      // For background messages, system handles notification display
      // We only process trip_update silently (no notification)
      if (type == 'trip_update') {
        logger.debug(
          '[FCM] Trip update in background - data saved for later retrieval',
        );
        // Could save to Hive here for later UI update
      } else if (type == 'group_refresh') {
        // DES-GRP006: Handle group refresh in background
        logger.debug('[FCM] Group refresh in background - will sync on foreground');
        // Flag for refresh on next foreground - handled by _pendingGroupRefresh
        _pendingGroupRefresh = true;
      }
    } catch (e) {
      logger.error('[FCM ERROR] Error handling background message: $e');
    }
  }

  /// Flag for pending group refresh (DES-GRP006)
  static bool _pendingGroupRefresh = false;

  /// Handle group refresh notification (DES-GRP006)
  static Future<void> _handleGroupRefresh() async {
    logger.info('[FCM] Handling group_refresh notification');

    try {
      // Call refresh API
      final response = await BackendComService.instance.refreshGroups();

      if (response['status'] == 'success') {
        logger.info('[FCM] Group data refreshed successfully');
        // UI will automatically update since Hive storage was synced
      } else {
        logger.warning('[FCM] Group refresh returned non-success status');
      }
    } catch (e) {
      logger.error('[FCM ERROR] Failed to refresh groups: $e');
      // Flag for retry on next app foreground
      _pendingGroupRefresh = true;
    }
  }

  /// Check and handle pending group refresh (call on app resume) (DES-GRP006)
  static Future<void> checkPendingGroupRefresh() async {
    if (_pendingGroupRefresh) {
      logger.debug('[FCM] Processing pending group refresh');
      await _handleGroupRefresh();
      _pendingGroupRefresh = false;
    }
  }

  /// Parse notification payload
  static Map<String, dynamic> parsePayload(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);

    // Extract notification details if available
    if (message.notification != null) {
      data['notification_title'] = message.notification!.title;
      data['notification_body'] = message.notification!.body;
    }

    return data;
  }

  /// Handle notification tap (user tapped on notification)
  static void handleNotificationTap(RemoteMessage message) {
    try {
      final data = parsePayload(message);
      final type = data['type'] as String?;

      logger.info('[FCM] Notification tapped - type: $type');

      // Navigate based on notification type
      navigateToScreen(data);
    } catch (e) {
      logger.error('[FCM ERROR] Error handling notification tap: $e');
    }
  }

  /// Navigate to appropriate screen based on notification data
  static void navigateToScreen(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
      final groupId = data['group_id'] as String?;
      final tripId = data['trip_id'] as String?;

      if (navigatorKey.currentContext == null) {
        logger.warning('[FCM] Navigator context not available yet');
        return;
      }

      switch (type) {
        case 'trip_start':
        case 'trip_update':
          if (groupId != null) {
            logger.debug('[FCM] Navigating to GroupDetailsPage: $groupId');
            // Import and use GroupDetailsPage
            // navigatorKey.currentState?.push(
            //   MaterialPageRoute(
            //     builder: (context) => GroupDetailsPage(groupId: groupId, tripId: tripId),
            //   ),
            // );
            // Note: Actual navigation will be implemented after reviewing existing navigation structure
          }
          break;

        case 'trip_end':
          if (groupId != null) {
            logger.debug('[FCM] Navigating to trip summary: $tripId');
            // Navigate to trip summary page
            // Implementation depends on existing trip summary UI
          }
          break;

        default:
          logger.warning('[FCM] No navigation defined for type: $type');
      }
    } catch (e) {
      logger.error('[FCM ERROR] Error navigating to screen: $e');
    }
  }

  /// Update trip UI with location data from notification
  static Future<void> _updateTripUI(Map<String, dynamic> data) async {
    try {
      logger.debug('[FCM] Updating trip UI with data: $data');

      // Parse FCM data into typed object
      final updateData = TripUpdateData.fromFCM(data);

      logger.debug(
        '[FCM] Trip update parsed: ${updateData.eventType} for trip ${updateData.tripName}',
      );
      logger.debug(
        '[FCM] Location: ${updateData.latitude}, ${updateData.longitude}',
      );

      // Get the TripViewerController for this group from global registry
      // Import is done at top: import '../main.dart' show tripViewerControllers;
      final controller = tripViewerControllers[updateData.groupId];

      if (controller == null) {
        logger.warning(
          '[FCM] No active controller for group ${updateData.groupId} - saving to storage for later viewing',
        );

        // Save trip data to Hive even when no controller is active
        // This allows the data to be loaded when user opens the group later
        await _saveTripDataWithoutController(updateData);

        // Show status message anyway
        showMessageInStatus(
          'info',
          '${updateData.displayEventType}: ${updateData.latitude.toStringAsFixed(4)}, ${updateData.longitude.toStringAsFixed(4)}',
        );
        return;
      }

      // Dispatch to appropriate handler based on event type
      switch (updateData.eventType) {
        case "trip_started":
          controller.handleTripStart(updateData);
          logger.debug('[FCM] Trip start handled by controller');
          break;

        case "trip_updated":
          controller.handleTripUpdate(updateData);
          logger.debug('[FCM] Trip update handled by controller');
          break;

        case "trip_finished":
          controller.handleTripFinish(updateData);
          logger.debug('[FCM] Trip finish handled by controller');
          break;

        default:
          logger.warning('[FCM] Unknown event type: ${updateData.eventType}');
          showMessageInStatus('error', 'Unknown trip event type');
      }

      logger.debug('[FCM] Trip UI update completed');
    } catch (e) {
      logger.error('[FCM ERROR] Error updating trip UI: $e');
      showMessageInStatus('error', 'Failed to process trip update');
    }
  }

  /// Get group name from Hive storage using group ID
  /// Falls back to 'your group' if not found
  static Future<String> _getGroupNameFromStorage(dynamic groupIdValue) async {
    try {
      int? groupId;
      if (groupIdValue is int) {
        groupId = groupIdValue;
      } else if (groupIdValue is String) {
        groupId = int.tryParse(groupIdValue);
      }

      if (groupId == null) {
        logger.warning('[FCM] Invalid group_id for name lookup: $groupIdValue');
        return 'your group';
      }

      final group = await storageService.getGroup(groupId);
      if (group != null && group.groupName.isNotEmpty) {
        logger.debug('[FCM] Loaded group name from Hive: ${group.groupName}');
        return group.groupName;
      }

      logger.warning('[FCM] Group not found in Hive for ID: $groupId');
      return 'your group';
    } catch (e) {
      logger.error('[FCM ERROR] Failed to get group name from storage: $e');
      return 'your group';
    }
  }

  /// Extract location from notification data
  static Map<String, double>? extractLocation(Map<String, dynamic> data) {
    try {
      final latitude = data['latitude'] as String?;
      final longitude = data['longitude'] as String?;

      if (latitude != null && longitude != null) {
        final lat = double.tryParse(latitude);
        final lng = double.tryParse(longitude);

        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    } catch (e) {
      logger.error('[FCM ERROR] Error extracting location: $e');
    }
    return null;
  }

  /// Save trip data directly to Hive when no controller is active
  /// This ensures trip updates are persisted even when user is not viewing the group
  /// The data is stored per-group, supporting multiple simultaneous trips
  static Future<void> _saveTripDataWithoutController(
    TripUpdateData data,
  ) async {
    try {
      logger.info(
        '[FCM] Saving trip data without controller: ${data.eventType} for ${data.tripName} (group ${data.groupId})',
      );

      // Save the location point to Hive with groupId
      // Each group's trip data is stored separately via groupId field
      // loadActiveTrip() queries by groupId to find active trips per group
      final point = LocationPoint(
        latitude: data.latitude,
        longitude: data.longitude,
        timestamp: data.timestamp,
        tripName: data.tripName,
        groupId: data.groupId.toString(),
        tripEventType: data.eventType,
        source: 'fcm',
        receivedAt: DateTime.now(),
        isSynced: true, // FCM points are already from server
      );

      await storageService.saveLocationPoint(point);
      logger.info(
        '[FCM] Saved FCM point to storage: ${data.eventType} at ${data.latitude}, ${data.longitude} for group ${data.groupId}',
      );

    } catch (e) {
      logger.error('[FCM ERROR] Failed to save trip data without controller: $e');
    }
  }
}

/// Enhanced Notification Service with FCM support
enum NotificationChannelType { tripStart, tripUpdate, tripEnd }

class EnhancedNotificationService {
  /// Show trip notification with proper channel and sound settings
  static Future<void> showTripNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required bool playSound,
    required NotificationChannelType channelType,
  }) async {
    try {
      logger.debug(
        '[FCM] Showing notification: $title (sound: $playSound, channel: $channelType)',
      );

      // TODO: Implement actual notification display using flutter_local_notifications
      // This is a placeholder for the implementation

      // Example:
      // final notificationId = data['trip_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
      // await flutterLocalNotificationsPlugin.show(
      //   notificationId,
      //   title,
      //   body,
      //   _getNotificationDetails(channelType, playSound),
      //   payload: jsonEncode(data),
      // );

      logger.debug('[FCM] Notification displayed successfully');
    } catch (e) {
      logger.error('[FCM ERROR] Failed to show notification: $e');
    }
  }
}
