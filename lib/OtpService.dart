import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // To access storageService
import 'package:flutter/foundation.dart';
import 'services/backend_com_service.dart';

class OtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String backendUrl;
  late final BackendComService _backendService;

  OtpService({required this.backendUrl}) {
    _backendService = BackendComService(baseUrl: backendUrl);
  }

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

      // 3) Send ID token to backend
      final backendResponse = await _backendService.sendIdTokenToBackend(
        idToken,
      );
      debugPrint('[AUTH] Backend Response: $backendResponse');
      debugPrint('[AUTH] ID Token: $idToken');

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
        debugPrint(
          '[AUTH] Syncing ${(groupList as List).length} groups from backend...',
        );
        final syncResult = await storageService.syncGroupsWithBackend(
          groupList,
        );
        debugPrint(
          '[AUTH] Group sync complete: Added=${syncResult['added']}, '
          'Removed=${syncResult['removed']}, Updated=${syncResult['updated']}, '
          'Total=${syncResult['total']}',
        );
      } else {
        debugPrint('[AUTH] No group_list in backend response, skipping sync');
      }

      // 6) Continue to home
      onBackendValidated();
      return userCredential;
    } catch (e) {
      onBackendFailed(e.toString());
      return null;
    }
  }
}
