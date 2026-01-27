import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backend_com_service.dart';
import 'add_members_screen.dart';
import 'remove_members_screen.dart';
import 'delete_group_dialog.dart';

/// Screen to display group members
class GroupMembersScreen extends StatefulWidget {
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

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  String? _currentDriverPhone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDriverPhone = widget.currentDriverPhone;
  }

  /// Check if current user can assign driver (admin only)
  bool _canAssignDriver() {
    return widget.isAdmin;
  }

  /// Assign driver to the group
  Future<void> _assignDriver(String phoneNumber) async {
    try {
      setState(() => _isLoading = true);

      await BackendComService.instance.assignDriver(
        groupId: widget.groupId,
        driverPhoneNumber: phoneNumber,
      );

      setState(() {
        _currentDriverPhone = phoneNumber;
        _isLoading = false;
      });

      // Success message shown by BackendComService via showMessageInStatus()
    } catch (e) {
      setState(() => _isLoading = false);

      // Error message already shown by BackendComService
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to assign driver')),
        );
      }
    }
  }

  /// Show confirmation dialog before assigning driver
  void _confirmAssignDriver(String phoneNumber) {
    final isReplacing = _currentDriverPhone != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Driver'),
        content: Text(
          isReplacing
              ? 'Assign $phoneNumber as the new driver?\n\nThis will replace the current driver.'
              : 'Assign $phoneNumber as the driver for this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _assignDriver(phoneNumber);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// Copy phone number to clipboard
  void _copyPhoneNumber(BuildContext context, String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $phoneNumber'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Normalize phone number for comparison (handles format variations)
  String _normalizePhoneNumber(String? phone) {
    if (phone == null) return '';
    // Remove all non-digit and non-plus characters
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Check if a phone number matches admin
  bool _isAdminPhone(String phoneNumber) {
    if (widget.adminPhoneNumber == null) return false;
    return _normalizePhoneNumber(phoneNumber) ==
        _normalizePhoneNumber(widget.adminPhoneNumber);
  }

  /// Check if a phone number matches driver
  bool _isDriverPhone(String phoneNumber) {
    if (_currentDriverPhone == null) return false;
    return _normalizePhoneNumber(phoneNumber) ==
        _normalizePhoneNumber(_currentDriverPhone);
  }

  /// Get the role description for a member
  String _getMemberRole(String phoneNumber) {
    final roles = <String>[];
    if (_isAdminPhone(phoneNumber)) roles.add('Admin');
    if (_isDriverPhone(phoneNumber)) roles.add('Driver');
    if (roles.isEmpty) return 'Member';
    return roles.join(' & ');
  }

  /// Navigate to add members screen (DES-GRP003)
  Future<void> _navigateToAddMembers() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );

    // Refresh member list if members were added
    if (result == true && mounted) {
      // Return to group details with refresh flag
      Navigator.pop(context, true);
    }
  }

  /// Navigate to remove members screen (DES-GRP004)
  Future<void> _navigateToRemoveMembers() async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final members = widget.memberPhoneNumbers ?? [];

    if (members.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove members - group has only one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RemoveMembersScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
          memberPhoneNumbers: members,
          currentUserPhone: currentUserPhone,
          adminPhoneNumber: widget.adminPhoneNumber,
        ),
      ),
    );

    // Refresh member list if members were removed
    if (result == true && mounted) {
      Navigator.pop(context, true); // Return to group details with refresh flag
    }
  }

  /// Show delete group dialog (DES-GRP005)
  Future<void> _showDeleteGroupDialog() async {
    final result = await DeleteGroupDialog.show(
      context: context,
      groupId: widget.groupId,
      groupName: widget.groupName,
    );

    if (result == true && mounted) {
      // Group was deleted - navigate back to home
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Pop all the way back to home/group list
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.memberPhoneNumbers ?? [];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.groupName} Members')),
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
                      if (widget.isAdmin) ...[
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
                // Members list and operations in a single scrollable view
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: members.length + (widget.isAdmin ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Group operations section at the end
                      if (index == members.length) {
                        return Column(
                          children: [
                            const Divider(height: 32),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Group Operations',
                                    style: TextStyle(
                                      color: Colors.deepPurple[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Delete Group button
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _showDeleteGroupDialog,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[50],
                                              foregroundColor: Colors.red[700],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: 0,
                                              side: BorderSide(
                                                color: Colors.red[300]!,
                                              ),
                                            ),
                                            child: const Text(
                                              'Delete Group',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Add Members button
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _navigateToAddMembers,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green[50],
                                              foregroundColor:
                                                  Colors.green[700],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: 0,
                                              side: BorderSide(
                                                color: Colors.green[300]!,
                                              ),
                                            ),
                                            child: const Text(
                                              'Add Members',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Remove Members button
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _navigateToRemoveMembers,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange[50],
                                              foregroundColor:
                                                  Colors.orange[700],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: 0,
                                              side: BorderSide(
                                                color: Colors.orange[300]!,
                                              ),
                                            ),
                                            child: const Text(
                                              'Remove Members',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 80), // Extra space
                          ],
                        );
                      }

                      // Member list item
                      final phoneNumber = members[index];
                      return Column(
                        children: [
                          ListTile(
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Copy button
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  color: Colors.grey[600],
                                  tooltip: 'Copy phone number',
                                  onPressed: () {
                                    _copyPhoneNumber(context, phoneNumber);
                                  },
                                ),
                                // Three-dot menu (admin only)
                                if (_canAssignDriver())
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                    ),
                                    tooltip: 'More options',
                                    enabled: !_isLoading,
                                    onSelected: (value) {
                                      if (value == 'set_driver') {
                                        _confirmAssignDriver(phoneNumber);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'set_driver',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.drive_eta,
                                              size: 20,
                                              color: Colors.deepOrange[700],
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('Set as Driver'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (index < members.length - 1) const Divider(),
                        ],
                      );
                    },
                  ),
                ),
                // Loading indicator
                if (_isLoading) const LinearProgressIndicator(),
              ],
            ),
    );
  }
}
