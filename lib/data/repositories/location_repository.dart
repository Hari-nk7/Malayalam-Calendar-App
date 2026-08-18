/// Location repository — manages observer location for sunrise/nakshatra
/// calculations. Handles GPS permission flow and manual city-picker.
///
/// City data: bundled GeoNames cities500 dataset (filtered for India + Gulf +
/// global diaspora cities), stored as a TSV asset loaded once into memory.
/// No network calls ever needed.
library location_repository;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';

/// A city entry from the bundled GeoNames dataset.
class GeoCity {
  final String name;
  final String asciiName;
  final double latitude;
  final double longitude;
  final String countryCode;
  final String admin1; // State / Emirate / Province

  const GeoCity({
    required this.name,
    required this.asciiName,
    required this.latitude,
    required this.longitude,
    required this.countryCode,
    required this.admin1,
  });

  LocationModel toLocationModel() => LocationModel(
    latitude: latitude,
    longitude: longitude,
    cityName: name,
    regionName: admin1,
    countryCode: countryCode,
    isGps: false,
  );
}

class LocationRepository {
  static const _locationBoxName = 'location_prefs';
  static const _locationKey = 'saved_location';
  static const _geoCityAsset = 'assets/geo/cities_india.tsv';

  late Box<String> _box;
  bool _isOpen = false;
  List<GeoCity>? _citiesCache;

  /// Initialize Hive box. Must be awaited before other methods.
  Future<void> initialize() async {
    if (_isOpen) return;
    _box = await Hive.openBox<String>(_locationBoxName);
    _isOpen = true;
  }

  // ---------------------------------------------------------------------------
  // Persisted location
  // ---------------------------------------------------------------------------

  /// Returns the saved location, or [LocationModel.trivandrum] as default.
  LocationModel getSavedLocation() {
    _assertOpen();
    final json = _box.get(_locationKey);
    if (json == null) return LocationModel.trivandrum;
    try {
      return LocationModel.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return LocationModel.trivandrum;
    }
  }

  /// Persists the selected location.
  Future<void> saveLocation(LocationModel location) async {
    _assertOpen();
    await _box.put(_locationKey, jsonEncode(location.toJson()));
  }

  /// Returns true if the user has previously saved a location.
  bool hasSavedLocation() {
    _assertOpen();
    return _box.containsKey(_locationKey);
  }

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------

  /// Requests GPS location permission and, if granted, returns the current
  /// location as a [LocationModel].
  ///
  /// Returns null if permission is denied or GPS is unavailable.
  Future<LocationModel?> requestGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Reverse-geocode to a city name using the bundled dataset.
      final nearestCity = await _findNearestCity(
        position.latitude,
        position.longitude,
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: nearestCity?.name ?? 'Current Location',
        regionName: nearestCity?.admin1,
        countryCode: nearestCity?.countryCode ?? 'IN',
        isGps: true,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // City search (GeoNames offline dataset)
  // ---------------------------------------------------------------------------

  /// Loads and caches the city dataset. Called lazily.
  Future<List<GeoCity>> _loadCities() async {
    if (_citiesCache != null) return _citiesCache!;

    try {
      final raw = await rootBundle.loadString(_geoCityAsset);
      final lines = const LineSplitter().convert(raw);
      _citiesCache = lines
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .map(_parseTsvLine)
          .whereType<GeoCity>()
          .toList();
    } catch (e) {
      _citiesCache = _keralaCities; // Fallback to hardcoded list
    }

    return _citiesCache!;
  }

  /// Searches the bundled city database for cities matching [query].
  ///
  /// Matches are case-insensitive prefix/substring matches on both the
  /// display name and ASCII name. Returns up to [limit] results.
  Future<List<GeoCity>> searchCities(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return _keralaCities;

    final cities = await _loadCities();
    final q = query.trim().toLowerCase();

    // Prioritise prefix matches, then substring matches.
    final prefixMatches = <GeoCity>[];
    final substringMatches = <GeoCity>[];

    for (final city in cities) {
      final nameLower = city.asciiName.toLowerCase();
      final displayLower = city.name.toLowerCase();
      if (nameLower.startsWith(q) || displayLower.startsWith(q)) {
        prefixMatches.add(city);
      } else if (nameLower.contains(q) || displayLower.contains(q)) {
        substringMatches.add(city);
      }
      if (prefixMatches.length + substringMatches.length >= limit * 2) break;
    }

    return [...prefixMatches, ...substringMatches].take(limit).toList();
  }

  /// Finds the nearest city in the dataset to the given coordinates.
  Future<GeoCity?> _findNearestCity(double lat, double lon) async {
    final cities = await _loadCities();
    if (cities.isEmpty) return null;

    GeoCity? nearest;
    double minDist = double.infinity;

    for (final city in cities) {
      final d = _haversineKm(lat, lon, city.latitude, city.longitude);
      if (d < minDist) {
        minDist = d;
        nearest = city;
      }
    }

    return minDist < 100 ? nearest : null; // Only claim if within 100 km
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _assertOpen() {
    if (!_isOpen) {
      throw StateError(
        'LocationRepository.initialize() must be awaited before use.',
      );
    }
  }

  GeoCity? _parseTsvLine(String line) {
    try {
      final parts = line.split('\t');
      if (parts.length < 6) return null;
      return GeoCity(
        name: parts[0],
        asciiName: parts[1],
        latitude: double.parse(parts[2]),
        longitude: double.parse(parts[3]),
        countryCode: parts[4],
        admin1: parts[5],
      );
    } catch (_) {
      return null;
    }
  }

  static double _haversineKm(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * 3.14159265 / 180;
    final dLon = (lon2 - lon1) * 3.14159265 / 180;
    final a = (dLat / 2) * (dLat / 2) +
        (lat1 * 3.14159265 / 180).abs() *
            (lat2 * 3.14159265 / 180).abs() *
            (dLon / 2) *
            (dLon / 2);
    return r * 2 * (a < 1 ? (a < 0 ? 0 : a) : 1);
  }

  // ---------------------------------------------------------------------------
  // Hardcoded Kerala + major city fallback (used if asset fails to load)
  // ---------------------------------------------------------------------------
  static final List<GeoCity> _keralaCities = [
    GeoCity(name: 'Thiruvananthapuram', asciiName: 'Thiruvananthapuram', latitude: 8.5241, longitude: 76.9366, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kollam', asciiName: 'Kollam', latitude: 8.8832, longitude: 76.6141, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Alappuzha', asciiName: 'Alappuzha', latitude: 9.4981, longitude: 76.3388, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Pathanamthitta', asciiName: 'Pathanamthitta', latitude: 9.2648, longitude: 76.7870, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kottayam', asciiName: 'Kottayam', latitude: 9.5916, longitude: 76.5222, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Idukki', asciiName: 'Idukki', latitude: 9.9189, longitude: 76.9730, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Ernakulam', asciiName: 'Ernakulam', latitude: 9.9816, longitude: 76.2999, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kochi', asciiName: 'Kochi', latitude: 9.9312, longitude: 76.2673, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Thrissur', asciiName: 'Thrissur', latitude: 10.5276, longitude: 76.2144, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Palakkad', asciiName: 'Palakkad', latitude: 10.7867, longitude: 76.6548, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Malappuram', asciiName: 'Malappuram', latitude: 11.0510, longitude: 76.0711, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kozhikode', asciiName: 'Kozhikode', latitude: 11.2588, longitude: 75.7804, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Wayanad', asciiName: 'Wayanad', latitude: 11.6854, longitude: 76.1320, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kannur', asciiName: 'Kannur', latitude: 11.8745, longitude: 75.3704, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Kasaragod', asciiName: 'Kasaragod', latitude: 12.4996, longitude: 74.9869, countryCode: 'IN', admin1: 'Kerala'),
    GeoCity(name: 'Dubai', asciiName: 'Dubai', latitude: 25.2048, longitude: 55.2708, countryCode: 'AE', admin1: 'Dubai'),
    GeoCity(name: 'Abu Dhabi', asciiName: 'Abu Dhabi', latitude: 24.4539, longitude: 54.3773, countryCode: 'AE', admin1: 'Abu Dhabi'),
    GeoCity(name: 'Sharjah', asciiName: 'Sharjah', latitude: 25.3463, longitude: 55.4209, countryCode: 'AE', admin1: 'Sharjah'),
    GeoCity(name: 'Muscat', asciiName: 'Muscat', latitude: 23.5880, longitude: 58.3829, countryCode: 'OM', admin1: 'Muscat'),
    GeoCity(name: 'Doha', asciiName: 'Doha', latitude: 25.2854, longitude: 51.5310, countryCode: 'QA', admin1: 'Ad Dawhah'),
    GeoCity(name: 'Kuwait City', asciiName: 'Kuwait City', latitude: 29.3697, longitude: 47.9783, countryCode: 'KW', admin1: 'Al Kuwayt'),
    GeoCity(name: 'Riyadh', asciiName: 'Riyadh', latitude: 24.6877, longitude: 46.7219, countryCode: 'SA', admin1: 'Riyadh'),
    GeoCity(name: 'Bahrain', asciiName: 'Bahrain', latitude: 26.0667, longitude: 50.5577, countryCode: 'BH', admin1: 'Al Manamah'),
    GeoCity(name: 'Mumbai', asciiName: 'Mumbai', latitude: 19.0760, longitude: 72.8777, countryCode: 'IN', admin1: 'Maharashtra'),
    GeoCity(name: 'Bengaluru', asciiName: 'Bengaluru', latitude: 12.9716, longitude: 77.5946, countryCode: 'IN', admin1: 'Karnataka'),
    GeoCity(name: 'Chennai', asciiName: 'Chennai', latitude: 13.0827, longitude: 80.2707, countryCode: 'IN', admin1: 'Tamil Nadu'),
    GeoCity(name: 'New Delhi', asciiName: 'New Delhi', latitude: 28.6139, longitude: 77.2090, countryCode: 'IN', admin1: 'Delhi'),
    GeoCity(name: 'Singapore', asciiName: 'Singapore', latitude: 1.3521, longitude: 103.8198, countryCode: 'SG', admin1: 'Singapore'),
    GeoCity(name: 'London', asciiName: 'London', latitude: 51.5074, longitude: -0.1278, countryCode: 'GB', admin1: 'England'),
    GeoCity(name: 'New York', asciiName: 'New York', latitude: 40.7128, longitude: -74.0060, countryCode: 'US', admin1: 'New York'),
  ];
}
