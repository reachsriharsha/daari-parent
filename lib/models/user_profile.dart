import 'package:hive/hive.dart';

part 'user_profile.g.dart';

/// User profile model for local storage and display
@HiveType(typeId: 10)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String profId;

  @HiveField(1)
  final String phoneNumber;

  @HiveField(2)
  final String? firstName;

  @HiveField(3)
  final String? lastName;

  @HiveField(4)
  final String? email;

  @HiveField(5)
  final DateTime lastUpdated;

  UserProfile({
    required this.profId,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    this.email,
    required this.lastUpdated,
  });

  /// Full name display
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return phoneNumber;
    }
  }

  /// Check if profile is complete
  bool get isComplete {
    return firstName != null && lastName != null && email != null;
  }

  /// Create from JSON (API response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      profId: json['prof_id'] ?? json['profile_id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      lastUpdated: DateTime.now(),
    );
  }

  /// Convert to JSON (for API request)
  Map<String, dynamic> toJson() {
    return {
      'prof_id': profId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    };
  }

  /// Copy with modifications
  UserProfile copyWith({
    String? profId,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
    DateTime? lastUpdated,
  }) {
    return UserProfile(
      profId: profId ?? this.profId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'UserProfile(profId: $profId, name: $fullName, email: $email)';
  }
}
