import 'package:flutter/material.dart';
import '../route_service.dart';

class RouteInfoCard extends StatelessWidget {
  final RouteInfo? routeInfo;
  final bool tripActive;

  const RouteInfoCard({
    super.key,
    required this.routeInfo,
    required this.tripActive,
  });

  @override
  Widget build(BuildContext context) {
    if (routeInfo == null || !tripActive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoColumn(
            icon: Icons.straighten,
            value: routeInfo!.distance,
            label: 'Distance',
          ),
          _buildInfoColumn(
            icon: Icons.access_time,
            value: routeInfo!.duration,
            label: 'Duration',
          ),
          _buildInfoColumn(
            icon: tripActive ? Icons.navigation : Icons.location_on,
            value: tripActive ? 'Tracking' : 'Ready',
            label: 'Status',
            iconColor: tripActive ? Colors.green : Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor ?? Colors.blue),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
