/// Sankranti calculator — determines Malayalam month boundaries.
///
/// A Malayalam month begins at the Sankranti (the instant the Sun's sidereal
/// longitude crosses a multiple of 30°). The civil-day assignment follows the
/// Kerala Aparahna rule:
///
///   If Sankranti falls BEFORE 3/5 of the daylight duration (Aparahna):
///     → The new month's Day 1 is the SAME Gregorian day.
///   If Sankranti falls ON OR AFTER the Aparahna threshold:
///     → The new month's Day 1 is the NEXT Gregorian day.
///
/// Kollavarsham year = Gregorian year − 825, adjusted at each Chingam Sankranti.
library sankranti_calculator;

import 'package:malayalam_calendar_app/core/ephemeris/ephemeris_service.dart';
import 'package:malayalam_calendar_app/core/astro/sunrise_calculator.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';

/// Result of a Sankranti calculation.
class SankrantiResult {
  /// The exact UTC moment of the Sankranti.
  final DateTime momentUtc;

  /// The Gregorian date on which the new Malayalam month begins (Day 1),
  /// after applying the Aparahna rule for the given location.
  final DateTime monthFirstDay;

  /// Whether the Sankranti fell before the Aparahna threshold (true → same
  /// day assignment) or on/after it (false → next day assignment).
  final bool sankrantiBeforeAparahna;

  const SankrantiResult({
    required this.momentUtc,
    required this.monthFirstDay,
    required this.sankrantiBeforeAparahna,
  });
}

class SankrantiCalculator {
  final EphemerisService _ephem;

  SankrantiCalculator({EphemerisService? ephemerisService})
      : _ephem = ephemerisService ?? EphemerisService.instance;

  /// Computes the Sankranti for a given [monthIndex] (0=Chingam…11=Karkidakam)
  /// occurring in [approximateGregorianYear], and applies the Aparahna rule for
  /// [location] to determine the first civil day of that month.
  ///
  /// [approximateGregorianYear] — the Gregorian year in which the Sankranti is
  /// expected. For months spanning year boundaries (Makaram, Kumbham, Meenam,
  /// which can occur in Jan–Apr), pass the year of the Sankranti itself.
  SankrantiResult computeSankranti({
    required int monthIndex,
    required int approximateGregorianYear,
    required LocationModel location,
  }) {
    final targetLon = kSankrantiLongitudes[monthIndex];

    // Build a search center: approximate month using known solar position.
    // Chingam Sankranti is around Aug 17, each subsequent month ~30 days later.
    // We use a lookup table for the approximate Gregorian month.
    final approxMonth = _approximateGregorianMonth(monthIndex);
    final searchCenter = DateTime.utc(approximateGregorianYear, approxMonth, 15);

    final sankrantiUtc = _ephem.findSankrantiMoment(
      targetLongitude: targetLon,
      searchCenter: searchCenter,
    );

    // Determine the Gregorian day on which the Sankranti occurred (in IST = UTC+5:30)
    // Kerala observes IST, so local civil date is UTC + 5h30m.
    final sankrantiIst = sankrantiUtc.add(const Duration(hours: 5, minutes: 30));
    final sankrantiGregorianDay = DateTime(
      sankrantiIst.year, sankrantiIst.month, sankrantiIst.day,
    );

    // Compute sunrise and sunset on that day for the Aparahna calculation.
    final solar = computeSolarTimes(
      sankrantiGregorianDay,
      location.latitude,
      location.longitude,
    );

    bool beforeAparahna = false;
    DateTime monthFirstDay;

    if (solar.sunriseUtc != null && solar.aparahnaThreshold != null) {
      beforeAparahna = sankrantiUtc.isBefore(solar.aparahnaThreshold!);
      if (beforeAparahna) {
        // Sankranti is before 3/5 of daylight → same day is month 1
        monthFirstDay = sankrantiGregorianDay;
      } else {
        // Sankranti is on/after Aparahna → next day is month 1
        monthFirstDay = sankrantiGregorianDay.add(const Duration(days: 1));
      }
    } else {
      // Edge case: no sunrise (polar region). Fall back to same-day rule.
      monthFirstDay = sankrantiGregorianDay;
      beforeAparahna = true;
    }

    return SankrantiResult(
      momentUtc: sankrantiUtc,
      monthFirstDay: monthFirstDay,
      sankrantiBeforeAparahna: beforeAparahna,
    );
  }

  /// Returns the Kollavarsham year for a given Gregorian date.
  ///
  /// Kollavarsham year = Gregorian year − 825.
  /// This is accurate for dates AFTER the Chingam Sankranti of that year.
  /// Before the Chingam Sankranti (typically before ~Aug 17), the KE year
  /// is still Gregorian year − 825 − 1.
  ///
  /// To get the exact boundary, call [computeSankranti] for Chingam (index 0)
  /// and compare with the date.
  static int kollavarshamYearApprox(DateTime gregorianDate) {
    // Before Chingam Sankranti (~Aug 17), KE year = Gregorian year − 825.
    // From Chingam Sankranti onwards (Aug 17 – Dec 31), KE year = Gregorian year − 824.
    if (gregorianDate.month < 8 ||
        (gregorianDate.month == 8 && gregorianDate.day < 17)) {
      return gregorianDate.year - 825;
    }
    return gregorianDate.year - 824;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Approximate Gregorian month in which a given Malayalam month's
  /// Sankranti occurs. Used only to build the binary-search center date.
  static int _approximateGregorianMonth(int malayalamMonthIndex) {
    // Chingam(0)=Aug, Kanni(1)=Sep, Thulam(2)=Oct, Vrischikam(3)=Nov,
    // Dhanu(4)=Dec, Makaram(5)=Jan, Kumbham(6)=Feb, Meenam(7)=Mar,
    // Medam(8)=Apr, Edavam(9)=May, Mithunam(10)=Jun, Karkidakam(11)=Jul
    const months = [8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7];
    return months[malayalamMonthIndex];
  }
}
