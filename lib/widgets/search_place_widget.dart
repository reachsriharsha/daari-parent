import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map_srvc/gmaps_service.dart';
import '../map_srvc/models/place_coordinates.dart';

class SearchPlaceWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final Function(LatLng, String) onPlaceSelected;

  const SearchPlaceWidget({
    super.key,
    required this.mapController,
    required this.onPlaceSelected,
  });

  @override
  State<SearchPlaceWidget> createState() => _SearchPlaceWidgetState();
}

class _SearchPlaceWidgetState extends State<SearchPlaceWidget> {
  final TextEditingController _searchController = TextEditingController();
  final _gMapService = GmapsService(
    'AIzaSyB29Wza44dK6JqjUS_Pe2CJlvvS0qI8P6A',
  ); //FIXME: Get the key from env variables

  List<PlacePrediction> _predictions = [];
  bool _isSearchPlaceLoading = false;
  String? _errorSearchPlace;
  Timer? _debounceTimer;
  String _placeSearchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[SEARCH] BUILD: _placeSearchQuery="$_placeSearchQuery", _predictions.length=${_predictions.length}, _isLoading=$_isSearchPlaceLoading',
    );

    return Column(
      children: [
        // Search row
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
          ],
        ),
        // Suggestions list below the search row
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
      ],
    );
  }
}
