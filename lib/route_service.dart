import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'utils/app_logger.dart';

class RouteService {
  // You'll need to add your Google Maps API key here
  // Make sure to enable the Directions API in Google Cloud Console
  static const String _apiKey =
      'AIzaSyDQ4s_fpwuw2xFyhFDYt37rsWcipzpgRTo'; // Replace with your actual API key

  final PolylinePoints polylinePoints = PolylinePoints();

  /// Get route polyline points between two locations
  Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _apiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
          avoidHighways: false,
          avoidTolls: false,
          avoidFerries: true,
        ),
      );

      if (result.points.isNotEmpty) {
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e, stackTrace) {
      logger.error(
        '[ROUTE ERROR] Failed to get route polyline: $e stacktrace: $stackTrace',
      );
    }
    return [];
  }

  /// Get detailed route information using Google Directions API
  Future<RouteInfo?> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return RouteInfo(
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            distanceValue: leg['distance']['value'],
            durationValue: leg['duration']['value'],
          );
        }
      }
    } catch (e, stackTrace) {
      logger.error('[ROUTE ERROR] Error getting route info: $e, $stackTrace');
    }
    return null;
  }

  /// Create a Polyline for display on Google Maps
  static Polyline createRoutePolyline({
    required List<LatLng> points,
    required String polylineId,
  }) {
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: points,
      color: const Color(0xFF3F51B5), // Blue color for route
      width: 4,
      patterns: [], // Solid line
    );
  }

  /// Create markers for origin and destination
  static Set<Marker> createRouteMarkers({
    required LatLng? currentLocation,
    required LatLng? destination,
  }) {
    Set<Marker> markers = {};

    if (currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    return markers;
  }
}

class RouteInfo {
  final String distance;
  final String duration;
  final int distanceValue;
  final int durationValue;

  RouteInfo({
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
  });
}
