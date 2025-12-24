import 'package:flutter/material.dart';
import 'location_storage_service.dart';
import 'backend_com_service.dart';
import '../utils/app_logger.dart';

/// Service class to handle user-related operations
class UserService {
  final String baseUrl;
  final LocationStorageService _storageService;
  late final BackendComService _backendService;

  UserService({
    required this.baseUrl,
    required LocationStorageService storageService,
  }) : _storageService = storageService {
    _backendService = BackendComService(baseUrl: baseUrl);
  }

  /// Update user home coordinates locally and sync to backend
  Future<Map<String, dynamic>> updateUserHomeCoordinates({
    required double latitude,
    required double longitude,
    void Function(String log)? onLog,
  }) async {
    try {
      // Get required data from storage
      final idToken = _storageService.getIdToken();
      final profId = _storageService.getProfId();

      if (idToken == null || idToken.isEmpty) {
        throw Exception('User not authenticated - ID token missing');
      }

      if (profId == null) {
        throw Exception('Profile ID not found');
      }

      onLog?.call(
        '[USER] Updating home coordinates: lat=$latitude, lng=$longitude',
      );

      // Send coordinates to backend
      final result = await _backendService.sendUserHomeCoordinatesToBackEnd(
        idToken: idToken,
        profId: profId,
        latitude: latitude,
        longitude: longitude,
        onLog: onLog,
      );

      onLog?.call('[USER] Home coordinates updated successfully');

      return result;
    } catch (e) {
      final errorMsg = '[USER ERROR] Failed to update home coordinates: $e';
      onLog?.call(errorMsg);
      logger.error(errorMsg);
      rethrow;
    }
  }

  /// Get current authentication status
  bool get isAuthenticated {
    final idToken = _storageService.getIdToken();
    return idToken != null && idToken.isNotEmpty;
  }

  /// Get current user profile ID
  String? get currentProfId => _storageService.getProfId();
}
