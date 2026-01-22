import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'services/location_storage_service.dart';
import 'services/app_initializer.dart';
import 'services/fcm_notification_handler.dart';
import 'controllers/trip_viewer_controller.dart';
import 'utils/app_logger.dart';

// Global instance of storage service
final LocationStorageService storageService = LocationStorageService();

// Global registry for TripViewerControllers (keyed by groupId)
final Map<int, TripViewerController> tripViewerControllers = {};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all services using centralized initializer
  await AppInitializer.initializeAllServices(storageService: storageService);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes to foreground, trigger sync check
    if (state == AppLifecycleState.resumed) {
      logger.debug('[APP LIFECYCLE] App resumed - checking for unsynced data');
      // Trigger bulk sync in TripController if it's active
      // This will be handled by the TripController when it's notified

      // DES-GRP006: Check for pending group refresh
      FCMNotificationHandler.checkPendingGroupRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Global navigator key for FCM navigation
      home: FutureBuilder<bool>(
        future: _checkSession(),
        builder: (context, snapshot) {
          // Show loading while checking session
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Navigate based on session validity
          final isValid = snapshot.data ?? false;
          return isValid ? const HomePage() : const LoginPage();
        },
      ),
    );
  }

  Future<bool> _checkSession() async {
    try {
      return storageService.isSessionValid();
    } catch (e) {
      logger.error('[SESSION] Error checking session: $e');
      return false;
    }
  }
}
