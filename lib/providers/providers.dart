/// Riverpod providers for the Malayalam Calendar App.
///
/// Dependency graph:
///   ephemerisInitProvider (FutureProvider)
///     ↓
///   locationProvider (StateNotifierProvider)
///     ↓
///   calendarMonthProvider (FutureProvider.family)
///     ↓
///   selectedDateProvider (StateProvider)
library providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:malayalam_calendar_app/core/ephemeris/ephemeris_service.dart';
import 'package:malayalam_calendar_app/core/astro/sankranti_calculator.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_day.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';
import 'package:malayalam_calendar_app/data/repositories/calendar_repository.dart';
import 'package:malayalam_calendar_app/data/repositories/cache_repository.dart';
import 'package:malayalam_calendar_app/data/repositories/location_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers (singletons via [Provider])
// ---------------------------------------------------------------------------

final cacheRepositoryProvider = Provider<CacheRepository>((ref) {
  return CacheRepository();
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

// ---------------------------------------------------------------------------
// Initialisation gate — all async startup in one place
// ---------------------------------------------------------------------------

/// Completes when Swiss Ephemeris + Hive + location repo are all ready.
/// All UI must be gated behind this provider's loading state.
final appInitProvider = FutureProvider<void>((ref) async {
  final cache = ref.read(cacheRepositoryProvider);
  final locationRepo = ref.read(locationRepositoryProvider);

  await Future.wait([
    EphemerisService.instance.initialize(),
    cache.initialize(),
    locationRepo.initialize(),
  ]);
});

// ---------------------------------------------------------------------------
// Location state
// ---------------------------------------------------------------------------

class LocationNotifier extends StateNotifier<LocationModel> {
  final LocationRepository _repo;

  LocationNotifier(this._repo) : super(_repo.getSavedLocation());

  /// Updates the location and persists it.
  Future<void> setLocation(LocationModel location) async {
    state = location;
    await _repo.saveLocation(location);
  }

  /// Attempts to use GPS. Returns true if successful.
  Future<bool> useGpsLocation() async {
    final gpsLoc = await _repo.requestGpsLocation();
    if (gpsLoc != null) {
      await setLocation(gpsLoc);
      return true;
    }
    return false;
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationModel>((ref) {
  final repo = ref.read(locationRepositoryProvider);
  return LocationNotifier(repo);
});

// ---------------------------------------------------------------------------
// Selected date (for day detail navigation)
// ---------------------------------------------------------------------------

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// ---------------------------------------------------------------------------
// Calendar view mode — Gregorian or Malayalam primary
// ---------------------------------------------------------------------------

enum CalendarViewMode { gregorian, malayalam }

final calendarViewModeProvider = StateProvider<CalendarViewMode>(
  (ref) => CalendarViewMode.gregorian,
);

// ---------------------------------------------------------------------------
// Calendar month provider (cached + computed on demand)
// ---------------------------------------------------------------------------

class MonthKey {
  final int kollavarshamYear;
  final int monthIndex;
  final String locationCacheKey;

  const MonthKey({
    required this.kollavarshamYear,
    required this.monthIndex,
    required this.locationCacheKey,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthKey &&
          kollavarshamYear == other.kollavarshamYear &&
          monthIndex == other.monthIndex &&
          locationCacheKey == other.locationCacheKey;

  @override
  int get hashCode =>
      kollavarshamYear.hashCode ^ monthIndex.hashCode ^ locationCacheKey.hashCode;
}

/// Provides a [MalayalamMonth] for the given key. Checks Hive cache first,
/// then computes and caches.
///
/// Automatically awaits [appInitProvider] before computing.
final calendarMonthProvider =
    FutureProvider.family<MalayalamMonth, MonthKey>((ref, key) async {
  // Wait for full app initialisation
  await ref.watch(appInitProvider.future);

  final cache = ref.read(cacheRepositoryProvider);
  final repo = ref.read(calendarRepositoryProvider);
  final location = ref.watch(locationProvider);

  // Check cache first
  final cached = cache.getCachedMonth(
    kollavarshamYear: key.kollavarshamYear,
    monthIndex: key.monthIndex,
    locationCacheKey: key.locationCacheKey,
  );
  if (cached != null) return cached;

  // Compute the month (may take 2–5 seconds on first computation)
  final month = repo.generateMonth(
    monthIndex: key.monthIndex,
    kollavarshamYear: key.kollavarshamYear,
    location: location,
  );

  // Cache it for future launches
  await cache.cacheMonth(month);
  return month;
});

// ---------------------------------------------------------------------------
// Current displayed month — Malayalam view (drives the Malayalam calendar grid)
// ---------------------------------------------------------------------------

final displayedMonthKeyProvider = StateProvider<MonthKey>((ref) {
  final location = ref.watch(locationProvider);
  final now = DateTime.now();
  final approxKEYear = SankrantiCalculator.kollavarshamYearApprox(now);
  final approxMonthIndex = _approxMalayalamMonthIndex(now);
  return MonthKey(
    kollavarshamYear: approxKEYear,
    monthIndex: approxMonthIndex,
    locationCacheKey: location.cacheKey,
  );
});

// ---------------------------------------------------------------------------
// Gregorian month view data
// ---------------------------------------------------------------------------

/// Key for a Gregorian month view.
class GregorianMonthKey {
  final int year;
  final int month; // 1–12
  final String locationCacheKey;

  const GregorianMonthKey({
    required this.year,
    required this.month,
    required this.locationCacheKey,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GregorianMonthKey &&
          year == other.year &&
          month == other.month &&
          locationCacheKey == other.locationCacheKey;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ locationCacheKey.hashCode;
}

/// Current displayed Gregorian month (drives the Gregorian calendar grid).
final displayedGregorianMonthProvider = StateProvider<GregorianMonthKey>((ref) {
  final now = DateTime.now();
  final location = ref.watch(locationProvider);
  return GregorianMonthKey(
    year: now.year,
    month: now.month,
    locationCacheKey: location.cacheKey,
  );
});

/// Pairs a MalayalamDay with its containing MalayalamMonth, for Gregorian view.
class GregorianDayData {
  final MalayalamDay day;
  final MalayalamMonth month;
  const GregorianDayData({required this.day, required this.month});
}

/// For a given Gregorian month, fetches all overlapping Malayalam months and
/// returns a list of [GregorianDayData?] — one per day in the Gregorian month.
/// Null entries mean that date fell outside all computed Malayalam months
/// (should not happen in practice for dates in 1800–2400 CE range).
final gregorianMonthDataProvider =
    FutureProvider.family<List<GregorianDayData?>, GregorianMonthKey>(
  (ref, key) async {
    await ref.watch(appInitProvider.future);

    final cache = ref.read(cacheRepositoryProvider);
    final repo = ref.read(calendarRepositoryProvider);
    final location = ref.watch(locationProvider);

    final daysInMonth = DateTime(key.year, key.month + 1, 0).day;
    final firstDay = DateTime(key.year, key.month, 1);
    final lastDay = DateTime(key.year, key.month, daysInMonth);

    // Find which Malayalam months overlap with this Gregorian month
    final monthKeys = _overlappingMalayalamKeys(firstDay, lastDay, key.locationCacheKey);

    // Build a map of date → (day, month) for fast lookup
    final allDays = <DateTime, GregorianDayData>{};
    for (final mk in monthKeys) {
      MalayalamMonth? malMonth = cache.getCachedMonth(
        kollavarshamYear: mk.kollavarshamYear,
        monthIndex: mk.monthIndex,
        locationCacheKey: mk.locationCacheKey,
      );
      if (malMonth == null) {
        malMonth = repo.generateMonth(
          monthIndex: mk.monthIndex,
          kollavarshamYear: mk.kollavarshamYear,
          location: location,
        );
        await cache.cacheMonth(malMonth);
      }
      for (final day in malMonth.days) {
        final dateKey = DateTime(
          day.gregorianDate.year,
          day.gregorianDate.month,
          day.gregorianDate.day,
        );
        allDays[dateKey] = GregorianDayData(day: day, month: malMonth);
      }
    }

    // Build result list — one entry per Gregorian day
    return List.generate(daysInMonth, (i) {
      final date = DateTime(key.year, key.month, i + 1);
      return allDays[date];
    });
  },
);

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Returns the 1 or 2 Malayalam MonthKeys that overlap with a given
/// Gregorian date range. Uses the approximate month mapping — actual
/// Sankranti boundary is resolved when the month is computed.
List<MonthKey> _overlappingMalayalamKeys(
    DateTime firstDay, DateTime lastDay, String locationKey) {
  final checkDates = [
    firstDay,
    firstDay.add(const Duration(days: 15)),
    lastDay,
  ];
  final keys = <MonthKey>[];
  for (final date in checkDates) {
    final ke = SankrantiCalculator.kollavarshamYearApprox(date);
    final mi = _approxMalayalamMonthIndex(date);
    final k = MonthKey(
      kollavarshamYear: ke,
      monthIndex: mi,
      locationCacheKey: locationKey,
    );
    if (!keys.contains(k)) {
      keys.add(k);
    }
  }
  return keys;
}

/// Approximate Malayalam month index for a given Gregorian date.
/// Accurately reflects that each Gregorian month starts in one Malayalam month
/// and transitions to the next around days 13–17.
int _approxMalayalamMonthIndex(DateTime date) {
  const transitions = {
    1: (14, 4, 5),   // Jan: Dhanu(4) -> Makaram(5)
    2: (13, 5, 6),   // Feb: Makaram(5) -> Kumbham(6)
    3: (14, 6, 7),   // Mar: Kumbham(6) -> Meenam(7)
    4: (14, 7, 8),   // Apr: Meenam(7) -> Medam(8)
    5: (14, 8, 9),   // May: Medam(8) -> Edavam(9)
    6: (14, 9, 10),  // Jun: Edavam(9) -> Mithunam(10)
    7: (16, 10, 11), // Jul: Mithunam(10) -> Karkidakam(11)
    8: (17, 11, 0),  // Aug: Karkidakam(11) -> Chingam(0)
    9: (17, 0, 1),   // Sep: Chingam(0) -> Kanni(1)
    10: (17, 1, 2),  // Oct: Kanni(1) -> Thulam(2)
    11: (16, 2, 3),  // Nov: Thulam(2) -> Vrischikam(3)
    12: (15, 3, 4),  // Dec: Vrischikam(3) -> Dhanu(4)
  };

  final t = transitions[date.month];
  if (t == null) return 0;
  return (date.day >= t.$1) ? t.$3 : t.$2;
}
