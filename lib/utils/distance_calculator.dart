import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Calculate Haversine distance between two geographic points
/// Returns distance in meters
///
/// Formula:
/// a = sin²(Δφ/2) + cos φ1 ⋅ cos φ2 ⋅ sin²(Δλ/2)
/// c = 2 ⋅ atan2(√a, √(1−a))
/// d = R ⋅ c
///
/// where φ is latitude, λ is longitude, R is earth's radius (6,371,000 meters)
double calculateDistance({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const double earthRadius = 6371000; // meters

  // Convert degrees to radians
  final double phi1 = lat1 * pi / 180;
  final double phi2 = lat2 * pi / 180;
  final double deltaPhi = (lat2 - lat1) * pi / 180;
  final double deltaLambda = (lon2 - lon1) * pi / 180;

  // Haversine formula
  final double a =
      sin(deltaPhi / 2) * sin(deltaPhi / 2) +
      cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  final double distance = earthRadius * c;

  return distance;
}

/// Convenience method for LatLng objects
/// Returns distance in meters
double calculateDistanceLatLng(LatLng point1, LatLng point2) {
  return calculateDistance(
    lat1: point1.latitude,
    lon1: point1.longitude,
    lat2: point2.latitude,
    lon2: point2.longitude,
  );
}
