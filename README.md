# Malayalam Calendar — Nithya Panchangam

A completely offline Malayalam (Kollavarsham) calendar for Android, built with Flutter. No internet connection needed. No ads. No backend.

---

## What this is

If you have ever tried to find a reliable digital Malayalam panchang that actually gets the nakshatras right — you know how frustrating it gets. Most apps either pull from an online API (which means they break when you need them most) or they use hardcoded lookup tables that are wrong past 2030.

This app calculates everything from first principles using the **Swiss Ephemeris**, the same astronomical engine used by professional astrologers and observatories. The Sun's exact sidereal longitude determines every month boundary (Sankranti), and the Moon's position at local sunrise determines each day's nakshatra — all computed for your specific location.

---

## What it does

- Displays the complete Malayalam Kollavarsham calendar month by month
- Computes nakshatras (27 stars) using the **Lahiri ayanamsa** — the Indian government standard
- Applies the **Kerala Aparahna rule** for correct Sankranti day assignment
- Correctly handles **spanning nakshatras** (same star across two sunrises) and **skipped nakshatras** (Moon moves faster than one star per day)
- Sunrise times calculated from your GPS coordinates using a proper solar position algorithm
- Works entirely offline — no API calls, no cloud sync
- Swipe left/right to navigate months; tap any day for detailed information

---

## The astronomy

Kollavarsham months begin at Sankrantis — the exact moment the Sun's sidereal longitude crosses a multiple of 30°. The app binary-searches for this moment to within one second accuracy.

The nakshatra for each day is the one the Moon occupies at local sunrise. Since the Moon moves about 13° per day (roughly one nakshatra width), it occasionally stays in the same nakshatra for two consecutive sunrises (repeat/span) or skips one entirely (skip).

Everything is computed in **Sidereal coordinates with Lahiri ayanamsa** — not tropical.

---

## Tech stack

| What | Why |
|---|---|
| Flutter | Cross-platform, single codebase for Android and iOS |
| [sweph](https://pub.dev/packages/sweph) | Dart FFI bindings for the Swiss Ephemeris (AGPL-3.0) |
| Riverpod | State management and async data fetching |
| Hive | Offline-first month caching — computed once, read instantly |
| Geolocator | GPS coordinates for sunrise and Aparahna calculation |
| Google Fonts (Noto Serif Malayalam) | Proper Malayalam script rendering |

---

## Running locally

You need Flutter 3.24+ and Java 17.

```bash
git clone <repo>
cd "Malayalam Calendar App"

# Point Flutter at Java 17 (required for Gradle)
flutter config --jdk-dir="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"

flutter pub get
flutter run
```

For Android, Android SDK is required. For iOS, Xcode is required.

---

## Project structure

```
lib/
├── core/
│   ├── astro/              # Nakshatra and Sankranti calculators
│   └── ephemeris/          # Swiss Ephemeris service wrapper
├── data/
│   ├── models/             # MalayalamDay, MalayalamMonth, LocationModel
│   └── repositories/       # Calendar, Cache, and Location repos
├── providers/              # Riverpod providers
└── ui/
    ├── calendar_grid/      # Main calendar screen
    ├── day_detail/         # Bottom sheet with full day info
    ├── settings/           # Location and preferences
    └── theme/              # App colours and typography
```

---

## Known limitations

- **Date range:** Swiss Ephemeris data bundled covers 1800–2400 CE. Dates outside this range will not compute.
- **Polar regions:** Sunrise may not exist. The app falls back to 6:00 AM local time in that case.
- **Ayanamsa:** Hardcoded to Lahiri (Chitra Paksha). Other ayanamsas (Raman, Krishnamurti) are not supported.

---

## License

Source code is MIT. The Swiss Ephemeris library (`sweph`) is AGPL-3.0 — if you distribute a modified version of this app, the source must remain open.
