import 'app_logger.dart';

/// Utility class for phone number normalization and validation
///
/// Ensures all phone numbers are in the format: +91XXXXXXXXXX
/// where X is a 10-digit Indian mobile number starting with 6-9
class PhoneNumberUtils {
  // Regex pattern for final validation: +91 followed by 10 digits starting with 6-9
  static final RegExp _validPhonePattern = RegExp(r'^\+91[6-9]\d{9}$');

  /// Normalize phone number to +91XXXXXXXXXX format
  ///
  /// Handles multiple input formats:
  /// - 9876543210 → +919876543210
  /// - 09876543210 → +919876543210 (removes leading 0)
  /// - 919876543210 → +919876543210
  /// - +919876543210 → +919876543210 (already valid)
  /// - +91 98765 43210 → +919876543210 (removes spaces)
  /// - +91-9876-543210 → +919876543210 (removes hyphens)
  ///
  /// Throws [ArgumentError] if the phone number cannot be normalized
  /// Returns normalized phone number in format +91XXXXXXXXXX
  static String normalizePhoneNumber(String rawPhone) {
    if (rawPhone.isEmpty) {
      throw ArgumentError('Phone number cannot be empty');
    }

    logger.debug('[PhoneNormalization] Input: $rawPhone');

    // Step 1: Remove all non-numeric characters except '+'
    String cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    logger.debug('[PhoneNormalization] After cleanup: $cleaned');

    // Step 2: Process based on length and pattern
    String normalized;

    if (cleaned.length == 10) {
      // Case: 9876543210 → +919876543210
      final firstDigit = int.parse(cleaned[0]);
      if (firstDigit >= 6 && firstDigit <= 9) {
        normalized = '+91$cleaned';
      } else {
        throw ArgumentError(
          'Invalid phone number: must start with 6-9 (got: ${cleaned[0]})',
        );
      }
    } else if (cleaned.length == 11) {
      // Case 1: 09876543210 → +919876543210 (remove leading 0)
      if (cleaned[0] == '0') {
        String withoutZero = cleaned.substring(1);
        final firstDigit = int.parse(withoutZero[0]);
        if (firstDigit >= 6 && firstDigit <= 9) {
          normalized = '+91$withoutZero';
        } else {
          throw ArgumentError(
            'Invalid phone number: must start with 6-9 after removing leading 0',
          );
        }
      } else {
        // Case 2: Any other 11-digit pattern → REJECT
        throw ArgumentError(
          'Invalid phone number: 11-digit numbers must start with 0',
        );
      }
    } else if (cleaned.length == 12) {
      // Case: 919876543210 → +919876543210
      if (cleaned.startsWith('91')) {
        String digits = cleaned.substring(2);
        final firstDigit = int.parse(digits[0]);
        if (firstDigit >= 6 && firstDigit <= 9) {
          normalized = '+$cleaned';
        } else {
          throw ArgumentError(
            'Invalid phone number: must start with 6-9 after country code',
          );
        }
      } else {
        throw ArgumentError(
          'Invalid phone number: 12-digit numbers must start with 91',
        );
      }
    } else if (cleaned.length == 13) {
      // Case: +919876543210 → validate and use as-is
      if (cleaned.startsWith('+91')) {
        String digits = cleaned.substring(3);
        final firstDigit = int.parse(digits[0]);
        if (digits.length == 10 && firstDigit >= 6 && firstDigit <= 9) {
          normalized = cleaned;
        } else {
          throw ArgumentError(
            'Invalid phone number: must have 10 digits starting with 6-9 after +91',
          );
        }
      } else {
        throw ArgumentError(
          'Invalid phone number: only Indian numbers (+91) are supported',
        );
      }
    } else {
      throw ArgumentError(
        'Invalid phone number length: ${cleaned.length} (expected 10-13 digits)',
      );
    }

    // Step 3: Final validation
    if (!validatePhoneNumber(normalized)) {
      throw ArgumentError('Phone number failed final validation: $normalized');
    }

    logger.debug('[PhoneNormalization] Output: $normalized');
    return normalized;
  }

  /// Validate if phone number matches the required format
  ///
  /// Returns true if the number matches +91[6-9]XXXXXXXXX pattern
  static bool validatePhoneNumber(String phoneNumber) {
    return _validPhonePattern.hasMatch(phoneNumber);
  }

  /// Try to normalize phone number, returning null if invalid
  ///
  /// This is a safe version that doesn't throw exceptions
  /// Use this when you want to handle invalid numbers gracefully
  static String? tryNormalizePhoneNumber(String rawPhone) {
    try {
      return normalizePhoneNumber(rawPhone);
    } catch (e) {
      logger.warning(
        '[PhoneNormalization] Failed to normalize: $rawPhone - $e',
      );
      return null;
    }
  }

  /// Get user-friendly error message for phone number validation
  static String getValidationErrorMessage(String rawPhone) {
    try {
      normalizePhoneNumber(rawPhone);
      return ''; // No error
    } catch (e) {
      if (e is ArgumentError) {
        String message = e.message.toString();

        // Provide user-friendly messages
        if (message.contains('empty')) {
          return 'Phone number is required';
        } else if (message.contains('start with 6-9')) {
          return 'Indian mobile numbers must start with 6, 7, 8, or 9';
        } else if (message.contains('only Indian numbers')) {
          return 'Only Indian phone numbers (+91) are supported';
        } else if (message.contains('length')) {
          return 'Invalid phone number length';
        } else if (message.contains('11-digit')) {
          return 'Invalid phone number format';
        } else {
          return 'Invalid phone number format';
        }
      }
      return 'Invalid phone number';
    }
  }

  /// Format phone number for display (optional, for future use)
  ///
  /// Converts +919876543210 to +91 98765 43210 for better readability
  /// Currently not used as per design decision to display as-is
  static String formatForDisplay(String normalizedPhone) {
    if (normalizedPhone.length == 13 && normalizedPhone.startsWith('+91')) {
      return '+91 ${normalizedPhone.substring(3, 8)} ${normalizedPhone.substring(8)}';
    }
    return normalizedPhone;
  }
}
