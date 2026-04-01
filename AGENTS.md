# AGENTS.md - AlmEly Randevu Portalı

AI agents guide for productive development in this Flutter + Firebase appointment booking platform for Turkish service providers.

## Project Overview

**almely_randevu** is a Flutter mobile app connecting users with local service providers (barbers, taxis, restaurants, etc.) for appointment booking in Trabzon, Turkey.

**Key Tech Stack:**
- Flutter (Dart) - UI & business logic
- Firebase (Firestore, Core) - Backend & authentication
- Google Maps, Geolocator, Geocoding - Location services
- Gradle (Kotlin) - Android build system

**Architecture:** Single `main.dart` file monolith with all screens and logic (currently not modularized - this is intentional for MVP phase).

---

## Critical Developer Workflows

### Building & Running
```bash
# Flutter setup check (must do first)
flutter doctor

# Clean rebuild (required after Gradle/dependencies changes)
flutter clean
flutter pub get
flutter run

# Android-specific builds
cd android
./gradlew build          # Debug APK
./gradlew assembleRelease  # Release APK
```

**Firebase Config:** App initializes with platform-specific configs:
- **Web:** Hardcoded credentials in `main()` (see lines 11-20)
- **Android/iOS:** Uses `google-services.json` (located in `android/app/`)

When credentials change, update both locations. Web init includes hardcoded `apiKey`, `projectId`, `appId` - these are not secrets for public web apps.

### Testing
```bash
# Run existing test (basic widget test)
flutter test test/widget_test.dart

# Current test coverage is minimal (only checks app startup)
# Tests must use mocked Firebase for CI/CD
```

---

## Codebase Structure & Patterns

### Single-File Architecture (`lib/main.dart`)
**Why:** MVP phase prioritizes rapid iteration over modularity. This is a deliberate trade-off.

**File contains (in order):**
1. **Entry point** (lines 8-27): Firebase init + app launch
2. **AlmElyApp** (28-40): Material theme config
3. **Screen classes** (41+): All 5 screens as StatefulWidget/StatelessWidget

**When to modularize:** Future scale should split:
- `screens/` folder (one file per screen)
- `services/` folder (Firebase, Geolocator wrappers)
- `models/` folder (data classes for Esnaf, User, Appointment)

### Navigation Pattern
- **Push-based:** Uses `Navigator.push()` for forward navigation
- **Replace:** Uses `Navigator.pushReplacement()` for login flows
- **No routing package:** Direct MaterialPageRoute calls throughout

**Example (line 68):**
```dart
Navigator.push(context, MaterialPageRoute(builder: (c) => const KullaniciGirisSayfasi()));
```

### State Management Pattern
- **StatefulWidget + Controller pattern:** TextEditingControllers for forms (see `_AdminPanelSayfasiState`, lines 155+)
- **No Provider/Riverpod:** Using direct widget state only
- **Firebase StreamBuilder:** `AnaSayfa` uses `StreamBuilder` for live Esnaf list (lines 121-138)

**Example (line 122-124):**
```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('esnaflar').where('kategori', isEqualTo: katAd).snapshots(),
  // ...
)
```

### Firebase Data Model
**Collection: `esnaflar`** (service providers)
```dart
{
  'isletmeAdi': String,          // Business name
  'kategori': String,             // One of: Kuaför, Taksi, Halı Saha, Oto Yıkama, Restoran, Düğün Salonu
  'telefon': String,
  'il': String,                   // Province (usually "Trabzon")
  'ilce': String,                 // District
  'adres': String,                // Full address
  'konum': GeoPoint(lat, lon),   // Location from GPS
  'kayitTarihi': Timestamp        // Server timestamp
}
```

### Location Integration
**Service:** Geolocator package v13.0.2 + Nominatim reverse geocoding

**Flow (AdminPanelSayfasi._konumZorla, lines 183-215):**
1. Check permission (`Geolocator.checkPermission()`)
2. Request if denied (`Geolocator.requestPermission()`)
3. Get GPS position (high accuracy)
4. Reverse-geocode via Nominatim API to extract address parts
5. Populate UI fields (il, ilce, adres)

**Key Detail:** Uses Nominatim free tier (OpenStreetMap) - Turkish address details from `address.province`, `address.district`, `address.suburb`, `address.road`, `address.house_number`.

---

## Authentication & Security Notes

### Hardcoded Credentials (DEMO ONLY)
**User login (lines 99-100):**
- Phone: `5064000963` or `05064000963`
- Password: `1234`

**Admin login (lines 326-327):**
- Username: `AlmEly`
- Password: `686596`

⚠️ **CRITICAL:** These are placeholder credentials for MVP. Replace with real auth before production:
- Implement Firebase Auth (phone or email)
- Move to secure environment variables
- Add OTP verification for phone-based login

### Firebase Access
No explicit security rules shown in codebase. **Assume Firestore rules need hardening:**
- Current setup likely allows unauthenticated read/write (debug mode)
- Production must implement role-based access control (users vs admins)

---

## Common Development Tasks

### Adding a New Service Category
1. Update hardcoded `kategoriler` list in `AnaSayfa` (line 107)
2. Update DropdownButtonFormField in `_esnafEkleFormu()` (line 263)
3. Test both screens

### Modifying Forms
- Text fields: Use `TextEditingController` (always dispose in `dispose()` method - currently missing, TODO)
- Dropdowns: Use `DropdownButtonFormField<String>` with `onChanged` callback
- Example: Admin form spans lines 220-315

### Firebase Queries
Pattern: `FirebaseFirestore.instance.collection('esnaflar').where('kategori', isEqualTo: value).snapshots()`

- For listening: Use `StreamBuilder`
- For one-time read: Use `.get()` instead of `.snapshots()`
- For write: Use `.add()`, `.set()`, or `.update()`

### Styling
- **Material 3:** Theme uses `ColorScheme.fromSeed()` with blue seed (line 38)
- **No custom design system:** Inline colors throughout (Colors.blue, Colors.orange, etc.)
- **Responsive:** Uses `MediaQuery` for bottom sheet sizing (line 111)

---

## Project-Specific Gotchas

1. **Single main.dart:** All code in one file. Search by class name or line numbers when navigating.
2. **No model classes:** Data is raw Maps from Firestore - no type safety.
3. **Missing dispose():** TextEditingControllers in `_AdminPanelSayfasiState` never call `dispose()` - will cause memory leaks on state rebuild.
4. **Turkish text throughout:** Comments, error messages, UI labels all in Turkish - maintain consistency.
5. **Nominatim rate limiting:** Reverse geocoding calls may hit rate limits if called rapidly - add debouncing for production.
6. **Firebase initialization context:** Must call `WidgetsFlutterBinding.ensureInitialized()` before Firebase.initializeApp() (line 10).

---

## Build Configuration

### Android Build
- **Namespace:** `com.example.almely_randevu`
- **Min SDK:** flutter.minSdkVersion (typically 21+)
- **Target SDK:** flutter.targetSdkVersion (typically 34+)
- **Kotlin JVM:** 17
- **Plugins:** `com.google.gms.google-services` required for Firebase

**File:** `android/app/build.gradle.kts` (lines 1-10 critical for Firebase)

### Root Dependencies
- **Flutter Gradle Plugin:** `dev.flutter.flutter-gradle-plugin`
- **Google Services:** `com.google.gms.google-services`
- **Kotlin:** `org.jetbrains.kotlin.android`

---

## Lint & Analysis

**Flutter lints enabled** via `analysis_options.yaml` (includes flutter_lints v5.0.0 rules).

Run analysis: `flutter analyze`

Current project likely has warnings on:
- Unused `dispose()` methods
- Dead code (hardcoded test credentials)
- Unhandled edge cases in location services

---

## Git & Versioning

- **Version:** 1.0.0+1 (pubspec.yaml)
- **Dart SDK:** >=3.2.3 <4.0.0
- **Publishing:** set to 'none' (internal app)

---

## Quick Reference: Key Files

| File | Purpose | Key Line Numbers |
|------|---------|------------------|
| `lib/main.dart` | All code | See structure above |
| `pubspec.yaml` | Dependencies + metadata | 1-29 |
| `android/app/build.gradle.kts` | Android build config | 1-43+ |
| `analysis_options.yaml` | Linting rules | All |
| `test/widget_test.dart` | Basic startup test | All |

---

## When Adding Features

1. **New Screen?** Add class to `main.dart`, update navigation in existing screens
2. **New Collection?** Plan Firestore schema, update queries, consider security rules
3. **Location Feature?** Leverage existing Geolocator + Nominatim pattern - add caching to reduce API calls
4. **User Authentication?** Replace hardcoded credentials with Firebase Auth (phone/email)
5. **Data Models?** Create Dart classes with `.fromMap()` / `.toMap()` - start in `main.dart`, move to separate files later

---

*This guide reflects project state as of latest commit. Update when architecture changes.*

