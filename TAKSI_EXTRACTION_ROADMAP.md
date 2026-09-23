# Taksi Module Extraction - Detailed Roadmap

## Overview

This document provides a step-by-step roadmap for extracting the Taksi (Taxi) module as a standalone feature module.

---

## Current State Architecture

```
almely_randevu/
├─ lib/
│  ├─ main.dart
│  ├─ firebase_options.dart
│  │
│  ├─ modeller/              [SHARED - NOT TAKSI-SPECIFIC]
│  │  ├─ esnaf_modeli.dart           (EsnafModeli - used by ALL)
│  │  ├─ randevu_modeli.dart         (RandevuModeli - used by ALL)
│  │  └─ taksi/
│  │     └─ taksi_talep_modeli.dart  (TaksiTalepModeli - TAKSI ONLY)
│  │
│  ├─ servisler/             [SHARED - NOT TAKSI-SPECIFIC]
│  │  ├─ firestore_servisi.dart      (SHARED)
│  │  ├─ bildirim_servisi.dart       (SHARED)
│  │  ├─ konum_servisi.dart          (SHARED)
│  │  ├─ onesignal_servisi.dart      (SHARED)
│  │  ├─ versiyon_servisi.dart       (SHARED)
│  │  ├─ storage_servisi.dart        (SHARED)
│  │  ├─ kimlik_dogrulama_servisi.dart (SHARED)
│  │  └─ taksi/
│  │     ├─ taksi_servisi.dart       (TAKSI ONLY)
│  │     └─ taksi_bildirim_servisi.dart (TAKSI ONLY)
│  │
│  ├─ widgets/               [SHARED - NOT TAKSI-SPECIFIC]
│  │  ├─ ana_buton.dart              (SHARED)
│  │  ├─ sos_butonu.dart             (SHARED)
│  │  └─ medya_goruntuleyici.dart    (SHARED)
│  │
│  ├─ yardimcilar/           [SHARED - NOT TAKSI-SPECIFIC]
│  │  ├─ resim_araclari.dart         (SHARED)
│  │  └─ taksi/
│  │     ├─ taksi_kilavuzu.dart      (TAKSI ONLY)
│  │     └─ taksi_kurallari.dart     (TAKSI ONLY)
│  │
│  └─ ekranlar/
│     ├─ [Core screens - used by ALL categories]
│     │  ├─ ana_ekran.dart           (imports taksi_yonlendirme)
│     │  ├─ giris_secim_ekrani.dart  (imports taksi_mod_secim_ekrani)
│     │  ├─ esnaf_paneli.dart        (conditional taksi imports)
│     │  ├─ esnaf_ajanda_ekrani.dart (conditional taksi imports)
│     │  ├─ esnaf_detay_ekrani.dart  (imports taksi_yonlendirme)
│     │  ├─ randevu_ekrani.dart      (52+ kategori checks)
│     │  ├─ esnaf_parametre_ekrani.dart (2 kategori checks)
│     │  └─ ... other non-taksi screens
│     │
│     └─ taksi/ [TAKSI MODULE - EXTRACTION TARGET]
│        ├─ taksi_ana_ekrani.dart
│        ├─ taksi_bildirim_ekrani.dart
│        ├─ taksi_mod_secim_ekrani.dart
│        ├─ taksi_musteri_ekrani.dart
│        ├─ taksi_cizelge_ekrani.dart
│        ├─ taksi_durak_takip_ekrani.dart
│        ├─ taksi_parametre_ekrani.dart
│        ├─ taksi_randevu_ekrani.dart
│        ├─ taksi_rehber_ekrani.dart
│        ├─ taksi_yonetici_ekrani.dart
│        └─ taksi_yonlendirme.dart

├─ pubspec.yaml
├─ android/
├─ ios/
└─ ... other files
```

---

## Target State Architecture

```
almely_randevu/ (MAIN APP - REDUCED)
├─ lib/
│  ├─ main.dart (DI setup + handler registration)
│  ├─ firebase_options.dart
│  │
│  ├─ ekranlar/
│  │  ├─ ana_ekran.dart (refactored - uses handlers)
│  │  ├─ randevu_ekrani.dart (refactored - 0 kategori checks)
│  │  ├─ esnaf_paneli.dart (refactored - uses handlers)
│  │  ├─ esnaf_ajanda_ekrani.dart (refactored - uses handlers)
│  │  ├─ esnaf_detay_ekrani.dart (refactored - uses handlers)
│  │  └─ ... other non-taksi screens
│  │
│  ├─ core/ (NEW)
│  │  ├─ category_handler.dart (interface)
│  │  └─ category_handler_registry.dart
│  │
│  └─ pubspec.yaml (imports almely_core + taksi_feature)
│
├─ android/
├─ ios/
└─ ... other files

almely_core/ (NEW SHARED PACKAGE)
├─ lib/
│  ├─ almely_core.dart (public API)
│  │
│  ├─ models/
│  │  ├─ esnaf_modeli.dart
│  │  └─ randevu_modeli.dart
│  │
│  ├─ services/
│  │  ├─ firestore_servisi.dart
│  │  ├─ bildirim_servisi.dart
│  │  ├─ konum_servisi.dart
│  │  ├─ onesignal_servisi.dart
│  │  ├─ versiyon_servisi.dart
│  │  ├─ storage_servisi.dart
│  │  └─ kimlik_dogrulama_servisi.dart
│  │
│  ├─ widgets/
│  │  ├─ ana_buton.dart
│  │  ├─ sos_butonu.dart
│  │  └─ medya_goruntuleyici.dart
│  │
│  ├─ helpers/
│  │  └─ resim_araclari.dart
│  │
│  └─ abstractions/
│     ├─ category_handler.dart
│     └─ category_handler_registry.dart
│
├─ pubspec.yaml
└─ README.md

taksi_feature/ (NEW FEATURE PACKAGE)
├─ lib/
│  ├─ taksi_feature.dart (public API)
│  │
│  ├─ presentation/
│  │  ├─ screens/
│  │  │  ├─ taksi_ana_ekrani.dart
│  │  │  ├─ taksi_bildirim_ekrani.dart
│  │  │  ├─ taksi_musteri_ekrani.dart
│  │  │  ├─ taksi_cizelge_ekrani.dart
│  │  │  ├─ taksi_durak_takip_ekrani.dart
│  │  │  ├─ taksi_parametre_ekrani.dart
│  │  │  ├─ taksi_randevu_ekrani.dart
│  │  │  ├─ taksi_rehber_ekrani.dart
│  │  │  ├─ taksi_yonetici_ekrani.dart
│  │  │  └─ taksi_yonlendirme.dart (refactored as handler)
│  │  │
│  │  └─ widgets/ (if any taksi-specific widgets)
│  │
│  ├─ domain/
│  │  ├─ models/
│  │  │  └─ taksi_talep_modeli.dart
│  │  │
│  │  └─ repositories/ (if needed)
│  │
│  ├─ data/
│  │  └─ services/
│  │     ├─ taksi_servisi.dart
│  │     └─ taksi_bildirim_servisi.dart
│  │
│  ├─ helpers/
│  │  ├─ taksi_kilavuzu.dart
│  │  └─ taksi_kurallari.dart
│  │
│  └─ taksi_category_handler.dart (implements CategoryHandler)
│
├─ pubspec.yaml (depends on almely_core)
└─ README.md
```

---

## Phase-by-Phase Implementation

### PHASE 1: Foundation (Days 1-3) - Create Shared Core

#### Step 1.1: Create almely_core package structure
```bash
# Create new package
cd .. && mkdir almely_core && cd almely_core
flutter create --template=package .

# Directory structure
mkdir -p lib/{models,services,widgets,helpers,abstractions}
```

#### Step 1.2: Create CategoryHandler abstraction
**File**: `almely_core/lib/abstractions/category_handler.dart`
```dart
import 'package:flutter/material.dart';
import '../models/esnaf_modeli.dart';

/// Abstract handler for category-specific behavior
abstract class CategoryHandler {
  /// Check if this handler can handle the given category
  bool canHandle(String kategori);
  
  /// Return category-specific detail screen
  Widget? getDetailScreen({
    required EsnafModeli esnaf,
    String? kullaniciTel,
  });
  
  /// Return category-specific booking screen
  Widget? getBookingScreen({
    required EsnafModeli esnaf,
    String? kullaniciTel,
    RandevuModu? modu,
  });
  
  /// Return category-specific schedule screen
  Widget? getScheduleScreen({
    required EsnafModeli esnaf,
  });
  
  /// Get custom UI label for this category
  String? getCustomLabel(String key, EsnafModeli esnaf);
  
  /// Get custom UI color for this category
  Color? getCustomColor(String key, EsnafModeli esnaf);
  
  /// Get custom UI icon for this category
  IconData? getCustomIcon(String key, EsnafModeli esnaf);
}

enum RandevuModu {
  standard,
  taksi,
  araçKiralama,
}
```

#### Step 1.3: Create CategoryHandlerRegistry
**File**: `almely_core/lib/abstractions/category_handler_registry.dart`
```dart
import 'package:flutter/material.dart';
import '../models/esnaf_modeli.dart';
import 'category_handler.dart';

class CategoryHandlerRegistry {
  final List<CategoryHandler> _handlers = [];
  
  void register(CategoryHandler handler) {
    _handlers.add(handler);
  }
  
  CategoryHandler? findHandler(String kategori) {
    try {
      return _handlers.firstWhere((h) => h.canHandle(kategori));
    } catch (e) {
      return null;
    }
  }
  
  Widget? buildDetailScreen(EsnafModeli esnaf, String? tel) {
    final handler = findHandler(esnaf.kategori);
    return handler?.getDetailScreen(esnaf: esnaf, kullaniciTel: tel);
  }
  
  Widget? buildBookingScreen(EsnafModeli esnaf, String? tel) {
    final handler = findHandler(esnaf.kategori);
    return handler?.getBookingScreen(esnaf: esnaf, kullaniciTel: tel);
  }
  
  Widget? buildScheduleScreen(EsnafModeli esnaf) {
    final handler = findHandler(esnaf.kategori);
    return handler?.getScheduleScreen(esnaf: esnaf);
  }
  
  String? getCustomLabel(String kategori, String key, EsnafModeli esnaf) {
    final handler = findHandler(kategori);
    return handler?.getCustomLabel(key, esnaf);
  }
}
```

#### Step 1.4: Move models to almely_core
```bash
# Move files
mv lib/modeller/esnaf_modeli.dart almely_core/lib/models/
mv lib/modeller/randevu_modeli.dart almely_core/lib/models/
mv lib/modeller/taksi/taksi_talep_modeli.dart taksi_feature/lib/domain/models/
```

#### Step 1.5: Move services to almely_core
```bash
# Move all shared services
mv lib/servisler/firestore_servisi.dart almely_core/lib/services/
mv lib/servisler/bildirim_servisi.dart almely_core/lib/services/
mv lib/servisler/konum_servisi.dart almely_core/lib/services/
mv lib/servisler/onesignal_servisi.dart almely_core/lib/services/
mv lib/servisler/versiyon_servisi.dart almely_core/lib/services/
mv lib/servisler/storage_servisi.dart almely_core/lib/services/
mv lib/servisler/kimlik_dogrulama_servisi.dart almely_core/lib/services/
```

#### Step 1.6: Move widgets to almely_core
```bash
# Move shared widgets
mv lib/widgets/ana_buton.dart almely_core/lib/widgets/
mv lib/widgets/sos_butonu.dart almely_core/lib/widgets/
mv lib/widgets/medya_goruntuleyici.dart almely_core/lib/widgets/
```

#### Step 1.7: Update almely_core pubspec.yaml
```yaml
# almely_core/pubspec.yaml
name: almely_core
description: "Shared core package for almely_randevu"
version: 1.0.0

environment:
  sdk: '>=3.2.3 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  cloud_firestore: ^6.4.1
  firebase_auth: ^6.5.1
  firebase_storage: ^13.4.1
  firebase_messaging: ^16.2.2
  firebase_core: ^4.9.0
  firebase_remote_config: ^6.5.1
  
  geolocator: ^14.0.2
  geocoding: ^4.0.0
  http: ^1.6.0
  url_launcher: ^6.3.1
  intl: ^0.20.2
  image_picker: ^1.2.2
  permission_handler: ^12.0.3
  onesignal_flutter: ^5.6.0
  flutter_timezone: ^5.1.0
  timezone: ^0.11.0
  flutter_local_notifications: ^22.0.0
  package_info_plus: ^10.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

#### Step 1.8: Update main pubspec.yaml to depend on almely_core
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Local packages
  almely_core:
    path: ../almely_core
  
  # Remaining packages...
  flutter_dotenv: ^5.2.1
```

#### Step 1.9: Update all imports in almely_randevu
```dart
// OLD: import 'package:almely_randevu/modeller/esnaf_modeli.dart';
// NEW:
import 'package:almely_core/models/esnaf_modeli.dart';

// OLD: import '../servisler/firestore_servisi.dart';
// NEW:
import 'package:almely_core/services/firestore_servisi.dart';

// OLD: import '../widgets/ana_buton.dart';
// NEW:
import 'package:almely_core/widgets/ana_buton.dart';
```

**Validation**:
- [ ] No import errors in almely_core
- [ ] No import errors in almely_randevu
- [ ] `flutter pub get` succeeds
- [ ] App builds successfully

---

### PHASE 2: Refactor Category Logic (Days 4-6)

#### Step 2.1: Replace kategori checks in randevu_ekrani.dart

**Before** (Line 30):
```dart
bool get _isTaksiModu => widget.modu == RandevuModu.taksi || 
                         widget.esnaf.kategori == 'Taksi';
```

**After** (using handler):
```dart
// In class definition, accept handler
final CategoryHandler? _categoryHandler;

bool get _isTaksiModu => _categoryHandler?.canHandle(widget.esnaf.kategori) ?? false;
```

**Before** (Line 137):
```dart
if (hizmetler.isEmpty && esnaf.kategori != 'Taksi') return;
```

**After**:
```dart
// Check if category requires services
if (hizmetler.isEmpty && _categoryHandler?.getCustomLabel('requiresServices', esnaf) != 'false') return;
```

#### Step 2.2: Create handler implementation mechanism

**File**: `almely_randevu/lib/core/category_handler.dart`
```dart
import 'package:flutter/material.dart';
import 'package:almely_core/almely_core.dart';

class DefaultCategoryHandler implements CategoryHandler {
  @override
  bool canHandle(String kategori) => false; // Default fallback
  
  @override
  Widget? getDetailScreen({required EsnafModeli esnaf, String? kullaniciTel}) => null;
  
  @override
  Widget? getBookingScreen({required EsnafModeli esnaf, String? kullaniciTel, RandevuModu? modu}) => null;
  
  @override
  Widget? getScheduleScreen({required EsnafModeli esnaf}) => null;
  
  @override
  String? getCustomLabel(String key, EsnafModeli esnaf) => null;
  
  @override
  Color? getCustomColor(String key, EsnafModeli esnaf) => null;
  
  @override
  IconData? getCustomIcon(String key, EsnafModeli esnaf) => null;
}
```

#### Step 2.3: Continue refactoring remaining files

Follow same pattern for:
- `esnaf_paneli.dart` (15 checks)
- `esnaf_ajanda_ekrani.dart` (13 checks)
- `esnaf_detay_ekrani.dart` (8 checks)
- `esnaf_parametre_ekrani.dart` (2 checks)
- `esnaf_randevu_onay_ekrani.dart` (2 checks)

**Validation**:
- [ ] All kategori checks replaced
- [ ] No `== 'Taksi'` strings in core screens
- [ ] Handlers registered in main.dart
- [ ] All screens still render correctly

---

### PHASE 3: Extract Taksi Feature (Days 7-10)

#### Step 3.1: Create taksi_feature package structure
```bash
mkdir -p ../taksi_feature/lib/{presentation,domain,data,helpers}
mkdir -p ../taksi_feature/lib/presentation/screens
```

#### Step 3.2: Create taksi_feature public API
**File**: `taksi_feature/lib/taksi_feature.dart`
```dart
export 'presentation/screens/taksi_ana_ekrani.dart';
export 'presentation/screens/taksi_musteri_ekrani.dart';
export 'presentation/screens/taksi_cizelge_ekrani.dart';
export 'presentation/screens/taksi_durak_takip_ekrani.dart';
export 'presentation/screens/taksi_parametre_ekrani.dart';
export 'presentation/screens/taksi_randevu_ekrani.dart';
export 'presentation/screens/taksi_rehber_ekrani.dart';
export 'presentation/screens/taksi_yonetici_ekrani.dart';
export 'presentation/screens/taksi_mod_secim_ekrani.dart';

export 'data/services/taksi_servisi.dart';
export 'data/services/taksi_bildirim_servisi.dart';

export 'domain/models/taksi_talep_modeli.dart';

export 'helpers/taksi_kilavuzu.dart';
export 'helpers/taksi_kurallari.dart';

export 'taksi_category_handler.dart';
```

#### Step 3.3: Create TaksiCategoryHandler
**File**: `taksi_feature/lib/taksi_category_handler.dart`
```dart
import 'package:flutter/material.dart';
import 'package:almely_core/almely_core.dart';
import 'presentation/screens/taksi_musteri_ekrani.dart';
import 'presentation/screens/taksi_randevu_ekrani.dart';
import 'presentation/screens/taksi_cizelge_ekrani.dart';
import 'presentation/screens/taksi_yonlendirme.dart';

class TaksiCategoryHandler implements CategoryHandler {
  @override
  bool canHandle(String kategori) => kategori == 'Taksi';
  
  @override
  Widget? getDetailScreen({
    required EsnafModeli esnaf,
    String? kullaniciTel,
  }) {
    return TaksiMusteriEkrani(
      esnaf: esnaf,
      kullaniciTel: kullaniciTel,
    );
  }
  
  @override
  Widget? getBookingScreen({
    required EsnafModeli esnaf,
    String? kullaniciTel,
    RandevuModu? modu,
  }) {
    return TaksiRandevuEkrani(
      esnaf: esnaf,
      kullaniciTel: kullaniciTel,
    );
  }
  
  @override
  Widget? getScheduleScreen({required EsnafModeli esnaf}) {
    return TaksiCizelgeEkrani(esnaf: esnaf);
  }
  
  @override
  String? getCustomLabel(String key, EsnafModeli esnaf) {
    switch (key) {
      case 'title':
        return '${esnaf.isletmeAdi} Rezervasyonu';
      case 'schedule_title':
        return 'Nöbet Çizelgesi';
      case 'requiresServices':
        return 'false'; // Taksi doesn't require services selection
      default:
        return null;
    }
  }
  
  @override
  Color? getCustomColor(String key, EsnafModeli esnaf) {
    if (key == 'accent') return Colors.amber;
    return null;
  }
  
  @override
  IconData? getCustomIcon(String key, EsnafModeli esnaf) {
    if (key == 'category') return Icons.local_taxi;
    return null;
  }
}
```

#### Step 3.4: Move taksi screens to feature
```bash
# Move all taksi screens to feature
mv lib/ekranlar/taksi/*.dart ../taksi_feature/lib/presentation/screens/
```

#### Step 3.5: Move taksi services to feature
```bash
# Move taksi services
mv lib/servisler/taksi/taksi_servisi.dart ../taksi_feature/lib/data/services/
mv lib/servisler/taksi/taksi_bildirim_servisi.dart ../taksi_feature/lib/data/services/
```

#### Step 3.6: Move taksi models and helpers to feature
```bash
# Move models
mv lib/modeller/taksi/taksi_talep_modeli.dart ../taksi_feature/lib/domain/models/

# Move helpers
mv lib/yardimcilar/taksi/taksi_kilavuzu.dart ../taksi_feature/lib/helpers/
mv lib/yardimcilar/taksi/taksi_kurallari.dart ../taksi_feature/lib/helpers/
```

#### Step 3.7: Update taksi_feature pubspec.yaml
```yaml
# taksi_feature/pubspec.yaml
name: taksi_feature
description: "Taksi (Taxi) feature module for almely_randevu"
version: 1.0.0

environment:
  sdk: '>=3.2.3 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  almely_core:
    path: ../almely_core
  
  google_maps_flutter: ^2.16.0
  http: ^1.6.0
  intl: ^0.20.2
  cloud_firestore: ^6.4.1
  geolocator: ^14.0.2
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

#### Step 3.8: Update main app pubspec.yaml
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  almely_core:
    path: ../almely_core
  taksi_feature:
    path: ../taksi_feature
  
  # Other dependencies...
```

#### Step 3.9: Register TaksiCategoryHandler in main.dart
```dart
// main.dart
import 'package:taksi_feature/taksi_feature.dart';
import 'package:almely_core/almely_core.dart';

void main() async {
  // ... Firebase initialization ...
  
  // Register category handlers
  final handlerRegistry = CategoryHandlerRegistry();
  handlerRegistry.register(TaksiCategoryHandler());
  // handlerRegistry.register(KuaforCategoryHandler()); // Future
  // handlerRegistry.register(RestaurantCategoryHandler()); // Future
  
  // Store in app state or context
  runApp(AlmelyApp(handlerRegistry: handlerRegistry));
}
```

**Validation**:
- [ ] No import errors
- [ ] taksi_feature builds independently
- [ ] All imports updated to use almely_core
- [ ] Handler registration works
- [ ] Taksi screens render correctly

---

### PHASE 4: Testing & Validation (Days 11-14)

#### Step 4.1: Unit tests for services
```bash
mkdir -p test/taksi_feature/data
```

**File**: `taksi_feature/test/data/taksi_servisi_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taksi_feature/data/services/taksi_servisi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('TaksiServisi', () {
    late TaksiServisi taksiServisi;
    
    setUp(() {
      // Mock Firebase
      taksiServisi = TaksiServisi();
    });
    
    test('talepGonder creates request', () async {
      // TODO: Implement test
    });
  });
}
```

#### Step 4.2: Widget tests for screens
```bash
mkdir -p test/taksi_feature/presentation
```

#### Step 4.3: Integration tests
```bash
mkdir -p integration_test/taksi
```

#### Step 4.4: Test CategoryHandler
```dart
test('TaksiCategoryHandler identifies Taksi category', () {
  final handler = TaksiCategoryHandler();
  expect(handler.canHandle('Taksi'), true);
  expect(handler.canHandle('Kuaför'), false);
});

test('TaksiCategoryHandler builds correct screens', () {
  final handler = TaksiCategoryHandler();
  final esnaf = EsnafModeli(/* ... */);
  
  final detailScreen = handler.getDetailScreen(esnaf: esnaf);
  expect(detailScreen, isNotNull);
  expect(detailScreen, isA<TaksiMusteriEkrani>());
});
```

#### Step 4.5: Manual testing checklist
- [ ] App launches without errors
- [ ] Taksi category displays correctly in home screen
- [ ] Taksi booking flow works end-to-end
- [ ] Taksi driver mode works
- [ ] Taksi admin mode works
- [ ] Taksi schedule management works
- [ ] Push notifications still work
- [ ] All UI colors and icons display correctly
- [ ] No hardcoded Taksi strings in core screens
- [ ] Feature can be disabled by not registering handler

#### Step 4.6: Performance testing
```bash
flutter run --profile
flutter analyze
flutter test --coverage
```

**Validation**:
- [ ] All tests pass
- [ ] No warnings or errors
- [ ] App performance unchanged
- [ ] Feature works in isolation
- [ ] Feature integrates correctly

---

## File Checklist

### Phase 1 - Core Package Creation
- [ ] `almely_core/pubspec.yaml` created
- [ ] Models moved to `almely_core/lib/models/`
- [ ] Services moved to `almely_core/lib/services/`
- [ ] Widgets moved to `almely_core/lib/widgets/`
- [ ] Abstractions created in `almely_core/lib/abstractions/`
- [ ] All imports updated in existing code

### Phase 2 - Category Logic Refactoring
- [ ] `randevu_ekrani.dart` refactored (12 checks)
- [ ] `esnaf_ajanda_ekrani.dart` refactored (13 checks)
- [ ] `esnaf_paneli.dart` refactored (15 checks)
- [ ] `esnaf_detay_ekrani.dart` refactored (8 checks)
- [ ] `esnaf_parametre_ekrani.dart` refactored (2 checks)
- [ ] `esnaf_randevu_onay_ekrani.dart` refactored (2 checks)
- [ ] CategoryHandler interface created
- [ ] DefaultCategoryHandler implemented

### Phase 3 - Feature Extraction
- [ ] `taksi_feature/pubspec.yaml` created
- [ ] All taksi screens moved
- [ ] All taksi services moved
- [ ] All taksi models moved
- [ ] All taksi helpers moved
- [ ] `TaksiCategoryHandler` implemented
- [ ] Public API exported in `taksi_feature.dart`
- [ ] All imports updated to use `almely_core`
- [ ] Handler registered in `main.dart`

### Phase 4 - Testing
- [ ] Unit tests written
- [ ] Widget tests written
- [ ] Integration tests written
- [ ] Manual testing completed
- [ ] No regressions found

---

## Rollback Plan

If extraction fails at any point:

### Quick Rollback (within Phase 1-2)
```bash
git revert <commit-hash>
# Go back to before almely_core creation
```

### Partial Rollback (within Phase 3)
```bash
# Keep almely_core, revert taksi_feature extraction
git checkout lib/ekranlar/taksi/
git checkout lib/servisler/taksi/
git checkout lib/modeller/taksi/
git checkout lib/yardimcilar/taksi/
```

### Full Rollback
```bash
# Start over with original code
git reset --hard <original-commit>
rm -rf almely_core taksi_feature
```

---

## Success Criteria

✅ **Phase 1 Complete When:**
- almely_core builds without errors
- All imports resolved
- App builds successfully
- No functionality changed

✅ **Phase 2 Complete When:**
- All kategori checks removed from core
- CategoryHandler interface implemented
- All core screens use handler registry
- App builds and runs without errors

✅ **Phase 3 Complete When:**
- taksi_feature builds independently
- All taksi code moved to feature
- Feature integrates with main app
- No functionality lost

✅ **Phase 4 Complete When:**
- All tests pass
- No regressions found
- Documentation updated
- Ready for production

---

## Timeline Summary

| Phase | Days | Task | Status |
|-------|------|------|--------|
| 1 | 1-3 | Create almely_core | Estimated |
| 2 | 4-6 | Refactor category logic | Estimated |
| 3 | 7-10 | Extract taksi_feature | Estimated |
| 4 | 11-14 | Testing & validation | Estimated |
| **TOTAL** | **14 days** | **Full extraction** | **2 weeks** |

**With 1 developer working full-time**

---

## Next Steps

1. **Review this roadmap** with your team
2. **Assess timeline** - is 2 weeks feasible?
3. **Set up version control** - create feature branch
4. **Allocate resources** - assign 1 developer
5. **Create milestones** in your project management tool
6. **Execute Phase 1** - create almely_core
7. **Gather feedback** - test with team
8. **Adjust plan** if needed
9. **Continue phases** 2-4
10. **Merge to main** - celebrate! 🎉

---

## References

- CategoryHandler interface: `almely_core/lib/abstractions/category_handler.dart`
- Refactoring guide: `TAKSI_DEPENDENCY_MAP.md`
- Summary: `TAKSI_EXTRACTION_SUMMARY.md`
- Analysis: `TAKSI_MODULE_ANALYSIS.md`

---

**Last Updated**: 2024
**Status**: Ready for implementation
**Difficulty**: Medium-High
**Recommended Team Size**: 1 developer
**Estimated Timeline**: 2-3 weeks
