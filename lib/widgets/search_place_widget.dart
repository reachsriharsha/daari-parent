import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map_srvc/gmaps_service.dart';
import '../map_srvc/models/place_coordinates.dart';
import '../utils/app_logger.dart';

class SearchPlaceWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final Function(LatLng, String, String) onPlaceSelected;
  final Function(LatLng, String, String)? onHomeAddressSelected;
  final VoidCallback onSetDestination;
  final dynamic storageService;
  final bool showDestinationSearch;
  final bool showHomeSearch;

  const SearchPlaceWidget({
    super.key,
    required this.mapController,
    required this.onPlaceSelected,
    this.onHomeAddressSelected,
    required this.onSetDestination,
    required this.storageService,
    this.showDestinationSearch = true,
    this.showHomeSearch = true,
  });

  @override
  State<SearchPlaceWidget> createState() => _SearchPlaceWidgetState();
}

class _SearchPlaceWidgetState extends State<SearchPlaceWidget> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _homeSearchController = TextEditingController();
  final _gMapService = GmapsService(
    'AIzaSyB29Wza44dK6JqjUS_Pe2CJlvvS0qI8P6A',
  ); //FIXME: Get the key from env variables

  // Destination search state
  List<PlacePrediction> _predictions = [];
  bool _isSearchPlaceLoading = false;
  String? _errorSearchPlace;
  Timer? _debounceTimer;
  String _placeSearchQuery = '';

  // Home address search state
  List<PlacePrediction> _homePredictions = [];
  bool _isHomeSearchLoading = false;
  String? _errorHomeSearch;
  Timer? _homeDebounceTimer;
  String _homeSearchQuery = '';
  bool _hasExistingHome = false;

  @override
  void initState() {
    super.initState();
    _loadSavedHomeAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _homeSearchController.dispose();
    _debounceTimer?.cancel();
    _homeDebounceTimer?.cancel();
    super.dispose();
  }

  /// Load saved home address from storage
  Future<void> _loadSavedHomeAddress() async {
    try {
      final homeData = widget.storageService.getHomeData();
      if (homeData != null && homeData['place_name'] != null) {
        setState(() {
          _homeSearchController.text = homeData['place_name'];
          _hasExistingHome = true;
        });
        logger.debug('[HOME] Loaded saved home: ${homeData['place_name']}');
      }
    } catch (e) {
      logger.error('[HOME ERROR] Failed to load saved home address: $e');
    }
  }

  Future<void> _searchPlaces(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
        _errorSearchPlace = null;
      });
      return;
    }

    logger.debug('[SEARCH] Searching for: $input');
    setState(() {
      _isSearchPlaceLoading = true;
      _errorSearchPlace = null;
    });

    try {
      //if length < 3, return
      if (input.length < 3) {
        setState(() {
          _predictions = [];
          _isSearchPlaceLoading = false;
        });
        logger.debug('[SEARCH] Cleared: query too short');
        return;
      }

      logger.debug('[SEARCH] Calling API with input: "$input"');
      final response = await _gMapService.getPlaceAutocomplete(input);

      logger.debug('[SEARCH] API Response:');
      logger.debug('   - Status: ${response.status}');
      logger.debug('   - Has Results: ${response.hasResults}');
      logger.debug('   - Predictions Count: ${response.predictions.length}');
      logger.debug('   - Error Message: ${response.errorMessage}');

      if (response.predictions.isNotEmpty) {
        logger.debug(
          '[SEARCH] First prediction: ${response.predictions.first.description}',
        );
      }

      setState(() {
        if (response.hasResults) {
          _predictions = response.predictions;
          logger.debug(
            '[SEARCH] SET STATE: Updated predictions to ${_predictions.length} items',
          );
          for (int i = 0; i < _predictions.length && i < 3; i++) {
            logger.debug('   [$i] ${_predictions[i].description}');
          }
        } else {
          _predictions = [];
          logger.debug(
            '[SEARCH] SET STATE: No results from API (status: ${response.status})',
          );
        }
        _isSearchPlaceLoading = false;
      });

      logger.debug(
        '[SEARCH] After setState: _predictions.length = ${_predictions.length}, _placeSearchQuery = "$_placeSearchQuery"',
      );
    } on PlaceServiceException catch (e) {
      logger.debug('[SEARCH ERROR] Search error: ${e.message}');
      setState(() {
        _errorSearchPlace = e.message;
        _predictions = [];
        _isSearchPlaceLoading = false;
      });
    } catch (e, stackTrace) {
      logger.debug('[SEARCH ERROR] Unexpected error: $e');
      logger.debug('Stack trace: $stackTrace');
      setState(() {
        _errorSearchPlace = 'Unexpected error: $e';
        _predictions = [];
        _isSearchPlaceLoading = false;
      });
    }
  }

  Future<void> _setCoordinatesFromPlaceId(String placeId) async {
    if (placeId.isEmpty) return;

    try {
      final details = await _gMapService.getPlaceDetails(
        placeId,
        fields:
            'name,formatted_address,geometry,rating,formatted_phone_number,website',
      );

      if (details.hasDetails) {
        logger.debug('[SEARCH] Place details: ${details.details}');
        final coords = details.details!.coordinates;
        final latLng = LatLng(coords.latitude, coords.longitude);
        final name = details.details!.name;
        final address = details.details!.formattedAddress.isNotEmpty
            ? details.details!.formattedAddress
            : name;

        logger.debug('[SEARCH] Selected place: $name at $latLng');
        logger.debug('[SEARCH] Address: $address');

        // Clear search state first
        setState(() {
          _placeSearchQuery = '';
          _searchController.text = '';
          _predictions = [];
        });

        // Notify parent widget to update map and show marker
        widget.onPlaceSelected(latLng, name, address);

        logger.debug('[SEARCH] Map should now show pin at $latLng');
      }
    } on PlaceServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _searchHomeAddress(String input) async {
    if (input.isEmpty) {
      setState(() {
        _homePredictions = [];
        _errorHomeSearch = null;
      });
      return;
    }

    logger.debug('[HOME SEARCH] Searching for: $input');
    setState(() {
      _isHomeSearchLoading = true;
      _errorHomeSearch = null;
    });

    try {
      if (input.length < 3) {
        setState(() {
          _homePredictions = [];
          _isHomeSearchLoading = false;
        });
        logger.debug('[HOME SEARCH] Cleared: query too short');
        return;
      }

      logger.debug('[HOME SEARCH] Calling API with input: "$input"');
      final response = await _gMapService.getPlaceAutocomplete(input);

      logger.debug('[HOME SEARCH] API Response:');
      logger.debug('   - Status: ${response.status}');
      logger.debug('   - Has Results: ${response.hasResults}');
      logger.debug('   - Predictions Count: ${response.predictions.length}');

      setState(() {
        if (response.hasResults) {
          _homePredictions = response.predictions;
          logger.debug(
            '[HOME SEARCH] SET STATE: Updated predictions to ${_homePredictions.length} items',
          );
        } else {
          _homePredictions = [];
          logger.debug(
            '[HOME SEARCH] SET STATE: No results from API (status: ${response.status})',
          );
        }
        _isHomeSearchLoading = false;
      });
    } on PlaceServiceException catch (e) {
      logger.debug('[HOME SEARCH ERROR] Search error: ${e.message}');
      setState(() {
        _errorHomeSearch = e.message;
        _homePredictions = [];
        _isHomeSearchLoading = false;
      });
    } catch (e, stackTrace) {
      logger.error(
        '[HOME SEARCH ERROR] Unexpected error: $e Stack trace: $stackTrace',
      );

      setState(() {
        _errorHomeSearch = 'Unexpected error: $e';
        _homePredictions = [];
        _isHomeSearchLoading = false;
      });
    }
  }

  Future<void> _setHomeAddressFromPlaceId(String placeId) async {
    if (placeId.isEmpty) return;

    try {
      final details = await _gMapService.getPlaceDetails(
        placeId,
        fields:
            'name,formatted_address,geometry,rating,formatted_phone_number,website',
      );

      if (details.hasDetails) {
        logger.debug('[HOME SEARCH] Place details: ${details.details}');
        final coords = details.details!.coordinates;
        final latLng = LatLng(coords.latitude, coords.longitude);
        final name = details.details!.name;
        final address = details.details!.formattedAddress.isNotEmpty
            ? details.details!.formattedAddress
            : name;

        logger.debug('[HOME SEARCH] Selected home address: $name at $latLng');

        // Clear search state first
        setState(() {
          _homeSearchQuery = '';
          _homeSearchController.text = '';
          _homePredictions = [];
        });

        // Show selected home address in SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Home Address: $address'),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Notify parent widget if callback is provided
        if (widget.onHomeAddressSelected != null) {
          widget.onHomeAddressSelected!(latLng, name, address);
        }

        logger.debug('[HOME SEARCH] Home address set to: $address');
      }
    } on PlaceServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.debug(
      '[SEARCH] BUILD: _placeSearchQuery="$_placeSearchQuery", _predictions.length=${_predictions.length}, _isLoading=$_isSearchPlaceLoading',
    );

    return Column(
      children: [
        // Destination search row with button
        if (widget.showDestinationSearch)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search destination for the trip...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onChanged: (String value) {
                    logger.debug(
                      '[SEARCH] Text changed: "$value" (length: ${value.length})',
                    );
                    _debounceTimer?.cancel();

                    // Clear predictions if less than 3 characters
                    if (value.length < 3) {
                      setState(() {
                        _predictions = [];
                        _errorSearchPlace = null;
                        _isSearchPlaceLoading = false;
                        _placeSearchQuery = '';
                      });
                      logger.debug('[SEARCH] Cleared: query too short');
                      return;
                    }

                    // Create new timer only if 3+ characters
                    logger.debug('[SEARCH] Starting debounce timer...');
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () {
                        logger.debug('[SEARCH] Debounce timer fired!');
                        setState(() {
                          _placeSearchQuery = value;
                        });
                        logger.debug(
                          '[SEARCH] Set query: "$_placeSearchQuery"',
                        );
                        _searchPlaces(value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onSetDestination,
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
            ],
          ),
        // Destination suggestions list
        if (widget.showDestinationSearch && _placeSearchQuery.isNotEmpty)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Builder(
              builder: (context) {
                logger.debug(
                  '[SEARCH] Container builder: _isLoading=$_isSearchPlaceLoading, _predictions.length=${_predictions.length}',
                );

                if (_isSearchPlaceLoading) {
                  logger.debug('[SEARCH]    -> Showing loading indicator');
                  return const Center(child: CircularProgressIndicator());
                }

                if (_predictions.isEmpty) {
                  logger.debug(
                    '[SEARCH]    -> Showing empty message: ${_errorSearchPlace ?? "No results found"}',
                  );
                  return Center(
                    child: Text(
                      _errorSearchPlace ?? 'No results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                logger.debug(
                  '[SEARCH]    -> Building ListView with ${_predictions.length} items',
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    logger.debug(
                      '[SEARCH]       Building item $index: ${_predictions[index].description}',
                    );
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(
                        _predictions[index].description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        logger.debug(
                          '[SEARCH] Tapped: ${_predictions[index].placeId}',
                        );
                        _setCoordinatesFromPlaceId(_predictions[index].placeId);
                      },
                    );
                  },
                );
              },
            ),
          ),
        if (widget.showDestinationSearch && widget.showHomeSearch)
          const SizedBox(height: 8),
        // Home address search row with button
        if (widget.showHomeSearch)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _homeSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search home address for the trip...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    prefixIcon: _hasExistingHome
                        ? const Icon(Icons.home, color: Colors.green, size: 20)
                        : null,
                  ),
                  onChanged: (String value) {
                    logger.debug(
                      '[HOME SEARCH] Text changed: "$value" (length: ${value.length})',
                    );
                    _homeDebounceTimer?.cancel();

                    // Clear existing home flag if user is typing
                    if (_hasExistingHome && value.isEmpty) {
                      setState(() {
                        _hasExistingHome = false;
                      });
                    }

                    // Clear predictions if less than 3 characters
                    if (value.length < 3) {
                      setState(() {
                        _homePredictions = [];
                        _errorHomeSearch = null;
                        _isHomeSearchLoading = false;
                        _homeSearchQuery = '';
                      });
                      logger.debug('[HOME SEARCH] Cleared: query too short');
                      return;
                    }

                    // Create new timer only if 3+ characters
                    logger.debug('[HOME SEARCH] Starting debounce timer...');
                    _homeDebounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () {
                        logger.debug('[HOME SEARCH] Debounce timer fired!');
                        setState(() {
                          _homeSearchQuery = value;
                        });
                        logger.debug(
                          '[HOME SEARCH] Set query: "$_homeSearchQuery"',
                        );
                        _searchHomeAddress(value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_homeSearchController.text.isNotEmpty &&
                      _homePredictions.isNotEmpty) {
                    // If there's a search result, select the first one
                    _setHomeAddressFromPlaceId(_homePredictions.first.placeId);
                  } else {
                    // Show message if no home address selected
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please search and select a home address first',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(80, 36),
                ),
                child: const Text('Set Home', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        // Home address suggestions list
        if (_homeSearchQuery.isNotEmpty)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Builder(
              builder: (context) {
                logger.debug(
                  '[HOME SEARCH] Container builder: _isLoading=$_isHomeSearchLoading, _homePredictions.length=${_homePredictions.length}',
                );

                if (_isHomeSearchLoading) {
                  logger.debug('[HOME SEARCH]    -> Showing loading indicator');
                  return const Center(child: CircularProgressIndicator());
                }

                if (_homePredictions.isEmpty) {
                  logger.debug(
                    '[HOME SEARCH]    -> Showing empty message: ${_errorHomeSearch ?? "No results found"}',
                  );
                  return Center(
                    child: Text(
                      _errorHomeSearch ?? 'No results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                logger.debug(
                  '[HOME SEARCH]    -> Building ListView with ${_homePredictions.length} items',
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _homePredictions.length,
                  itemBuilder: (context, index) {
                    logger.debug(
                      '[HOME SEARCH]       Building item $index: ${_homePredictions[index].description}',
                    );
                    return ListTile(
                      leading: const Icon(Icons.home),
                      title: Text(
                        _homePredictions[index].description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        logger.debug(
                          '[HOME SEARCH] Tapped: ${_homePredictions[index].placeId}',
                        );
                        _setHomeAddressFromPlaceId(
                          _homePredictions[index].placeId,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
