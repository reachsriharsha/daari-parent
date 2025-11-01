# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**Chalaka** is a Flutter mobile application for group management with location-based features and trip tracking. The app integrates Firebase authentication with OTP verification, Google Maps for location services, and a custom backend API for group management and real-time trip tracking.

## Common Development Commands

### Build Commands
```bash
# Get dependencies
flutter pub get

# Run on debug mode (requires connected device/emulator)
flutter run

# Build APK for Android
flutter build apk

# Build for specific platforms
flutter build ios
flutter build windows
flutter build web
flutter build linux
flutter build macos
```

### Testing Commands
```bash
# Run all tests
flutter test

# Run widget tests specifically
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Code Quality Commands
```bash
# Analyze code for issues
flutter analyze

# Format code according to Dart style
flutter format .

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade
```

### Device Management
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Clean build artifacts
flutter clean
```

## Architecture Overview

### Core Application Structure

The app follows a service-oriented architecture with clear separation of concerns:

**Authentication Flow:**
- `main.dart` → `login_page.dart` → `OtpService.dart` → Firebase Auth → Backend validation → `home_page.dart`

**Key Services:**
- **`OtpService`**: Handles Firebase phone authentication and backend token validation
- **`GroupService`**: Manages group CRUD operations, trip tracking, and location updates
- **`SharedPrefs`**: Persistent storage wrapper for user session data

**Data Flow:**
1. User authentication via Firebase OTP
2. Backend validation returns `prof_id` and stores `id_token`
3. Groups stored locally in `assets/data/groups.json` and synced with backend
4. Real-time location tracking during active trips
5. Location updates sent to backend every 30 seconds during trips

### Page Architecture

**Login Flow:**
- `LoginPage` → OTP verification → `HomePage`
- Requires Ngrok URL input for backend connectivity
- Stores authentication tokens in SharedPreferences

**Main Application:**
- `HomePage`: Displays groups, handles group creation dialog
- `GroupDetailsPage`: Map interface for location selection, trip management
- `SelectContactsPage`: Contact picker for group member selection

### Backend Integration

The app communicates with a custom backend via Ngrok tunneling:

**Key Endpoints:**
- `POST /auth/login` - Firebase token validation
- `POST /api/groups/create` - Group creation
- `POST /api/groups/update` - Location updates
- `POST /api/groups/trip/create` - Trip initiation
- `POST /api/groups/trip/update` - Trip updates/completion

**Authentication:**
- Uses Firebase ID tokens as Bearer tokens
- All API calls include `Authorization: Bearer <id_token>` header

### Location Services Architecture

**Permission Handling:**
- Uses `geolocator` for location services
- Requests location permissions dynamically
- Handles permission denied scenarios gracefully

**Trip Management:**
- Automatic location updates every 30 seconds during active trips
- Trip states: start → periodic updates → finish
- Real-time location sharing within groups

**Map Integration:**
- Google Maps for location visualization
- Location search via `geocoding` package
- Tap-to-select location functionality

### Contact Integration

**Contact Access:**
- Uses `flutter_contacts` for contact list access
- Permission handling via `permission_handler`
- Search functionality for contact selection
- Extracts phone numbers for group member addition

### Local Data Management

**Storage Strategy:**
- Groups cached locally in `assets/data/groups.json`
- Copied to app documents directory on first run
- Dual storage: local cache + backend synchronization
- Session data in SharedPreferences

## Key Dependencies

### Core Flutter Packages
- `google_maps_flutter`: Map integration
- `firebase_core` & `firebase_auth`: Authentication
- `geolocator`: Location services
- `geocoding`: Address/coordinate conversion

### Data & Networking
- `http`: Backend API communication
- `shared_preferences`: Local data persistence
- `path_provider`: File system access

### UI & Contacts
- `flutter_contacts`: Contact access
- `permission_handler`: Runtime permissions
- `cupertino_icons`: iOS-style icons

## Development Environment Setup

1. **Firebase Configuration:**
   - Ensure `google-services.json` is present in `android/app/`
   - Update Firebase configuration in `main.dart` with actual values
   - Replace placeholder API keys and project IDs

2. **Backend Setup:**
   - Requires Ngrok tunnel for local backend development
   - Backend URL configured dynamically during login
   - Ensure backend endpoints match the service calls

3. **Platform-specific Setup:**
   - **Android**: Location permissions in manifest, Google Maps API key
   - **iOS**: Location permissions in Info.plist, Google Maps configuration
   - **Windows/Linux/macOS**: Location service limitations apply

## Testing Strategy

**Widget Tests:**
- Basic app initialization test in `test/widget_test.dart`
- Consider adding tests for authentication flow
- Add unit tests for service classes

**Integration Testing:**
- Test OTP authentication flow
- Test group creation and management
- Test location services and permissions

## Firebase Configuration Notes

The app currently contains placeholder Firebase configuration values that need to be replaced with actual project credentials:

- API Key: Currently uses placeholder key
- App ID: Platform-specific identifiers needed
- Project ID: Must match Firebase console project
- Messaging Sender ID: Required for proper authentication

## Security Considerations

**Token Management:**
- Firebase ID tokens stored in SharedPreferences
- Tokens used for backend API authentication
- Consider token refresh mechanisms for long sessions

**Location Privacy:**
- Real-time location sharing within groups
- Location data sent to backend for trip tracking
- Users should be informed about location usage

## Build Configuration

**Platform Targets:**
- Primary: Android (Google Maps integrated)
- Secondary: iOS, Windows, Linux, macOS, Web
- Platform-specific permissions and configurations required

**Asset Management:**
- Groups data initialized from `assets/data/groups.json`
- Ensure asset paths are correctly configured in `pubspec.yaml`