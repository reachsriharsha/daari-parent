/*
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
*/
