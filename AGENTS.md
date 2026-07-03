# AGENTS.md - AlmEly Randevu Portalı

AI agents guide for productive development in this Flutter + Firebase appointment booking platform for Turkish service providers.

## Project Overview

**almely_randevu** is a Flutter mobile app connecting users with local service providers (barbers, taxis, restaurants, etc.) for appointment booking in Trabzon, Turkey.

**Key Tech Stack:**
- Flutter (Dart) - UI & business logic
- Firebase (Firestore, Core, Storage) - Backend, Auth, and File storage
- OneSignal - Professional notification management
- Google Maps, Geolocator, Geocoding - Location services
- Gradle (Kotlin) - Android build system

**Architecture:** The project follows a modular structure for better maintainability and scale:
- `lib/ekranlar/`: UI Screens (Admin, Esnaf Panel, User screens, etc.)
- `lib/modeller/`: Data models (Esnaf, Randevu)
- `lib/servisler/`: Business logic and external API wrappers (Firestore, OneSignal, Location)
- `lib/widgets/`: Reusable UI components
- `lib/yardimcilar/`: Helper functions and utilities

---

## Critical Developer Workflows

### Building & Running
```bash
# Flutter setup check
flutter doctor

# Clean rebuild
flutter clean
flutter pub get
flutter run
```

**Firebase Config:** 
- Uses `google-services.json` (located in `android/app/`) for mobile.
- `lib/firebase_options.dart` contains platform-specific configurations.
- API keys for OneSignal and other services are managed via `.env` file (loaded in `main.dart`).

### Testing
```bash
# Run existing test
flutter test test/widget_test.dart
```

---

## Codebase Structure & Patterns

### State Management
- **StatefulWidget + Controller pattern:** Standard for forms and local state.
- **ValueNotifier:** Extensively used in `RandevuEkrani` for reactive UI updates without full `setState`.
- **Firebase StreamBuilder/FutureBuilder:** Used for real-time data sync across the app.

### Navigation
- Uses a global `navigatorKey` (defined in `main.dart`) for navigation from services.
- Standard `Navigator.push()` and `Navigator.pushReplacement()` flows.

### Firebase Data Model
**Collection: `esnaflar`**
```dart
{
  'isletmeAdi': String,
  'kategori': String,
  'randevuOnayModu': 'Otomatik' | 'Manuel',
  'ajandayiKendimAyarlayacagim': bool, // Manual calendar vs Dynamic structure
  'maksimumRandevuGunu': int,           // How many days ahead customers can book
  'minimumRandevuSuresi': int,          // Minimum booking duration in minutes
  'bakimTemizlikSuresi': int,           // Buffer time after rentals (minutes)
  'akilliTakipModu': bool,               // Smart notifications for kiralama
  // ... other fields
}
```

### Notification System (OneSignal)
- **Service:** `lib/servisler/onesignal_servisi.dart`
- **Logic:** Users are tagged with their phone number (`telefon`) for targeted delivery.
- **Smart Tracking:** For "Araç Kiralama", notifications are scheduled via REST API for both customer (extension reminder) and provider (delay alert).
- **Sync Logic:** `BildirimServisi.syncAkilliTakipBildirimleri` ensures scheduled notifications are restored if they were missed or not planned during the initial booking (e.g., due to network issues).

---

## Common Development Tasks

### Adding a New Setting
1. Update `EsnafModeli` (model, fromMap, toMap, copyWith).
2. Add the UI control in `EsnafParametreEkrani.dart`.
3. If it affects scheduling, update the logic in `RandevuEkrani.dart` or `EsnafAjandaEkrani.dart`.

### Location Integration
**Service:** `lib/servisler/konum_servisi.dart`
Uses Geolocator + Nominatim for reverse geocoding to populate address fields.

---

## Project-Specific Gotchas

1. **Turkish Language:** UI and logs are primarily in Turkish.
2. **OneSignal Tagging:** Always use `OneSignalServisi.kullaniciyiKaydet` when a user/provider logs in to ensure they receive scheduled alerts.
3. **Calendar Logic:** `RandevuEkrani` handles both "Araç Kiralama" (date range) and standard (service-based) flows.
4. **Environment Variables:** Ensure `.env` contains `ONESIGNAL_REST_API_KEY`.

