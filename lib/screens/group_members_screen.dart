import 'package:flutter/material.dart';

/// Screen to display group members
class GroupMembersScreen extends StatelessWidget {
  final String groupName;
  final int groupId;
  final bool isAdmin;
  final List<String>? memberPhoneNumbers;
  final String? adminPhoneNumber;
  final String? currentDriverPhone;

  const GroupMembersScreen({
    super.key,
    required this.groupName,
    required this.groupId,
    this.isAdmin = false,
    this.memberPhoneNumbers,
    this.adminPhoneNumber,
    this.currentDriverPhone,
  });

  /// Normalize phone number for comparison (handles format variations)
  String _normalizePhoneNumber(String? phone) {
    if (phone == null) return '';
    // Remove all non-digit and non-plus characters
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Check if a phone number matches admin
  bool _isAdminPhone(String phoneNumber) {
    if (adminPhoneNumber == null) return false;
    return _normalizePhoneNumber(phoneNumber) ==
        _normalizePhoneNumber(adminPhoneNumber);
  }

  /// Check if a phone number matches driver
  bool _isDriverPhone(String phoneNumber) {
    if (currentDriverPhone == null) return false;
    return _normalizePhoneNumber(phoneNumber) ==
        _normalizePhoneNumber(currentDriverPhone);
  }

  /// Get the role description for a member
  String _getMemberRole(String phoneNumber) {
    final roles = <String>[];
    if (_isAdminPhone(phoneNumber)) roles.add('Admin');
    if (_isDriverPhone(phoneNumber)) roles.add('Driver');
    if (roles.isEmpty) return 'Member';
    return roles.join(' & ');
  }

  @override
  Widget build(BuildContext context) {
    final members = memberPhoneNumbers ?? [];
    return Scaffold(
      appBar: AppBar(title: Text('$groupName Members')),
      body: members.isEmpty
          ? const Center(
              child: Text(
                'No members in this group',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                // Header with member count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.purple[50],
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Text(
                        '${members.length} ${members.length == 1 ? 'Member' : 'Members'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'You\'re Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Members list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final phoneNumber = members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple[100],
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.deepPurple[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                phoneNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Admin badge
                            if (_isAdminPhone(phoneNumber))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Driver badge
                            if (_isDriverPhone(phoneNumber))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.drive_eta,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Driver',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          _getMemberRole(phoneNumber),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Icon(Icons.phone, color: Colors.grey[400]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
