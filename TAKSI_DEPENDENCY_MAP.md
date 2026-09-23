# Taksi Module - Detailed Dependency Map

## 1. Import Dependencies by File

### Taksi Screens Import Map

#### `taksi_musteri_ekrani.dart` (40.8 KB) - Customer Booking Screen
```
IMPORTS:
├─ flutter (Material, Foundation, Gestures)
├─ cloud_firestore ✅ EXTERNAL
├─ geolocator ✅ EXTERNAL
├─ google_maps_flutter ✅ EXTERNAL
├─ intl ✅ EXTERNAL
├─ url_launcher ✅ EXTERNAL
│
├─ EsnafModeli ............................ 🔴 SHARED CORE
├─ BildirimServisi ........................ 🔴 SHARED CORE
├─ FirestoreServisi ....................... 🔴 SHARED CORE
├─ KonumServisi ........................... 🔴 SHARED CORE
│
├─ taksi_rehber_ekrani .................... 🟡 TAKSI (internal)
├─ taksi_yonlendirme ...................... 🟡 TAKSI (internal)
│
├─ AnaButon ............................... 🔴 SHARED WIDGETS
├─ SosButonu .............................. 🔴 SHARED WIDGETS
│
DEPENDENCIES: 4 core services + 2 core models + 2 shared widgets
EXTERNAL: 6 pub packages
```

#### `taksi_cizelge_ekrani.dart` (48.9 KB) - Schedule Management
```
IMPORTS:
├─ flutter (Material)
├─ cloud_firestore ✅ EXTERNAL
├─ intl ✅ EXTERNAL
│
├─ EsnafModeli ............................ 🔴 SHARED CORE
│
├─ taksi_rehber_ekrani .................... 🟡 TAKSI (internal)
│
DEPENDENCIES: 1 core model
INTEGRATIONS: Direct Firestore queries (no service abstraction)
```

#### `taksi_randevu_ekrani.dart` (22 KB) - Reservation Booking
```
IMPORTS:
├─ flutter (Material)
├─ http ✅ EXTERNAL (Google Distance Matrix)
├─ intl ✅ EXTERNAL
├─ geolocator ✅ EXTERNAL
│
├─ EsnafModeli ............................ 🔴 SHARED CORE
├─ RandevuModeli .......................... 🔴 SHARED CORE
├─ FirestoreServisi ....................... 🔴 SHARED CORE
├─ KonumServisi ........................... 🔴 SHARED CORE
│
├─ AnaButon ............................... 🔴 SHARED WIDGETS
├─ SosButonu .............................. 🔴 SHARED WIDGETS
│
DEPENDENCIES: 2 core models + 2 core services + 2 shared widgets
COMPLEXITY: ValueNotifier for reactive state
```

#### `taksi_durak_takip_ekrani.dart` (28.1 KB) - Driver Stand Tracking
```
IMPORTS:
├─ flutter (Material)
├─ geolocator ✅ EXTERNAL
│
├─ surucu_dogrulama_ekrani ................. 🟠 PARENT MODULE (non-Taksi)
├─ surucu_profil_detay_ekrani ............. 🟠 PARENT MODULE (non-Taksi)
├─ taksi_rehber_ekrani .................... 🟡 TAKSI (internal)
│
DEPENDENCIES: 2 parent screens (cross-module coupling!)
WARNING: 🔴 MODERATE COUPLING TO PARENT SCREENS
```

#### `taksi_parametre_ekrani.dart` (8.2 KB) - Settings
```
IMPORTS:
├─ flutter (Material)
│
├─ FirestoreServisi ....................... 🔴 SHARED CORE
├─ EsnafModeli ............................ 🔴 SHARED CORE
│
├─ taksi_rehber_ekrani .................... 🟡 TAKSI (internal)
│
DEPENDENCIES: 1 core model + 1 core service
```

#### `taksi_yonetici_ekrani.dart` (6.4 KB) - Admin Panel
```
IMPORTS:
├─ flutter (Material)
├─ cloud_firestore ✅ EXTERNAL
│
├─ TaksiTalepModeli ....................... 🟡 TAKSI MODEL
├─ EsnafModeli ............................ 🔴 SHARED CORE
├─ TaksiServisi ........................... 🟡 TAKSI SERVICE
├─ FirestoreServisi ....................... 🔴 SHARED CORE
├─ TaksiBildirimServisi ................... 🟡 TAKSI SERVICE
├─ RandevuModeli .......................... 🔴 SHARED CORE
│
DEPENDENCIES: 2 taksi services + 2 core models + 1 core service
```

#### `taksi_mod_secim_ekrani.dart` (5.4 KB) - Mode Selector
```
IMPORTS:
├─ flutter (Material)
│
├─ AnaEkran ............................... 🟠 PARENT MODULE (navigation)
├─ EsnafPaneli ............................ 🟠 PARENT MODULE (navigation)
├─ TaksiDurakTakipEkrani .................. 🟡 TAKSI (internal)
│
DEPENDENCIES: Navigation to parent screens
WARNING: 🔴 ENTRY POINT - TIGHTLY COUPLED TO NAVIGATION STRUCTURE
```

#### `taksi_rehber_ekrani.dart` (16.8 KB) - User Guide
```
IMPORTS:
├─ flutter (Material)
│
DEPENDENCIES: NONE (self-contained, constants-only)
STATUS: ✅ FULLY EXTRACTABLE
```

#### `taksi_yonlendirme.dart` (963 B) - Router/Dispatcher
```
IMPORTS:
├─ flutter (Material)
│
├─ EsnafModeli ............................ 🔴 SHARED CORE
├─ EsnafDetayEkrani ....................... 🟠 PARENT MODULE
├─ RandevuEkrani .......................... 🟠 PARENT MODULE
├─ TaksiMusteriEkrani ..................... 🟡 TAKSI (internal)
├─ TaksiRandevuEkrani ..................... 🟡 TAKSI (internal)
│
DEPENDENCIES: Router/dispatcher for Taksi vs regular screens
WARNING: 🔴 CRITICAL INTEGRATION POINT - Hardcoded kategori == 'Taksi' check
```

#### `taksi_ana_ekrani.dart` (2.7 KB) - Home Screen
```
IMPORTS:
├─ flutter (Material)
│
DEPENDENCIES: NONE (self-contained)
STATUS: ✅ FULLY EXTRACTABLE
```

#### `taksi_bildirim_ekrani.dart` (426 B) - Notification Screen
```
IMPORTS:
├─ flutter (Material)
│
DEPENDENCIES: NONE (UI-only)
STATUS: ✅ FULLY EXTRACTABLE
```

---

## 2. Service Dependencies

### `taksi_servisi.dart`
```dart
IMPORTS:
├─ cloud_firestore
│
CLASS: TaksiServisi
├─ Constructor: FirebaseFirestore (injected)
├─ Methods:
│   ├─ talepGonder() → Firestore
│   ├─ talepleriDinle() → Firestore Stream
│   └─ talepDurumGuncelle() → Firestore
│
STATUS: ✅ MINIMAL DEPENDENCY
Collection: 'taksi_talepleri' (Taksi-specific)
```

### `taksi_bildirim_servisi.dart`
```dart
IMPORTS:
├─ flutter (Material, BuildContext)
├─ BildirimServisi ........................ 🔴 SHARED CORE DEPENDENCY
│
CLASS: TaksiBildirimServisi
├─ Static methods:
│   ├─ sendTalepKabulBildirim()
│   └─ sendTalepReddetBildirim()
├─ Both methods delegate to BildirimServisi.bildirimGonder()
│
STATUS: 🟡 WRAPPER DEPENDENCY
Dependency: Must inject BildirimServisi
```

---

## 3. Integration Points in Core Modules

### `randevu_ekrani.dart` - Conditional Taksi Logic
```dart
TAKSI INTEGRATIONS:
├─ Line 30:  bool get _isTaksiModu => widget.modu == RandevuModu.taksi || 
                                       widget.esnaf.kategori == 'Taksi'
│
├─ Line 137: if (hizmetler.isEmpty && esnaf.kategori != 'Taksi') return;
│
├─ Line 258: if (esnaf.kategori == 'Taksi' && toplam == 0) return 30;
│
├─ Line 270: if (!esnaf.ajandayiKendimAyarlayacagim || 
              esnaf.kategori == 'Taksi') { ... }
│
├─ Line 383: if (esnaf.kategori == 'Taksi' && kanal != null) 
              { // Taksi-specific schedule logic }
│
├─ Line 557: final isTaksi = esnaf.kategori == 'Taksi';
│
├─ Line 771: Text(widget.esnaf.kategori == 'Taksi' ? 
              "${widget.esnaf.isletmeAdi} Rezervasyonu" : "Randevu Al", ...)
│
├─ Line 796: if (esnaf.kategori == 'Taksi') ...[
              // Custom UI flow for Taksi
            ]
│
├─ Line 898: bool isTaksi = esnaf.kategori == 'Taksi';
│
├─ Line 1007: _adimBasligi(_isAracKiralama ? "3" : 
              (esnaf.kategori == 'Taksi' ? "4" : "5"), ...)
│
├─ Line 1070: bool butonAktif = saat != null && 
              (_isAracKiralama || hizmetler.isNotEmpty || 
               widget.esnaf.kategori == 'Taksi')
│
├─ Line 1083: if (widget.esnaf.kategori == 'Taksi') { ... }
│
└─ Line 1167: if (widget.esnaf.kategori == 'Taksi') ...[
              SosButonu(...)
            ]

TOTAL: 12+ kategori checks
RISK: 🔴 HIGH - Difficult to extract without breaking core logic
```

### `esnaf_ajanda_ekrani.dart` - Schedule Management
```dart
TAKSI INTEGRATIONS:
├─ Line 68: } else if (widget.esnaf.kategori == 'Taksi' && 
             (widget.esnaf.aracOdakliSistem || ...)) {
             _seciliKanallar.add(widget.esnaf.araclar.first['plaka']);
│
├─ Line 256: if (guncelKanallar.isNotEmpty && esnaf.kategori != 'Taksi') {
│
├─ Line 261: } else if (esnaf.kategori == 'Taksi' && 
              esnaf.araclar.isNotEmpty) {
│
├─ Line 416: if (_birGunCalisBirGunYat || esnaf.kategori == 'Taksi') {
│
├─ Line 967: (guncelEsnaf.kategori == 'Taksi' && 
              guncelEsnaf.araclar.any((a) => a['plaka'] == k))
│
├─ Line 978: if (guncelEsnaf.kategori == 'Taksi' && 
              guncelEsnaf.araclar.isNotEmpty) {
│
├─ Line 1108: if (guncelEsnaf.kategori == 'Taksi' && 
               _seciliKanallar.length == 1) {
│
├─ Line 1612: final isTaksi = esnaf.kategori == 'Taksi';
│
├─ Line 1674: if (esnaf.kategori == 'Taksi' && 
               (esnaf.aracOdakliSistem || ...)) {
│
├─ Line 1910: if (esnaf.kategori == 'Taksi') ...[
│
├─ Line 2043: if (esnaf.kategori == 'Taksi') ...[
│
└─ Line 2217: if (esnaf.kategori == 'Taksi')

TOTAL: 13+ kategori checks
COMPLEXITY: Very high - vehicle/channel differentiation logic
RISK: 🔴 CRITICAL - Deep integration with scheduling system
```

### `esnaf_paneli.dart` - Main Provider Panel
```dart
TAKSI INTEGRATIONS:
├─ Line 23-28: Imports taksi_*.dart files
│
├─ Line 200: if (widget.esnaf.kategori == 'Taksi' && _is724) {
│
├─ Line 699: final List globalPersoneller = widget.esnaf.kategori == 'Taksi'
             ? araclar.map(...) : personeller;
│
├─ Line 722: if (cleanKanalNames.isNotEmpty && 
              widget.esnaf.kategori != 'Taksi') {
│
├─ Line 724: } else if (widget.esnaf.kategori == 'Taksi' && 
              araclar.isNotEmpty) {
│
├─ Line 780: 'personeller': widget.esnaf.kategori == 'Taksi'
             ? araclar.map(...) : personeller,
│
├─ Line 933-934: Conditional 'acilis'/'kapanis' time handling for Taksi
│
├─ Line 942: 'personeller': widget.esnaf.kategori == 'Taksi'
│
├─ Line 1105: bool isTaksi = widget.esnaf.kategori == 'Taksi';
│
├─ Line 1169: if (widget.esnaf.kategori == 'Taksi') {
              await navigator.push(MaterialPageRoute(
                builder: (c) => TaksiParametreEkrani(...)
              ));
│
├─ Line 3441: if (widget.esnaf.kategori == 'Taksi') {
              Navigator.push(..., TaksiRehberEkrani(...));
│
├─ Line 3485: if (!exists && widget.esnaf.kategori != 'Taksi') {
│
├─ Line 3512: if (widget.esnaf.kategori == 'Taksi') 
              return const SizedBox.shrink();
│
├─ Line 3835: if (widget.esnaf.kategori == 'Taksi') ...[
              _bolumKart("Filo Yönetimi", ...)
│
├─ Line 3878: if (value && widget.esnaf.kategori != 'Taksi') {
│
├─ Line 3882: } else if (!value && widget.esnaf.kategori != 'Taksi') {
│
├─ Line 3898: if (widget.esnaf.kategori == 'Taksi') ...[
│
└─ Line 3979: if (widget.esnaf.kategori != 'Taksi') ...[

TOTAL: 15+ kategori checks
COMPLEXITY: Highest - Vehicle fleet management, time handling, UI sections
RISK: 🔴 CRITICAL - Deeply embedded in provider panel
```

### `esnaf_detay_ekrani.dart` - Provider Detail Screen
```dart
TAKSI INTEGRATIONS:
├─ Line 84: void _ajandaDinle() {
             if (widget.esnaf.kategori != 'Taksi') return;
│
├─ Line 236: bool isTaksi = _guncelEsnaf.kategori == 'Taksi';
│
├─ Line 337: if (_guncelEsnaf.kategori == 'Taksi')
             IconButton(tooltip: 'Taksi kullanım kılavuzu', ...)
│
├─ Line 414: Text(_guncelEsnaf.kategori == 'Taksi' ? 
             "Gündüz Mesai Saatleri" : "Çalışma Programı ...", ...)
│
├─ Line 449: if (_guncelEsnaf.araclar.isNotEmpty && 
             (_guncelEsnaf.kategori == 'Taksi' || ...)) {
│
├─ Line 472: if (_guncelEsnaf.kategori == 'Taksi') {
             // Vehicle hourly visibility logic
│
├─ Line 494: if (_guncelEsnaf.kategori == 'Taksi') {
             // Vehicle filtering logic
│
├─ Line 803: if (!_guncelEsnaf.randevuAlinmasin && 
             _guncelEsnaf.kategori != 'Taksi' && ...)
│
├─ Line 1093: if (_guncelEsnaf.kategori == 'Taksi')
             Padding(...)
│
├─ Line 1110: if (!_guncelEsnaf.ajandayiKendimAyarlayacagim || 
              _guncelEsnaf.kategori == 'Taksi') {
│
└─ Line 1143: floatingActionButton: _guncelEsnaf.kategori == 'Taksi'
              ? SosButonu(...) : ...

TOTAL: 8+ kategori checks
RISK: 🔴 HIGH - Integrated into detail view logic
```

### `ana_ekran.dart` - Main Home Screen
```dart
TAKSI INTEGRATIONS:
├─ Line 15-16: import 'taksi/taksi_mod_secim_ekrani.dart'
├─ Line 15-16: import 'taksi/taksi_yonlendirme.dart'
│
├─ Category icon handling:
│   case 'Taksi': return Icons.local_taxi;
│
├─ Category color handling:
│   case 'Taksi': return Colors.amber;
│
RISK: 🟡 MEDIUM - Only for UI rendering of category
```

### `giris_secim_ekrani.dart` - Login Selection
```dart
TAKSI INTEGRATIONS:
├─ Line 16: import 'taksi/taksi_mod_secim_ekrani.dart';
│
RISK: 🟡 MEDIUM - Only imports for route handling
```

---

## 4. Model Dependencies

### `EsnafModeli` (Core Model)
```dart
TAKSI-SPECIFIC FIELDS (used throughout Taksi module):
├─ kategori: String                    // Used for kategori == 'Taksi' checks
├─ araclar: List<Map>                 // Vehicle list (Taksi-specific)
├─ aracOdakliSistem: bool            // Vehicle-focused mode
├─ istirahatliAraclariGizle: bool    // Hide off-duty vehicles
├─ konumDogrulamaMesafesi: double     // Location verification distance
├─ bakimTemizlikSuresi: int          // Maintenance time
├─ bakimSurecindeRandevuAlinsin: bool // Allow booking during maintenance
├─ akilliTakipModu: bool              // Smart tracking for rentals
├─ akilliTakipSuresi: int             // Smart tracking duration
├─ saatlikUzatmaUcreti: double       // Hourly extension fee
│
RISK: 🔴 TIGHT COUPLING - Taksi-specific fields in shared model
```

### `RandevuModeli` (Core Model)
```dart
TAKSI-SPECIFIC FIELDS:
├─ nereden: String?                   // Taxi pickup location
├─ nereye: String?                    // Taxi destination
│
RISK: 🟡 ACCEPTABLE - Only 2 fields, minimal impact
```

### `TaksiTalepModeli` (Taksi-Specific)
```dart
USAGE:
├─ taksi_yonetici_ekrani.dart         (Request management)
│
DEPENDENCIES:
├─ cloud_firestore only (GeoPoint, Timestamp)
│
STATUS: ✅ INDEPENDENT
```

---

## 5. Circular Dependency Check

```
Dependency Graph:
┌─────────────────┐
│  taksi_screens  │
└────────┬────────┘
         │
         ├──────────> EsnafModeli ──────────────┐
         │                                      │
         ├──────────> RandevuModeli             │
         │                                      │
         ├──────────> FirestoreServisi ─────────┤──> cloud_firestore
         │                                      │
         ├──────────> BildirimServisi ──────────┤──> OneSignalServisi
         │                                      │
         ├──────────> KonumServisi ─────────────┤──> geolocator
         │                                      │
         └──────────> TaksiServisi ─────────────┘

Circular Dependencies: ❌ NONE FOUND ✅

All dependencies flow outward. No bidirectional imports.
No module imports from taksi_screens back to core.
```

---

## 6. Dependency Injection Points

### Current State (Tightly Coupled)
```dart
// In taksi_musteri_ekrani.dart
final FirestoreServisi _firestoreServisi = FirestoreServisi();
final KonumServisi _konumServisi = KonumServisi();

// Problem: Hard-coded instantiation
// Solution: Use constructor injection
```

### Recommended Refactoring
```dart
class TaksiMusteriEkrani extends StatefulWidget {
  final FirestoreServisi firestoreServisi;
  final KonumServisi konumServisi;
  final BildirimServisi bildirimServisi;
  
  const TaksiMusteriEkrani({
    required this.firestoreServisi,
    required this.konumServisi,
    required this.bildirimServisi,
    // ... other parameters
  });
}

// Usage:
TaksiMusteriEkrani(
  firestoreServisi: injector.get<FirestoreServisi>(),
  konumServisi: injector.get<KonumServisi>(),
  bildirimServisi: injector.get<BildirimServisi>(),
  // ...
)
```

---

## 7. Cross-Module Dependencies Summary

| From | To | Type | Impact |
|------|----|----|--------|
| `ana_ekran.dart` | `taksi_mod_secim_ekrani.dart` | ✅ Import | Low - Feature selection only |
| `giris_secim_ekrani.dart` | `taksi_mod_secim_ekrani.dart` | ✅ Import | Low - Login flow only |
| `esnaf_paneli.dart` | `taksi_cizelge_ekrani.dart` | ⚠️ Conditional Import | Medium - Panel integration |
| `esnaf_paneli.dart` | `taksi_parametre_ekrani.dart` | ⚠️ Conditional Import | Medium - Settings routing |
| `esnaf_ajanda_ekrani.dart` | `taksi_cizelge_ekrani.dart` | ⚠️ Conditional Render | High - Schedule logic |
| `randevu_ekrani.dart` | (no direct imports) | ✅ Conditional Logic | High - 12+ checks in code |
| `esnaf_detay_ekrani.dart` | `taksi_yonlendirme.dart` | ✅ Import | Low - Navigation only |
| `taksi_durak_takip_ekrani.dart` | `surucu_dogrulama_ekrani.dart` | 🔴 Cross-Module | **MODERATE - Non-Taksi module** |
| `taksi_durak_takip_ekrani.dart` | `surucu_profil_detay_ekrani.dart` | 🔴 Cross-Module | **MODERATE - Non-Taksi module** |

---

## 8. File-by-File Extractability Score

| File | Size | Extractable? | Effort | Notes |
|------|------|--------------|--------|-------|
| `taksi_rehber_ekrani.dart` | 16.8K | ✅ 10/10 | Low | No dependencies |
| `taksi_ana_ekrani.dart` | 2.7K | ✅ 10/10 | Low | No dependencies |
| `taksi_bildirim_ekrani.dart` | 426B | ✅ 10/10 | Low | UI only |
| `taksi_parametre_ekrani.dart` | 8.2K | ✅ 8/10 | Low | 1 service dependency |
| `taksi_yonetici_ekrani.dart` | 6.4K | ✅ 7/10 | Low | Services + models |
| `taksi_randevu_ekrani.dart` | 22K | 🟡 6/10 | Medium | 4 service dependencies |
| `taksi_musteri_ekrani.dart` | 40.8K | 🟡 5/10 | Medium | 4 service dependencies |
| `taksi_cizelge_ekrani.dart` | 48.9K | 🟡 4/10 | High | Integrated with parent |
| `taksi_durak_takip_ekrani.dart` | 28.1K | 🟡 3/10 | High | Cross-module dependencies |
| `taksi_mod_secim_ekrani.dart` | 5.4K | 🔴 2/10 | Very High | Navigation hub |
| `taksi_yonlendirme.dart` | 963B | 🔴 1/10 | Very High | Category router |

**Average Extractability: 5.5/10** - Moderate difficulty with significant refactoring needed

---

## 9. Recommended Extraction Strategy

### Step 1: Create Abstract Interfaces
```dart
// almely_core/lib/abstractions/category_handler.dart
abstract class CategoryHandler {
  bool canHandle(String kategori);
  Widget? getDetailScreen(EsnafModeli esnaf, String? tel);
  Widget? getBookingScreen(EsnafModeli esnaf, String? tel);
  String? getCustomLabel(String key, EsnafModeli esnaf);
}
```

### Step 2: Implement in Taksi
```dart
// taksi_feature/lib/taksi_category_handler.dart
class TaksiCategoryHandler implements CategoryHandler {
  @override
  bool canHandle(String kategori) => kategori == 'Taksi';
  
  @override
  Widget? getDetailScreen(EsnafModeli esnaf, String? tel) 
    => TaksiMusteriEkrani(esnaf: esnaf, kullaniciTel: tel);
}
```

### Step 3: Register Handlers
```dart
// main.dart
final categoryHandlers = [
  TaksiCategoryHandler(),
  KuaforCategoryHandler(),
  // ... other handlers
];

final handlerRegistry = CategoryHandlerRegistry(categoryHandlers);
```

### Step 4: Replace Checks
```dart
// Before:
if (esnaf.kategori == 'Taksi') {
  return TaksiMusteriEkrani(...);
}

// After:
final handler = handlerRegistry.findHandler(esnaf.kategori);
return handler?.getDetailScreen(esnaf, tel) 
  ?? EsnafDetayEkrani(esnaf: esnaf);
```

---

## Conclusion

**Overall Dependency Assessment:**
- 🔴 **Critical**: 2 files (taksi_yonlendirme, taksi_mod_secim_ekrani) - navigation routers
- 🔴 **High**: 5 files - deep integration with core screens
- 🟡 **Medium**: 3 files - moderate service dependencies  
- ✅ **Low**: 1 file - independent

**Extraction Complexity: HIGH**
- Requires creating shared `almely_core` package
- Requires refactoring 60+ kategori checks
- Requires implementing handler/plugin architecture
- Estimated effort: 2-3 weeks

**Recommendation: Proceed with extraction using Handler Pattern**
