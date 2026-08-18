/// Data models for the Malayalam Calendar App.
library malayalam_day;

/// Represents a single day in the Malayalam (Kollavarsham) calendar.
class MalayalamDay {
  /// The Gregorian date this Malayalam day corresponds to.
  final DateTime gregorianDate;

  /// Malayalam month index (0–11): Chingam=0, Kanni=1, …, Karkidakam=11.
  final int malayalamMonthIndex;

  /// Day number within the Malayalam month (1-based).
  final int malayalamDate;

  /// Nakshatra index (0–26) of the Moon at local sunrise on this day.
  final int nakshatraIndex;

  /// True if this day's nakshatra is the same as the previous day's.
  ///
  /// Occurs when the Moon is moving slower than average (~11.8°/day)
  /// and does not cross a nakshatra boundary between two consecutive
  /// sunrises. Both days share the same "star".
  final bool spansFromPreviousDay;

  /// True if this is the SECOND of a pair of consecutive days with the same
  /// nakshatra (i.e., yesterday also had this nakshatra).
  /// This is a convenience alias that equals [spansFromPreviousDay].
  bool get isRepeatedFromYesterday => spansFromPreviousDay;

  /// True if this nakshatra appears on at least one other day in the same
  /// Malayalam month (i.e., the nakshatra cycle wrapped around).
  ///
  /// Because the Moon's sidereal cycle (~27.3 days) is shorter than a
  /// Malayalam month (~29–32 days), the same nakshatra can appear twice
  /// in one month — once early, once late. When this is true, both
  /// occurrences are flagged. [hasLaterRepeat] distinguishes which is first.
  ///
  /// Kerala tradition is genuinely split on which occurrence to use for
  /// birthday/anniversary observances — both are shown, with the second
  /// flagged as "commonly observed" (see [hasLaterRepeat]).
  final bool isRepeatOccurrence;

  /// When [isRepeatOccurrence] is true:
  /// - true  → this is the FIRST occurrence; a later occurrence exists.
  /// - false → this is the SECOND (or later) occurrence, commonly observed.
  final bool hasLaterRepeat;

  /// The UTC timestamp of local sunrise on this day (computed for the
  /// user's location). Used to anchor nakshatra and for display.
  final DateTime sunriseUtc;

  const MalayalamDay({
    required this.gregorianDate,
    required this.malayalamMonthIndex,
    required this.malayalamDate,
    required this.nakshatraIndex,
    required this.sunriseUtc,
    this.spansFromPreviousDay = false,
    this.isRepeatOccurrence = false,
    this.hasLaterRepeat = false,
  });

  /// Returns the nakshatra name for this day.
  String get nakshatraName {
    const names = [
      'അശ്വതി', 'ഭരണി', 'കാർത്തിക', 'രോഹിണി', 'മകയിരം', 'തിരുവാതിര',
      'പുണർതം', 'പൂയം', 'ആയില്യം', 'മകം', 'പൂരം',
      'ഉത്രം', 'അത്തം', 'ചിത്തിര', 'ചോതി', 'വിശാഖം', 'അനിഴം',
      'തൃക്കേട്ട', 'മൂലം', 'പൂരാടം', 'ഉത്രാടം', 'തിരുവോണം',
      'അവിട്ടം', 'ചതയം', 'പൂരൂരുട്ടാതി', 'ഉത്രട്ടാതി',
      'രേവതി',
    ];
    return names[nakshatraIndex];
  }

  MalayalamDay copyWith({
    DateTime? gregorianDate,
    int? malayalamMonthIndex,
    int? malayalamDate,
    int? nakshatraIndex,
    DateTime? sunriseUtc,
    bool? spansFromPreviousDay,
    bool? isRepeatOccurrence,
    bool? hasLaterRepeat,
  }) {
    return MalayalamDay(
      gregorianDate: gregorianDate ?? this.gregorianDate,
      malayalamMonthIndex: malayalamMonthIndex ?? this.malayalamMonthIndex,
      malayalamDate: malayalamDate ?? this.malayalamDate,
      nakshatraIndex: nakshatraIndex ?? this.nakshatraIndex,
      sunriseUtc: sunriseUtc ?? this.sunriseUtc,
      spansFromPreviousDay: spansFromPreviousDay ?? this.spansFromPreviousDay,
      isRepeatOccurrence: isRepeatOccurrence ?? this.isRepeatOccurrence,
      hasLaterRepeat: hasLaterRepeat ?? this.hasLaterRepeat,
    );
  }

  Map<String, dynamic> toJson() => {
    'gregorianDate': gregorianDate.toIso8601String(),
    'malayalamMonthIndex': malayalamMonthIndex,
    'malayalamDate': malayalamDate,
    'nakshatraIndex': nakshatraIndex,
    'sunriseUtc': sunriseUtc.toIso8601String(),
    'spansFromPreviousDay': spansFromPreviousDay,
    'isRepeatOccurrence': isRepeatOccurrence,
    'hasLaterRepeat': hasLaterRepeat,
  };

  factory MalayalamDay.fromJson(Map<String, dynamic> json) => MalayalamDay(
    gregorianDate: DateTime.parse(json['gregorianDate'] as String),
    malayalamMonthIndex: json['malayalamMonthIndex'] as int,
    malayalamDate: json['malayalamDate'] as int,
    nakshatraIndex: json['nakshatraIndex'] as int,
    sunriseUtc: DateTime.parse(json['sunriseUtc'] as String),
    spansFromPreviousDay: (json['spansFromPreviousDay'] as bool?) ?? false,
    isRepeatOccurrence: (json['isRepeatOccurrence'] as bool?) ?? false,
    hasLaterRepeat: (json['hasLaterRepeat'] as bool?) ?? false,
  );

  @override
  String toString() =>
      'MalayalamDay(${gregorianDate.toIso8601String().substring(0, 10)}, '
      'M${malayalamMonthIndex + 1}D$malayalamDate, nakshatra=$nakshatraIndex)';
}
