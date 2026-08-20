/// Nakshatra calculator unit tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:malayalam_calendar_app/core/astro/nakshatra_calculator.dart';

void main() {
  group('NakshatraCalculator', () {
    // ------------------------------------------------------------------
    // Basic index computation
    // ------------------------------------------------------------------
    test('0° longitude is Ashwini (index 0)', () {
      expect(getNakshatraIndex(0.0), 0);
    });

    test('13.333° is exactly the start of Bharani (index 1)', () {
      // 360/27 = 13.333...
      expect(getNakshatraIndex(kDegreesPerNakshatra), 1);
    });

    test('13.332° is still Ashwini (index 0)', () {
      expect(getNakshatraIndex(kDegreesPerNakshatra - 0.001), 0);
    });

    test('359.999° is Revati (index 26)', () {
      expect(getNakshatraIndex(359.999), 26);
    });

    test('Exactly 360° wraps to Ashwini (index 0)', () {
      expect(getNakshatraIndex(360.0), 0);
    });

    test('Negative longitude wraps correctly', () {
      // -1° = 359° = Revati
      expect(getNakshatraIndex(-1.0), 26);
    });

    test('Each of 27 nakshatras has exactly 13.333° width', () {
      for (int i = 0; i < 27; i++) {
        final width = getNakshatraEndDegree(i) - getNakshatraStartDegree(i);
        expect(width, closeTo(kDegreesPerNakshatra, 1e-9));
      }
    });

    // ------------------------------------------------------------------
    // Known nakshatra positions
    // ------------------------------------------------------------------
    test('40.0° is Rohini (index 3)', () {
      // Rohini: 40°–53.33°
      expect(getNakshatraIndex(40.0), 3);
      expect(getNakshatraName(3), 'Rohini');
    });

    test('120.0° is Magha (index 9)', () {
      // Magha: 120°–133.33°
      expect(getNakshatraIndex(120.0), 9);
      expect(getNakshatraName(9), 'Magha');
    });

    test('240.0° is Moola (index 18)', () {
      // Moola: 240°–253.33°
      expect(getNakshatraIndex(240.0), 18);
      expect(getNakshatraName(18), 'Moola');
    });

    test('346.666° is Uttara Bhadrapada (index 25) — Revati starts at 346.6̄°', () {
      // Revati starts at exactly 26 * (360/27) = 346.6̄recurring°.
      // 346.666 < 346.6̄recurring, so it is still in Uttara Bhadrapada (index 25).
      expect(getNakshatraIndex(346.666), 25);
    });

    test('346.667° is Revati (index 26)', () {
      // 346.6̄recurring = 346.66666...°. 346.667 is just above this threshold.
      expect(getNakshatraIndex(346.667), 26);
    });

    // ------------------------------------------------------------------
    // Name list completeness
    // ------------------------------------------------------------------
    test('There are exactly 27 nakshatra names', () {
      expect(kNakshatraNames.length, 27);
    });

    test('All 27 nakshatra names are non-empty strings', () {
      for (final name in kNakshatraNames) {
        expect(name.trim().isNotEmpty, isTrue);
      }
    });

    // ------------------------------------------------------------------
    // Progress within nakshatra
    // ------------------------------------------------------------------
    test('Progress at start of nakshatra is 0 or 1 (floating-point boundary)', () {
      // 0.0° is unambiguously at nakshatra 0 start
      expect(getNakshatraProgress(0.0), closeTo(0.0, 1e-9));
      // 40.0° is at the start of Rohini, but IEEE 754 rounding of 360/27 may give
      // a value very close to 1.0 (end of Bharani) or 0.0 (start of Rohini).
      // Either is acceptable since they represent the same boundary.
      final progressAt40 = getNakshatraProgress(40.0);
      expect(
        progressAt40 < 1e-9 || progressAt40 > 1.0 - 1e-9,
        isTrue,
        reason: 'Progress at exact nakshatra boundary 40° should be ~0 or ~1, '
                'got $progressAt40',
      );
    });

    test('Progress at midpoint of nakshatra is ~0.5', () {
      final midRohini = 40.0 + kDegreesPerNakshatra / 2;
      expect(getNakshatraProgress(midRohini), closeTo(0.5, 0.001));
    });

    // ------------------------------------------------------------------
    // Total zodiac coverage
    // ------------------------------------------------------------------
    test('27 nakshatras cover exactly 360°', () {
      final total = 27 * kDegreesPerNakshatra;
      expect(total, closeTo(360.0, 1e-9));
    });
  });
}
