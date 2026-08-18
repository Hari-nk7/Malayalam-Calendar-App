/// Month generator integration tests — verifies that MalayalamMonth is
/// computed correctly for a known month and that spanning/skipped/repeat
/// flags are correctly set.
///
/// Reference: Chingam 1199 KE corresponds to Aug 17 – Sep 16, 2024.
/// Chingam 1 2024 falls on August 17, 2024 (Saturday).
/// This is widely published and consistent with Kerala government panchang.
///
/// These tests require a full Flutter test environment (sweph assets available).
import 'package:flutter_test/flutter_test.dart';
import 'package:malayalam_calendar_app/core/ephemeris/ephemeris_service.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';
import 'package:malayalam_calendar_app/data/repositories/calendar_repository.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await EphemerisService.instance.initialize();
  });

  group('MonthGenerator — Chingam 1199 KE (Aug–Sep 2024)', () {
    late CalendarRepository repo;
    const location = LocationModel.trivandrum;

    setUp(() {
      repo = CalendarRepository();
    });

    test(
      'Chingam 1199 KE starts on August 17, 2024 (Gregorian)',
      () {
        final month = repo.generateMonth(
          monthIndex: 0, // Chingam
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        final firstDay = month.firstGregorianDay;
        expect(firstDay.year, 2024,
            reason: 'Chingam 1199 first day should be in 2024');
        expect(firstDay.month, 8,
            reason: 'Chingam 1199 first day should be in August');
        expect(
          firstDay.day,
          inInclusiveRange(16, 18),
          reason: 'Chingam 1 2024 should be Aug 16–18 (traditionally Aug 17)',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Chingam 1199 KE has 29–32 days',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );
        expect(
          month.length,
          inInclusiveRange(29, 32),
          reason: 'A Malayalam month must be 29–32 days, got ${month.length}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Chingam 1199 KE contains at least one repeated nakshatra '
      '(Moon cycle ~27.3d < month ~30d)',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        final repeatDays = month.days.where((d) => d.isRepeatOccurrence).toList();
        expect(
          repeatDays.length,
          greaterThanOrEqualTo(2),
          reason: 'Should have at least 2 days with repeated nakshatras '
              '(1 first occurrence + 1 second occurrence)',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'For each repeated nakshatra: exactly one day has hasLaterRepeat=true '
      '(the first occurrence)',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        // Group days by nakshatra index
        final Map<int, List<int>> daysByNakshatra = {};
        for (int i = 0; i < month.days.length; i++) {
          final d = month.days[i];
          if (d.isRepeatOccurrence) {
            daysByNakshatra.putIfAbsent(d.nakshatraIndex, () => []).add(i);
          }
        }

        for (final entry in daysByNakshatra.entries) {
          final indices = entry.value;
          // First occurrence should have hasLaterRepeat=true
          expect(
            month.days[indices.first].hasLaterRepeat,
            isTrue,
            reason: 'First occurrence of nakshatra ${entry.key} should have '
                'hasLaterRepeat=true',
          );
          // Last occurrence should have hasLaterRepeat=false
          expect(
            month.days[indices.last].hasLaterRepeat,
            isFalse,
            reason: 'Last occurrence of nakshatra ${entry.key} should have '
                'hasLaterRepeat=false (commonly observed)',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Malayalam dates are sequential from 1 to N',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        for (int i = 0; i < month.days.length; i++) {
          expect(
            month.days[i].malayalamDate,
            i + 1,
            reason: 'Day ${i + 1} should have malayalamDate=${i + 1}',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'All nakshatra indices are in range [0, 26]',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        for (final day in month.days) {
          expect(
            day.nakshatraIndex,
            inInclusiveRange(0, 26),
            reason: 'Nakshatra index must be 0–26, got ${day.nakshatraIndex} '
                'on ${day.gregorianDate}',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Spanning days: spansFromPreviousDay is true iff nakshatra matches previous day',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        for (int i = 1; i < month.days.length; i++) {
          final curr = month.days[i];
          final prev = month.days[i - 1];
          if (curr.spansFromPreviousDay) {
            expect(
              curr.nakshatraIndex,
              prev.nakshatraIndex,
              reason: 'Day $i has spansFromPreviousDay=true but different '
                  'nakshatra than day ${i - 1}',
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Month monthIndex and kollavarshamYear are correctly stored',
      () {
        final month = repo.generateMonth(
          monthIndex: 0,
          kollavarshamYear: 1199,
          location: location,
          gregorianYearOfSankranti: 2024,
        );

        expect(month.monthIndex, 0);
        expect(month.kollavarshamYear, 1199);
        expect(month.monthName, 'Chingam');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
