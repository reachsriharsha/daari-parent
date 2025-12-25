import 'package:flutter/material.dart';

class TripControlButtons extends StatelessWidget {
  final bool hasDestination;
  final VoidCallback onSetAddress;
  final VoidCallback onMyLocation;

  const TripControlButtons({
    super.key,
    required this.hasDestination,
    required this.onSetAddress,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: onSetAddress,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 36),
          ),
          child: const Text('Set Destination', style: TextStyle(fontSize: 12)),
        ),
        ElevatedButton.icon(
          onPressed: onMyLocation,
          icon: const Icon(Icons.my_location, size: 16),
          label: const Text('My Location', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[800],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(80, 36),
          ),
        ),
      ],
    );
  }
}
