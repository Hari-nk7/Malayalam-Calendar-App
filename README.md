# Malayalam Calendar — Nithya Panchangam

A completely offline, high-precision Malayalam (Kollavarsham) calendar and Panchangam for Android and iOS, built with Flutter. No internet connection required. No ads. No tracking. No cloud dependencies.

---

## What this is

Most digital calendar apps for Kerala either rely on remote API calls (leaving you stranded offline) or use rigid, pre-generated lookup tables that quickly become inaccurate or fail beyond a few years.

This app calculates all astronomical data from first principles on-device using the **Swiss Ephemeris** (via native C/FFI bindings) — the gold standard used by observatories and professional astrologers worldwide. 

Designed like a traditional physical Malayalam wall calendar, it provides a seamless dual-perspective experience: navigate in standard Gregorian months with embedded Malayalam dates and nakshatras, or switch to pure Kollavarsham mode.

---

## Key Features

### 📅 Dual-Perspective Calendar Views
- **Gregorian Primary View:** Standard physical wall calendar layout (January–December). Displays Gregorian dates prominently, with the corresponding Malayalam month, date, and Nakshatra embedded in each cell.
- **Malayalam Month Visual Transitions:** Subtle per-month color gradients clearly demarcate the transition where one Malayalam month ends and the next begins (e.g., Karkidakam transitioning into Chingam in mid-August).
- **Malayalam Primary View:** Pure Kollavarsham navigation (*Chingam, Kanni, Thulam...* with accurate Kollavarsham era years, e.g., `1202 KE`). Large traditional dates with secondary Gregorian references.
- **Instant Bi-Directional Synchronization:** Toggling between Gregorian and Malayalam modes automatically jumps to the corresponding month in the alternate calendar system.

### 🪐 Astronomical Precision
- **Lahiri Ayanamsa (Chitra Paksha):** Standard sidereal calculation aligned with the Indian Astronomical Ephemeris.
- **Kerala Aparahna Rule:** Precise allocation of month-start day based on whether the Sun's Sankranti occurs before or after the traditional Aparahna threshold.
- **Nakshatra Dynamics:** Correctly handles **spanning nakshatras** (same star spanning two consecutive sunrises) and **skipped nakshatras** (Moon moving through a star entirely between sunrises).
- **Location-Specific Sunrise Times:** Computed using high-accuracy solar positioning algorithms based on your GPS coordinates or selected city.

### 🔍 Deep Astronomical Day Details
- Tap any date cell to open a comprehensive breakdown:
  - Exact Malayalam date and Kollavarsham year
  - Sunrise time for your exact latitude and longitude
  - Nakshatra active at sunrise, along with entry/exit timestamps
  - Sun's sidereal longitude and active Rashi
  - Clear explanations for repeat/spanning and skipped nakshatras

### ⚡ Offline-First Architecture
- **Zero Network Calls:** Everything is computed on your device.
- **Instant Month Caching:** Computed months are cached locally in Hive boxes; once calculated, they load instantly.
- **Built-in Offline Geodatabase:** Search and select Indian and diaspora cities without requiring active internet access.

---

## The Astronomy Behind the Calendar

1. **Sankranti (Month Boundaries):**
   Kollavarsham months begin when the Sun enters a new sidereal zodiac sign (Rashi boundaries at every 30° multiple, starting from Chingam at 120° Simha). The app performs a binary search on the Sun's sidereal position to pinpoint the Sankranti to sub-second precision.

2. **Aparahna Allocation:**
   Under traditional Kerala calendar rules, the start date of a Malayalam month depends on whether the Sankranti occurs during the *Aparahna* period (approx. 3/5ths into the day from sunrise to sunset). The app computes local sunrise and sunset to apply this rule accurately.

3. **Sunrise Nakshatras:**
   The primary star assigned to each day is the Nakshatra occupied by the Moon at local sunrise. The app calculates the Moon's longitude relative to the 27 equal 13°20' lunar divisions.

---

## Tech Stack

| Component | Technology | Purpose |
|---|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.5+) | Cross-platform UI for Android and iOS |
| **Astro Engine** | [`sweph`](https://pub.dev/packages/sweph) | Native FFI bindings to Swiss Ephemeris (C library) |
| **State Management** | [Riverpod](https://riverpod.dev) | Reactive state graph, async family providers, and view sync |
| **Persistence** | [Hive](https://pub.dev/packages/hive) | Lightweight, ultra-fast NoSQL box storage for cached months |
| **Location** | [Geolocator](https://pub.dev/packages/geolocator) | GPS coordinate resolution for local sunrise calculations |
| **Typography** | Google Fonts (`Noto Serif Malayalam`, `Inter`) | Malayalam script and numeral rendering |

---

## Project Structure

```
lib/
├── core/
│   ├── astro/              # Sankranti & Nakshatra calculation engines
│   └── ephemeris/          # Swiss Ephemeris lifecycle and FFI wrapper
├── data/
│   ├── models/             # MalayalamDay, MalayalamMonth, LocationModel
│   └── repositories/       # Calendar, Hive Cache, and Location repositories
├── providers/              # Riverpod state providers and month resolvers
└── ui/
    ├── calendar_grid/      # Dual-view calendar screens, grids, and view toggles
    ├── day_detail/         # Detailed astronomical bottom sheet
    ├── settings/           # Location preferences and GPS settings
    └── theme/              # Color palette, dark cosmic gradients, and typography
```

---

## Building and Running

### Prerequisites
- Flutter SDK `^3.24.0`
- Java 17 (recommended for Gradle builds)
- Android SDK (API 21+) / Xcode for iOS

### Setup Instructions

```bash
# Clone the repository
git clone <repo-url>
cd "Malayalam Calendar App"

# Ensure Flutter uses Java 17 (if multiple JDKs exist on macOS)
flutter config --jdk-dir="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Building Release APK
```bash
flutter build apk --release
```

---

## Astronomical Scope & Notes

- **Ephemeris Range:** The bundled Swiss Ephemeris data files support dates from **1800 to 2400 CE**.
- **Ayanamsa:** Configured to **Lahiri (Chitra Paksha)**, the standard adopted by the Government of India Calendar Reform Committee and most Kerala panchangam publishers.
- **Polar Regions:** For extreme latitudes where the sun does not rise or set, calculations fallback gracefully to 06:00 local solar mean time.

---

## License

- The application source code is licensed under the **MIT License**.
- The underlying Swiss Ephemeris library is licensed under **GNU AGPL-3.0**.
