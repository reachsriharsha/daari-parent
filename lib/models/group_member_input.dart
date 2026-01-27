/// Input model for group members with optional name fields
/// Used during group creation and adding members to existing groups
class GroupMemberInput {
  final String phoneNumber;
  final String? firstName;
  final String? lastName;

  GroupMemberInput({required this.phoneNumber, this.firstName, this.lastName});

  Map<String, dynamic> toJson() => {
    'member_phone_number': phoneNumber,
    if (firstName != null && firstName!.isNotEmpty)
      'member_first_name': firstName,
    if (lastName != null && lastName!.isNotEmpty) 'member_last_name': lastName,
  };

  @override
  String toString() {
    final name = getDisplayName();
    return name.isNotEmpty ? '$name ($phoneNumber)' : phoneNumber;
  }

  String getDisplayName() {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.join(' ');
  }
}
