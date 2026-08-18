/// MalayalamMonth model — a fully computed month in the Kollavarsham calendar.
library malayalam_month;

import 'malayalam_day.dart';

/// The 12 Malayalam month names in order (index 0–11).
/// Year starts at Chingam (Sun enters sidereal Simha/Leo = 120°).
const List<String> kMalayalamMonthNames = [
  'ചിങ്ങം',    // 0 — Sun in Simha    (120°–150°)
  'കന്നി',      // 1 — Sun in Kanya    (150°–180°)
  'തുലാം',     // 2 — Sun in Tula     (180°–210°)
  'വൃശ്ചികം', // 3 — Sun in Vrischika(210°–240°)
  'ധനു',      // 4 — Sun in Dhanu    (240°–270°)
  'മകരം',    // 5 — Sun in Makara   (270°–300°)
  'കുംഭം',    // 6 — Sun in Kumbha   (300°–330°)
  'മീനം',     // 7 — Sun in Meena    (330°–360°)
  'മേടം',      // 8 — Sun in Mesha    (  0°– 30°)
  'ഇടവം',     // 9 — Sun in Vrishabha( 30°– 60°)
  'മിഥുനം',   //10 — Sun in Mithuna  ( 60°– 90°)
  'കർക്കിടകം', //11 — Sun in Karka    ( 90°–120°)
];

/// Sidereal Sun longitude at the START of each Malayalam month.
/// Index corresponds to month index in [kMalayalamMonthNames].
/// Chingam (index 0) starts when Sun reaches 120° sidereal.
const List<double> kSankrantiLongitudes = [
  120.0, // Chingam  (Simha)
  150.0, // Kanni    (Kanya)
  180.0, // Thulam   (Tula)
  210.0, // Vrischikam(Vrischika)
  240.0, // Dhanu    (Dhanu)
  270.0, // Makaram  (Makara)
  300.0, // Kumbham  (Kumbha)
  330.0, // Meenam   (Meena)
    0.0, // Medam    (Mesha)
   30.0, // Edavam   (Vrishabha)
   60.0, // Mithunam (Mithuna)
   90.0, // Karkidakam(Karka)
];

/// A fully computed Malayalam calendar month.
class MalayalamMonth {
  /// Kollavarsham year number (Gregorian year − 825, adjusted at Chingam
  /// Sankranti each year).
  final int kollavarshamYear;

  /// Month index (0=Chingam … 11=Karkidakam).
  final int monthIndex;

  /// All days in this month, in chronological order.
  final List<MalayalamDay> days;

  /// Nakshatra indices that were entered AND exited by the Moon between
  /// two consecutive sunrises — they never "own" a sunrise this month.
  final List<int> skippedNakshatras;

  /// UTC timestamp when this month data was computed (for cache validity).
  final DateTime generatedAt;

  /// Location key used to generate this month (lat rounded to 0.1°, lon to 0.1°).
  /// Cache is invalidated if location changes beyond this granularity.
  final String locationKey;

  const MalayalamMonth({
    required this.kollavarshamYear,
    required this.monthIndex,
    required this.days,
    required this.skippedNakshatras,
    required this.generatedAt,
    required this.locationKey,
  });

  /// Month name from [kMalayalamMonthNames].
  String get monthName => kMalayalamMonthNames[monthIndex];

  /// Number of days in this month.
  int get length => days.length;

  /// Gregorian date of the first day of this month.
  DateTime get firstGregorianDay => days.first.gregorianDate;

  /// Gregorian date of the last day of this month.
  DateTime get lastGregorianDay => days.last.gregorianDate;

  Map<String, dynamic> toJson() => {
    'kollavarshamYear': kollavarshamYear,
    'monthIndex': monthIndex,
    'days': days.map((d) => d.toJson()).toList(),
    'skippedNakshatras': skippedNakshatras,
    'generatedAt': generatedAt.toIso8601String(),
    'locationKey': locationKey,
  };

  factory MalayalamMonth.fromJson(Map<String, dynamic> json) {
    return MalayalamMonth(
      kollavarshamYear: json['kollavarshamYear'] as int,
      monthIndex: json['monthIndex'] as int,
      days: (json['days'] as List)
          .map((d) => MalayalamDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      skippedNakshatras: List<int>.from(json['skippedNakshatras'] as List),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      locationKey: json['locationKey'] as String,
    );
  }

  @override
  String toString() =>
      'MalayalamMonth($monthName $kollavarshamYear KE, ${days.length} days)';
}
