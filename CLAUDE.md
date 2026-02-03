# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**daari-parent** is the Flutter-based Android parent app for real-time school van tracking. It receives FCM notifications from the backend, displays live driver location on Google Maps, and provides proximity-based audio announcements via text-to-speech.

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Generate Hive adapters (after modifying models)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running
```bash
# Run on connected device/emulator
flutter run

# Run with specific device
flutter run -d <device-id>

# Build APK for testing
flutter build apk --debug
flutter build apk --release
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/<test_file>.dart
```

## Architecture Overview

The app uses a reactive, event-driven architecture with per-group state management and immutable state patterns.

### Core Design Patterns

**1. Per-Group TripViewerController Registry**
- Global registry: `Map<int, TripViewerController> tripViewerControllers`
- Each group has independent controller instance
- FCM messages routed to correct controller by `group_id`
- Supports parents with children in multiple schools simultaneously

**2. Immutable State Pattern**
- `TripViewingState` is fully immutable
- All updates create new instances: `state.addPoint(newPoint)`
- Predictable state transitions
- Easier debugging and time-travel debugging
- Works seamlessly with Flutter's rebuild model

**3. FCM-Driven Architecture**
- Backend pushes trip updates via Firebase Cloud Messaging
- Three message types: `trip_started`, `trip_updated`, `trip_finished`
- Handles foreground, background, and terminated app states
- `trip_updated` are silent (data-only) to reduce notification fatigue

**4. Proximity Announcement System**
- Audio alerts when van approaches home location
- Thresholds: 1km, 500m, 200m, 100m
- One-time announcements per threshold using boolean flags
- Uses `flutter_tts` for text-to-speech
- Flags reset when trip finishes

**5. Passive Location Tracking**
- Parent app never uses GPS directly
- All location data received via FCM from backend
- No background services needed (unlike driver app)
- Battery-efficient for parents

### Key File Locations

**Entry Point & Core**
- `lib/main.dart` - App initialization, Hive setup, controller registry, session routing
- `lib/constants.dart` - App-wide constants and configuration values

**Pages (Main Screens)**
- `lib/login_page.dart` - Firebase phone auth, FCM token registration, ngrok URL config
- `lib/home_page.dart` - Dashboard showing all groups, group creation
- `lib/group_details_page.dart` - **Critical**: Trip viewing with map, status widget, announcements
- `lib/select_contacts_page.dart` - Contact picker with phone validation

**Controllers**
- `lib/controllers/trip_viewer_controller.dart` - **Critical**: Per-group trip state, FCM message handling, proximity detection, map updates

**Models**
- `lib/models/trip_viewing_state.dart` - **Critical**: Immutable trip state with helper methods
- `lib/models/trip_update_data.dart` - FCM payload parser
- `lib/models/trip_status_data.dart` - Calculated trip statistics (elapsed time, distance, ETA)
- `lib/models/group.dart` - Hive model (TypeId: 3)
- `lib/models/app_settings.dart` - Hive model (TypeId: 2)
- `lib/models/trip_settings.dart` - Hive model (TypeId: 1)
- `lib/models/location_point.dart` - Hive model (TypeId: 0)

**Services**
- `lib/services/app_initializer.dart` - Service initialization orchestrator
- `lib/services/backend_com_service.dart` - HTTP API client (singleton)
- `lib/services/fcm_notification_handler.dart` - **Critical**: FCM message routing to controllers
- `lib/services/announcement_service.dart` - Text-to-speech proximity announcements
- `lib/services/location_storage_service.dart` - Hive database manager
- `lib/services/notification_service.dart` - Local notification display

**Screens (Dialogs/Subpages)**
- `lib/screens/group_members_screen.dart` - Member list, add/remove members, driver assignment
- `lib/screens/add_members_screen.dart` - Add members workflow
- `lib/screens/remove_members_screen.dart` - Remove members workflow with validation
- `lib/screens/delete_group_dialog.dart` - Group deletion confirmation

**Widgets**
- `lib/widgets/trip_status_widget.dart` - Display elapsed time, distance, speed, ETA
- `lib/widgets/status_widget.dart` - Global status message system
- `lib/widgets/search_place_widget.dart` - Google Places autocomplete

**Utilities**
- `lib/utils/app_logger.dart` - Centralized logging with file output
- `lib/utils/phone_number_utils.dart` - Phone validation/normalization to `+91XXXXXXXXXX`
- `lib/utils/distance_calculator.dart` - Haversine distance calculations

### TripViewerController State Machine

```
IDLE (isTripActive=false, points=[])
  ↓ FCM: trip_started
VIEWING (isTripActive=true, points=[start, ...])
  ↓ FCM: trip_updated (multiple)
VIEWING (points grow with each update)
  ↓ FCM: trip_finished
FINISHED (show completion UI)
  ↓ Reset
IDLE
```

**State is immutable** - each update creates new `TripViewingState` instance.

### FCM Message Handling

**Message Payload Structure**
```json
{
  "data": {
    "type": "trip_started | trip_updated | trip_finished",
    "trip_name": "trip_5_12_1705312200",
    "group_id": "5",
    "latitude": "28.6139",
    "longitude": "77.2090",
    "timestamp": "2025-01-15T10:30:00Z",
    "group_name": "School Group A"
  }
}
```

**App State Handling**
- **Foreground**: `onMessage` listener → Parse → Route to controller → Update UI
- **Background**: `firebaseMessagingBackgroundHandler` → System notification → Update on resume
- **Terminated**: System shows notification → Tap opens app → `getInitialMessage()` → Navigate to group

### Proximity Announcement Logic

```dart
void _checkProximityAndAnnounce(LatLng driverLocation) {
  final distance = Geolocator.distanceBetween(
    driverLocation.latitude, driverLocation.longitude,
    homeLocation.latitude, homeLocation.longitude,
  );

  if (distance <= 100 && !_announced100m) {
    _announced100m = true;
    announcementService.announce("Van is arriving");
  } else if (distance <= 200 && !_announced200m) {
    _announced200m = true;
    announcementService.announce("Van is 200 meters away");
  }
  // ... similar for 500m and 1km
}
```

**Reset flags** when trip finishes to enable announcements for next trip.

### Android Notification Channels

```
Channel ID    | Importance | Sound | Purpose
tripStart     | HIGH       | Yes   | Trip started alert
tripUpdate    | LOW        | No    | Silent UI updates
tripEnd       | DEFAULT    | No    | Trip finished notification
```

Channels created at app startup via `FlutterLocalNotificationsPlugin`.

### Map Visualization

**Markers**
- 🟢 Green: Trip start location
- 🔴 Red: Current driver location (animated)
- 🔵 Blue: Destination (school)
- 🏠 Custom: Child's home (if set)

**Polylines**
- Blue line connecting all points in `TripViewingState.points`
- Width: 4.0, Color: Colors.blue

**Camera Behavior**
- Auto-follows driver location during active trip
- Smooth animation via `CameraUpdate.newLatLng()`
- Zoom level maintained by user preference

### Trip Status Display

Calculated from `TripViewingState`:
- **Elapsed Time**: `now - startTime` → "00:15:32"
- **Distance from Home**: `Geolocator.distanceBetween()` → "1.2 km"
- **Current Speed**: `distance / time` → "25 km/h"
- **ETA**: `distance / speed` → "~3 min"

### Phone Number Normalization

All phone numbers must be normalized to `+91XXXXXXXXXX` format:
- Use `PhoneNumberUtils.normalizePhoneNumber()` before API calls
- Reject non-India numbers (only +91 supported)
- Validation regex: `^\+91[6-9]\d{9}$`
- Applied in: contact selection, group creation, member management

### Multi-Group Support

Parents can have children in multiple schools:
```dart
// Access pattern in main.dart
TripViewerController getOrCreateController(int groupId) {
  return tripViewerControllers.putIfAbsent(
    groupId,
    () => TripViewerController(groupId: groupId),
  );
}
```

Each group maintains independent trip state. FCM handler routes messages to correct controller.

### App Initialization Sequence

1. `main()` → Hive initialization → Open boxes
2. `AppInitializer.initializeAllServices()` → Firebase → FCM token
3. Register FCM listeners: `onMessage`, `onBackgroundMessage`
4. Check session validity in Hive
5. Route to LoginPage or HomePage based on session

### Error Handling

- **FCM token invalid**: Re-register token with backend
- **Group not found**: Refresh groups list from backend
- **Location permission denied**: Show rationale dialog (not critical for parent app)
- **Network unavailable**: Show cached data, retry on restore
- **TTS unavailable**: Disable announcements, log warning

### Differences from Driver App

| Aspect             | Parent App       | Driver App       |
|--------------------|------------------|------------------|
| Location tracking  | Passive (FCM)    | Active (GPS)     |
| Trip control       | View only        | Start/Finish     |
| Background service | No (FCM only)    | Yes (location)   |
| Notifications      | Receives via FCM | Sends via API    |
| Multi-group trips  | View multiple    | One at a time    |
| Announcements      | Proximity TTS    | None             |

### Important Notes When Developing

- **TripViewerController must be per-group** - Never use a single global controller
- **State is immutable** - Use `state.addPoint()`, never mutate directly
- **FCM message routing is critical** - Extract `group_id` and route to correct controller
- **Proximity flags must reset** - On trip finish, reset all announcement flags
- **Handle all three app states** - Foreground, background, terminated FCM handling
- **Silent notifications for updates** - Only `trip_started` and `trip_finished` are visible
- **Phone normalization before API calls** - Backend validation is strict
- **Controller lifecycle** - Controllers persist in global registry, not widget lifecycle
- **Home location is optional** - Handle null gracefully if not set
- **Map markers update on every FCM** - Don't accumulate old markers

### Testing Critical Paths

When testing, verify:
1. **Multi-group handling**: Create/join multiple groups, receive updates for each
2. **FCM in all states**: Test foreground, background, terminated message handling
3. **Proximity announcements**: Test all thresholds, verify one-time-only behavior
4. **Immutable state**: Verify new instances created, old state unchanged
5. **Notification channels**: Verify correct sound/importance for each message type
6. **Trip finish cleanup**: Verify map clears, announcement flags reset
7. **Phone normalization**: Test various formats with/without +91, spaces, hyphens
8. **Session persistence**: Verify login state survives app restart
