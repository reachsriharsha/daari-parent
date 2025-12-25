import 'package:flutter/material.dart';

class TripControlButtons extends StatelessWidget {
  final bool hasDestination;
  final VoidCallback onSetAddress;
  final VoidCallback onMyLocation;
  final String? address;

  const TripControlButtons({
    super.key,
    required this.hasDestination,
    required this.onSetAddress,
    required this.onMyLocation,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: onSetAddress,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(80, 36),
              ),
              child: const Text(
                'Set Destination',
                style: TextStyle(fontSize: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onMyLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('My Location', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[100],
                foregroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(80, 36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Display address or message
        if (address != null && address!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              address!,
              style: const TextStyle(fontSize: 12, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Destination address is not set for the group',
              style: TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
