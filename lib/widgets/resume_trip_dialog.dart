import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';

/// Dialog to ask user if they want to resume an incomplete trip
class ResumeTripDialog extends StatelessWidget {
  final TripController tripController;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const ResumeTripDialog({
    super.key,
    required this.tripController,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final tripInfo = tripController.getIncompleteTripInfo();

    if (tripInfo == null) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 8),
          Text('Incomplete Trip Found'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'It looks like you have an incomplete trip. Would you like to resume it?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (tripInfo['tripName'] != null) ...[
            Text(
              'Trip: ${tripInfo['tripName']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
          ],
          if (tripInfo['tripId'] != null) ...[
            Text('Trip ID: ${tripInfo['tripId']}'),
            const SizedBox(height: 4),
          ],
          if (tripInfo['startTime'] != null) ...[
            Text(
              'Started: ${_formatDateTime(tripInfo['startTime'])}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDiscard();
          },
          child: const Text('Discard', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onResume();
          },
          child: const Text('Resume Trip'),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  /// Show the resume trip dialog
  static Future<void> show({
    required BuildContext context,
    required TripController tripController,
    required VoidCallback onResume,
    required VoidCallback onDiscard,
  }) async {
    if (tripController.hasIncompleteTrip()) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ResumeTripDialog(
          tripController: tripController,
          onResume: onResume,
          onDiscard: onDiscard,
        ),
      );
    }
  }
}
