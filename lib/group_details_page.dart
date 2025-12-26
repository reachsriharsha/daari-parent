import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'controllers/trip_viewer_controller.dart';
import 'main.dart'; // For storageService and tripViewerControllers
import 'screens/group_members_screen.dart';
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
  final String? placeName;
  final String? address;
  final bool isAdmin;
  final List<String> memberPhoneNumbers;

  const GroupDetailsPage({
    super.key,
    required this.groupName,
    required this.groupId,
    this.destinationLatitude,
    this.destinationLongitude,
    this.placeName,
    this.address,
    this.isAdmin = false,
    this.memberPhoneNumbers = const [],
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

  // Admin editing state
  bool _isEditingDestination = false;
  bool _isEditingHome = false;

  // Home address state
  String? _homePlaceName;
  String? _homeAddress;

  // Helper getters
  bool get _isAdmin => widget.isAdmin;
  bool get _hasDestination => widget.placeName != null;
  bool get _hasHomeAddress => _homePlaceName != null;

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
    _loadHomeAddress();
  }

  /// Load home address from storage
  Future<void> _loadHomeAddress() async {
    final homeData = storageService.getHomeData();
    if (homeData != null) {
      setState(() {
        _homePlaceName = homeData['place_name'];
        _homeAddress = homeData['address'];
      });
      logger.debug(
        '[HOME] Loaded saved home: $_homePlaceName at $_homeAddress',
      );
    }
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

    // After successful save, exit editing mode
    if (mounted) {
      setState(() {
        _isEditingDestination = false;
      });
    }
  }

  /// Handle home address selection from search
  Future<void> _handleHomeAddressSelected(
    LatLng location,
    String placeName,
    String address,
  ) async {
    logger.debug('[HOME] Home selected: $placeName at $location - $address');

    try {
      // Update user home data in backend
      await _updateUserHomeCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
        homeAddress: address,
        homePlaceName: placeName,
      );

      // Save to local storage for proximity announcements
      await storageService.saveHomeCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
        address: address,
        placeName: placeName,
      );

      // Update local state and exit edit mode
      if (mounted) {
        setState(() {
          _homePlaceName = placeName;
          _homeAddress = address;
          _isEditingHome = false;
        });
        _showSnackBar('Home saved: $placeName');
      }
    } catch (e, stackTrace) {
      logger.error(
        '[HOME ERROR] Failed to save home: $e\nStacktrace: $stackTrace',
      );
      if (mounted) {
        _showSnackBar('[ERROR] Failed to save home address');
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

  /// Update user home data in backend
  Future<Map<String, dynamic>> _updateUserHomeCoordinates({
    required double latitude,
    required double longitude,
    String? homeAddress,
    String? homePlaceName,
  }) async {
    final backendUrl = storageService.getNgrokUrl() ?? "";
    final userService = UserService(
      baseUrl: backendUrl,
      storageService: storageService,
    );

    return await userService.updateUserHomeCoordinates(
      latitude: latitude,
      longitude: longitude,
      homeAddress: homeAddress,
      homePlaceName: homePlaceName,
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
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: _buildAppBarActions(),
      ),
      body: Column(
        children: [
          _buildHomeAddressRow(),
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

  /// Build AppBar title with destination and home info
  Widget _buildAppBarTitle() {
    return GestureDetector(
      onTap: () {
        // Navigate to group members screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupMembersScreen(
              groupName: widget.groupName,
              memberPhoneNumbers: widget.memberPhoneNumbers,
              isAdmin: _isAdmin,
            ),
          ),
        );
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Group name with members icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.groupName),
                const SizedBox(width: 4),
                const Icon(Icons.people, size: 16, color: Colors.white70),
              ],
            ),
            // Destination display
            if (widget.placeName != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📍 ${widget.placeName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEditingDestination = !_isEditingDestination;
                        });
                      },
                      child: Icon(
                        _isEditingDestination ? Icons.close : Icons.edit,
                        size: 16,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.address != null)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    widget.address!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: Colors.green,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ] else if (_isAdmin)
              Text(
                'Tap search to set destination',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[400],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build AppBar actions
  List<Widget> _buildAppBarActions() {
    // Edit icons are now inline with addresses in the title
    return [];
  }

  /// Build home address row below AppBar
  Widget _buildHomeAddressRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: _hasHomeAddress
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _homePlaceName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_homeAddress != null && _homeAddress!.isNotEmpty)
                        Text(
                          _homeAddress!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  )
                : Text(
                    'Tap to set home address',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500],
                    ),
                  ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isEditingHome = !_isEditingHome;
              });
            },
            child: Icon(
              _isEditingHome ? Icons.close : Icons.edit,
              size: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Build search section
  Widget _buildSearchSection() {
    // Determine which searches to show:
    // - Destination search: admin AND (editing OR no destination)
    // - Home search: editing OR no home address
    final bool showDestinationSearch =
        _isAdmin && (_isEditingDestination || !_hasDestination);
    final bool showHomeSearch = _isEditingHome || !_hasHomeAddress;

    // Hide entire widget only if both are hidden
    if (!showDestinationSearch && !showHomeSearch) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SearchPlaceWidget(
        mapController: _mapController,
        onPlaceSelected: _handlePlaceSelected,
        onHomeAddressSelected: _handleHomeAddressSelected,
        onSetDestination: _handleSetAddress,
        storageService: storageService,
        showDestinationSearch: showDestinationSearch,
        showHomeSearch: showHomeSearch,
      ),
    );
  }

  /// Build control buttons section
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TripControlButtons(onMyLocation: _handleMyLocation),
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
