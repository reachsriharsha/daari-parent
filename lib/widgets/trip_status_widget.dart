import 'package:flutter/material.dart';
import '../models/trip_status_data.dart';

/// Enhanced status widget for displaying trip event information
/// Shows event type, coordinates, timestamp, and additional details
class TripStatusWidget extends StatelessWidget {
  final TripStatusData? statusData;

  const TripStatusWidget({super.key, this.statusData});

  @override
  Widget build(BuildContext context) {
    if (statusData == null) {
      return const SizedBox.shrink();
    }

    // Get bottom padding to avoid system navigation bar
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(statusData!),
        border: Border(
          top: BorderSide(color: _getBorderColor(statusData!), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Event type and timestamp
          Row(
            children: [
              Icon(
                _getIcon(statusData!),
                color: _getTextColor(statusData!),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusData!.eventType,
                  style: TextStyle(
                    color: _getTextColor(statusData!),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                statusData!.formattedTime,
                style: TextStyle(
                  color: _getTextColor(statusData!),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Additional info (if available)
          if (statusData!.additionalInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              statusData!.additionalInfo!,
              style: TextStyle(
                color: _getTextColor(statusData!).withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get background color based on event type
  Color _getBackgroundColor(TripStatusData data) {
    if (data.isStartEvent) {
      return Colors.purple.shade50;
    } else if (data.isUpdateEvent) {
      return Colors.blue.shade50;
    } else if (data.isFinishEvent) {
      return Colors.green.shade50;
    }
    return Colors.grey.shade50;
  }

  /// Get border color based on event type
  Color _getBorderColor(TripStatusData data) {
    if (data.isStartEvent) {
      return Colors.purple.shade300;
    } else if (data.isUpdateEvent) {
      return Colors.blue.shade300;
    } else if (data.isFinishEvent) {
      return Colors.green.shade300;
    }
    return Colors.grey.shade300;
  }

  /// Get text color based on event type
  Color _getTextColor(TripStatusData data) {
    if (data.isStartEvent) {
      return Colors.purple.shade700;
    } else if (data.isUpdateEvent) {
      return Colors.blue.shade700;
    } else if (data.isFinishEvent) {
      return Colors.green.shade700;
    }
    return Colors.grey.shade700;
  }

  /// Get icon based on event type
  IconData _getIcon(TripStatusData data) {
    if (data.isStartEvent) {
      return Icons.play_circle_outline;
    } else if (data.isUpdateEvent) {
      return Icons.navigation_outlined;
    } else if (data.isFinishEvent) {
      return Icons.check_circle_outline;
    }
    return Icons.info_outline;
  }
}
