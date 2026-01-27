import 'package:flutter/material.dart';
import '../models/group_member_input.dart';
import '../select_contacts_page.dart';
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
  List<GroupMemberInput> selectedMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const int maxMembers = 20;

  Future<void> _submitMembers() async {
    if (selectedMembers.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one member');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await BackendComService.instance.addGroupMembers(
        groupId: widget.groupId,
        groupName: widget.groupName,
        members: selectedMembers,
      );

      if (response['status'] == 'success') {
        // Show success and pop back
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        setState(
          () => _errorMessage = response['message'] ?? 'Failed to add members',
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
      appBar: AppBar(title: const Text('Add Members'), elevation: 2),
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
                    'Members to add: ${selectedMembers.length}/$maxMembers',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            // Selected members list or empty state
            Expanded(
              child: selectedMembers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No members selected',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to select\nmembers from your contacts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = selectedMembers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              member.getDisplayName(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              member.phoneNumber,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedMembers.removeAt(index);
                                });
                              },
                              tooltip: 'Remove member',
                            ),
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
                  // Select from contacts button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          selectedMembers.length < maxMembers && !_isLoading
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => SelectContactsPage(
                                    onMembersSelected: (members) {
                                      setState(() {
                                        // Limit to maxMembers
                                        final availableSlots =
                                            maxMembers - selectedMembers.length;
                                        if (members.length > availableSlots) {
                                          selectedMembers.addAll(
                                            members.take(availableSlots),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Only $availableSlots members added (max $maxMembers)',
                                              ),
                                            ),
                                          );
                                        } else {
                                          selectedMembers.addAll(members);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.contacts),
                      label: const Text('Select from Contacts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Submit button
                  ElevatedButton(
                    onPressed: selectedMembers.isNotEmpty && !_isLoading
                        ? _submitMembers
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 24,
                      ),
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
                        : const Icon(Icons.check, size: 24),
                  ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
