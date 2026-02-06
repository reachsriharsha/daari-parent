import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // To access storageService
import '../models/user_profile.dart';
import '../widgets/status_widget.dart';
import '../utils/app_logger.dart';

/// Service for managing user profile data (with home address support for parent app)
class ProfileService {
  // Singleton instance
  static final ProfileService instance = ProfileService._internal();

  factory ProfileService() {
    return instance;
  }

  ProfileService._internal();

  static const String _profileCacheKey = 'user_profile_cache';

  /// Get user profile from cache
  Future<UserProfile?> getCachedProfile() async {
    try {
      final box = await storageService.openBox('app_settings');
      final profileData = box.get(_profileCacheKey);

      logger.debug('[PROFILE] Getting cached profile, key: $_profileCacheKey, data: $profileData');

      if (profileData != null && profileData is Map) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(profileData));
        logger.debug('[PROFILE] Successfully loaded cached profile: ${profile.firstName} ${profile.lastName}');
        return profile;
      }
      logger.debug('[PROFILE] No cached profile found');
      return null;
    } catch (e) {
      logger.error('[PROFILE] Error getting cached profile: $e');
      return null;
    }
  }

  /// Fetch user profile from backend
  /// Returns cached profile data or creates new empty profile
  Future<UserProfile?> fetchProfile() async {
    try {
      final profId = storageService.getProfId();
      final user = FirebaseAuth.instance.currentUser;
      final phoneNumber = user?.phoneNumber;

      if (profId == null || phoneNumber == null) {
        logger.error('[PROFILE] No profile ID or phone number found');
        return null;
      }

      // Check cache first
      final cached = await getCachedProfile();
      if (cached != null && cached.profId == profId) {
        logger.debug('[PROFILE] Returning cached profile');
        // Update phone number in case it changed
        return cached.copyWith(phoneNumber: phoneNumber);
      }

      // No cached profile found - create empty profile
      logger.debug('[PROFILE] No cached profile found, creating new empty profile');
      final profile = UserProfile(
        profId: profId,
        phoneNumber: phoneNumber,
        firstName: null,
        lastName: null,
        email: null,
        lastUpdated: DateTime.now(),
      );

      // Cache the empty profile
      await _cacheProfile(profile);

      return profile;
    } catch (e) {
      logger.error('[PROFILE] Error fetching profile: $e');

      // Try to return cached profile even on error
      final cached = await getCachedProfile();
      if (cached != null) {
        logger.info('[PROFILE] Returning cached profile due to fetch error');
        return cached;
      }

      rethrow;
    }
  }

  /// Update user profile (parent app version with home address support)
  Future<bool> updateProfile({
    required String profId,
    String? firstName,
    String? lastName,
    String? email,
    Map<String, double>? homeCoordinates,
    String? homeAddress,
    String? homePlaceName,
  }) async {
    try {
      // Trim whitespace
      final trimmedFirstName = firstName?.trim();
      final trimmedLastName = lastName?.trim();
      final trimmedEmail = email?.trim();
      final trimmedHomeAddress = homeAddress?.trim();
      final trimmedHomePlaceName = homePlaceName?.trim();

      // Client-side validation
      // At least one field must be updated
      if ((trimmedFirstName == null || trimmedFirstName.isEmpty) &&
          (trimmedLastName == null || trimmedLastName.isEmpty) &&
          (trimmedEmail == null || trimmedEmail.isEmpty) &&
          homeCoordinates == null &&
          (trimmedHomeAddress == null || trimmedHomeAddress.isEmpty) &&
          (trimmedHomePlaceName == null || trimmedHomePlaceName.isEmpty)) {
        throw ValidationException('Please provide at least one field to update');
      }

      // Name validation: if both are being updated, at least one should be non-empty
      if ((trimmedFirstName != null || trimmedLastName != null) &&
          (trimmedFirstName == null || trimmedFirstName.isEmpty) &&
          (trimmedLastName == null || trimmedLastName.isEmpty)) {
        throw ValidationException(
            'Please provide at least a first name or last name');
      }

      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        if (!_isValidEmail(trimmedEmail)) {
          throw ValidationException('Please enter a valid email address');
        }
      }

      // Get backend URL and token
      final baseUrl = storageService.getNgrokUrl();
      if (baseUrl == null || baseUrl.isEmpty) {
        showMessageInStatus("error", "Backend URL is not set");
        throw Exception("Backend URL is not set");
      }

      final idToken = await storageService.getIdToken();
      final url = Uri.parse("$baseUrl/api/users/update/");

      // Prepare request body
      final Map<String, dynamic> requestBody = {
        'prof_id': profId,
      };

      if (trimmedFirstName != null && trimmedFirstName.isNotEmpty) {
        requestBody['first_name'] = trimmedFirstName;
      }
      if (trimmedLastName != null && trimmedLastName.isNotEmpty) {
        requestBody['last_name'] = trimmedLastName;
      }
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        requestBody['email'] = trimmedEmail;
      }

      // Add home address fields
      if (homeCoordinates != null) {
        requestBody['home_coordinates'] = homeCoordinates;
      }
      if (trimmedHomeAddress != null && trimmedHomeAddress.isNotEmpty) {
        requestBody['home_address'] = trimmedHomeAddress;
      }
      if (trimmedHomePlaceName != null && trimmedHomePlaceName.isNotEmpty) {
        requestBody['home_place_name'] = trimmedHomePlaceName;
      }

      logger.debug('[API Request] POST $url Body: ${jsonEncode(requestBody)}');

      // Call backend API
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      logger.debug(
          '[API Response Status] ${response.statusCode} Body: ${response.body}');

      if (response.statusCode == 200) {
        // Update cache
        final user = FirebaseAuth.instance.currentUser;
        final phoneNumber = user?.phoneNumber ?? '';
        final updatedProfile = UserProfile(
          profId: profId,
          phoneNumber: phoneNumber,
          firstName: trimmedFirstName,
          lastName: trimmedLastName,
          email: trimmedEmail,
          lastUpdated: DateTime.now(),
        );
        await _cacheProfile(updatedProfile);

        logger.info('[PROFILE] ✅ Profile updated successfully');
        showMessageInStatus("success", "Profile updated successfully");
        return true;
      } else if (response.statusCode == 401) {
        logger.error('[PROFILE ERROR] Unauthorized (401) - Clearing session');
        await storageService.clearSession();
        showMessageInStatus("error", "Session expired. Please login again.");
        throw Exception('Session expired. Please login again.');
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['detail'] ?? 'Failed to update profile';
        showMessageInStatus("error", errorMessage);
        throw Exception(errorMessage);
      }
    } on ValidationException {
      rethrow;
    } catch (e) {
      logger.error('[PROFILE ERROR] Error updating profile: $e');
      showMessageInStatus("error", "Failed to update profile");
      rethrow;
    }
  }

  /// Cache profile to local storage
  Future<void> _cacheProfile(UserProfile profile) async {
    try {
      final box = await storageService.openBox('app_settings');
      final profileJson = profile.toJson();
      logger.debug('[PROFILE] Caching profile for ${profile.profId}: $profileJson');
      await box.put(_profileCacheKey, profileJson);
      logger.debug('[PROFILE] ✅ Successfully cached profile for ${profile.profId}');

      // Verify it was saved
      final verifyData = box.get(_profileCacheKey);
      logger.debug('[PROFILE] Verification - Data in Hive: $verifyData');
    } catch (e) {
      logger.error('[PROFILE ERROR] Error caching profile: $e');
      logger.error('[PROFILE ERROR] Stack trace: ${StackTrace.current}');
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}

/// Custom exception for validation errors
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => message;
}
