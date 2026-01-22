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
    final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
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
      // Admin action buttons (DES-GRP003, DES-GRP004)
      floatingActionButton: widget.isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Remove Members FAB (DES-GRP004)
                FloatingActionButton.extended(
                  heroTag: 'remove_members',
                  onPressed: _isLoading ? null : _navigateToRemoveMembers,
                  icon: const Icon(Icons.person_remove),
                  label: const Text('Remove'),
                  backgroundColor: Colors.red,
                ),
                const SizedBox(height: 12),
                // Add Members FAB (DES-GRP003)
                FloatingActionButton.extended(
                  heroTag: 'add_members',
                  onPressed: _isLoading ? null : _navigateToAddMembers,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add'),
                  backgroundColor: Colors.green,
                ),
              ],
            )
          : null,
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
                      );
                    },
                  ),
                ),
                // Loading indicator
                if (_isLoading) const LinearProgressIndicator(),

                // Delete Group section (admin only) - DES-GRP005
                if (widget.isAdmin) ...[
                  const Divider(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _showDeleteGroupDialog,
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            label: const Text(
                              'Delete Group',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ],
            ),
    );
  }
}
