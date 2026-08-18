/// Location model — represents the observer's position for astronomical
/// calculations (sunrise time, which depends on longitude/latitude).
library location_model;

import 'dart:math' as math;

class LocationModel {
  /// Observer latitude in decimal degrees (positive = North).
  final double latitude;

  /// Observer longitude in decimal degrees (positive = East).
  final double longitude;

  /// Human-readable city name.
  final String cityName;

  /// District / state / region (optional, for disambiguation).
  final String? regionName;

  /// Country code (ISO 3166-1 alpha-2), e.g. "IN", "AE".
  final String countryCode;

  /// True if this location was obtained from the device GPS.
  final bool isGps;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.cityName,
    this.regionName,
    this.countryCode = 'IN',
    this.isGps = false,
  });

  /// Cache key: lat/lon rounded to 0.1° (≈11 km grid).
  /// Two locations within the same 11 km cell share the same cache entry.
  String get cacheKey {
    final latRounded = (latitude * 10).round() / 10;
    final lonRounded = (longitude * 10).round() / 10;
    return '${latRounded.toStringAsFixed(1)},${lonRounded.toStringAsFixed(1)}';
  }

  /// Distance from another location in kilometres (haversine formula).
  double distanceKmFrom(LocationModel other) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(other.latitude - latitude);
    final dLon = _toRad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(latitude)) *
            math.cos(_toRad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'cityName': cityName,
    'regionName': regionName,
    'countryCode': countryCode,
    'isGps': isGps,
  };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    cityName: json['cityName'] as String,
    regionName: json['regionName'] as String?,
    countryCode: (json['countryCode'] as String?) ?? 'IN',
    isGps: (json['isGps'] as bool?) ?? false,
  );

  /// Default location: Thiruvananthapuram (capital of Kerala).
  static const LocationModel trivandrum = LocationModel(
    latitude: 8.5241,
    longitude: 76.9366,
    cityName: 'Thiruvananthapuram',
    regionName: 'Kerala',
    countryCode: 'IN',
  );

  @override
  String toString() => '$cityName ($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationModel &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
