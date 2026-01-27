import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  /// Request location permission from user
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Check if GPS/Location Service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current GPS position
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await this.hasPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Convert coordinates to address (reverse geocoding)
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Unknown location';

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].where((p) => p != null && p.isNotEmpty).toList();

      return parts.join(', ');
    } catch (e) {
      print('Error reverse geocoding: $e');
      return 'Lat: $lat, Lng: $lng';
    }
  }

  /// Get city name from coordinates
  Future<String> getCityFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Unknown';

      final place = placemarks.first;
      return place.locality ?? place.administrativeArea ?? 'Unknown';
    } catch (e) {
      print('Error getting city: $e');
      return 'Unknown';
    }
  }

  /// Convert city name to coordinates (forward geocoding)
  Future<LatLng?> getCoordinatesFromCity(String cityName) async {
    try {
      final locations = await locationFromAddress(cityName);
      if (locations.isEmpty) return null;

      final location = locations.first;
      return LatLng(location.latitude, location.longitude);
    } catch (e) {
      print('Error forward geocoding: $e');
      return null;
    }
  }

  /// Search for a location and return coordinates
  Future<Map<String, dynamic>?> searchLocation(String query) async {
    try {
      // 1. Try Nominatim (OpenStreetMap) first for better precision with house numbers
      final searchQuery = query.contains('Philippines') ? query : '$query, Philippines';
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=1&addressdetails=1');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'KonektizenApp/1.0',
        'Accept-Language': 'en-US,en;q=0.5',
      });
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final result = data[0];
          print('Nominatim found: ${result['display_name']}');
          return {
            'lat': double.parse(result['lat']),
            'lng': double.parse(result['lon']),
            'address': result['display_name'],
          };
        }
      }

      // 2. Fallback to system geocoder
      final locations = await locationFromAddress(searchQuery);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return {
          'lat': location.latitude,
          'lng': location.longitude,
        };
      }
      return null;
    } catch (e) {
      print('Error searching location: $e');
      return null;
    }
  }

  /// Search for cities matching query (for autocomplete)
  Future<List<String>> searchCities(String query) async {
    if (query.length < 2) return [];

    try {
      // For Philippines cities - you can expand this list
      final philippineCities = [
        'Manila', 'Quezon City', 'Makati', 'Pasig', 'Taguig',
        'Cebu City', 'Davao City', 'Naga City', 'Iloilo City',
        'Cagayan de Oro', 'Bacolod', 'Baguio', 'Zamboanga',
        'Antipolo', 'Pasay', 'Caloocan', 'Mandaluyong', 'Parañaque',
      ];

      return philippineCities
          .where((city) => city.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching cities: $e');
      return [];
    }
  }
}

final locationService = LocationService();
