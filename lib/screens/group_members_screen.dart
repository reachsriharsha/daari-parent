import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/backend_com_service.dart';
import '../services/contact_sync_service.dart';
import '../utils/phone_number_utils.dart';
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
  final ContactSyncService _contactSync = ContactSyncService();
  String? _currentDriverPhone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDriverPhone = widget.currentDriverPhone;
    _contactSync.initialize();
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

  /// Launch phone dialer to call the number
  Future<void> _callPhoneNumber(String phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot call $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if a phone number matches admin
  bool _isAdminPhone(String phoneNumber) {
    if (widget.adminPhoneNumber == null) return false;
    final normalizedPhone = PhoneNumberUtils.tryNormalizePhoneNumber(
      phoneNumber,
    );
    final normalizedAdmin = PhoneNumberUtils.tryNormalizePhoneNumber(
      widget.adminPhoneNumber!,
    );
    return normalizedPhone != null &&
        normalizedAdmin != null &&
        normalizedPhone == normalizedAdmin;
  }

  /// Check if a phone number matches driver
  bool _isDriverPhone(String phoneNumber) {
    if (_currentDriverPhone == null) return false;
    final normalizedPhone = PhoneNumberUtils.tryNormalizePhoneNumber(
      phoneNumber,
    );
    final normalizedDriver = PhoneNumberUtils.tryNormalizePhoneNumber(
      _currentDriverPhone!,
    );
    return normalizedPhone != null &&
        normalizedDriver != null &&
        normalizedPhone == normalizedDriver;
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
                      final isAdmin = _isAdminPhone(phoneNumber);
                      final isDriver = _isDriverPhone(phoneNumber);

                      // Get contact name from sync service
                      final contactName = _contactSync.getContactName(
                        widget.groupId,
                        phoneNumber,
                      );

                      // Format display name
                      final displayName = contactName ?? phoneNumber;

                      // Get initials for avatar (if contact name available)
                      String? initials;
                      if (contactName != null && contactName.isNotEmpty) {
                        if (contactName.contains(' ')) {
                          final parts = contactName.split(' ');
                          initials =
                              parts[0][0].toUpperCase() +
                              (parts.length > 1
                                  ? parts[1][0].toUpperCase()
                                  : '');
                        } else {
                          initials = contactName.substring(0, 1).toUpperCase();
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 6,
                        ),
                        elevation: (isDriver || isAdmin) ? 2 : 1,
                        color: isAdmin
                            ? Colors.blue[50]
                            : isDriver
                            ? Colors.orange[50]
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isAdmin
                              ? BorderSide(color: Colors.blue[200]!, width: 1.5)
                              : isDriver
                              ? BorderSide(
                                  color: Colors.deepOrange[200]!,
                                  width: 1.5,
                                )
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              // Avatar/Index
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isAdmin
                                    ? Colors.blue[100]
                                    : isDriver
                                    ? Colors.deepOrange[100]
                                    : Colors.deepPurple[100],
                                child: isAdmin
                                    ? Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.blue[800],
                                        size: 18,
                                      )
                                    : isDriver
                                    ? Icon(
                                        Icons.drive_eta,
                                        color: Colors.deepOrange[800],
                                        size: 18,
                                      )
                                    : initials != null
                                    ? Text(
                                        initials,
                                        style: TextStyle(
                                          color: Colors.deepPurple[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: Colors.deepPurple[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              // Main content column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Display name (contact name or phone)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Phone number as subtitle (only if contact name exists)
                                    if (contactName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          phoneNumber,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    // Action buttons row
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        // Action buttons
                                        IconButton(
                                          icon: const Icon(
                                            Icons.copy,
                                            size: 18,
                                          ),
                                          color: Colors.grey[600],
                                          tooltip: 'Copy',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: () {
                                            _copyPhoneNumber(
                                              context,
                                              phoneNumber,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.phone,
                                            size: 18,
                                          ),
                                          color: Colors.green[600],
                                          tooltip: 'Call',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          onPressed: () {
                                            _callPhoneNumber(phoneNumber);
                                          },
                                        ),
                                        if (_canAssignDriver())
                                          PopupMenuButton<String>(
                                            icon: Icon(
                                              Icons.more_vert,
                                              color: Colors.grey[600],
                                              size: 18,
                                            ),
                                            tooltip: 'More',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            enabled: !_isLoading,
                                            onSelected: (value) {
                                              if (value == 'set_driver') {
                                                _confirmAssignDriver(
                                                  phoneNumber,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'set_driver',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.drive_eta,
                                                      size: 18,
                                                      color: Colors
                                                          .deepOrange[700],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Text('Set as Driver'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    // Role badges row
                                    Row(
                                      children: [
                                        // Badges
                                        if (isAdmin)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[700],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.admin_panel_settings,
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'ADMIN',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (isAdmin && isDriver)
                                          const SizedBox(width: 4),
                                        if (isDriver)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.deepOrange[700],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.drive_eta,
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'DRIVER',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
