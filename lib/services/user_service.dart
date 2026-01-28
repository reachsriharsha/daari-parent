import 'location_storage_service.dart';
import 'backend_com_service.dart';
import '../utils/app_logger.dart';

/// Service class to handle user-related operations
class UserService {
  final String baseUrl;
  final LocationStorageService _storageService;

  UserService({
    required this.baseUrl,
    required LocationStorageService storageService,
  }) : _storageService = storageService;

  /// Update user home coordinates, address, and place name locally and sync to backend
  Future<Map<String, dynamic>> updateUserHomeCoordinates({
    required double latitude,
    required double longitude,
    String? homeAddress,
    String? homePlaceName,
    void Function(String log)? onLog,
  }) async {
    try {
      // Get required data from storage
      final idToken = await _storageService.getIdToken();
      final profId = _storageService.getProfId();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('User not authenticated - ID token missing');
      }

      if (profId == null) {
        throw Exception('Profile ID not found');
      }

      onLog?.call(
        '[USER] Updating home: $homePlaceName at ($latitude, $longitude) - $homeAddress',
      );

      // Send data to backend
      final result = await BackendComService.instance
          .sendUserHomeCoordinatesToBackEnd(
            idToken: idToken,
            profId: profId,
            latitude: latitude,
            longitude: longitude,
            homeAddress: homeAddress,
            homePlaceName: homePlaceName,
            onLog: onLog,
          );

      onLog?.call('[USER] Home data updated successfully');

      return result;
    } catch (e) {
      final errorMsg = '[USER ERROR] Failed to update home coordinates: $e';
      onLog?.call(errorMsg);
      logger.error(errorMsg);
      rethrow;
    }
  }

  /// Get current authentication status
  Future<bool> get isAuthenticated async {
    final idToken = await _storageService.getIdToken();
    return idToken != null && idToken.isNotEmpty;
  }

  /// Get current user profile ID
  String? get currentProfId => _storageService.getProfId();
}
