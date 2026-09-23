# Taksi (Taxi) Module Dependency Analysis

## Executive Summary

**Extraction Feasibility: PARTIALLY POSSIBLE (requires shared core package)**

The Taksi module has **tight coupling** to shared services and models. It can be extracted into a separate Flutter feature module, but only if shared models, services, and utilities are moved to a common package first.

---

## 1. Core Taksi Files

### A. UI Screens (`lib/ekranlar/taksi/`)
| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `taksi_ana_ekrani.dart` | Home screen for Taxi module | 100+ | Self-contained |
| `taksi_bildirim_ekrani.dart` | Notification display | 426 | Minimal (1 screen) |
| `taksi_mod_secim_ekrani.dart` | Mode selector (Customer/Driver/Manager) | 5.4K | **Depends on core screens** |
| `taksi_musteri_ekrani.dart` | Customer (passenger) booking screen | 40.8K | **Heavy dependencies** |
| `taksi_cizelge_ekrani.dart` | Schedule/Shift management | 48.9K | **Heavy dependencies** |
| `taksi_durak_takip_ekrani.dart` | Driver stand tracking | 28.1K | **Heavy dependencies** |
| `taksi_parametre_ekrani.dart` | Settings/Parameters | 8.2K | **Depends on FirestoreServisi** |
| `taksi_randevu_ekrani.dart` | Reservation booking | 22K | **Heavy dependencies** |
| `taksi_rehber_ekrani.dart` | User guide/tutorial | 16.8K | Self-contained |
| `taksi_yonetici_ekrani.dart` | Admin/Manager panel | 6.4K | **Depends on services** |
| `taksi_yonlendirme.dart` | Routing logic | 963B | **Integration wrapper** |

**Total: 11 files | ~200+ KB of code**

### B. Data Models (`lib/modeller/taksi/`)
| File | Purpose | Dependencies |
|------|---------|--------------|
| `taksi_talep_modeli.dart` | Taxi request model | `cloud_firestore` only ✅ |

**Status: ✅ STANDALONE** - Can be extracted independently

### C. Services (`lib/servisler/taksi/`)
| File | Purpose | Dependencies |
|------|---------|--------------|
| `taksi_servisi.dart` | Taxi-specific business logic | `cloud_firestore` only ✅ |
| `taksi_bildirim_servisi.dart` | Notification orchestration | **Depends on `BildirimServisi`** ⚠️ |

**Status: ⚠️ PARTIAL** - Core logic is independent, but notification wrapper depends on shared service

### D. Helpers (`lib/yardimcilar/taksi/`)
| File | Purpose | Dependencies |
|------|---------|--------------|
| `taksi_kilavuzu.dart` | User guide content (constants) | None ✅ |
| `taksi_kurallari.dart` | Validation rules (static methods) | None ✅ |

**Status: ✅ STANDALONE** - Pure utility/constants

---

## 2. External Dependencies (Outside Taksi Folder)

### A. Shared Models (REQUIRED - Cannot avoid)
| Model | Used By Taksi | Where |
|-------|---------------|-------|
| **`EsnafModeli`** | All screens | Taxi business/provider data |
| **`RandevuModeli`** | Multiple screens | Appointment/reservation data |

**Status: 🔴 CRITICAL DEPENDENCY** - Taksi is tightly coupled to core models

### B. Shared Services (REQUIRED - Cannot avoid)
| Service | Used By Taksi | Specific Usage |
|---------|---------------|----------------|
| **`FirestoreServisi`** | taksi_parametre, taksi_cizelge, taksi_musteri | Firestore CRUD operations |
| **`BildirimServisi`** | taksi_musteri, taksi_bildirim_servisi | Notification sending |
| **`KonumServisi`** | taksi_musteri, taksi_randevu | Location & geocoding |
| **`OneSignalServisi`** | (indirectly via BildirimServisi) | Push notification management |

**Status: 🔴 CRITICAL DEPENDENCY** - Taksi cannot function without these

### C. Shared Widgets (REQUIRED)
| Widget | Used By Taksi | Where |
|--------|---------------|-------|
| **`AnaButon`** | taksi_randevu, taksi_musteri | Primary action buttons |
| **`SosButonu`** | taksi_musteri, taksi_randevu | Emergency SOS button |

**Status: 🟡 CRITICAL** - UI consistency requires these

### D. Integration Points (Where Taksi is imported)
**Files that import Taksi screens/modules:**

```
lib/ekranlar/ana_ekran.dart
  ├─ imports: taksi_mod_secim_ekrani.dart
  └─ imports: taksi_yonlendirme.dart
  
lib/ekranlar/giris_secim_ekrani.dart
  ├─ imports: taksi_mod_secim_ekrani.dart
  
lib/ekranlar/esnaf_ajanda_ekrani.dart
  ├─ imports: taksi_cizelge_ekrani.dart  ⚠️ CONDITIONAL (only if kategori == 'Taksi')
  
lib/ekranlar/esnaf_detay_ekrani.dart
  ├─ imports: taksi_yonlendirme.dart
  ├─ imports: taksi_rehber_ekrani.dart
  
lib/ekranlar/esnaf_paneli.dart
  ├─ imports: taksi_durak_takip_ekrani.dart  ⚠️ CONDITIONAL
  ├─ imports: taksi_cizelge_ekrani.dart      ⚠️ CONDITIONAL
  ├─ imports: taksi_rehber_ekrani.dart       ⚠️ CONDITIONAL
  ├─ imports: taksi_parametre_ekrani.dart    ⚠️ CONDITIONAL
  
lib/ekranlar/esnaf_randevu_onay_ekrani.dart
  ├─ imports: taksi_rehber_ekrani.dart       ⚠️ CONDITIONAL
  
lib/ekranlar/randevu_ekrani.dart
  ├─ NO direct imports (logic handled via kategori checks)
```

---

## 3. Category-Based Integration Points

### A. Hardcoded 'Taksi' Category Checks

**Files with `kategori == 'Taksi'` checks:**
```
1. ekranlar/esnaf_ajanda_ekrani.dart      (13+ checks)
2. ekranlar/esnaf_detay_ekrani.dart       (8+ checks)
3. ekranlar/esnaf_paneli.dart             (15+ checks)
4. ekranlar/esnaf_parametre_ekrani.dart   (2+ checks)
5. ekranlar/esnaf_randevu_onay_ekrani.dart (2+ checks)
6. ekranlar/randevu_ekrani.dart            (12+ checks)
```

**Type of checks:**
- Conditional screen rendering
- Different workflow logic (e.g., schedule vs slots)
- Vehicle management flows
- UI adjustments (labels, buttons)
- Notification timing

**Status: 🔴 CRITICAL BLOCKER** - Cannot extract Taksi without refactoring these checks into a plugin/interface

### B. Example: Conditional Navigation in `randevu_ekrani.dart`

```dart
// Line 30
bool get _isTaksiModu => widget.modu == RandevuModu.taksi || widget.esnaf.kategori == 'Taksi';

// Line 258
if (esnaf.kategori == 'Taksi' && toplam == 0) {
    return 30; // Default 30-minute reservation
}

// Line 383
if (esnaf.kategori == 'Taksi' && kanal != null && kanal.isNotEmpty) {
    // Taksi-specific schedule logic
}

// Line 796
if (esnaf.kategori == 'Taksi') ...[
    SliverToBoxAdapter(child: _adimBasligi("1", "Zaman Seçimi")),
    // Custom UI flow for Taksi
]
```

---

## 4. Shared Resources & Dependencies Matrix

### A. Firestore Collections Used by Taksi

| Collection | Taksi Usage |
|------------|-------------|
| `esnaflar` | Read provider info, vehicles, settings |
| `randevular` | Create/read appointments |
| `taksi_talepleri` | Store taxi requests (Taksi-specific) |
| `yorumlar` | Read/write reviews |

### B. Firebase Features Used

| Feature | Taksi Dependency | Risk Level |
|---------|------------------|-----------|
| Firestore CRUD | ✅ Heavy | 🔴 High |
| Cloud Storage | ⚠️ Image uploads | 🟡 Medium |
| Cloud Messaging | ✅ Notifications | 🔴 High |
| Remote Config | ⚠️ Feature flags | 🟡 Medium |

### C. Third-Party Libraries Used

| Package | Usage in Taksi | Extractable? |
|---------|----------------|--------------|
| `google_maps_flutter` | Vehicle tracking map | ✅ Yes (feature-specific) |
| `geolocator` | Location services | ✅ Yes (feature-specific) |
| `geocoding` | Address lookup | ✅ Yes (feature-specific) |
| `intl` | Date formatting | ✅ Yes (shared) |
| `url_launcher` | WhatsApp/phone calls | ✅ Yes (feature-specific) |
| `http` | Reverse geocoding (Nominatim) | ✅ Yes (feature-specific) |

---

## 5. Circular Dependencies Check

### A. Dependency Direction
```
taksi_screens ──────> FirestoreServisi
   ↑                      ↑
   |                      |
   └──────── EsnafModeli ──┘

taksi_screens ──────> BildirimServisi
   ↑                      ↑
   |                      |
   └──────── RandevuModeli ─┘
```

**Status: ✅ NO CIRCULAR DEPENDENCIES** - Dependencies flow outward only

### B. Cross-Module Dependencies
```
ana_ekran.dart
   ├─ imports taksi_yonlendirme.dart
   ├─ imports AnaEkran (itself)
   └─ imports all core services

esnaf_paneli.dart
   ├─ imports taksi_cizelge_ekrani.dart (conditional)
   ├─ imports esnaf_ajanda_ekrani.dart
   └─ imports all core services
```

**Status: 🟡 LOOSE COUPLING** - Can be extracted but entry points must remain

---

## 6. Can It Be Extracted? Detailed Analysis

### ✅ WHAT CAN BE EXTRACTED

**As a standalone Flutter Feature Module (`taksi_feature` package):**

1. **All Taksi UI screens** (except `taksi_yonlendirme.dart` which is a router)
   - `taksi_ana_ekrani.dart`
   - `taksi_musteri_ekrani.dart`
   - `taksi_cizelge_ekrani.dart`
   - `taksi_durak_takip_ekrani.dart`
   - `taksi_parametre_ekrani.dart`
   - `taksi_randevu_ekrani.dart`
   - `taksi_rehber_ekrani.dart`
   - `taksi_yonetici_ekrani.dart`

2. **Taksi-specific services**
   - `TaksiServisi`
   - `TaksiBildirimServisi` (with BildirimServisi as injected dependency)

3. **Taksi models**
   - `TaksiTalepModeli`

4. **Taksi helpers**
   - `TaksiKilavuzu`
   - `TaksiKurallari`

### ⚠️ WHAT REQUIRES SHARED CORE PACKAGE

**Create `almely_core` package with:**

```
almely_core/
  ├─ lib/
  │   ├─ models/
  │   │   ├─ esnaf_modeli.dart      (SHARE)
  │   │   ├─ randevu_modeli.dart    (SHARE)
  │   │   └─ ...
  │   ├─ services/
  │   │   ├─ firestore_servisi.dart (SHARE)
  │   │   ├─ bildirim_servisi.dart  (SHARE)
  │   │   ├─ konum_servisi.dart     (SHARE)
  │   │   └─ onesignal_servisi.dart (SHARE)
  │   ├─ widgets/
  │   │   ├─ ana_buton.dart         (SHARE)
  │   │   └─ sos_butonu.dart        (SHARE)
  │   └─ helpers/
  │       └─ ...common utilities
  └─ pubspec.yaml
```

### 🔴 WHAT BLOCKS EXTRACTION

1. **Category-based conditional logic** in:
   - `randevu_ekrani.dart` (12+ kategori checks)
   - `esnaf_ajanda_ekrani.dart` (13+ kategori checks)
   - `esnaf_paneli.dart` (15+ kategori checks)
   - `esnaf_detay_ekrani.dart` (8+ kategori checks)

2. **Module routing/entry points**:
   - `taksi_yonlendirme.dart` (decides which screen to show based on kategori)
   - `taksi_mod_secim_ekrani.dart` (navigation logic)

3. **Tight integration** in:
   - `ana_ekran.dart` (direct imports)
   - `giris_secim_ekrani.dart` (direct imports)
   - `esnaf_paneli.dart` (conditional imports)

---

## 7. Minimum Viable Package Structure

### Option A: Feature Module (Recommended)

```
almely_randevu/ (Main app)
├── lib/
│   ├── main.dart
│   ├── modeller/          ──> MOVE TO almely_core
│   ├── servisler/         ──> MOVE TO almely_core
│   ├── widgets/           ──> MOVE TO almely_core
│   ├── ekranlar/
│   │   ├── taksi/         ──> BECOMES taksi_feature/
│   │   ├── ana_ekran.dart
│   │   ├── randevu_ekrani.dart (REFACTOR: inject Taksi handler)
│   │   └── ...
│   └── yardimcilar/       ──> MOVE TO almely_core
│
└── pubspec.yaml
    dependencies:
      almely_core: 
        path: ../almely_core
      taksi_feature:
        path: ../taksi_feature

almely_core/
├── lib/
│   ├── models/
│   ├── services/
│   ├── widgets/
│   └── helpers/
└── pubspec.yaml

taksi_feature/
├── lib/
│   ├── screens/
│   │   └── (all taksi screens)
│   ├── services/
│   │   └── (taksi_servisi.dart, taksi_bildirim_servisi.dart)
│   ├─ models/
│   │   └── taksi_talep_modeli.dart
│   ├── helpers/
│   │   └── (taksi guidelines & rules)
│   └── taksi_feature.dart (public API)
└── pubspec.yaml
    dependencies:
      almely_core
```

### Option B: Plugin Architecture (For true separation)

If you want **zero coupling** to main app:

```
almely_randevu/ (Main app)
├── lib/
│   ├── core/
│   │   └── category_handler.dart  (Abstract interface)
│   └── ...
└── pubspec.yaml
    dependencies:
      almely_core
      taksi_feature

taksi_feature/
├── lib/
│   ├── taksi_category_handler.dart (Implements interface)
│   ├── screens/
│   └── ...
└── pubspec.yaml
    dependencies:
      almely_core
```

---

## 8. Extraction Challenges & Solutions

| Challenge | Severity | Solution |
|-----------|----------|----------|
| **Category checks in core screens** | 🔴 High | Use Strategy pattern or Handler registration |
| **Shared models in services** | 🔴 High | Extract to `almely_core` package |
| **Navigation/Routing** | 🟡 Medium | Use abstract Router interface |
| **Notification service coupling** | 🟡 Medium | Inject BildirimServisi into Taksi services |
| **Firestore collection usage** | 🟡 Medium | Collections are app-level, no issue if core is shared |
| **Third-party library conflicts** | 🟢 Low | All are compatible, can be duplicated |

---

## 9. Recommended Extraction Path

### Phase 1: Extract Shared Core (Week 1-2)
1. Create `almely_core` package
2. Move `EsnafModeli`, `RandevuModeli` → core
3. Move all shared services → core
4. Move shared widgets → core
5. Update imports in all files

### Phase 2: Refactor Category Logic (Week 2-3)
1. Create `CategoryHandler` interface in core
2. Implement `TaksiCategoryHandler` in taksi_feature
3. Replace `kategori == 'Taksi'` checks with handler calls
4. Register handlers at app initialization

### Phase 3: Extract Taksi Feature (Week 3-4)
1. Create `taksi_feature` package
2. Move all taksi screens → feature
3. Move `TaksiServisi`, `TaksiBildirimServisi` → feature
4. Create `TaksiFeatureEntry` public API
5. Update main app to load feature

### Phase 4: Test & Refine (Week 4+)
1. Test feature in isolation
2. Test feature as plugin
3. Benchmark app size reduction
4. Document API

---

## 10. Feasibility Matrix

| Aspect | Score | Notes |
|--------|-------|-------|
| **Code Isolation** | 7/10 | Taksi screens are mostly isolated, but core logic is shared |
| **Dependency Clarity** | 6/10 | Clear dependencies, but many integration points |
| **Extraction Effort** | 5/10 | Medium effort due to category checks and shared models |
| **Maintenance Benefit** | 8/10 | High benefit once extracted; clearer architecture |
| **Risk Level** | 7/10 | Moderate risk; requires careful refactoring |
| **Overall Extractability** | 6/10 | **POSSIBLE with significant refactoring** |

---

## 11. File Size Analysis

```
Taksi Module Size Breakdown:
├─ Screens:        ~200 KB (11 files)
├─ Services:       ~2 KB (2 files)
├─ Models:         ~1.5 KB (1 file)
├─ Helpers:        ~2 KB (2 files)
└─ Total:          ~205 KB

Percentage of app: ~8-10% of total codebase
Potential reduction: If extracted, core app: ~800 KB
```

---

## Conclusion

**Taksi module CAN be extracted as a standalone feature module, but with conditions:**

✅ **Pros:**
- Cleaner codebase organization
- Easier to maintain and test independently
- Can be versioned separately
- Reduces main app size by ~10%
- Easier to reuse in other Flutter projects

❌ **Cons:**
- Requires creating and maintaining `almely_core` package
- Significant refactoring of category-based logic
- Shared models and services must be abstracted
- Testing complexity increases initially

🎯 **Recommendation:**
**Extract as Feature Module** using **Dependency Injection** pattern. Refactor category checks to use a `CategoryHandler` interface, making the system pluggable for future feature modules (Kuaför, Restoran, etc.).
