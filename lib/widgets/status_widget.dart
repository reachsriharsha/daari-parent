import 'package:flutter/material.dart';

enum StatusType { error, info, success }

/// Global status message management
class StatusManager {
  static final ValueNotifier<StatusMessage?> _statusNotifier = ValueNotifier(
    null,
  );

  /// Show a status message globally
  static void showMessage(String type, String message) {
    final statusType = _getStatusType(type);
    _statusNotifier.value = StatusMessage(message: message, type: statusType);
  }

  /// Clear the current status message
  static void clearMessage() {
    _statusNotifier.value = null;
  }

  /// Get the current status notifier for listening
  static ValueNotifier<StatusMessage?> get statusNotifier => _statusNotifier;

  static StatusType _getStatusType(String type) {
    switch (type.toLowerCase()) {
      case 'error':
        return StatusType.error;
      case 'info':
        return StatusType.info;
      case 'success':
        return StatusType.success;
      default:
        return StatusType.info;
    }
  }
}

/// Status message data class
class StatusMessage {
  final String message;
  final StatusType type;

  StatusMessage({required this.message, required this.type});
}

/// Custom Status Widget that displays at bottom of screen
class CustomStatusWidget extends StatelessWidget {
  const CustomStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusMessage?>(
      valueListenable: StatusManager.statusNotifier,
      builder: (context, statusMessage, child) {
        if (statusMessage == null) {
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
            bottom: 12 + bottomPadding, // Add extra padding for navigation bar
          ),
          decoration: BoxDecoration(
            color: _getBackgroundColor(statusMessage.type),
            border: Border(
              top: BorderSide(
                color: _getBorderColor(statusMessage.type),
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getIcon(statusMessage.type),
                color: _getTextColor(statusMessage.type),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusMessage.message,
                  style: TextStyle(
                    color: _getTextColor(statusMessage.type),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: StatusManager.clearMessage,
                icon: Icon(
                  Icons.close,
                  color: _getTextColor(statusMessage.type),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(StatusType type) {
    switch (type) {
      case StatusType.error:
        return Colors.red.shade50;
      case StatusType.info:
        return Colors.blue.shade50;
      case StatusType.success:
        return Colors.green.shade50;
    }
  }

  Color _getBorderColor(StatusType type) {
    switch (type) {
      case StatusType.error:
        return Colors.red.shade300;
      case StatusType.info:
        return Colors.blue.shade300;
      case StatusType.success:
        return Colors.green.shade300;
    }
  }

  Color _getTextColor(StatusType type) {
    switch (type) {
      case StatusType.error:
        return Colors.red.shade700;
      case StatusType.info:
        return Colors.blue.shade700;
      case StatusType.success:
        return Colors.green.shade700;
    }
  }

  IconData _getIcon(StatusType type) {
    switch (type) {
      case StatusType.error:
        return Icons.error_outline;
      case StatusType.info:
        return Icons.info_outline;
      case StatusType.success:
        return Icons.check_circle_outline;
    }
  }
}

/// Global function for easy access from anywhere in the app
void showMessageInStatus(String type, String message) {
  StatusManager.showMessage(type, message);
}

/// Global function to clear status message
void clearStatusMessage() {
  StatusManager.clearMessage();
}

/*
showMessageInStatus("error", "Backend connection failed");
showMessageInStatus("info", "Connecting to server...");  
showMessageInStatus("success", "Login successful!");
clearStatusMessage(); // To clear current message
*/
