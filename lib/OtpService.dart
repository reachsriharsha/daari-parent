import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // To access storageService
import 'package:flutter/foundation.dart';
import 'services/backend_com_service.dart';
import 'services/fcm_service.dart';
import 'utils/app_logger.dart';

class OtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String backendUrl;
  final FCMService _fcmService = FCMService();

  OtpService({required this.backendUrl});

  /// Step 1: Send OTP
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto verification or instant verification on some devices
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Step 2: Verify OTP & Login with backend
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String smsCode,
    required Function() onBackendValidated,
    required Function(String error) onBackendFailed,
  }) async {
    try {
      // 1) Sign in with OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      // 2) Get Firebase ID token
      final idToken = await firebaseUser?.getIdToken();
      if (idToken == null) {
        onBackendFailed('Firebase ID token is null');
        return null;
      }

      // 2.5) Get FCM token (always send on login)
      final fcmToken = _fcmService.currentToken ?? await _fcmService.getToken();
      logger.debug(
        '[AUTH] FCM Token: ${fcmToken != null ? "${fcmToken.substring(0, 20)}..." : "null"}',
      );

      // 3) Send ID token + FCM token to backend
      // Create a temporary BackendComService for login (singleton not configured yet)
      final backendService = BackendComService.instance;
      backendService.setBaseUrl(backendUrl);
      final backendResponse = await backendService.loginToBackEnd(
        idToken,
        fcmToken: fcmToken,
      );
      logger.debug(
        '[AUTH] Backend Response: $backendResponse ID Token: $idToken',
      );

      if (backendResponse["prof_id"] == null) {
        onBackendFailed("prof_id missing in backend response");
        return null;
      }

      // 4) Save values to Hive
      await storageService.saveIdToken(idToken);
      await storageService.saveProfId(backendResponse["prof_id"]);
      await storageService.saveNgrokUrl(backendUrl);

      // 5) Sync groups from backend with local Hive storage
      final groupList = backendResponse["group_list"];
      if (groupList != null) {
        logger.debug(
          '[AUTH] Syncing ${(groupList as List).length} groups from backend...',
        );
        final syncResult = await storageService.syncGroupsWithBackend(
          groupList,
        );
        logger.debug(
          '[AUTH] Group sync complete: Added=${syncResult['added']}, '
          'Removed=${syncResult['removed']}, Updated=${syncResult['updated']}, '
          'Total=${syncResult['total']}',
        );
      } else {
        logger.debug('[AUTH] No group_list in backend response, skipping sync');
      }

      // 6) Sync home details from backend
      final homeDetails = backendResponse["home_details"];
      if (homeDetails != null) {
        logger.debug('[AUTH] Syncing home details from backend...');
        try {
          final homeCoords = homeDetails["home_coordinates"];
          if (homeCoords != null) {
            await storageService.saveHomeCoordinates(
              latitude: homeCoords["latitude"],
              longitude: homeCoords["longitude"],
              address: homeDetails["home_address"],
              placeName: homeDetails["home_place_name"],
            );
            logger.debug(
              '[AUTH] Home details synced: ${homeDetails["home_place_name"]} at '
              '(${homeCoords["latitude"]}, ${homeCoords["longitude"]})',
            );
          }
        } catch (e) {
          logger.error('[AUTH ERROR] Failed to sync home details: $e');
        }
      } else {
        logger.debug('[AUTH] No home_details in backend response');
      }

      // 7) Continue to home
      onBackendValidated();
      return userCredential;
    } catch (e) {
      onBackendFailed(e.toString());
      return null;
    }
  }

  /// Refresh FCM token on backend (called when token changes)
  Future<bool> refreshFcmToken() async {
    try {
      // Get current ID token from Hive
      final idToken = storageService.getIdToken();
      if (idToken == null) {
        logger.debug('[AUTH] Cannot refresh FCM token - no ID token found');
        return false;
      }

      // Get current FCM token
      final fcmToken = _fcmService.currentToken ?? await _fcmService.getToken();
      if (fcmToken == null) {
        logger.debug('[AUTH] Cannot refresh FCM token - no FCM token found');
        return false;
      }

      // Send to backend
      await BackendComService.instance.refreshFcmToken(
        idToken: idToken,
        fcmToken: fcmToken,
      );

      logger.debug('[AUTH] FCM token refreshed successfully on backend');
      return true;
    } catch (e, stackTrace) {
      logger.error(
        '[AUTH ERROR] Failed to refresh FCM token: $e Stack trace: $stackTrace',
      );
      return false;
    }
  }
}
