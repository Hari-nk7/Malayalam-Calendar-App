/// NOAA Solar Calculator — pure Dart implementation
///
/// Based on Jean Meeus, "Astronomical Algorithms" (2nd ed.), Chapter 25,
/// and the NOAA Solar Calculator spreadsheet methodology.
///
/// Accuracy: ±1 minute for dates 1901–2099 at latitudes within ±65°.
/// Atmospheric refraction model: standard 0.833° depression at horizon.
library sunrise_calculator;

import 'dart:math' as math;

/// Result of a sunrise/sunset calculation.
class SolarTimes {
  /// Sunrise in UTC. Null if the sun does not rise (polar night).
  final DateTime? sunriseUtc;

  /// Sunset in UTC. Null if the sun does not set (midnight sun).
  final DateTime? sunsetUtc;

  /// Solar noon in UTC (always valid).
  final DateTime solarNoonUtc;

  const SolarTimes({
    required this.sunriseUtc,
    required this.sunsetUtc,
    required this.solarNoonUtc,
  });

  /// Duration of daylight. Returns Duration.zero if polar night.
  Duration get daylightDuration {
    if (sunriseUtc == null || sunsetUtc == null) return Duration.zero;
    return sunsetUtc!.difference(sunriseUtc!);
  }

  /// Aparahna threshold: 3/5 of the way through the daylight period.
  /// Used for the Kerala month-start (Sankranti assignment) rule.
  DateTime? get aparahnaThreshold {
    if (sunriseUtc == null || sunsetUtc == null) return null;
    final dayMs = daylightDuration.inMilliseconds;
    return sunriseUtc!.add(Duration(milliseconds: (dayMs * 3 ~/ 5)));
  }
}

/// Computes sunrise, solar noon, and sunset for a given date and location.
///
/// [date] — the calendar date (year/month/day are used; time component ignored).
/// [latitudeDeg] — observer latitude in degrees (positive = North).
/// [longitudeDeg] — observer longitude in degrees (positive = East).
/// [elevationMeters] — observer elevation above sea level (default 0).
///
/// Returns [SolarTimes] with UTC timestamps.
SolarTimes computeSolarTimes(
  DateTime date,
  double latitudeDeg,
  double longitudeDeg, {
  double elevationMeters = 0,
}) {
  // Julian Day for the given date at noon UTC (time-zone-agnostic).
  final jd = _julianDay(date.year, date.month, date.day);

  // Julian century from J2000.0
  final T = (jd - 2451545.0) / 36525.0;

  // Geometric mean longitude of the Sun (degrees), corrected for aberration.
  final L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360;

  // Mean anomaly of the Sun (degrees)
  final M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360;
  final Mrad = _toRad(M);

  // Equation of the centre
  final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * math.sin(Mrad) +
      (0.019993 - 0.000101 * T) * math.sin(2 * Mrad) +
      0.000289 * math.sin(3 * Mrad);

  // Sun's true longitude
  final sunLon = L0 + C;

  // Sun's apparent longitude (correcting for nutation and aberration)
  final omega = 125.04 - 1934.136 * T;
  final sunApparentLon = sunLon - 0.00569 - 0.00478 * math.sin(_toRad(omega));

  // Mean obliquity of the ecliptic (arc-seconds → degrees)
  final meanObliq = 23 +
      (26 + (21.448 - T * (46.8150 + T * (0.00059 - T * 0.001813))) / 60) /
          60;

  // Corrected obliquity for apparent sun position
  final obliqCorr = meanObliq + 0.00256 * math.cos(_toRad(omega));

  // Sun's right ascension (degrees) — not used directly but supports future work
  // final rightAscension = _toDeg(
  //   math.atan2(math.cos(_toRad(obliqCorr)) * math.sin(_toRad(sunApparentLon)),
  //              math.cos(_toRad(sunApparentLon))));

  // Sun's declination (degrees)
  final declination =
      _toDeg(math.asin(math.sin(_toRad(obliqCorr)) * math.sin(_toRad(sunApparentLon))));

  // Equation of time (minutes)
  final y = math.tan(_toRad(obliqCorr / 2)) * math.tan(_toRad(obliqCorr / 2));
  final eqOfTime = 4 *
      _toDeg(y * math.sin(2 * _toRad(L0)) -
          2 * _eccent(T) * math.sin(Mrad) +
          4 * _eccent(T) * y * math.sin(Mrad) * math.cos(2 * _toRad(L0)) -
          0.5 * y * y * math.sin(4 * _toRad(L0)) -
          1.25 * _eccent(T) * _eccent(T) * math.sin(2 * Mrad));

  // Hour angle at sunrise/sunset (degrees).
  // NOAA uses 90.833° as the standard zenith for sunrise/sunset:
  //   90° (horizon) + 0.5° (solar radius) + 0.567° (standard refraction) ≈ 90.833°
  // Additional correction for elevation h (metres): sqrt(h) * 2.076 / 60 degrees.
  final zenith = 90.833 + math.sqrt(elevationMeters) * 2.076 / 60.0;
  final cosHourAngle =
      (math.cos(_toRad(zenith)) -
          math.sin(_toRad(latitudeDeg)) * math.sin(_toRad(declination))) /
      (math.cos(_toRad(latitudeDeg)) * math.cos(_toRad(declination)));

  // Solar noon in minutes past UTC midnight
  final solarNoonMinutes = (720 - 4 * longitudeDeg - eqOfTime);
  final solarNoonUtc = _minutesToDateTime(date, solarNoonMinutes);

  // Polar cases
  if (cosHourAngle > 1.0) {
    // Sun never rises (polar night)
    return SolarTimes(
      sunriseUtc: null,
      sunsetUtc: null,
      solarNoonUtc: solarNoonUtc,
    );
  }
  if (cosHourAngle < -1.0) {
    // Sun never sets (midnight sun)
    return SolarTimes(
      sunriseUtc: null,
      sunsetUtc: null,
      solarNoonUtc: solarNoonUtc,
    );
  }

  final hourAngle = _toDeg(math.acos(cosHourAngle));

  // Sunrise: solar noon minus hour angle × 4 minutes/degree
  final sunriseMinutes = solarNoonMinutes - hourAngle * 4;
  final sunsetMinutes = solarNoonMinutes + hourAngle * 4;

  return SolarTimes(
    sunriseUtc: _minutesToDateTime(date, sunriseMinutes),
    sunsetUtc: _minutesToDateTime(date, sunsetMinutes),
    solarNoonUtc: solarNoonUtc,
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Julian Day number for a Gregorian calendar date.
double _julianDay(int year, int month, int day) {
  if (month <= 2) {
    year -= 1;
    month += 12;
  }
  final A = year ~/ 100;
  final B = 2 - A + A ~/ 4;
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      day +
      B -
      1524.5;
}

/// Earth's orbital eccentricity.
double _eccent(double T) =>
    0.016708634 - T * (0.000042037 + 0.0000001267 * T);

/// Convert degrees to radians.
double _toRad(double deg) => deg * math.pi / 180.0;

/// Convert radians to degrees.
double _toDeg(double rad) => rad * 180.0 / math.pi;

/// Convert minutes past UTC midnight on [date] into a UTC [DateTime].
DateTime _minutesToDateTime(DateTime date, double minutesPastMidnight) {
  final totalSeconds = (minutesPastMidnight * 60).round();
  return DateTime.utc(date.year, date.month, date.day)
      .add(Duration(seconds: totalSeconds));
}
