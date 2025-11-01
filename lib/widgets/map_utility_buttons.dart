import 'package:flutter/material.dart';

class MapUtilityButtons extends StatelessWidget {
  final bool showRouteButton;
  final VoidCallback onMyLocation;
  final VoidCallback? onShowRoute;

  const MapUtilityButtons({
    super.key,
    required this.showRouteButton,
    required this.onMyLocation,
    this.onShowRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: onMyLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('My Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[800],
          ),
        ),
        if (showRouteButton && onShowRoute != null)
          ElevatedButton.icon(
            onPressed: onShowRoute,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Show Route'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[100],
              foregroundColor: Colors.blue[800],
            ),
          ),
      ],
    );
  }
}
