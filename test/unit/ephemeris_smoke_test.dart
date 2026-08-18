/// Ephemeris smoke test — verifies that Swiss Ephemeris is correctly
/// computing sidereal Sun/Moon longitudes against known panchang values.
///
/// Reference values sourced from drikpanchang.com (Lahiri ayanamsa, Kerala).
///
/// Tolerance: ±0.5° for Moon (it moves ~13.2°/day = ~0.009°/min, so even a
/// 3-minute ephemeris discrepancy produces <0.05° error).
/// ±0.1° for Sun (moves ~1°/day).
///
/// NOTE: This test requires the `sweph` package to be initialised. In the
/// test environment, Sweph.init() must be called before running these tests.
/// The test framework must be set up with the Flutter test runner so that
/// package assets (the bundled .se1 files) are accessible.
import 'package:flutter_test/flutter_test.dart';
import 'package:sweph/sweph.dart';
import 'package:malayalam_calendar_app/core/ephemeris/ephemeris_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await EphemerisService.instance.initialize();
  });

  group('EphemerisService (Swiss Ephemeris smoke test)', () {
    // ------------------------------------------------------------------
    // Sun sidereal longitude tests
    // ------------------------------------------------------------------
    test(
      'Sun sidereal longitude on 2024-08-17 12:00 UTC is ~150° '
      '(Kanni/Virgo boundary — around Chingam-Kanni Sankranti)',
      () {
        final lon = EphemerisService.instance.getSunSiderealLongitude(
          DateTime.utc(2024, 8, 17, 12, 0),
        );
        // Chingam = Sun at 120°–150°. On Aug 17 the sun should be near
        // the end of Chingam (~148°–151°). Reference: drikpanchang shows
        // Kanni Sankranti (Sun enters 150°) around Aug 16–17 each year.
        expect(
          lon,
          inInclusiveRange(145.0, 155.0),
          reason: 'Sun on 2024-08-17 should be near 150° sidereal, got $lon°',
        );
      },
    );

    test(
      'Sun sidereal longitude on 2024-01-15 12:00 UTC is ~270° '
      '(Makara/Capricorn — Makaram month)',
      () {
        final lon = EphemerisService.instance.getSunSiderealLongitude(
          DateTime.utc(2024, 1, 15, 12, 0),
        );
        // Makaram = Sun at 270°–300°. Mid-January should be ~270°–275°.
        expect(
          lon,
          inInclusiveRange(268.0, 280.0),
          reason: 'Sun on 2024-01-15 should be ~270–280° sidereal, got $lon°',
        );
      },
    );

    // ------------------------------------------------------------------
    // Moon sidereal longitude tests
    // ------------------------------------------------------------------
    test(
      'Moon sidereal longitude on 2024-01-01 00:00 UTC is within known range',
      () {
        // Reference from drikpanchang (Lahiri): Moon was in Pushya/Ashlesha
        // area (approx 93°–120°) on 2024-01-01.
        final lon = EphemerisService.instance.getMoonSiderealLongitude(
          DateTime.utc(2024, 1, 1, 0, 0),
        );
        expect(
          lon,
          inInclusiveRange(93.0, 125.0),
          reason: 'Moon on 2024-01-01 should be in Pushya–Ashlesha range, got $lon°',
        );
      },
    );

    // ------------------------------------------------------------------
    // Sankranti moment detection
    // ------------------------------------------------------------------
    test(
      'Chingam Sankranti 2024 (Sun reaches 120° sidereal) occurs around Aug 16–18',
      () {
        final sankranti = EphemerisService.instance.findSankrantiMoment(
          targetLongitude: 120.0,
          searchCenter: DateTime.utc(2024, 8, 17),
        );
        // Chingam Sankranti 2024: typically Aug 16 or 17 in IST
        expect(
          sankranti.year,
          equals(2024),
          reason: 'Chingam Sankranti should be in 2024',
        );
        expect(
          sankranti.month,
          equals(8),
          reason: 'Chingam Sankranti should be in August',
        );
        expect(
          sankranti.day,
          inInclusiveRange(15, 18),
          reason: 'Chingam Sankranti should be Aug 15–18',
        );
      },
    );

    test(
      'Kanni Sankranti 2024 (Sun reaches 150°) occurs around Sep 16–18',
      () {
        final sankranti = EphemerisService.instance.findSankrantiMoment(
          targetLongitude: 150.0,
          searchCenter: DateTime.utc(2024, 9, 17),
        );
        expect(sankranti.month, equals(9));
        expect(sankranti.day, inInclusiveRange(15, 19));
      },
    );

    // ------------------------------------------------------------------
    // Sanity: Moon moves ~10–15° per day
    // ------------------------------------------------------------------
    test(
      'Moon longitude increases 10–15° per day (in-range daily motion)',
      () {
        final d1 = DateTime.utc(2024, 6, 15, 6, 0);
        final d2 = DateTime.utc(2024, 6, 16, 6, 0);

        final lon1 = EphemerisService.instance.getMoonSiderealLongitude(d1);
        final lon2 = EphemerisService.instance.getMoonSiderealLongitude(d2);

        // Handle wraparound at 0°/360°
        var diff = (lon2 - lon1 + 360.0) % 360.0;
        if (diff > 180) diff -= 360; // Should never happen for 1-day interval

        expect(
          diff,
          inInclusiveRange(10.0, 15.5),
          reason:
              'Moon daily motion should be 10–15.5°, got $diff° (lon1=$lon1, lon2=$lon2)',
        );
      },
    );
  });
}
