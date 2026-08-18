/// Swiss Ephemeris service — wraps the `sweph` package for this app.
///
/// Responsibilities:
///   - One-time initialisation of the Sweph library + ephemeris assets
///   - Setting sidereal mode to Lahiri (SE_SIDM_LAHIRI) once at startup
///   - Providing clean, typed Dart methods for Sun and Moon sidereal longitudes
///   - Binary-search for the exact Julian Day of a Sankranti (Sun at n×30°)
///
/// IMPORTANT: swe_set_sid_mode must be called before any swe_calc_ut call that
/// uses SEFLG_SIDEREAL. This service does it in [initialize] and it is sticky
/// for the process lifetime.
library ephemeris_service;

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sweph/sweph.dart';

/// Singleton service wrapping Swiss Ephemeris (via the `sweph` package).
class EphemerisService {
  EphemerisService._();
  static final EphemerisService instance = EphemerisService._();

  bool _initialized = false;

  /// Initialize the Swiss Ephemeris.
  ///
  /// Must be called (and awaited) before any other method on this class.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    String epheDir;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      epheDir = p.join(appSupportDir.path, 'ephe_files');
    } catch (_) {
      epheDir = 'ephe_files';
    }

    await Sweph.init(
      epheFilesPath: epheDir,
      epheAssets: [
        // Bundled with the `sweph` package — covers 1800–2400 CE:
        'packages/sweph/assets/ephe/sepl_18.se1',  // planets (incl. Sun)
        'packages/sweph/assets/ephe/semo_18.se1',  // Moon
        'packages/sweph/assets/ephe/seleapsec.txt', // leap seconds
      ],
    );

    // Set sidereal mode to Lahiri (Chitra Paksha) — the Indian government
    // and Kerala panchang standard. This call is sticky for the process.
    Sweph.swe_set_sid_mode(
      SiderealMode.SE_SIDM_LAHIRI,
      SiderealModeFlag.SE_SIDBIT_NONE,
      0.0, // t0 (not used when SE_SIDBIT_NONE)
    );

    _initialized = true;
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'EphemerisService.initialize() must be awaited before use.',
      );
    }
  }

  /// Returns the **sidereal** longitude of the Sun (degrees, [0, 360)) at
  /// the given UTC moment.
  ///
  /// Uses Lahiri ayanamsa as set in [initialize].
  double getSunSiderealLongitude(DateTime utc) {
    _assertInitialized();
    final jd = _toJulianDay(utc);
    final result = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_SUN,
      SwephFlag.SEFLG_SWIEPH | SwephFlag.SEFLG_SIDEREAL,
    );
    return _normalizeLon(result.longitude);
  }

  /// Returns the **sidereal** longitude of the Moon (degrees, [0, 360)) at
  /// the given UTC moment.
  ///
  /// Uses Lahiri ayanamsa as set in [initialize].
  double getMoonSiderealLongitude(DateTime utc) {
    _assertInitialized();
    final jd = _toJulianDay(utc);
    final result = Sweph.swe_calc_ut(
      jd,
      HeavenlyBody.SE_MOON,
      SwephFlag.SEFLG_SWIEPH | SwephFlag.SEFLG_SIDEREAL,
    );
    return _normalizeLon(result.longitude);
  }

  /// Finds the exact UTC moment when the Sun's sidereal longitude first
  /// crosses [targetLongitude] degrees, searching in a ±45-day window
  /// around [searchCenter].
  ///
  /// Uses binary search converging to within 1 second.
  ///
  /// [targetLongitude] — the Sankranti longitude to search for (e.g. 120.0
  /// for Chingam Sankranti). Must be in [0, 360).
  ///
  /// [searchCenter] — approximate UTC time to search around (e.g. the
  /// 1st of the expected month's start).
  DateTime findSankrantiMoment({
    required double targetLongitude,
    required DateTime searchCenter,
  }) {
    _assertInitialized();

    // ±45 days window (covers any month boundary comfortably).
    var lo = searchCenter.subtract(const Duration(days: 45));
    var hi = searchCenter.add(const Duration(days: 45));

    // The Sun moves ~1°/day. We binary-search for the moment the Sun's
    // sidereal longitude == targetLongitude.
    // Handle the 0°/360° wraparound: shift everything so target is at 180°.
    double _shifted(double lon) {
      final d = (lon - targetLongitude + 360.0) % 360.0;
      // Map [0,360) → [-180, 180): negative means "before", positive "after"
      return d <= 180.0 ? d : d - 360.0;
    }

    // Verify the crossing is within window
    final shiftedLo = _shifted(getSunSiderealLongitude(lo));
    final shiftedHi = _shifted(getSunSiderealLongitude(hi));

    if (shiftedLo > 0 || shiftedHi < 0) {
      // Widen search window and try again (shouldn't happen for normal dates)
      lo = searchCenter.subtract(const Duration(days: 90));
      hi = searchCenter.add(const Duration(days: 90));
    }

    // Binary search: converge to within 1 second
    while (hi.difference(lo).inSeconds > 1) {
      final mid = lo.add(Duration(
        milliseconds: hi.difference(lo).inMilliseconds ~/ 2,
      ));
      final shifted = _shifted(getSunSiderealLongitude(mid));
      if (shifted < 0) {
        lo = mid; // crossing is after mid
      } else {
        hi = mid; // crossing is before or at mid
      }
    }

    return lo.add(Duration(
      milliseconds: hi.difference(lo).inMilliseconds ~/ 2,
    ));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a UTC [DateTime] to a Julian Day number (double).
  static double _toJulianDay(DateTime utc) {
    final ut = utc.toUtc();
    final hour = ut.hour + ut.minute / 60.0 + ut.second / 3600.0;
    return Sweph.swe_julday(
      ut.year,
      ut.month,
      ut.day,
      hour,
      CalendarType.SE_GREG_CAL,
    );
  }

  /// Normalise longitude to [0, 360).
  static double _normalizeLon(double lon) => ((lon % 360.0) + 360.0) % 360.0;
}
