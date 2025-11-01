# Copilot Instructions for Chalaka (Daari-C)

## Project Overview

**Chalaka** is a Flutter mobile app for group-based trip tracking with real-time location sharing. It uses Firebase authentication, Google Maps, and a custom backend API accessible via Ngrok tunneling. The app supports offline-first location storage using Hive and automatic crash recovery for interrupted trips.

## Architecture

### Service-Oriented Design

The app separates business logic into distinct services:

- **`TripController`** (`lib/controllers/trip_controller.dart`) - Trip state management using `ChangeNotifier` pattern. Manages location streaming, path visualization, and backend synchronization.
- **`GroupService`** (`lib/group_service.dart`) - Group CRUD operations, dual storage (local + backend).
- **`OtpService`** (`lib/OtpService.dart`) - Firebase phone auth + backend token validation.
- **`LocationStorageService`** (`lib/services/location_storage_service.dart`) - Hive-based offline storage for location points and trip recovery.
- **`RouteService`** (`lib/route_service.dart`) - Google Directions API integration for route planning.

### Critical Data Flow: Trip Tracking

**Location Updates:** GPS stream → Hive storage → Backend API (every 5m or 8s)

```dart
// Stream triggers on EITHER 5-meter movement OR 8-second timeout (whichever comes first)
LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5, timeLimit: Duration(seconds: 8))
```

**Key point:** Trip updates are driven by the GPS location stream (`_startLocationTracking()`) in `TripController`. There is NO separate timer for updates anymore (see `CHANGE_HISTORY.md` for details on this refactoring).

### Offline-First Architecture

Location points are **always** saved to Hive first, then synced to backend:

1. Save `LocationPoint` to Hive with `isSynced: false`
2. Attempt backend sync via `GroupService.sendUpdateTripMsg()`
3. Mark `isSynced: true` on success; leave false for later bulk sync
4. On app resume, `checkAndSyncUnsyncedPoints()` uploads all unsynced points

**Crash Recovery:** If app crashes mid-trip, Hive's `trip_settings` box preserves state. On next launch, `ResumeTripDialog` prompts user to resume or discard incomplete trip.

## Code Generation & Build

### Hive Type Adapters

**ALWAYS** regenerate adapters after modifying `@HiveType` models:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Affected files: `lib/models/location_point.dart`, `lib/models/trip_settings.dart` → generates `.g.dart` files.

### Standard Build Commands

```bash
flutter pub get                    # Get dependencies
flutter run                         # Debug run (requires device/emulator)
flutter build apk                   # Android production build
flutter analyze                     # Static analysis
flutter format .                    # Dart code formatting
```

## Critical Conventions

### Authentication Flow

1. User enters phone + Ngrok URL in `LoginPage`
2. Firebase OTP verification via `OtpService.verifyOtp()`
3. Backend validates Firebase ID token at `POST /auth/login`
4. Response contains `prof_id` and `group_list` → saved to Hive via `LocationStorageService`
5. ID token used as Bearer token for all API calls: `Authorization: Bearer <id_token>`

**Important:** All authentication data (id_token, prof_id, ngrok_url) is stored in Hive's `app_settings` box, NOT SharedPreferences.

### Trip Lifecycle

```
Start → GPS Streaming → Hive Save → Backend Sync → Finish → Summary
```

- **Start:** `TripController.startTrip()` → saves `TripSettings` to Hive, sends "start" event
- **Tracking:** Location stream automatically updates `_pathPoints[]` and syncs to backend
- **Finish:** `_sendTripFinish()` → sends "finish" event, clears `TripSettings`, keeps `_pathPoints` for summary
- **Polyline:** Blue line on map represents traveled path (`_pathPoints`), NOT planned route

### State Management Patterns

- **Global Service Instance:** `final storageService = LocationStorageService()` in `main.dart` (initialized before Firebase)
- **TripController:** Injected with `storageService` in each `GroupDetailsPage` instance
- **ChangeNotifier:** `TripController` notifies UI via `notifyListeners()` after `_pathPoints` updates
- **Lifecycle Observer:** `GroupDetailsPage` implements `WidgetsBindingObserver` to trigger sync on app resume

### Data Storage Architecture

**Primary Storage: Hive** (via `LocationStorageService`)

- `id_token` - Firebase authentication token (Bearer token for API calls)
- `prof_id` - User profile ID from backend
- `ngrok_url` - Backend base URL
- `LocationPoint` - Trip location data with sync status
- `TripSettings` - Active trip state for crash recovery

**Secondary Storage: SharedPreferences**

- Only for temporary/non-critical data (background service coordination)
- Authentication tokens have been migrated OUT of SharedPreferences to Hive

**Group Data Storage**

- Groups stored in local JSON file: `assets/data/groups.json` → `app_documents/groups.json`
- Managed by `GroupService.getLocalGroups()` and `GroupService.createGroup()`

### Error Handling Philosophy

- **Hive failures:** Continue trip, log error (trip can survive without local storage)
- **Backend failures:** Keep point in Hive as unsynced, retry later
- **Permission denials:** Graceful fallback messages, don't block other features

## File Organization

### Page Architecture

- **`LoginPage`** → **`HomePage`** → **`GroupDetailsPage`** (main map interface)
- `SelectContactsPage` - Contact picker for group members (uses `flutter_contacts`)
- Widgets in `lib/widgets/`:
  - `trip_control_buttons.dart` - Start/Stop trip UI
  - `search_place_widget.dart` - Geocoding search
  - `resume_trip_dialog.dart` - Crash recovery prompt
  - `route_info_card.dart` - Distance/duration display

### Models & Persistence

- **Hive models** (`@HiveType`): `LocationPoint`, `TripSettings` in `lib/models/`
- **SharedPreferences wrapper**: `lib/shared_preferences.dart` for session data
- **Groups data**: `assets/data/groups.json` copied to app documents on first run

## Backend Integration

### API Endpoints

All require `Authorization: Bearer <id_token>` header:

- `POST /auth/login` - Firebase token validation
- `POST /api/groups/create` - Create group
- `POST /api/groups/update` - Update group location
- `POST /api/groups/trip/create` - Start trip (event: "start")
- `POST /api/groups/trip/update` - Location update (event: "update") OR finish (event: "finish")

**Request Pattern Example:**

```dart
final response = await http.post(
  Uri.parse("$baseUrl/api/groups/trip/update"),
  headers: {"Authorization": "Bearer $idToken", "Content-Type": "application/json"},
  body: jsonEncode({"group_id": groupId, "trip_id": tripId, "event": "update", "coordinates": {...}})
);
```

## Known Issues & Workarounds

### Background Location Tracking

**Status: ✅ ENABLED** - The app now uses `flutter_background_service` with Android foreground service for reliable background tracking.

**Implementation:**

- Persistent notification shown during active trips (Android requirement)
- Dual tracking: Foreground stream for UI updates + Background service for reliability
- Location points saved to Hive even when app is in background
- Automatic sync to backend when network is available

**Key Files:**

- `lib/services/background_location_service.dart` - Core background tracking logic
- `lib/services/notification_service.dart` - Permission handler for Android 13+
- Background service runs in separate isolate with own Hive instance

**User Experience:**

- Notification displays "Trip Tracking Active - X points recorded"
- Tracking continues during phone calls, app switching, and screen off
- Notification cannot be dismissed while trip is active (Android system requirement)

### API Keys in Source

Google Maps API key (`AIzaSyDQ4s_fpwuw2xFyhFDYt37rsWcipzpgRTo`) and Firebase config are currently hardcoded in:

- `lib/route_service.dart` - Directions API key
- `lib/main.dart` - Firebase initialization
- `android/app/google-services.json` - Android config

**For production:** Move to environment variables or secure storage.

### Data Retention

`LocationStorageService.deleteOldPoints()` removes Hive data older than 7 days (runs on app init).

## Testing & Debugging

### Trip Testing Checklist

1. **Start trip** → Verify Hive save: look for `💾 Saved location point:` logs + notification appears
2. **Background tracking** → Switch to another app for 5 minutes, verify `🌍 [BACKGROUND]` logs continue
3. **Phone call** → Receive call during trip, verify tracking continues
4. **Kill app mid-trip** → Reopen, check for resume dialog (notification should still be visible)
5. **Offline mode** → Turn off internet, start trip, verify Hive storage
6. **Sync test** → Bring app to foreground after offline trip, check for `📤 Found X unsynced points`
7. **Statistics** → After trip finish, verify log: `🏁 Trip finished: Total points: X, Synced: Y, Unsynced: Z`
8. **Notification** → Verify notification disappears after trip ends

### Debug Logging

Key log prefixes for monitoring:

- `💾` - Hive storage operations
- `✅` - Successful backend sync
- `❌` - Errors (storage or network)
- `📤` - Bulk sync triggered
- `🔄` - Trip resume
- `🏁` - Trip completion
- `🌍 [BACKGROUND]` - Background service location updates
- `🚀 [BACKGROUND]` - Background service start/stop

### Analyzing Issues

- **No location updates:** Check `Geolocator` permissions + location services enabled
- **Path not showing:** Verify `_tripActive == true` and `_pathPoints.isNotEmpty`
- **Backend errors:** Check Ngrok URL validity + ID token expiration
- **Performance:** Adjust `distanceFilter` (currently 5m) if too many updates

## Common Tasks

### Adding New Hive Fields

1. Update `@HiveField` annotations in model class
2. Increment `typeId` if adding new model, or update field indices
3. Run `flutter pub run build_runner build --delete-conflicting-outputs`
4. Handle migration for existing data if needed

### Modifying Trip Update Logic

**Critical:** All location updates flow through `_startLocationTracking()` in `TripController`. Do NOT add separate timers (see `CHANGE_HISTORY.md` for why this was removed).

### Integrating New Backend Endpoints

Follow existing pattern in `GroupService`:

1. Get `id_token` from Hive: `storageService.getIdToken()`
2. Add Bearer token to headers
3. Parse response, handle errors with try/catch
4. Log request/response for debugging (use `onLog` callback pattern)

## References

- **Architecture changes:** See `CHANGE_HISTORY.md` for trip controller refactoring details
- **Hive setup:** See `HIVE_IMPLEMENTATION.md` for storage patterns
- **Dev workflows:** See `WARP.md` for platform-specific commands
- **Main flow:** `main.dart` → `LoginPage` → `HomePage` → `GroupDetailsPage`
