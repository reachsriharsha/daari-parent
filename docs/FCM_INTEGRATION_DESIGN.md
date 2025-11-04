# Firebase Cloud Messaging (FCM) Integration Design

## Overview

This document outlines the complete design for integrating Firebase Cloud Messaging (FCM) into the Daari-Parent app to receive real-time notifications when the Daari-Driver app starts a trip.

## Architecture

### Component Structure

```
┌─────────────────────────────────────────────────────────┐
│                     Main Application                     │
│  - Initialize all services (Hive, Firebase, FCM)        │
│  - Set up global service instances                      │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│              FCM Service (New)                          │
│  - Initialize FCM                                       │
│  - Request notification permissions                     │
│  - Get FCM token                                        │
│  - Handle token refresh                                 │
│  - Register message handlers (foreground/background)    │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ├──► Notification Handler (New)
                    │    - Process incoming messages
                    │    - Parse notification payload
                    │    - Route to appropriate UI handler
                    │
                    ├──► Local Notification Service (Enhanced)
                    │    - Display local notifications
                    │    - Handle notification taps
                    │    - Manage notification channels
                    │
                    └──► Backend Integration (Modified)
                         - Send FCM token during login
                         - Update token when refreshed
```

## File Structure

### New Files

1. **`lib/services/fcm_service.dart`**

   - Main FCM service class
   - Token management
   - Message handler registration

2. **`lib/services/fcm_notification_handler.dart`**

   - Callback class for FCM messages
   - Notification payload parsing
   - Navigation logic based on notification type

3. **`lib/services/app_initializer.dart`**
   - Centralized service initialization
   - Proper initialization order
   - Error handling for service setup

### Modified Files

1. **`lib/main.dart`**

   - Call centralized app initializer
   - Remove individual service initializations

2. **`lib/OtpService.dart`**

   - Add FCM token to login API call
   - Handle token update on refresh

3. **`lib/services/notification_service.dart`**

   - Enhance for FCM notification display
   - Add notification channel management
   - Handle notification tap actions

4. **`android/app/build.gradle.kts`**

   - Verify FCM dependencies

5. **`android/app/src/main/AndroidManifest.xml`**
   - Add FCM-related permissions and metadata

## Detailed Design

### 1. FCM Service (`fcm_service.dart`)

```dart
class FCMService {
  // Singleton pattern
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  // Key Functions:

  // 1. Initialize FCM
  Future<void> initialize()

  // 2. Request notification permissions
  Future<void> requestPermissions()

  // 3. Get FCM token
  Future<String?> getToken()

  // 4. Handle token refresh
  void setupTokenRefreshListener()

  // 5. Register message handlers
  void setupMessageHandlers()

  // 6. Save token to Hive
  Future<void> saveTokenToHive(String token)

  // 7. Get saved token from Hive
  Future<String?> getSavedToken()
}
```

#### Token Management Strategy

- **Initial Token**: Retrieved during app initialization
- **Token Storage**: Saved to Hive's `app_settings` box with key `fcm_token`
- **Token Refresh**: Automatically handled via `FirebaseMessaging.instance.onTokenRefresh`
- **Backend Sync**:
  - **Always send during login** (use existing `/auth/login` endpoint)
  - **On token refresh**: Send to backend via new `/api/user/refreshtoken` endpoint
  - Token always sent regardless of whether it changed (simplified logic)### 2. FCM Notification Handler (`fcm_notification_handler.dart`)

```dart
class FCMNotificationHandler {
  // Handle foreground messages
  static Future<void> handleForegroundMessage(RemoteMessage message)

  // Handle background messages (top-level function required)
  static Future<void> handleBackgroundMessage(RemoteMessage message)

  // Parse notification payload
  static Map<String, dynamic> parsePayload(RemoteMessage message)

  // Route to appropriate screen based on notification type
  static void navigateToScreen(BuildContext context, Map<String, dynamic> data)

  // Handle notification tap
  static void handleNotificationTap(RemoteMessage message)
}

// Top-level function for background handler (Firebase requirement)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FCMNotificationHandler.handleBackgroundMessage(message);
}
```

#### Message Handling Strategy

**Foreground Messages** (app is open):

- Display in-app notification banner using `flutter_local_notifications`
- Option to auto-navigate to trip details
- Update UI if on relevant screen

**Background Messages** (app is in background):

- System tray notification automatically shown by FCM
- On tap: Navigate to trip details page
- Save notification data for later retrieval

**Terminated State** (app not running):

- System tray notification shown
- On tap: App launches and navigates to trip details

### 3. App Initializer (`app_initializer.dart`)

```dart
class AppInitializer {
  // Initialize all services in correct order
  static Future<void> initializeAllServices() async {
    // 1. Hive Storage
    await _initializeHive();

    // 2. Firebase Core
    await _initializeFirebase();

    // 3. FCM Service
    await _initializeFCM();

    // 4. Background Location Service
    await _initializeBackgroundLocation();

    // 5. Local Notifications
    await _initializeLocalNotifications();
  }

  private methods for each initialization...
}
```

#### Initialization Order & Rationale

1. **Hive Storage**: Required by all other services for data persistence
2. **Firebase Core**: Prerequisite for FCM and Auth
3. **FCM Service**: Set up messaging before user interactions
4. **Background Location**: Independent, can be parallel with FCM
5. **Local Notifications**: Used by FCM handler, initialize after FCM

### 4. Backend Integration

#### Login API Modification

**Current Login Request** (`POST /auth/login`):

```json
{
  "id_token": "firebase_id_token_here"
}
```

**Enhanced Login Request**:

```json
{
  "id_token": "firebase_id_token_here",
  "fcm_token": "fcm_device_token_here",
  "platform": "android" // or "ios"
}
```

**Login Response** (unchanged):

```json
{
  "prof_id": "user_profile_id",
  "group_list": [...]
}
```

#### New Token Update Endpoint (Backend Requirement)

**Endpoint**: `POST /api/user/refreshtoken`

**Headers**:

```
Authorization: Bearer <firebase_id_token>
Content-Type: application/json
```

**Request Body**:

```json
{
  "fcm_token": "new_fcm_token_here",
  "platform": "android"
}
```

**Purpose**: Update FCM token when it refreshes without requiring re-login

### 5. Notification Payload Structure

#### Expected Backend Message Format

```json
{
  "notification": {
    "title": "Trip Started",
    "body": "Driver has started a trip in Group Name"
  },
  "data": {
    "type": "trip_start",
    "group_id": "group_123",
    "trip_id": "trip_456",
    "driver_name": "John Doe",
    "timestamp": "2025-11-04T10:30:00Z",
    "latitude": "12.9716",
    "longitude": "77.5946"
  }
}
```

**Note**: All notification types (trip_start, trip_update, trip_end) include optional `latitude` and `longitude` fields for driver location.

#### Notification Types

| Type          | Description            | Action on Tap                                                      | Sound          |
| ------------- | ---------------------- | ------------------------------------------------------------------ | -------------- |
| `trip_start`  | Driver started a trip  | Navigate to GroupDetailsPage (if foreground, show location & path) | Yes (one-time) |
| `trip_update` | Driver location update | Update map with latest location & path (foreground only)           | No             |
| `trip_end`    | Driver ended a trip    | Navigate to trip summary                                           | No             |

**Note**: All notification types include optional driver location data (`latitude`, `longitude`) in payload.

### 6. Enhanced Notification Service

**Current Capabilities**:

- Android 13+ notification permissions
- Basic notification display

**New Capabilities**:

- **Notification Channels**: Create separate channels for different notification types
  - `trip_start`: High priority, sound + vibration (one-time)
  - `trip_updates`: Low priority, silent (no notification in foreground)
  - `trip_end`: Normal priority, vibration only
- **Custom Notification Actions**:
  - "View Trip" - Navigate to details
  - "Dismiss" - Clear notification
- **Notification Grouping**: Group multiple trip notifications by group_id
- **Sound Behavior**:
  - trip_start: Play sound once and finish (non-persistent)
  - trip_update: Silent
  - trip_end: Silent

### 7. Hive Storage Updates

**New Hive Keys** (in `app_settings` box):

| Key               | Type     | Purpose                               |
| ----------------- | -------- | ------------------------------------- |
| `fcm_token`       | String   | Current FCM device token              |
| `fcm_token_sent`  | bool     | Whether current token sent to backend |
| `last_fcm_update` | DateTime | Last token update timestamp           |

## Firebase Console Configuration

### Required Steps on console.firebase.com

#### 1. Enable Cloud Messaging

1. Navigate to your project: **otptest1-cbe83**
2. Go to **Build** → **Cloud Messaging**
3. Click on **Settings** (gear icon) → **Cloud Messaging** tab
4. Verify **Cloud Messaging API (Legacy)** is enabled
   - **Note**: For new projects, use **Firebase Cloud Messaging API (V1)**
5. Enable **Firebase Cloud Messaging API (V1)** (recommended):
   - Click on the three-dot menu → **Manage API in Google Cloud Console**
   - Enable **Firebase Cloud Messaging API**

#### 2. Android Configuration

1. Verify `google-services.json` is up to date:

   - Download latest from **Project Settings** → **General** → **Your apps**
   - Replace `android/app/google-services.json` if changed

2. No additional Android-specific FCM configuration needed (already handled by `google-services.json`)

#### 3. Server Key (for Backend)

1. Go to **Project Settings** → **Cloud Messaging** tab
2. Note down:
   - **Server Key** (for legacy HTTP API) - if using legacy
   - **Service Account** (for HTTP v1 API) - recommended approach
3. Provide to backend team for sending notifications

#### 4. Testing Tools

1. **Cloud Messaging** → **Send test message**:
   - Use FCM token from app logs
   - Test notification delivery
   - Verify payload structure

#### 5. Analytics & Monitoring (Optional)

1. Enable **Google Analytics** for FCM metrics
2. View delivery stats: **Cloud Messaging** → **Reports**
3. Monitor:
   - Delivery rate
   - Open rate
   - Token refresh rate

### Service Account Setup (Recommended for Backend)

#### For Backend Team:

1. Go to **Project Settings** → **Service Accounts**
2. Click **Generate New Private Key**
3. Download JSON file (keep secure!)
4. Use with Firebase Admin SDK for sending messages

**Backend Code Example (Node.js)**:

```javascript
const admin = require("firebase-admin");
const serviceAccount = require("./path/to/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Send notification
const message = {
  notification: {
    title: "Trip Started",
    body: "Driver has started a trip",
  },
  data: {
    type: "trip_start",
    group_id: "group_123",
    trip_id: "trip_456",
  },
  token: userFcmToken,
};

admin.messaging().send(message);
```

## Dependencies

### Flutter Packages (Add to `pubspec.yaml`)

```yaml
dependencies:
  firebase_messaging: ^14.7.9 # FCM core
  flutter_local_notifications: ^17.0.0 # Already exists, may need update
```

### Android Configuration

**`android/app/build.gradle.kts`** - Verify:

```kotlin
dependencies {
    implementation("com.google.firebase:firebase-messaging:23.3.1")
}
```

**`android/app/src/main/AndroidManifest.xml`** - Add:

```xml
<!-- FCM Permissions -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<application>
    <!-- FCM Default Icon -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />

    <!-- FCM Default Color -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/notification_color" />

    <!-- Auto-initialization -->
    <meta-data
        android:name="firebase_messaging_auto_init_enabled"
        android:value="true" />
</application>
```

## Error Handling & Edge Cases

### 1. Token Retrieval Failure

- **Scenario**: `getToken()` returns null
- **Handling**:
  - Retry after 5 seconds (max 3 attempts)
  - Allow login to proceed without FCM token
  - Log error for debugging
  - Show user-friendly message

### 2. Permission Denied

- **Scenario**: User denies notification permissions
- **Handling**:
  - App functions normally without notifications
  - Show settings button to enable later
  - Periodic reminder (once per week)

### 3. Backend API Failure

- **Scenario**: Failed to send FCM token during login
- **Handling**:
  - Store token locally with `fcm_token_sent: false`
  - Retry on next app resume
  - Don't block login flow

### 4. Token Refresh During Offline

- **Scenario**: Token refreshes when no internet
- **Handling**:
  - Save new token to Hive immediately
  - Queue backend update for when online
  - Use connectivity package to detect network

### 5. App Killed During Token Update

- **Scenario**: App crashes mid-token update
- **Handling**:
  - On next launch, check `fcm_token_sent` flag
  - Re-send if false
  - Implement idempotent backend endpoint

## Implementation Phases

### Phase 1: Core FCM Setup (Day 1)

- [ ] Create `FCMService` class
- [ ] Create `AppInitializer` class
- [ ] Update `main.dart` to use initializer
- [ ] Request notification permissions
- [ ] Get and store FCM token in Hive
- [ ] Test token retrieval with debug logs

### Phase 2: Message Handling (Day 2)

- [ ] Create `FCMNotificationHandler` class
- [ ] Implement foreground message handler
- [ ] Implement background message handler
- [ ] Setup local notification display
- [ ] Test with Firebase Console test messages

### Phase 3: Backend Integration (Day 3)

- [ ] Modify `OtpService.login()` to include FCM token
- [ ] Implement token refresh listener
- [ ] Add token update API call
- [ ] Test login with FCM token
- [ ] Verify token persistence

### Phase 4: Navigation & UX (Day 4)

- [ ] Implement notification tap handling
- [ ] Add navigation to GroupDetailsPage
- [ ] Create notification channels
- [ ] Add custom notification actions
- [ ] Test end-to-end flow

### Phase 5: Testing & Polish (Day 5)

- [ ] Test all notification types
- [ ] Test foreground/background/terminated states
- [ ] Handle edge cases and errors
- [ ] Add logging and analytics
- [ ] Documentation update

## Testing Strategy

### Manual Testing

1. **Token Generation**:

   ```
   - Launch app → Check logs for FCM token
   - Copy token from debug logs
   - Verify token saved in Hive
   ```

2. **Foreground Notification**:

   ```
   - App is open and active
   - Send test message from Firebase Console
   - Verify in-app notification appears
   - Tap notification → verify navigation
   ```

3. **Background Notification**:

   ```
   - Minimize app (don't kill)
   - Send test message
   - Verify system tray notification
   - Tap → verify app opens and navigates
   ```

4. **Terminated State**:

   ```
   - Force close app
   - Send test message
   - Verify notification appears
   - Tap → verify app launches and navigates
   ```

5. **Token Refresh**:
   ```
   - Clear app data
   - Launch app → note token
   - Reinstall app → verify new token
   - Check backend received update
   ```

### Automated Testing (Future)

- Mock `FirebaseMessaging` for unit tests
- Test notification payload parsing
- Test navigation logic with mock context
- Integration tests for token flow

## Logging Strategy

### Debug Logs Format

```dart
// Token operations
debugPrint('[FCM] Token retrieved: ${token.substring(0, 20)}...');
debugPrint('[FCM] Token saved to Hive');
debugPrint('[FCM] Token sent to backend: $success');

// Message handling
debugPrint('[FCM] Foreground message received: ${message.notification?.title}');
debugPrint('[FCM] Background message processed: ${message.messageId}');
debugPrint('[FCM] Notification tapped: $data');

// Errors
debugPrint('[FCM ERROR] Failed to get token: $error');
debugPrint('[FCM ERROR] Permission denied');
debugPrint('[FCM ERROR] Backend update failed: $error');
```

## Security Considerations

1. **Token Storage**:

   - Store in Hive (encrypted at OS level)
   - Never log full tokens in production
   - Clear on logout

2. **Backend Validation**:

   - Verify Firebase ID token before accepting FCM token
   - Validate token format
   - Rate limit token updates

3. **Notification Payload**:

   - Validate all data fields before use
   - Sanitize user-generated content (driver names, etc.)
   - Don't include sensitive info in notification body

4. **Permissions**:
   - Request notification permission at appropriate time
   - Explain why permissions needed
   - Gracefully handle denials

## Performance Considerations

1. **Token Retrieval**:

   - Async operation, don't block UI
   - Cache token in memory after first retrieval
   - Throttle token refresh API calls

2. **Message Processing**:

   - Keep handlers lightweight
   - Offload heavy processing to isolates
   - Avoid blocking UI thread

3. **Notification Display**:
   - Limit notification frequency
   - Group related notifications
   - Auto-dismiss old notifications

## Rollback Plan

If FCM integration causes issues:

1. **Code Rollback**:

   - Remove FCM initialization from `AppInitializer`
   - Comment out FCM token in login API
   - App continues to function without notifications

2. **Data Cleanup**:

   - Clear `fcm_token` from Hive
   - Backend marks tokens as inactive

3. **Gradual Rollout**:
   - Use feature flag to enable/disable FCM
   - A/B test with subset of users
   - Monitor crash rates and performance

## Future Enhancements

1. **Topic Subscriptions**: Subscribe to group-specific topics
2. **Rich Notifications**: Images, action buttons, custom layouts
3. **Notification Preferences**: User control over notification types
4. **Analytics**: Track notification engagement
5. **Multi-device Support**: Handle multiple FCM tokens per user
6. **Silent Notifications**: Background data sync triggers

## References

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Channels](https://developer.android.com/develop/ui/views/notifications/channels)

## Appendix: Code Snippets

### Sample Notification Display

```dart
Future<void> showNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'trip_updates',
    'Trip Updates',
    channelDescription: 'Notifications for trip start/stop events',
    importance: Importance.high,
    priority: Priority.high,
    ticker: 'Trip Update',
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    data['trip_id'].hashCode, // Unique ID per trip
    title,
    body,
    platformDetails,
    payload: jsonEncode(data),
  );
}
```

### Sample Navigation Handler

```dart
void handleNotificationTap(String? payload) {
  if (payload == null) return;

  final data = jsonDecode(payload);
  final type = data['type'];

  switch (type) {
    case 'trip_start':
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => GroupDetailsPage(
            groupId: data['group_id'],
            tripId: data['trip_id'],
          ),
        ),
      );
      break;
    // Handle other types...
  }
}
```

---

**Document Version**: 1.0  
**Last Updated**: November 4, 2025  
**Author**: Daari Development Team  
**Status**: Design Phase - Awaiting Review
