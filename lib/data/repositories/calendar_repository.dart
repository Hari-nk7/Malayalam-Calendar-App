/// Calendar Repository — generates a full MalayalamMonth with all flags.
///
/// Algorithm:
///   1. Find the Sankranti moment for this month (using SankrantiCalculator).
///   2. Apply Aparahna rule → first Gregorian day of the month.
///   3. Find the NEXT month's Sankranti → that first Gregorian day is the
///      exclusive upper bound of THIS month.
///   4. For each day in [firstDay, nextFirstDay):
///      a. Compute sunrise(day, location).
///      b. Get Moon sidereal longitude at that sunrise UTC.
///      c. Compute nakshatra index.
///   5. Post-process flags across the full day list:
///      a. Spanning: day[i].nakshatra == day[i-1].nakshatra
///         → day[i].spansFromPreviousDay = true
///      b. Skipped: any nakshatra whose 30° span the Moon crossed entirely
///         between two consecutive sunrises. Detected by checking if the
///         consecutive nakshatra indices differ by more than 1 (mod 27).
///      c. Repeat in month: nakshatra appears on 2+ days in the same month.
///         Both marked isRepeatOccurrence=true; first marked hasLaterRepeat=true.
library calendar_repository;

import 'package:malayalam_calendar_app/core/ephemeris/ephemeris_service.dart';
import 'package:malayalam_calendar_app/core/astro/sunrise_calculator.dart';
import 'package:malayalam_calendar_app/core/astro/nakshatra_calculator.dart';
import 'package:malayalam_calendar_app/core/astro/sankranti_calculator.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_day.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';

class CalendarRepository {
  final EphemerisService _ephem;
  final SankrantiCalculator _sankranti;

  CalendarRepository({
    EphemerisService? ephemerisService,
    SankrantiCalculator? sankrantiCalculator,
  })  : _ephem = ephemerisService ?? EphemerisService.instance,
        _sankranti = sankrantiCalculator ??
            SankrantiCalculator(
              ephemerisService: ephemerisService ?? EphemerisService.instance,
            );

  /// Generates a complete [MalayalamMonth] for the given month index and year.
  ///
  /// [monthIndex] — 0=Chingam … 11=Karkidakam
  /// [kollavarshamYear] — e.g. 1200
  /// [location] — observer location (affects sunrise time)
  ///
  /// For months that span a Gregorian year boundary (Makaram=5, Kumbham=6,
  /// Meenam=7, Medam=8), [gregorianYearOfSankranti] is the Gregorian year
  /// in which the Sankranti actually falls. Pass null to auto-compute.
  MalayalamMonth generateMonth({
    required int monthIndex,
    required int kollavarshamYear,
    required LocationModel location,
    int? gregorianYearOfSankranti,
  }) {
    // --- Step 1: Determine the Gregorian year of the Sankranti ---
    // KE year N corresponds to Gregorian year N+824 for Chingam–Dhanu.
    // Months 0–4 (Chingam–Dhanu) are in Gregorian year KE+824.
    // Months 5–11 (Makaram–Karkidakam) are in Gregorian year KE+825.
    final baseGregorianYear = kollavarshamYear + 824;
    final gregorianYear = gregorianYearOfSankranti ??
        _gregorianYearForSankranti(monthIndex, baseGregorianYear);

    // --- Step 2: Compute this month's Sankranti + first day ---
    final thisSankranti = _sankranti.computeSankranti(
      monthIndex: monthIndex,
      approximateGregorianYear: gregorianYear,
      location: location,
    );

    // --- Step 3: Compute next month's Sankranti + first day ---
    final nextMonthIndex = (monthIndex + 1) % 12;
    // Next month falls in the next Gregorian year ONLY when transitioning
    // from Dhanu (4, December) to Makaram (5, January).
    // In all other cases (including Karkidakam 11 -> Chingam 0, July to August),
    // the Gregorian year remains the same.
    final nextGregorianYear =
        (monthIndex == 4) ? gregorianYear + 1 : gregorianYear;

    final nextSankranti = _sankranti.computeSankranti(
      monthIndex: nextMonthIndex,
      approximateGregorianYear: nextGregorianYear,
      location: location,
    );

    // --- Step 4: Build the day list ---
    final firstDay = thisSankranti.monthFirstDay;
    final exclusiveLastDay = nextSankranti.monthFirstDay;

    // Sanity check: a month should be 29–32 days
    final totalDays = exclusiveLastDay.difference(firstDay).inDays;
    assert(
      totalDays >= 28 && totalDays <= 33,
      'Generated month has unexpected length: $totalDays days '
      '($firstDay – $exclusiveLastDay)',
    );

    final rawDays = <_RawDay>[];

    for (int i = 0; i < totalDays; i++) {
      final gregorianDate = firstDay.add(Duration(days: i));
      final solar = computeSolarTimes(
        gregorianDate,
        location.latitude,
        location.longitude,
      );

      final sunriseUtc = solar.sunriseUtc ??
          // Fallback for polar regions: use 6:00 AM local time
          DateTime.utc(
            gregorianDate.year,
            gregorianDate.month,
            gregorianDate.day,
            1, 0, // ~06:30 IST
          );

      final moonLon = _ephem.getMoonSiderealLongitude(sunriseUtc);
      final nakshatraIdx = getNakshatraIndex(moonLon);

      rawDays.add(_RawDay(
        gregorianDate: gregorianDate,
        nakshatraIndex: nakshatraIdx,
        sunriseUtc: sunriseUtc,
        malayalamDate: i + 1,
      ));
    }

    // --- Step 5: Compute spanning and skipped flags ---
    // We also need the previous day's nakshatra (day before month start)
    // to correctly flag day 1 as "spansFromPreviousDay" if needed.
    final dayBeforeStart = firstDay.subtract(const Duration(days: 1));
    final solarBefore = computeSolarTimes(
      dayBeforeStart, location.latitude, location.longitude,
    );
    final sunriseBefore = solarBefore.sunriseUtc ??
        DateTime.utc(dayBeforeStart.year, dayBeforeStart.month,
            dayBeforeStart.day, 1, 0);
    final moonLonBefore = _ephem.getMoonSiderealLongitude(sunriseBefore);
    final nakshatraBefore = getNakshatraIndex(moonLonBefore);

    final List<bool> spansFlags = List.filled(totalDays, false);
    final List<int> skippedNakshatras = [];

    // Check day 0 against the day before the month
    if (rawDays.isNotEmpty && rawDays[0].nakshatraIndex == nakshatraBefore) {
      spansFlags[0] = true;
    }

    for (int i = 1; i < rawDays.length; i++) {
      final curr = rawDays[i].nakshatraIndex;
      final prev = rawDays[i - 1].nakshatraIndex;

      if (curr == prev) {
        // Same nakshatra at both sunrises → current day "spans from previous"
        spansFlags[i] = true;
      }

      // Detect skipped nakshatras: the Moon crossed one or more complete
      // nakshatra spans between these two sunrises.
      // The Moon moves forward (increasing longitude), so we check if
      // there are indices between prev and curr (exclusive, in the forward
      // direction, mod 27) that were skipped.
      final gap = (curr - prev + 27) % 27;
      if (gap >= 2) {
        // Indices between prev+1 and curr-1 (mod 27) were skipped.
        for (int k = 1; k < gap; k++) {
          final skipped = (prev + k) % 27;
          if (!skippedNakshatras.contains(skipped)) {
            skippedNakshatras.add(skipped);
          }
        }
      }
    }

    // --- Step 6: Detect repeat nakshatras within the month ---
    // Count occurrences of each nakshatra index across the day list.
    final Map<int, List<int>> nakshatraDayIndices = {};
    for (int i = 0; i < rawDays.length; i++) {
      final idx = rawDays[i].nakshatraIndex;
      nakshatraDayIndices.putIfAbsent(idx, () => []).add(i);
    }

    // Build sets of day indices that have repeat or later-repeat flags
    final Set<int> repeatDayIndices = {};
    final Set<int> hasLaterRepeatDayIndices = {};

    for (final entry in nakshatraDayIndices.entries) {
      if (entry.value.length >= 2) {
        // All occurrences are repeats
        repeatDayIndices.addAll(entry.value);
        // All but the LAST occurrence have a later repeat
        for (int k = 0; k < entry.value.length - 1; k++) {
          hasLaterRepeatDayIndices.add(entry.value[k]);
        }
      }
    }

    // --- Step 7: Assemble final MalayalamDay objects ---
    final days = <MalayalamDay>[];
    for (int i = 0; i < rawDays.length; i++) {
      final raw = rawDays[i];
      days.add(MalayalamDay(
        gregorianDate: raw.gregorianDate,
        malayalamMonthIndex: monthIndex,
        malayalamDate: raw.malayalamDate,
        nakshatraIndex: raw.nakshatraIndex,
        sunriseUtc: raw.sunriseUtc,
        spansFromPreviousDay: spansFlags[i],
        isRepeatOccurrence: repeatDayIndices.contains(i),
        hasLaterRepeat: hasLaterRepeatDayIndices.contains(i),
      ));
    }

    return MalayalamMonth(
      kollavarshamYear: kollavarshamYear,
      monthIndex: monthIndex,
      days: days,
      skippedNakshatras: skippedNakshatras,
      generatedAt: DateTime.now().toUtc(),
      locationKey: location.cacheKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Maps a Malayalam month index to the Gregorian year in which its Sankranti
  /// falls, given the KE base Gregorian year (= KE year + 825).
  ///
  /// Chingam (0) through Dhanu (4): in base year (Aug–Dec).
  /// Makaram (5) through Karkidakam (11): in base year + 1 (Jan–Jul).
  static int _gregorianYearForSankranti(int monthIndex, int baseYear) {
    // Months 5–11 fall in the following Gregorian year.
    return (monthIndex >= 5) ? baseYear + 1 : baseYear;
  }
}

/// Internal helper struct for the pre-flag-computation day list.
class _RawDay {
  final DateTime gregorianDate;
  final int nakshatraIndex;
  final DateTime sunriseUtc;
  final int malayalamDate;

  const _RawDay({
    required this.gregorianDate,
    required this.nakshatraIndex,
    required this.sunriseUtc,
    required this.malayalamDate,
  });
}
