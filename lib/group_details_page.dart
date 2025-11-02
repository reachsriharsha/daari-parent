import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'controllers/trip_controller.dart';
import 'widgets/search_place_widget.dart';
import 'widgets/trip_control_buttons.dart';
import 'widgets/map_utility_buttons.dart';
import 'widgets/route_info_card.dart';
import 'widgets/resume_trip_dialog.dart';
import 'widgets/status_widget.dart';
import 'main.dart'; // For storageService

class GroupDetailsPage extends StatefulWidget {
  final String groupName;
  final int groupId;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const GroupDetailsPage({
    super.key,
    required this.groupName,
    required this.groupId,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final LatLng _karnatakaCenter = const LatLng(12.9716, 77.5946); // Bengaluru

  // Controller for managing trip logic (pass storage service)
  late final TripController _tripController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize TripController with storage service
    _tripController = TripController(storageService);

    _tripController.getCurrentLocation();
    _initializeDestination();

    // Check for incomplete trips after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForIncompleteTrip();
    });
  }

  /// Check if there's an incomplete trip and ask user to resume
  Future<void> _checkForIncompleteTrip() async {
    if (_tripController.hasIncompleteTrip()) {
      await ResumeTripDialog.show(
        context: context,
        tripController: _tripController,
        onResume: () async {
          await _tripController.resumeTrip();
          _showSnackBar('[RESUME] Trip resumed successfully');
        },
        onDiscard: () async {
          await _tripController.discardIncompleteTrip();
          _showSnackBar('[RESUME] Incomplete trip discarded');
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes to foreground, check and sync unsynced points
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        '[APP LIFECYCLE] App resumed in GroupDetailsPage - triggering sync check',
      );
      _tripController.checkAndSyncUnsyncedPoints();
    }
  }

  /// Initialize destination from stored coordinates
  void _initializeDestination() {
    // Check if we have valid destination coordinates
    if (widget.destinationLatitude != null &&
        widget.destinationLongitude != null) {
      final lat = widget.destinationLatitude!;
      final lng = widget.destinationLongitude!;

      // Only use coordinates if they are not both zero
      if (lat != 0.0 || lng != 0.0) {
        final destination = LatLng(lat, lng);
        _tripController.setPickedLocation(destination);

        debugPrint('[MAP] Initialized with destination: $lat, $lng');
      }
    }
  }

  /// Setup map after it's created
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // If we have a destination, update markers and animate to it
    if (_tripController.pickedLocation != null) {
      _tripController.updateMarkersAndRoute();

      // Animate camera to destination
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_tripController.pickedLocation!, 15),
      );

      debugPrint('[MAP] Map created and camera moved to destination');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripController.dispose();
    super.dispose();
  }

  /// Handle place selection from search
  Future<void> _handlePlaceSelected(LatLng location, String placeName) async {
    debugPrint('[MAP] Place selected: $placeName at $location');

    // Set the picked location
    _tripController.setPickedLocation(location);

    // Update markers (no route path)
    _tripController.updateMarkersAndRoute();

    // Animate map to the selected location
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
    }

    // Show confirmation message
    _showSnackBar('[MAP] Selected: $placeName');

    // Automatically send coordinates to backend
    await _sendCoordinatesToBackend();
  }

  /// Send selected coordinates to backend
  Future<void> _sendCoordinatesToBackend() async {
    try {
      debugPrint('[API] Sending coordinates to backend...');
      final result = await _tripController.updateGroupAddress(
        groupId: widget.groupId,
        onLog: (log) {}, // Ignore logs for auto-save
        onSuccess: () {
          // Refresh UI after successful update
          if (mounted) {
            setState(() {
              // Trigger rebuild to reflect updated coordinates in Hive
            });
          }
        },
      );

      if (mounted) {
        debugPrint('[API] Coordinates sent successfully: ${result['message']}');
        // Optionally show a subtle success indicator
        // _showSnackBar('[API] Location saved');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[API ERROR] Failed to send coordinates: $e');
        _showSnackBar('[API WARNING] Failed to save location to server');
      }
    }
  }

  /// Handle start trip button
  Future<void> _handleStartTrip() async {
    if (_tripController.pickedLocation == null) {
      _showSnackBar('Please set a destination first by tapping on the map.');
      return;
    }

    String logs = "";
    try {
      await _tripController.startTrip(
        groupId: widget.groupId,
        onLog: (log) => logs = log,
        onTripStarted: () {
          // Animate map to current position when trip starts
          if (_tripController.currentLocation != null &&
              _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_tripController.currentLocation!, 16),
            );
            debugPrint(
              '[MAP] Map focused on current position: ${_tripController.currentLocation}',
            );
          }
        },
      );

      if (mounted) {
        _showSnackBar("[TRIP] Trip started - Live tracking enabled");
      }
    } catch (e) {
      if (mounted) {
        _showApiLogsDialog(logs.isNotEmpty ? logs : e.toString());
        _showSnackBar("[TRIP ERROR] Failed to start trip: $e");
      }
    }
  }

  /// Handle finish trip button
  Future<void> _handleFinishTrip() async {
    String logs = "";
    try {
      logs = await _tripController.finishTrip(
        widget.groupId,
        (log) => logs = log,
      );

      if (mounted) {
        _showApiLogsDialog(logs);
        _showSnackBar("[TRIP] Trip finished");
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("[TRIP ERROR] Failed to finish trip: $e");
      }
    }
  }

  /// Handle set address button
  Future<void> _handleSetAddress() async {
    if (_tripController.pickedLocation == null) {
      _showSnackBar('Please tap on the map to pick a location.');
      return;
    }

    String logs = "";
    try {
      final result = await _tripController.updateGroupAddress(
        groupId: widget.groupId,
        onLog: (log) => logs = log,
        onSuccess: () {
          // Refresh UI after successful update
          if (mounted) {
            setState(() {
              // Trigger rebuild to reflect updated Hive data
            });
          }
        },
      );

      if (mounted) {
        _showApiLogsDialog(logs);
        _showSnackBar(result['message'] ?? 'Address updated!');
      }
    } catch (e) {
      if (mounted) {
        _showApiLogsDialog(logs.isNotEmpty ? logs : e.toString());
        _showSnackBar("[API ERROR] Failed to update address: $e");
      }
    }
  }

  /// Handle my location button
  Future<void> _handleMyLocation() async {
    await _tripController.getCurrentLocation();
    if (_tripController.currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_tripController.currentLocation!, 16),
      );
    }
  }

  /// Fit the map to show the entire route
  void _fitMapToRoute() {
    if (_mapController == null ||
        _tripController.currentLocation == null ||
        _tripController.pickedLocation == null) {
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(
              _tripController.currentLocation!.latitude,
              _tripController.pickedLocation!.latitude,
            ) -
            0.01,
        math.min(
              _tripController.currentLocation!.longitude,
              _tripController.pickedLocation!.longitude,
            ) -
            0.01,
      ),
      northeast: LatLng(
        math.max(
              _tripController.currentLocation!.latitude,
              _tripController.pickedLocation!.latitude,
            ) +
            0.01,
        math.max(
              _tripController.currentLocation!.longitude,
              _tripController.pickedLocation!.longitude,
            ) +
            0.01,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  /// Handle map tap
  void _handleMapTap(LatLng position) {
    _tripController.setPickedLocation(position);

    if (_tripController.tripActive) {
      _tripController.updateMarkersAndRoute();
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Show API logs dialog
  void _showApiLogsDialog(String logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Logs'),
        content: SingleChildScrollView(child: Text(logs)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: AnimatedBuilder(
        animation: _tripController,
        builder: (context, child) {
          return Column(
            children: [
              _buildSearchSection(),
              _buildControlButtons(),
              _buildRouteInfo(),
              _buildMapView(),
              const CustomStatusWidget(),
            ],
          );
        },
      ),
    );
  }

  /// Build search section
  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SearchPlaceWidget(
        mapController: _mapController,
        onPlaceSelected: _handlePlaceSelected,
      ),
    );
  }

  /// Build control buttons section
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TripControlButtons(
            tripActive: _tripController.tripActive,
            hasDestination: _tripController.pickedLocation != null,
            onStartTrip: _handleStartTrip,
            onFinishTrip: _handleFinishTrip,
            onSetAddress: _handleSetAddress,
            onMyLocation: _handleMyLocation,
          ),
          if (_tripController.tripActive &&
              _tripController.currentLocation != null &&
              _tripController.pickedLocation != null) ...[
            const SizedBox(height: 8),
            MapUtilityButtons(
              showRouteButton: true,
              onMyLocation: _handleMyLocation,
              onShowRoute: _fitMapToRoute,
            ),
          ],
        ],
      ),
    );
  }

  /// Build route info display
  Widget _buildRouteInfo() {
    return Column(
      children: [
        RouteInfoCard(
          routeInfo: _tripController.routeInfo,
          tripActive: _tripController.tripActive,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Build map view
  Widget _buildMapView() {
    return Expanded(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _karnatakaCenter,
          zoom: 7.5,
        ),
        mapType: MapType.normal,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        onTap: _handleMapTap,
        markers: _tripController.markers,
        polylines: _tripController.polylines,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
