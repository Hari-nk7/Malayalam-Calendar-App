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
// Current displayed month (drives the calendar grid)
// ---------------------------------------------------------------------------

final displayedMonthKeyProvider = StateProvider<MonthKey>((ref) {
  final location = ref.watch(locationProvider);
  final now = DateTime.now();
  // Approximate KE year — exact value is refined after Sankranti computation
  final approxKEYear = SankrantiCalculator.kollavarshamYearApprox(now);
  // Approximate month index based on current date
  final approxMonthIndex = _approxMalayalamMonthIndex(now);
  return MonthKey(
    kollavarshamYear: approxKEYear,
    monthIndex: approxMonthIndex,
    locationCacheKey: location.cacheKey,
  );
});

/// Very rough approximation of the Malayalam month index for a given date.
/// Used only to initialise [displayedMonthKeyProvider]; the accurate value
/// comes from the computed [MalayalamMonth].
int _approxMalayalamMonthIndex(DateTime date) {
  if (date.month == 8) {
    // Before ~Aug 17 is Karkidakam (11), from Aug 17 is Chingam (0)
    return (date.day >= 17) ? 0 : 11;
  }
  const monthMap = {
    9: 1,  // Kanni
    10: 2, // Thulam
    11: 3, // Vrischikam
    12: 4, // Dhanu
    1: 5,  // Makaram
    2: 6,  // Kumbham
    3: 7,  // Meenam
    4: 8,  // Medam
    5: 9,  // Edavam
    6: 10, // Mithunam
    7: 11, // Karkidakam
  };
  return monthMap[date.month] ?? 0;
}
