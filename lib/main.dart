import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'controllers/trip_controller.dart';
import 'services/location_storage_service.dart';

// Global instance of storage service
final LocationStorageService storageService = LocationStorageService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage first
  try {
    await storageService.init();
    debugPrint('[HIVE] Hive storage initialized');
  } catch (e) {
    debugPrint('[HIVE ERROR] Failed to initialize Hive: $e');
  }

  // Only initialize Firebase if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey:
            "AIzaSyAwierriEkBCarzpDCbLLzoBQPoEO_Uiro", // Replace with your actual API key
        appId:
            "1:192909758501:android:0d216829daceeca0caefcc", // Replace with your actual App ID
        messagingSenderId:
            "YOUR_MESSAGING_SENDER_ID", // Replace with your actual Messaging Sender ID
        projectId: "otptest1-cbe83", // Replace with your actual Project ID
      ),
    );
  }

  // Initialize background location service
  await TripController.initializeBackgroundService();

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
      debugPrint('[APP LIFECYCLE] App resumed - checking for unsynced data');
      // Trigger bulk sync in TripController if it's active
      // This will be handled by the TripController when it's notified
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage());
  }
}
