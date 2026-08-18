/// Hive-based cache for pre-computed MalayalamMonth data.
///
/// Cache key format: "$kollavarshamYear-$monthIndex-$locationCacheKey"
/// e.g. "1200-0-9.9,76.3"  (Chingam 1200 KE, Trivandrum)
///
/// Cache is invalidated when:
///   1. Location changes by > 10 km (different cache key at 0.1° resolution)
///   2. Manual cache clear by user
///
/// Months are stored as JSON strings in a Hive box named 'calendar_cache'.
library cache_repository;

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';

class CacheRepository {
  static const _boxName = 'calendar_cache_v2';
  static const _maxCachedMonths = 24; // Keep up to 24 months in cache

  late Box<String> _box;
  bool _isOpen = false;

  /// Initialize the Hive box. Must be called before any other method.
  Future<void> initialize() async {
    if (_isOpen) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _isOpen = true;
  }

  /// Returns a cached [MalayalamMonth] if available, or null.
  MalayalamMonth? getCachedMonth({
    required int kollavarshamYear,
    required int monthIndex,
    required String locationCacheKey,
  }) {
    _assertOpen();
    final key = _makeKey(kollavarshamYear, monthIndex, locationCacheKey);
    final json = _box.get(key);
    if (json == null) return null;
    try {
      return MalayalamMonth.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted cache entry — remove it
      _box.delete(key);
      return null;
    }
  }

  /// Stores a [MalayalamMonth] in the cache.
  Future<void> cacheMonth(MalayalamMonth month) async {
    _assertOpen();
    final key = _makeKey(
      month.kollavarshamYear,
      month.monthIndex,
      month.locationKey,
    );
    await _box.put(key, jsonEncode(month.toJson()));
    await _evictOldEntriesIfNeeded();
  }

  /// Clears all cached month data.
  Future<void> clearAll() async {
    _assertOpen();
    await _box.clear();
  }

  /// Removes cached entries for a specific location (e.g., after location change).
  Future<void> clearForLocation(String locationCacheKey) async {
    _assertOpen();
    final keysToDelete = _box.keys
        .whereType<String>()
        .where((k) => k.endsWith('-$locationCacheKey'))
        .toList();
    for (final k in keysToDelete) {
      await _box.delete(k);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _makeKey(int year, int monthIndex, String locationKey) =>
      '$year-$monthIndex-$locationKey';

  void _assertOpen() {
    if (!_isOpen) {
      throw StateError('CacheRepository.initialize() must be awaited before use.');
    }
  }

  /// Evict oldest entries if we exceed [_maxCachedMonths].
  Future<void> _evictOldEntriesIfNeeded() async {
    if (_box.length <= _maxCachedMonths) return;
    // Simple FIFO eviction: delete entries until we're at limit.
    final keys = _box.keys.toList();
    final toDelete = keys.take(_box.length - _maxCachedMonths).toList();
    for (final k in toDelete) {
      await _box.delete(k);
    }
  }
}
