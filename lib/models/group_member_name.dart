import 'package:hive/hive.dart';

part 'group_member_name.g.dart';

/// Hive model for storing contact names for group members
/// This allows us to display contact names from phone's contact list
/// instead of just showing phone numbers
@HiveType(typeId: 7)
class GroupMemberName extends HiveObject {
  /// Group ID this name belongs to
  @HiveField(0)
  int groupId;

  /// Phone number in normalized format (+91XXXXXXXXXX)
  @HiveField(1)
  String phoneNumber;

  /// Contact name from device contacts
  @HiveField(2)
  String contactName;

  /// Timestamp when this name was last synced
  /// Used for cache invalidation and debugging
  @HiveField(3)
  DateTime lastSynced;

  GroupMemberName({
    required this.groupId,
    required this.phoneNumber,
    required this.contactName,
    required this.lastSynced,
  });

  @override
  String toString() {
    return 'GroupMemberName(groupId: $groupId, phone: $phoneNumber, '
        'name: $contactName, synced: $lastSynced)';
  }
}
