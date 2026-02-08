# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**daari-parent** is the Flutter-based Android parent app for real-time school van tracking. It receives FCM notifications from the backend, displays live driver location on Google Maps, and provides proximity-based audio announcements via text-to-speech. The app supports multi-group tracking, contact synchronization, user profile management, and comprehensive diagnostics.

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

### Compilation Verification

**IMPORTANT**: After every code change, compile with the following command and ensure no errors are found:

```bash
flutter build apk --debug --target-platform android-arm64
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/<test_file>.dart
```

## Architecture Overview

The app uses a reactive, event-driven architecture with per-group state management, immutable state patterns, and comprehensive service layers for backend communication, contact sync, and user profile management.

### Core Design Patterns

**1. Per-Group TripViewerController Registry**

- Global registry: `Map<int, TripViewerController> tripViewerControllers`
- Each group has independent controller instance
- FCM messages routed to correct controller by `group_id`
- Supports parents with children in multiple schools simultaneously
- DES-TRP001: 3-tier trip loading (in-memory → Hive → backend)

**2. Immutable State Pattern**

- `TripViewingState` is fully immutable
- All updates create new instances: `state.addPoint(newPoint, eventType: 'trip_updated')`
- Predictable state transitions
- Easier debugging and time-travel debugging
- Works seamlessly with Flutter's rebuild model

**3. FCM-Driven Architecture**

- Backend pushes trip updates via Firebase Cloud Messaging
- Three message types: `trip_started`, `trip_updated`, `trip_finished`
- Handles foreground, background, and terminated app states
- `trip_updated` are silent (data-only) to reduce notification fatigue
- DES-GRP006: Group refresh triggered via FCM, handled on app resume

**4. Dual Proximity Announcement System**

- **Home proximity**: Audio alerts when van approaches parent's home
- **Destination proximity**: Alerts when van approaches school/destination
- Thresholds: 1km, 500m, 200m, 100m (50m for destination reached)
- One-time announcements per threshold using boolean flags
- Uses `flutter_tts` for text-to-speech
- Flags reset when trip finishes

**5. Passive Location Tracking**

- Parent app never uses GPS directly
- All location data received via FCM from backend
- No background services needed (unlike driver app)
- Battery-efficient for parents

**6. Contact Sync Service**

- Smart permission reuse (checks existing grant before requesting)
- Syncs device contact names with group member phone numbers
- Stores in Hive (`GroupMemberName` model, TypeId: 5)
- Fallback to phone number display if permission denied
- Automatic sync on group load

**7. User Profile Management**

- Profile stored in Hive (`UserProfile` model, TypeId: 10)
- Supports first name, last name, email editing
- Profile cached locally with backend sync
- Home address support for proximity calculations

**8. Diagnostic & Logging System**

- Centralized logging via `AppLogger`
- Log viewer screen with filtering by level
- Diagnostic ZIP creation (Hive data + logs + device info)
- Share logs for troubleshooting

### Key File Locations

**Entry Point & Core**

- `lib/main.dart` - App initialization, Hive setup, controller registry, session routing, app lifecycle observer
- `lib/constants.dart` - App-wide constants and configuration values

**Pages (Main Screens)**

- `lib/login_page.dart` - Firebase phone auth, FCM token registration, ngrok URL config
- `lib/home_page.dart` - Dashboard showing all groups, group creation, profile navigation
- `lib/group_details_page.dart` - **Critical**: Trip viewing with map, status widget, dual proximity announcements
- `lib/select_contacts_page.dart` - Contact picker with phone validation and normalization

**Controllers**

- `lib/controllers/trip_viewer_controller.dart` - **Critical**: Per-group trip state, FCM message handling, dual proximity detection (home + destination), map updates, DES-TRP001 3-tier loading

**Models**

- `lib/models/trip_viewing_state.dart` - **Critical**: Immutable trip state with helper methods
- `lib/models/trip_update_data.dart` - FCM payload parser with event type support
- `lib/models/trip_status_data.dart` - Calculated trip statistics (elapsed time, distance, ETA)
- `lib/models/group.dart` / `group.g.dart` - Hive model (TypeId: 3) with destination, address, place name
- `lib/models/group_member_name.dart` / `group_member_name.g.dart` - Hive model (TypeId: 5) for contact sync
- `lib/models/user_profile.dart` / `user_profile.g.dart` - Hive model (TypeId: 10) for user data
- `lib/models/group_member_input.dart` - Input model for group member creation
- `lib/models/app_settings.dart` / `app_settings.g.dart` - Hive model (TypeId: 2)
- `lib/models/trip_settings.dart` / `trip_settings.g.dart` - Hive model (TypeId: 1)
- `lib/models/location_point.dart` / `location_point.g.dart` - Hive model (TypeId: 0)

**Services**

- `lib/services/app_initializer.dart` - Service initialization orchestrator
- `lib/services/backend_com_service.dart` - HTTP API client (singleton), DES-AUTH001 device info
- `lib/services/fcm_notification_handler.dart` - **Critical**: FCM message routing to controllers, DES-GRP006 group refresh
- `lib/services/fcm_service.dart` - FCM token management and registration
- `lib/services/announcement_service.dart` - Text-to-speech proximity announcements
- `lib/services/audio_notification_service.dart` - Background audio playback using just_audio
- `lib/services/notification_service.dart` - Local notification display with channel management
- `lib/services/location_storage_service.dart` - Hive database manager for all data persistence
- `lib/services/group_service.dart` - Group management business logic
- `lib/services/user_service.dart` - User-related operations and home coordinate updates
- `lib/services/profile_service.dart` - User profile fetching, caching, and updates
- `lib/services/contact_sync_service.dart` - Contact name synchronization with smart permissions
- `lib/services/device_info_service.dart` - Device information collection (DES-AUTH001)
- `lib/services/diagnostic_service.dart` - Diagnostic ZIP creation for troubleshooting

**Screens (Dialogs/Subpages)**

- `lib/screens/group_members_screen.dart` - Member list with contact names, add/remove members, driver assignment
- `lib/screens/add_members_screen.dart` - Add members workflow with contact selection
- `lib/screens/remove_members_screen.dart` - Remove members workflow with validation
- `lib/screens/delete_group_dialog.dart` - Group deletion confirmation with name verification
- `lib/screens/profile_page.dart` - User profile viewing and editing (name, email)
- `lib/screens/log_viewer_screen.dart` - Log file viewer with filtering and sharing

**Widgets**

- `lib/widgets/trip_status_widget.dart` - Display elapsed time, distance, speed, ETA
- `lib/widgets/status_widget.dart` - Global status message system
- `lib/widgets/search_place_widget.dart` - Google Places autocomplete for address selection
- `lib/widgets/trip_control_buttons.dart` - Trip control UI elements
- `lib/widgets/route_info_card.dart` - Route information display
- `lib/widgets/map_utility_buttons.dart` - Map control buttons

**Map Services**

- `lib/map_srvc/gmaps_service.dart` - Google Maps Places API integration (autocomplete, place details)
- `lib/map_srvc/models/place_coordinates.dart` - Place coordinate models
- `lib/map_srvc/models/place_prediction.dart` - Autocomplete prediction models

**Utilities**

- `lib/utils/app_logger.dart` - Centralized logging with file output and rotation
- `lib/utils/phone_number_utils.dart` - Phone validation/normalization to `+91XXXXXXXXXX`
- `lib/utils/distance_calculator.dart` - Haversine distance calculations

**Other**

- `lib/route_service.dart` - Google Maps Directions API integration
- `lib/OtpService.dart` - Firebase phone authentication wrapper
- `lib/shared_preferences.dart` - User preferences management

### TripViewerController State Machine

```
IDLE (isTripActive=false, points=[])
  ↓ FCM: trip_started / DES-TRP001: loadActiveTrip()
VIEWING (isTripActive=true, points=[start, ...])
  ↓ FCM: trip_updated (multiple, silent)
VIEWING (points grow with each update, proximity checks)
  ↓ FCM: trip_finished
FINISHED (show completion UI, disable wakelock)
  ↓ Reset proximity flags
IDLE
```

**State is immutable** - each update creates new `TripViewingState` instance.

### FCM Message Handling

**Message Payload Structure**

```json
{
  "notification": {
    "title": "Trip Started",
    "body": "Driver has started the trip"
  },
  "data": {
    "type": "trip_started | trip_updated | trip_finished | group_refresh",
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

- **Foreground**: `onMessage` listener → Parse → Route to controller → Update UI → Proximity check
- **Background**: `firebaseMessagingBackgroundHandler` → Store notification → Update on app resume
- **Terminated**: System shows notification → Tap opens app → `getInitialMessage()` → Navigate to group
- **DES-GRP006**: `group_refresh` notifications processed on app resume

### Dual Proximity Announcement Logic

**Home Proximity:**

```dart
void _checkProximityToHome(double lat, double lng) {
  final homeCoords = _getHomeCoordinates();
  if (homeCoords == null) return;

  final distance = DistanceCalculator.calculateDistance(
    lat, lng, homeCoords.latitude, homeCoords.longitude,
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

**Destination Proximity:**

```dart
void _checkProximityToDestination(double lat, double lng) {
  final destCoords = await _getGroupDestination();
  if (destCoords == null) return;

  final distance = DistanceCalculator.calculateDistance(
    lat, lng, destCoords.latitude, destCoords.longitude,
  );

  if (distance <= 50 && !_announcedDestReached) {
    _announcedDestReached = true;
    announcementService.announce("Van has reached destination");
  } else if (distance <= 100 && !_announcedDest100m) {
    _announcedDest100m = true;
    announcementService.announce("Van is approaching destination");
  }
  // ... similar for 200m, 500m, 1km
}
```

**Reset flags** when trip finishes to enable announcements for next trip.

### Android Notification Channels

```
Channel ID    | Importance | Sound | Purpose
tripStart     | HIGH       | Yes   | Trip started alert with audio
tripUpdate    | LOW        | No    | Silent UI updates
tripEnd       | DEFAULT    | No    | Trip finished notification
```

Channels created at app startup via `FlutterLocalNotificationsPlugin`.

### Map Visualization

**Markers**

- 🟢 Green: Trip start location
- 🔴 Red: Current driver location (animated, updated on every FCM)
- 🔵 Blue: Destination (school/drop-off point)
- 🏠 Custom: Child's home (if set in user profile)

**Polylines**

- Blue line connecting all points in `TripViewingState.points`
- Width: 4.0, Color: Colors.blue
- Updated on every `trip_updated` FCM message

**Camera Behavior**

- Auto-follows driver location during active trip
- Smooth animation via `CameraUpdate.newLatLng()`
- Fit-to-path on trip finish
- Zoom level maintained by user interaction

### Trip Status Display

Calculated from `TripViewingState` by `TripStatusData`:

- **Elapsed Time**: `DateTime.now() - startTime` → "00:15:32"
- **Distance from Home**: `Geolocator.distanceBetween()` → "1.2 km"
- **Current Speed**: Calculated from position changes → "25 km/h"
- **ETA**: `distance / speed` → "~3 min"

### Phone Number Normalization

All phone numbers must be normalized to `+91XXXXXXXXXX` format:

- Use `PhoneNumberUtils.normalizePhoneNumber()` before all API calls
- Validation pipeline: Remove spaces/hyphens → Detect format → Normalize → Validate
- Regex: `^\+91[6-9]\d{9}$`
- Applied in: contact selection, group creation, member add/remove, contact sync
- Reject non-India numbers (only +91 supported)

### Contact Sync With Smart Permissions

```dart
// ContactSyncService uses smart permission checking
Future<bool> requestPermission() async {
  // Check if already granted (e.g., from SelectContactsPage)
  if (await Permission.contacts.isGranted) {
    return true; // No dialog - reuses existing grant
  }
  // Only request if not yet granted
  return (await Permission.contacts.request()).isGranted;
}
```

**How It Works:**

1. User grants permission in SelectContactsPage during group creation
2. ContactSyncService checks permission status first
3. If already granted, proceeds without dialog
4. Only requests if not yet granted or permanently denied
5. Gracefully handles permission denial (shows phone numbers)

### Multi-Group Support

Parents can have children in multiple schools:

```dart
// Global registry in main.dart
final Map<int, TripViewerController> tripViewerControllers = {};

// Access pattern
TripViewerController getOrCreateController(int groupId) {
  return tripViewerControllers.putIfAbsent(
    groupId,
    () => TripViewerController(
      groupId: groupId,
      storageService: storageService,
    ),
  );
}
```

Each group maintains independent trip state. FCM handler routes messages to correct controller by `group_id`.

### App Initialization Sequence

1. `main()` → `WidgetsFlutterBinding.ensureInitialized()`
2. `AppInitializer.initializeAllServices()` → Firebase → Hive → FCM
3. Register FCM listeners: `onMessage`, `onBackgroundMessage`
4. Register lifecycle observer (DES-GRP006 group refresh check)
5. Check session validity in Hive
6. Route to LoginPage or HomePage based on session

### Error Handling

| Error                      | Detection          | Action                               |
| -------------------------- | ------------------ | ------------------------------------ |
| FCM token invalid          | Registration error | Re-register token with backend       |
| Group not found            | 404 from backend   | Trigger group refresh (DES-GRP006)   |
| Location permission denied | Permission error   | Show rationale (optional for parent) |
| Network unavailable        | SocketException    | Show cached data, retry on restore   |
| TTS unavailable            | PlatformException  | Disable announcements, log warning   |
| Contact permission denied  | Permission denied  | Show phone numbers instead of names  |

### DES-TRP001: 3-Tier Trip Loading

**Optimization Strategy:**

1. **Tier 1 - In-Memory** (0ms): Check if trip already loaded in `_viewingState`
2. **Tier 2 - Hive Cache** (<50ms): Load from Hive with freshness validation
3. **Tier 3 - Backend API** (<500ms): Fetch from backend if cache stale/missing

**Implementation:**

```dart
Future<void> loadActiveTrip() async {
  // Tier 1: In-memory check
  if (_viewingState.isTripActive) return;

  // Tier 2: Hive cache
  final cachedTrip = await _loadFromHive(groupId);
  if (cachedTrip != null && cachedTrip.isFresh) {
    _viewingState = cachedTrip;
    return;
  }

  // Tier 3: Backend API
  final apiTrip = await _fetchFromBackend(groupId);
  if (apiTrip != null) {
    _viewingState = apiTrip;
    await _saveToHive(apiTrip);
  }
}
```

### Differences from Driver App

| Aspect             | Driver App          | Parent App                     |
| ------------------ | ------------------- | ------------------------------ |
| Location tracking  | Active (GPS)        | Passive (FCM)                  |
| Trip control       | Start/Update/Finish | View only                      |
| Background service | Yes (location)      | No (FCM only)                  |
| Notifications      | Sends via backend   | Receives via FCM               |
| Multi-group trips  | One at a time       | View multiple simultaneously   |
| Announcements      | None                | Dual proximity TTS (home+dest) |
| Contact sync       | No                  | Yes (with smart permissions)   |
| Profile management | No                  | Yes (with home address)        |
| Diagnostics        | Basic               | Full (ZIP export)              |

### Important Notes When Developing

- **TripViewerController must be per-group** - Never use a single global controller
- **State is immutable** - Use `state.addPoint(point, eventType: ...)`, never mutate directly
- **FCM message routing is critical** - Extract `group_id` and route to correct controller
- **Dual proximity flags must reset** - On trip finish, reset all home AND destination announcement flags
- **Handle all three app states** - Foreground, background, terminated FCM handling
- **Silent notifications for updates** - Only `trip_started` has sound, `trip_updated` is silent
- **Phone normalization before API calls** - Backend validation is strict, always use `PhoneNumberUtils`
- **Controller lifecycle** - Controllers persist in global registry, not widget lifecycle
- **Home location is optional** - Handle null gracefully, use cached coordinates from profile
- **Map markers update on every FCM** - Update current location marker, don't accumulate
- **Contact sync uses smart permissions** - Checks existing grant before requesting
- **DES-TRP001 tier loading** - Prefer in-memory → Hive → backend, don't skip tiers
- **DES-GRP006 group refresh** - Check pending refresh on app resume via `didChangeAppLifecycleState`
- **Wakelock management** - Enable on trip start, disable on trip finish
- **Hive TypeId spacing** - Use documented TypeIds, don't create conflicts

### Testing Critical Paths

When testing, verify:

1. **Multi-group handling**: Create/join multiple groups, receive updates for each independently
2. **FCM in all states**: Test foreground, background, terminated message handling
3. **Dual proximity announcements**: Test home AND destination thresholds, verify one-time-only
4. **Immutable state**: Verify new instances created, old state unchanged on updates
5. **Notification channels**: Verify correct sound/importance for each message type
6. **Trip finish cleanup**: Verify map clears, ALL proximity flags reset (home + dest)
7. **Phone normalization**: Test various formats: `9876543210`, `+91 98765 43210`, `+91-9876543210`
8. **Session persistence**: Verify login state survives app restart
9. **Contact sync permissions**: Grant in SelectContactsPage, verify no re-request in sync
10. **DES-TRP001 loading**: Test in-memory hit, Hive cache hit, backend fallback scenarios
11. **DES-GRP006 group refresh**: Test FCM `group_refresh`, verify Hive sync on app resume
12. **Wakelock behavior**: Screen stays on during trip, locks normally after finish
13. **Profile management**: Edit name/email, verify Hive cache and backend sync
14. **Diagnostic ZIP**: Generate ZIP, verify contents (Hive data, logs, device info)
