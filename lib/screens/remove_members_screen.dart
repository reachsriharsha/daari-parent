import 'package:flutter/material.dart';
import '../services/backend_com_service.dart';
import '../utils/phone_number_utils.dart';

/// Screen for removing members from an existing group (DES-GRP004)
class RemoveMembersScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final List<String> memberPhoneNumbers;
  final String currentUserPhone;
  final String? adminPhoneNumber;

  const RemoveMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.memberPhoneNumbers,
    required this.currentUserPhone,
    this.adminPhoneNumber,
  });

  @override
  State<RemoveMembersScreen> createState() => _RemoveMembersScreenState();
}

class _RemoveMembersScreenState extends State<RemoveMembersScreen> {
  final Set<String> _selectedPhoneNumbers = {};
  bool _isLoading = false;
  String? _errorMessage;

  static const int maxMembers = 20;

  /// Check if a phone number is the current user
  bool _isCurrentUser(String phoneNumber) {
    final normalizedPhone = PhoneNumberUtils.tryNormalizePhoneNumber(
      phoneNumber,
    );
    final normalizedCurrentUser = PhoneNumberUtils.tryNormalizePhoneNumber(
      widget.currentUserPhone,
    );
    return normalizedPhone != null &&
        normalizedCurrentUser != null &&
        normalizedPhone == normalizedCurrentUser;
  }

  /// Check if a phone number is the admin
  bool _isAdmin(String phoneNumber) {
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

  bool _canRemoveMore() {
    return _selectedPhoneNumbers.length < maxMembers;
  }

  void _toggleSelection(String phoneNumber) {
    // Cannot select self (admin)
    if (_isCurrentUser(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove yourself from the group'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_selectedPhoneNumbers.contains(phoneNumber)) {
        _selectedPhoneNumbers.remove(phoneNumber);
      } else if (_canRemoveMore()) {
        _selectedPhoneNumbers.add(phoneNumber);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum $maxMembers members can be removed at once'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _confirmAndRemove() async {
    if (_selectedPhoneNumbers.isEmpty) {
      setState(
        () => _errorMessage = 'Please select at least one member to remove',
      );
      return;
    }

    // Check if trying to remove all other members (last member scenario)
    final otherMembersCount = widget.memberPhoneNumbers
        .where((phone) => !_isCurrentUser(phone))
        .length;
    if (_selectedPhoneNumbers.length >= otherMembersCount) {
      setState(
        () => _errorMessage =
            'Cannot remove all members. Delete the group instead.',
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text(
          'Are you sure you want to remove ${_selectedPhoneNumbers.length} member(s) from the group?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _removeMembers();
  }

  Future<void> _removeMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await BackendComService.instance.removeGroupMembers(
        groupId: widget.groupId,
        groupName: widget.groupName,
        memberPhoneNumbers: _selectedPhoneNumbers.toList(),
      );

      if (response['status'] == 'success') {
        // Show success and pop back
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        setState(
          () =>
              _errorMessage = response['message'] ?? 'Failed to remove members',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remove Members'), elevation: 2),
      body: SafeArea(
        child: Column(
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade100,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),

            // Group info and selection count
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${_selectedPhoneNumbers.length}/$maxMembers',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select members for removal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Member list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.memberPhoneNumbers.length,
                itemBuilder: (context, index) {
                  final phoneNumber = widget.memberPhoneNumbers[index];
                  final isCurrentUser = _isCurrentUser(phoneNumber);
                  final isAdminUser = _isAdmin(phoneNumber);
                  final isSelected = _selectedPhoneNumbers.contains(
                    phoneNumber,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: isCurrentUser
                            ? null // Disabled for current user
                            : (_) => _toggleSelection(phoneNumber),
                        activeColor: Colors.red,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              phoneNumber,
                              style: TextStyle(
                                color: isCurrentUser ? Colors.grey : null,
                                fontWeight: isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                          if (isAdminUser)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        isCurrentUser
                            ? 'You (cannot remove yourself)'
                            : isSelected
                            ? 'Selected for removal'
                            : 'Tap to select',
                        style: TextStyle(
                          color: isCurrentUser
                              ? Colors.grey
                              : isSelected
                              ? Colors.red
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      enabled: !isCurrentUser,
                      onTap: isCurrentUser
                          ? null
                          : () => _toggleSelection(phoneNumber),
                      tileColor: isSelected
                          ? Colors.red.withOpacity(0.1)
                          : null,
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _selectedPhoneNumbers.isEmpty
                          ? null
                          : _confirmAndRemove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Remove (${_selectedPhoneNumbers.length})'),
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading) const LinearProgressIndicator(color: Colors.red),
          ],
        ),
      ),
    );
  }
}
