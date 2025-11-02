import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map_srvc/gmaps_service.dart';
import '../map_srvc/models/place_coordinates.dart';

class SearchPlaceWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final Function(LatLng, String) onPlaceSelected;
  final Function(LatLng, String)? onHomeAddressSelected;
  final VoidCallback onSetDestination;

  const SearchPlaceWidget({
    super.key,
    required this.mapController,
    required this.onPlaceSelected,
    this.onHomeAddressSelected,
    required this.onSetDestination,
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

  @override
  void dispose() {
    _searchController.dispose();
    _homeSearchController.dispose();
    _debounceTimer?.cancel();
    _homeDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchPlaces(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
        _errorSearchPlace = null;
      });
      return;
    }

    debugPrint('[SEARCH] Searching for: $input');
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
        debugPrint('[SEARCH] Cleared: query too short');
        return;
      }

      debugPrint('[SEARCH] Calling API with input: "$input"');
      final response = await _gMapService.getPlaceAutocomplete(input);

      debugPrint('[SEARCH] API Response:');
      debugPrint('   - Status: ${response.status}');
      debugPrint('   - Has Results: ${response.hasResults}');
      debugPrint('   - Predictions Count: ${response.predictions.length}');
      debugPrint('   - Error Message: ${response.errorMessage}');

      if (response.predictions.isNotEmpty) {
        debugPrint(
          '[SEARCH] First prediction: ${response.predictions.first.description}',
        );
      }

      setState(() {
        if (response.hasResults) {
          _predictions = response.predictions;
          debugPrint(
            '[SEARCH] SET STATE: Updated predictions to ${_predictions.length} items',
          );
          for (int i = 0; i < _predictions.length && i < 3; i++) {
            debugPrint('   [$i] ${_predictions[i].description}');
          }
        } else {
          _predictions = [];
          debugPrint(
            '[SEARCH] SET STATE: No results from API (status: ${response.status})',
          );
        }
        _isSearchPlaceLoading = false;
      });

      debugPrint(
        '[SEARCH] After setState: _predictions.length = ${_predictions.length}, _placeSearchQuery = "$_placeSearchQuery"',
      );
    } on PlaceServiceException catch (e) {
      debugPrint('[SEARCH ERROR] Search error: ${e.message}');
      setState(() {
        _errorSearchPlace = e.message;
        _predictions = [];
        _isSearchPlaceLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[SEARCH ERROR] Unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
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
        debugPrint('[SEARCH] Place details: ${details.details}');
        final coords = details.details!.coordinates;
        final latLng = LatLng(coords.latitude, coords.longitude);
        final name = details.details!.name;

        debugPrint('[SEARCH] Selected place: $name at $latLng');

        // Clear search state first
        setState(() {
          _placeSearchQuery = '';
          _searchController.text = '';
          _predictions = [];
        });

        // Notify parent widget to update map and show marker
        widget.onPlaceSelected(latLng, name);

        debugPrint('[SEARCH] Map should now show pin at $latLng');
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

    debugPrint('[HOME SEARCH] Searching for: $input');
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
        debugPrint('[HOME SEARCH] Cleared: query too short');
        return;
      }

      debugPrint('[HOME SEARCH] Calling API with input: "$input"');
      final response = await _gMapService.getPlaceAutocomplete(input);

      debugPrint('[HOME SEARCH] API Response:');
      debugPrint('   - Status: ${response.status}');
      debugPrint('   - Has Results: ${response.hasResults}');
      debugPrint('   - Predictions Count: ${response.predictions.length}');

      setState(() {
        if (response.hasResults) {
          _homePredictions = response.predictions;
          debugPrint(
            '[HOME SEARCH] SET STATE: Updated predictions to ${_homePredictions.length} items',
          );
        } else {
          _homePredictions = [];
          debugPrint(
            '[HOME SEARCH] SET STATE: No results from API (status: ${response.status})',
          );
        }
        _isHomeSearchLoading = false;
      });
    } on PlaceServiceException catch (e) {
      debugPrint('[HOME SEARCH ERROR] Search error: ${e.message}');
      setState(() {
        _errorHomeSearch = e.message;
        _homePredictions = [];
        _isHomeSearchLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[HOME SEARCH ERROR] Unexpected error: $e');
      debugPrint('Stack trace: $stackTrace');
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
        debugPrint('[HOME SEARCH] Place details: ${details.details}');
        final coords = details.details!.coordinates;
        final latLng = LatLng(coords.latitude, coords.longitude);
        final name = details.details!.name;
        final address = details.details!.formattedAddress.isNotEmpty
            ? details.details!.formattedAddress
            : name;

        debugPrint('[HOME SEARCH] Selected home address: $name at $latLng');

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
          widget.onHomeAddressSelected!(latLng, address);
        }

        debugPrint('[HOME SEARCH] Home address set to: $address');
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
    debugPrint(
      '[SEARCH] BUILD: _placeSearchQuery="$_placeSearchQuery", _predictions.length=${_predictions.length}, _isLoading=$_isSearchPlaceLoading',
    );

    return Column(
      children: [
        // Destination search row with button
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
                  debugPrint(
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
                    debugPrint('[SEARCH] Cleared: query too short');
                    return;
                  }

                  // Create new timer only if 3+ characters
                  debugPrint('[SEARCH] Starting debounce timer...');
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    debugPrint('[SEARCH] Debounce timer fired!');
                    setState(() {
                      _placeSearchQuery = value;
                    });
                    debugPrint('[SEARCH] Set query: "$_placeSearchQuery"');
                    _searchPlaces(value);
                  });
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
        if (_placeSearchQuery.isNotEmpty)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Builder(
              builder: (context) {
                debugPrint(
                  '[SEARCH] Container builder: _isLoading=$_isSearchPlaceLoading, _predictions.length=${_predictions.length}',
                );

                if (_isSearchPlaceLoading) {
                  debugPrint('[SEARCH]    -> Showing loading indicator');
                  return const Center(child: CircularProgressIndicator());
                }

                if (_predictions.isEmpty) {
                  debugPrint(
                    '[SEARCH]    -> Showing empty message: ${_errorSearchPlace ?? "No results found"}',
                  );
                  return Center(
                    child: Text(
                      _errorSearchPlace ?? 'No results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                debugPrint(
                  '[SEARCH]    -> Building ListView with ${_predictions.length} items',
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    debugPrint(
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
                        debugPrint(
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
        const SizedBox(height: 16),
        // Home address search row with button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _homeSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search home address for the trip...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                onChanged: (String value) {
                  debugPrint(
                    '[HOME SEARCH] Text changed: "$value" (length: ${value.length})',
                  );
                  _homeDebounceTimer?.cancel();

                  // Clear predictions if less than 3 characters
                  if (value.length < 3) {
                    setState(() {
                      _homePredictions = [];
                      _errorHomeSearch = null;
                      _isHomeSearchLoading = false;
                      _homeSearchQuery = '';
                    });
                    debugPrint('[HOME SEARCH] Cleared: query too short');
                    return;
                  }

                  // Create new timer only if 3+ characters
                  debugPrint('[HOME SEARCH] Starting debounce timer...');
                  _homeDebounceTimer = Timer(
                    const Duration(milliseconds: 500),
                    () {
                      debugPrint('[HOME SEARCH] Debounce timer fired!');
                      setState(() {
                        _homeSearchQuery = value;
                      });
                      debugPrint(
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
                debugPrint(
                  '[HOME SEARCH] Container builder: _isLoading=$_isHomeSearchLoading, _homePredictions.length=${_homePredictions.length}',
                );

                if (_isHomeSearchLoading) {
                  debugPrint('[HOME SEARCH]    -> Showing loading indicator');
                  return const Center(child: CircularProgressIndicator());
                }

                if (_homePredictions.isEmpty) {
                  debugPrint(
                    '[HOME SEARCH]    -> Showing empty message: ${_errorHomeSearch ?? "No results found"}',
                  );
                  return Center(
                    child: Text(
                      _errorHomeSearch ?? 'No results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                debugPrint(
                  '[HOME SEARCH]    -> Building ListView with ${_homePredictions.length} items',
                );
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _homePredictions.length,
                  itemBuilder: (context, index) {
                    debugPrint(
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
                        debugPrint(
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
