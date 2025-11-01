import 'dart:convert';

import 'package:http/http.dart' as http;
//import '../constatnts.dart';
//import 'models/get_place_autocomplete.dart';
import 'models/place_coordinates.dart';
//import 'models/get_details_from_placeid.dart';

class GmapsService {
  final String _apiKey;
  static const String _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _placeDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  GmapsService(this._apiKey);

  /// Fetches place predictions based on user input
  ///
  /// Returns [PlaceAutocompleteResponse] with predictions or error info
  /// Throws [PlaceServiceException] for network or parsing errors
  Future<PlaceAutocompleteResponse> getPlaceAutocomplete(
    String input, {
    String? sessionToken,
    String? types, // e.g., 'geocode', 'establishment'
    String? components, // e.g., 'country:us'
  }) async {
    if (input.trim().isEmpty) {
      return PlaceAutocompleteResponse(
        status: 'INVALID_REQUEST',
        predictions: [],
        errorMessage: 'Input cannot be empty',
      );
    }

    try {
      final queryParams = {
        'input': input,
        'key': _apiKey,
        if (sessionToken != null) 'sessiontoken': sessionToken,
        if (types != null) 'types': types,
        if (components != null) 'components': components,
      };

      final uri = Uri.parse(
        _autocompleteUrl,
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw PlaceServiceException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = PlaceAutocompleteResponse.fromJson(json);

        // Check for API-level errors
        if (!result.isSuccess) {
          throw PlaceServiceException(
            result.errorMessage ?? 'API returned status: ${result.status}',
          );
        }

        return result;
      } else {
        throw PlaceServiceException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on PlaceServiceException {
      rethrow;
    } catch (e) {
      throw PlaceServiceException('Failed to fetch places: $e');
    }
  }

  /// Fetches detailed information about a place including coordinates
  ///
  /// [placeId] - The place ID from autocomplete response
  /// [fields] - Comma-separated list of fields to return (e.g., 'geometry,name,formatted_address')
  ///            Leave null to get all basic fields
  /// [sessionToken] - Session token for billing optimization (use same token as autocomplete)
  ///
  /// Returns [PlaceDetailsResponse] with place details including lat/lng
  /// Throws [PlaceServiceException] for network or parsing errors
  Future<PlaceDetailsResponse> getPlaceDetails(
    String placeId, {
    String? fields,
    String? sessionToken,
  }) async {
    if (placeId.trim().isEmpty) {
      throw PlaceServiceException('Place ID cannot be empty');
    }

    try {
      final queryParams = {
        'place_id': placeId,
        'key': _apiKey,
        if (fields != null) 'fields': fields,
        if (sessionToken != null) 'sessiontoken': sessionToken,
      };

      final uri = Uri.parse(
        _placeDetailsUrl,
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw PlaceServiceException('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = PlaceDetailsResponse.fromJson(json);

        // Check for API-level errors
        if (!result.isSuccess) {
          throw PlaceServiceException(
            result.errorMessage ?? 'API returned status: ${result.status}',
          );
        }

        return result;
      } else {
        throw PlaceServiceException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on PlaceServiceException {
      rethrow;
    } catch (e) {
      throw PlaceServiceException('Failed to fetch place details: $e');
    }
  }

  /// Convenience method to get only coordinates from a place ID
  ///
  /// Returns [PlaceCoordinates] with latitude and longitude
  /// Throws [PlaceServiceException] if place not found or network error
  Future<PlaceCoordinates> getCoordinatesFromPlaceId(
    String placeId, {
    String? sessionToken,
  }) async {
    final response = await getPlaceDetails(
      placeId,
      fields: 'geometry',
      sessionToken: sessionToken,
    );

    if (!response.hasDetails) {
      throw PlaceServiceException(
        'No coordinates found for place ID: $placeId',
      );
    }

    return response.details!.coordinates;
  }
}

// Custom exception for better error handling
class PlaceServiceException implements Exception {
  final String message;
  PlaceServiceException(this.message);

  @override
  String toString() => 'PlaceServiceException: $message';
}
