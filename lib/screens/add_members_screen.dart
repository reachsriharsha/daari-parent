import 'package:flutter/material.dart';
import '../services/backend_com_service.dart';

/// Screen for adding members to an existing group (DES-GRP003)
class AddMembersScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final List<_MemberInputController> _memberControllers = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const int maxMembers = 20;

  @override
  void initState() {
    super.initState();
    _addMemberInput(); // Start with one empty input
  }

  void _addMemberInput() {
    if (_memberControllers.length >= maxMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $maxMembers members allowed')),
      );
      return;
    }

    setState(() {
      _memberControllers.add(_MemberInputController());
    });
  }

  void _removeMemberInput(int index) {
    if (_memberControllers.length > 1) {
      setState(() {
        _memberControllers[index].dispose();
        _memberControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitMembers() async {
    // Clear previous error
    setState(() => _errorMessage = null);

    // Validate inputs
    final members = <GroupMemberInput>[];
    for (int i = 0; i < _memberControllers.length; i++) {
      final controller = _memberControllers[i];
      final phone = controller.phoneController.text.trim();

      if (phone.isEmpty) {
        setState(
            () => _errorMessage = 'Phone number is required for member ${i + 1}');
        return;
      }

      // Basic phone validation - at least 10 digits
      if (phone.length < 10) {
        setState(() =>
            _errorMessage = 'Invalid phone number for member ${i + 1}');
        return;
      }

      members.add(GroupMemberInput(
        phoneNumber: phone,
        firstName: controller.firstNameController.text.trim().isEmpty
            ? null
            : controller.firstNameController.text.trim(),
        lastName: controller.lastNameController.text.trim().isEmpty
            ? null
            : controller.lastNameController.text.trim(),
      ));
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await BackendComService.instance.addGroupMembers(
        groupId: widget.groupId,
        groupName: widget.groupName,
        members: members,
      );

      if (response['status'] == 'success') {
        // Show success and pop back
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        setState(() => _errorMessage = response['message'] ?? 'Failed to add members');
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
      appBar: AppBar(
        title: const Text('Add Members'),
        elevation: 2,
      ),
      body: Column(
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

          // Group info and member count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
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
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Members to add: ${_memberControllers.length}/$maxMembers',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Member input list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _memberControllers.length,
              itemBuilder: (context, index) {
                return _MemberInputCard(
                  controller: _memberControllers[index],
                  index: index + 1,
                  onRemove: _memberControllers.length > 1
                      ? () => _removeMemberInput(index)
                      : null,
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
                // Add another member button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _memberControllers.length < maxMembers && !_isLoading
                        ? _addMemberInput
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Submit button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitMembers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _memberControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Controller for a single member input row
class _MemberInputController {
  final phoneController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  void dispose() {
    phoneController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
  }
}

/// Widget for a single member input card
class _MemberInputCard extends StatelessWidget {
  final _MemberInputController controller;
  final int index;
  final VoidCallback? onRemove;

  const _MemberInputCard({
    required this.controller,
    required this.index,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green[100],
                      child: Text(
                        '$index',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Member $index',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: onRemove,
                    tooltip: 'Remove member',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: '9876543210',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      hintText: 'Optional',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller.lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'Optional',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
