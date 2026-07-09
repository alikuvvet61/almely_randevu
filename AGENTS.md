# AGENTS.md - AlmEly Randevu Portalı

AI agents guide for productive development in this Flutter + Firebase appointment booking platform for Turkish service providers.

## Project Overview

**almely_randevu** is a Flutter mobile app connecting users with local service providers (barbers, taxis, restaurants, etc.) for appointment booking in Trabzon, Turkey.

**Key Tech Stack:**
- Flutter (Dart) - UI & business logic
- Firebase (Firestore, Core, Storage, Auth, Remote Config) - Backend, Auth, File storage, and dynamic config
- OneSignal - Professional push notifications with phone-based tagging
- Google Maps, Geolocator, Geocoding - Location services
- firebase_local_notifications - Local notification scheduling
- image_picker, url_launcher - External integrations (photo uploads, WhatsApp links)
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

### UI Patterns
- **ModalBottomSheet**: Extensively used for in-place selections (categories, time slots, appointment options).
- **Image Picker Integration**: `image_picker` package for photo uploads in profile/business settings.
- **URL Launcher**: Used for WhatsApp integration (`url_launcher.launch()` with `whatsapp://` scheme).
- **Error Recovery:** StatefulWidget screens use `mounted` checks before `setState` calls to prevent errors during navigation or disposal.

### Firebase Data Model
**Collections:**
- **`esnaflar`** - Service providers (barbers, taxis, restaurants, etc.)
- **`randevular`** - Appointment bookings
- **`kategoriler`** - Service categories
- **`hizmet_tanimlari`** - Service definitions (duration, pricing)
- **`yorumlar`** - Customer reviews

**Primary Collection: `esnaflar`**
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
- **Retry Pattern:** OneSignal registration includes exponential backoff retry logic (see lines 89-96 in onesignal_servisi.dart) to handle network failures.

### Core Services
- **`FirestoreServisi`**: CRUD operations for all Firestore collections. Uses transaction-based operations for atomicity (e.g., atomic appointment approval with provider slot update).
- **`BildirimServisi`**: Smart notification orchestration, especially for rental ("kiralama") extensions and delays.
- **`KimlikDogrulamaServisi`**: Firebase phone authentication with SMS verification codes.
- **`VersiyonServisi`**: Firebase Remote Config management for server-side feature flags and configuration.
- **`KonumServisi`**: Location retrieval (Geolocator) and reverse geocoding (Nominatim) for address population.

---

## Error Handling & Debugging

### Error Patterns
- **Try-Catch Blocks**: All Firebase and service operations wrap calls in try-catch with `debugPrint` logging for visibility.
- **FirebaseException Handling**: Specifically catch and log Firebase exceptions to identify auth, network, or permission issues.
- **Mounted Checks**: StatefulWidget lifecycle protection—always check `if (mounted)` before calling `setState()` after async operations.
- **OneSignal Initialization Errors**: Wrapped in try-catch with error isolation to prevent OneSignal failures from crashing app initialization (see `main.dart` lines 30-50).

### Debugging
- Enable `debugPrint()` statements throughout services (filtered by tag when needed).
- Firebase Emulator: Not currently active, but uses real Firestore with `google-services.json` from Android configuration.
- Local Notifications: Test via `flutter_local_notifications` with platform-specific debugging (Android logcat for kernel logs).

## Common Development Tasks

### Adding a New Setting
1. Update `EsnafModeli` (model, fromMap, toMap, copyWith).
2. Add the UI control in `EsnafParametreEkrani.dart`.
3. If it affects scheduling, update the logic in `RandevuEkrani.dart` or `EsnafAjandaEkrani.dart`.

### Creating a New Service
1. Create file in `lib/servisler/` following naming pattern: `{konu}_servisi.dart`.
2. Use dependency injection: pass required services (e.g., FirestoreServisi, OneSignalServisi) to constructor.
3. Wrap all external API calls in try-catch with descriptive `debugPrint` logging.
4. Expose public async methods that services depend on (e.g., `Future<void> initialize()`).

### Location Integration
**Service:** `lib/servisler/konum_servisi.dart`
Uses Geolocator + Nominatim for reverse geocoding to populate address fields. Handle permission requests gracefully.

### Admin & Review Features
- **Admin Panel:** `AdminEkrani` manages provider approvals, category editing, and system-wide settings.
- **Review System:** `yorumlar` collection stores customer reviews linked to providers and appointments. `RandevuEkrani` triggers review prompts post-appointment.

---

## Project-Specific Gotchas

1. **Turkish Language:** UI and logs are primarily in Turkish. Variable names, Firestore field names, and error messages follow Turkish naming conventions.
2. **OneSignal Tagging:** Always use `OneSignalServisi.kullaniciyiKaydet` when a user/provider logs in to ensure they receive scheduled alerts. Includes phone number as unique tag.
3. **OneSignal Retry Logic:** Registration includes exponential backoff (up to 3 retries with 1000ms delays) to handle network transients.
4. **Calendar Logic:** `RandevuEkrani` handles both "Araç Kiralama" (date range, multi-day) and standard service-based (hourly slots) appointment flows.
5. **Firestore Transactions:** Use atomic transactions for operations affecting multiple documents (e.g., approving an appointment updates both `randevular` and provider's `esnaflar` slot availability).
6. **Environment Variables:** Ensure `.env` contains `ONESIGNAL_REST_API_KEY` for scheduled notification REST API calls. Load via `flutter_dotenv` in `main.dart`.
7. **Web Support:** Notification listener (`BildirimDinle`) works on mobile but has limitations on web; test platform-specific behavior accordingly.

