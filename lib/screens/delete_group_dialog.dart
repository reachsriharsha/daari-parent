import 'package:flutter/material.dart';
import '../services/backend_com_service.dart';

/// Dialog for confirming group deletion with name verification (DES-GRP005)
class DeleteGroupDialog extends StatefulWidget {
  final int groupId;
  final String groupName;

  const DeleteGroupDialog({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  /// Show the delete group dialog
  static Future<bool?> show({
    required BuildContext context,
    required int groupId,
    required String groupName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          DeleteGroupDialog(groupId: groupId, groupName: groupName),
    );
  }

  @override
  State<DeleteGroupDialog> createState() => _DeleteGroupDialogState();
}

class _DeleteGroupDialogState extends State<DeleteGroupDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _performDelete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await BackendComService.instance.deleteGroup(
        groupId: widget.groupId,
        groupName: widget.groupName,
      );

      if (response['status'] == 'success') {
        if (mounted) {
          Navigator.pop(context, true); // Return true for success
        }
      } else {
        setState(
          () => _errorMessage = response['message'] ?? 'Failed to delete group',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to delete group: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          const Text('Delete Group'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group name
            const Text(
              'You are about to delete:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${widget.groupName}"',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Warning message
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to proceed?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        // Delete button
        ElevatedButton(
          onPressed: _isLoading ? null : _performDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
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
              : const Text('Delete'),
        ),
      ],
    );
  }
}
