// models/place_coordinates.dart

class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }

  @override
  String toString() => description;
}

class PlaceAutocompleteResponse {
  final List<PlacePrediction> predictions;
  final String status;
  final String? errorMessage;

  PlaceAutocompleteResponse({
    required this.predictions,
    required this.status,
    this.errorMessage,
  });

  factory PlaceAutocompleteResponse.fromJson(Map<String, dynamic> json) {
    return PlaceAutocompleteResponse(
      status: json['status'] ?? 'UNKNOWN_ERROR',
      errorMessage: json['error_message'],
      predictions:
          (json['predictions'] as List<dynamic>?)
              ?.map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => status == 'OK' || status == 'ZERO_RESULTS';
  bool get hasResults => predictions.isNotEmpty;
}

class PlaceCoordinates {
  final double latitude;
  final double longitude;

  PlaceCoordinates({required this.latitude, required this.longitude});

  factory PlaceCoordinates.fromJson(Map<String, dynamic> json) {
    final location = json['location'] ?? {};
    return PlaceCoordinates(
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() => 'Lat: $latitude, Lng: $longitude';
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final PlaceCoordinates coordinates;
  final String? phoneNumber;
  final String? website;
  final double? rating;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.coordinates,
    this.phoneNumber,
    this.website,
    this.rating,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? {};
    final geometry = result['geometry'] ?? {};

    return PlaceDetails(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '',
      formattedAddress: result['formatted_address'] ?? '',
      coordinates: PlaceCoordinates.fromJson(geometry),
      phoneNumber: result['formatted_phone_number'],
      website: result['website'],
      rating: (result['rating'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => '$name at $formattedAddress';
}

class PlaceDetailsResponse {
  final PlaceDetails? details;
  final String status;
  final String? errorMessage;

  PlaceDetailsResponse({this.details, required this.status, this.errorMessage});

  factory PlaceDetailsResponse.fromJson(Map<String, dynamic> json) {
    final status = json['status'] ?? 'UNKNOWN_ERROR';

    return PlaceDetailsResponse(
      status: status,
      errorMessage: json['error_message'],
      details: (status == 'OK' && json['result'] != null)
          ? PlaceDetails.fromJson(json)
          : null,
    );
  }

  bool get isSuccess => status == 'OK';
  bool get hasDetails => details != null;
}
/*
class PlaceAutocompleteResponse {
  final List<PlacePrediction> predictions;
  final String status;
  final String? errorMessage;

  PlaceAutocompleteResponse({
    required this.predictions,
    required this.status,
    this.errorMessage,
  });

  factory PlaceAutocompleteResponse.fromJson(Map<String, dynamic> json) {
    return PlaceAutocompleteResponse(
      status: json['status'] ?? 'UNKNOWN_ERROR',
      errorMessage: json['error_message'],
      predictions:
          (json['predictions'] as List<dynamic>?)
              ?.map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => status == 'OK' || status == 'ZERO_RESULTS';
  bool get hasResults => predictions.isNotEmpty;
}
*/