import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'controllers/trip_viewer_controller.dart';
import 'main.dart'; // For storageService and tripViewerControllers
import 'services/group_service.dart';
import 'services/user_service.dart';
import 'widgets/search_place_widget.dart';
import 'widgets/status_widget.dart';
import 'widgets/trip_control_buttons.dart';
import 'widgets/trip_status_widget.dart';
import 'utils/app_logger.dart';

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

  // Location state for parent app (view-only)
  LatLng? _pickedLocation;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Trip viewer controller for remote trip viewing
  late TripViewerController _tripViewerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize trip viewer controller
    _tripViewerController = TripViewerController(
      storageService: storageService,
      groupId: widget.groupId,
    );

    // Register controller in global registry for FCM access
    tripViewerControllers[widget.groupId] = _tripViewerController;
    logger.debug(
      '[GROUP] Registered TripViewerController for group ${widget.groupId}',
    );

    // Load any active trip being watched
    _tripViewerController.loadActiveTrip();

    // Listen to controller updates
    _tripViewerController.addListener(_onTripViewerUpdate);

    _initializeDestination();
  }

  /// Handle trip viewer updates
  void _onTripViewerUpdate() {
    setState(() {
      // Merge viewer markers with own markers
      _markers = {..._getOwnMarkers(), ..._tripViewerController.markers};

      // Merge polylines
      _polylines = {..._tripViewerController.polylines};
    });
  }

  /// Get markers for own location/destination (not from remote trip)
  Set<Marker> _getOwnMarkers() {
    final ownMarkers = <Marker>{};

    if (_currentLocation != null) {
      ownMarkers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'My Location'),
        ),
      );
    }

    if (_pickedLocation != null) {
      ownMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _pickedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    return ownMarkers;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Parent app doesn't need to sync trip points
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
        _pickedLocation = destination;
        _updateMarkers();

        logger.debug('[MAP] Initialized with destination: $lat, $lng');
      }
    }
  }

  /// Update markers on map
  void _updateMarkers() {
    setState(() {
      _markers = {..._getOwnMarkers(), ..._tripViewerController.markers};
    });
  }

  /// Setup map after it's created
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Provide map controller to trip viewer
    _tripViewerController.setMapController(controller);

    // If we have a destination, animate to it
    if (_pickedLocation != null) {
      // Animate camera to destination
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickedLocation!, 15),
      );

      logger.debug('[MAP] Map created and camera moved to destination');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripViewerController.removeListener(_onTripViewerUpdate);

    // Unregister controller from global registry
    tripViewerControllers.remove(widget.groupId);
    logger.debug(
      '[GROUP] Unregistered TripViewerController for group ${widget.groupId}',
    );

    _tripViewerController.dispose();
    super.dispose();
  }

  /// Handle place selection from search
  Future<void> _handlePlaceSelected(LatLng location, String placeName) async {
    logger.debug('[MAP] Place selected: $placeName at $location');

    // Set the picked location
    _pickedLocation = location;
    _updateMarkers();

    // Animate map to the selected location
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
    }

    // Show confirmation message
    _showSnackBar('[MAP] Selected: $placeName');

    // Automatically send coordinates to backend
    await _sendCoordinatesToBackend();
  }

  /// Handle home address selection from search
  Future<void> _handleHomeAddressSelected(
    LatLng location,
    String address,
  ) async {
    logger.debug('[HOME] Home address selected: $address at $location');

    try {
      // Update user home coordinates using UserService
      await _updateUserHomeCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      // Save to local storage for proximity announcements
      await storageService.saveHomeCoordinates(
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        _showSnackBar('[HOME] Home address saved: $address');
      }
    } catch (e, stackTrace) {
      logger.error(
        '[HOME ERROR] Failed to save home address: $e Stacktrace: $stackTrace',
      );
      if (mounted) {
        _showSnackBar('[HOME ERROR] Failed to save home address');
      }
    }
  }

  /// Send selected coordinates to backend
  Future<void> _sendCoordinatesToBackend() async {
    if (_pickedLocation == null) return;

    try {
      logger.debug('[API] Sending coordinates to backend...');
      final result = await _updateGroupAddressInBackend(
        groupId: widget.groupId,
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
      );

      if (mounted) {
        logger.debug(
          '[API] Coordinates sent successfully: ${result['message']}',
        );
        // Refresh UI after successful update
        setState(() {});
      }
    } catch (e, stackTrace) {
      if (mounted) {
        logger.error(
          '[API ERROR] Failed to send coordinates: $e Stacktrace: $stackTrace',
        );
        _showSnackBar('[API WARNING] Failed to save location to server');
      }
    }
  }

  /// Update group address in backend
  Future<Map<String, dynamic>> _updateGroupAddressInBackend({
    required int groupId,
    required double latitude,
    required double longitude,
  }) async {
    final backendUrl = storageService.getNgrokUrl() ?? "";
    final groupService = GroupService(baseUrl: backendUrl);

    return await groupService.updateGroup(
      groupId: groupId,
      latitude: latitude,
      longitude: longitude,
      onLog: (log) => logger.debug('[API] $log'),
    );
  }

  /// Update user home coordinates in backend
  Future<Map<String, dynamic>> _updateUserHomeCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final backendUrl = storageService.getNgrokUrl() ?? "";
    final userService = UserService(
      baseUrl: backendUrl,
      storageService: storageService,
    );

    return await userService.updateUserHomeCoordinates(
      latitude: latitude,
      longitude: longitude,
      onLog: (log) => logger.debug('[USER] $log'),
    );
  }

  /// Handle set address button
  Future<void> _handleSetAddress() async {
    if (_pickedLocation == null) {
      _showSnackBar('Please tap on the map to pick a location.');
      return;
    }

    String logs = "";
    try {
      final result = await _updateGroupAddressInBackend(
        groupId: widget.groupId,
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
      );

      if (mounted) {
        _showApiLogsDialog(logs);
        _showSnackBar(result['message'] ?? 'Address updated!');
        setState(() {});
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
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _updateMarkers();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 16),
        );
      }
    } catch (e, stackTrace) {
      logger.error(
        '[LOCATION ERROR] Failed to get current location: $e stacktrace: $stackTrace',
      );
      _showSnackBar('Failed to get current location');
    }
  }

  /// Handle map tap
  void _handleMapTap(LatLng position) {
    _pickedLocation = position;
    _updateMarkers();
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
      body: Column(
        children: [
          _buildSearchSection(),
          _buildControlButtons(),
          _buildMapView(),
          // Use TripStatusWidget for remote trip status
          ValueListenableBuilder(
            valueListenable: _tripViewerController.statusNotifier,
            builder: (context, statusData, _) {
              if (statusData != null) {
                return TripStatusWidget(statusData: statusData);
              }
              // Fallback to original status widget
              return const CustomStatusWidget();
            },
          ),
        ],
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
        onHomeAddressSelected: _handleHomeAddressSelected,
        onSetDestination: _handleSetAddress,
      ),
    );
  }

  /// Build control buttons section
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TripControlButtons(
        hasDestination: _pickedLocation != null,
        onSetAddress: _handleSetAddress,
        onMyLocation: _handleMyLocation,
      ),
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
        markers: _markers,
        polylines: _polylines,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
