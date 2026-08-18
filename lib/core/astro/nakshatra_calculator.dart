/// Nakshatra (lunar mansion) calculator.
///
/// The sidereal zodiac is divided into 27 nakshatras of exactly 13°20' each
/// (360 / 27 = 13.3333...°). The nakshatra of the day is determined by the
/// Moon's sidereal longitude at local sunrise.
library nakshatra_calculator;

/// The 27 nakshatra names in order (index 0–26).
const List<String> kNakshatraNames = [
  'അശ്വതി',         //  0 :   0°00' – 13°20'
  'ഭരണി',         //  1 :  13°20' – 26°40'
  'കാർത്തിക',        //  2 :  26°40' – 40°00'
  'രോഹിണി',          //  3 :  40°00' – 53°20'
  'മകയിരം',      //  4 :  53°20' – 66°40'
  'തിരുവാതിര',           //  5 :  66°40' – 80°00'
  'പുണർതം',       //  6 :  80°00' – 93°20'
  'പൂയം',          //  7 :  93°20' – 106°40'
  'ആയില്യം',        //  8 : 106°40' – 120°00'
  'മകം',           //  9 : 120°00' – 133°20'
  'പൂരം',  // 10 : 133°20' – 146°40'
  'ഉത്രം', // 11 : 146°40' – 160°00'
  'അത്തം',           // 12 : 160°00' – 173°20'
  'ചിത്തിര',          // 13 : 173°20' – 186°40'
  'ചോതി',           // 14 : 186°40' – 200°00'
  'വിശാഖം',        // 15 : 200°00' – 213°20'
  'അനിഴം',        // 16 : 213°20' – 226°40'
  'തൃക്കേട്ട',        // 17 : 226°40' – 240°00'
  'മൂലം',           // 18 : 240°00' – 253°20'
  'പൂരാടം',   // 19 : 253°20' – 266°40'
  'ഉത്രാടം',  // 20 : 266°40' – 280°00'
  'തിരുവോണം',        // 21 : 280°00' – 293°20'
  'അവിട്ടം',       // 22 : 293°20' – 306°40'
  'ചതയം',     // 23 : 306°40' – 320°00'
  'പൂരൂരുട്ടാതി',// 24 : 320°00' – 333°20'
  'ഉത്രട്ടാതി',//25 : 333°20' – 346°40'
  'രേവതി',          // 26 : 346°40' – 360°00'
];

/// Degrees per nakshatra (exactly 360/27).
const double kDegreesPerNakshatra = 360.0 / 27.0; // 13.3333...°

/// Returns the nakshatra index (0–26) for a given sidereal Moon longitude.
///
/// [moonSiderealLongitude] must be in degrees [0, 360).
/// Wraps automatically if slightly outside that range.
int getNakshatraIndex(double moonSiderealLongitude) {
  // Normalise to [0, 360)
  final lon = moonSiderealLongitude % 360.0;
  final normalized = lon < 0 ? lon + 360.0 : lon;
  return (normalized / kDegreesPerNakshatra).floor().clamp(0, 26);
}

/// Returns the nakshatra name for a given index (0–26).
String getNakshatraName(int index) {
  assert(index >= 0 && index <= 26, 'Nakshatra index out of range: $index');
  return kNakshatraNames[index];
}

/// Returns the nakshatra name for a given sidereal Moon longitude.
String getNakshatraNameForLongitude(double moonSiderealLongitude) {
  return getNakshatraName(getNakshatraIndex(moonSiderealLongitude));
}

/// Returns the start degree of a nakshatra (inclusive).
double getNakshatraStartDegree(int index) => index * kDegreesPerNakshatra;

/// Returns the end degree of a nakshatra (exclusive).
double getNakshatraEndDegree(int index) => (index + 1) * kDegreesPerNakshatra;

/// Describes where within a nakshatra a given longitude falls.
///
/// Returns a value in [0, 1) where 0 = nakshatra start, 1 = nakshatra end.
double getNakshatraProgress(double moonSiderealLongitude) {
  final lon = moonSiderealLongitude % 360.0;
  final normalized = lon < 0 ? lon + 360.0 : lon;
  return (normalized % kDegreesPerNakshatra) / kDegreesPerNakshatra;
}
