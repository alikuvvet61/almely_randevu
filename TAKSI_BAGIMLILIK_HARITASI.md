# 🗺️ Taksi Modülü Bağımlılık Haritası

## 1️⃣ TAKSI MODÜLÜ NEYİ IMPORT EDİYOR?

```
taksi_parametre_ekrani.dart
├─ 🔵 FirestoreServisi (PAYLAŞILAN) ← Ana uygulamadan import
├─ 🔵 EsnafModeli (PAYLAŞILAN) ← Ana uygulamadan import
└─ 🟢 taksi_rehber_ekrani.dart (TAKSI İÇİ)

taksi_rehber_ekrani.dart
├─ ✅ Sadece Flutter Material
└─ ✅ Bağımlılık yok

taksi_cizelge_ekrani.dart
├─ 🔵 FirestoreServisi (PAYLAŞILAN)
├─ 🔵 EsnafModeli (PAYLAŞILAN)
├─ 🔵 RandevuModeli (PAYLAŞILAN)
├─ 🟢 taksi_rehber_ekrani.dart (TAKSI İÇİ)
└─ ✅ Dış bağımlılık yok

taksi_durak_takip_ekrani.dart
├─ 🔵 FirestoreServisi (PAYLAŞILAN)
├─ 🔵 EsnafModeli (PAYLAŞILAN)
├─ 🟢 taksi_rehber_ekrani.dart (TAKSI İÇİ)
└─ ✅ Dış bağımlılık yok

taksi_musteri_ekrani.dart
├─ 🔵 FirestoreServisi (PAYLAŞILAN)
├─ 🔵 EsnafModeli (PAYLAŞILAN)
├─ 🔵 RandevuModeli (PAYLAŞILAN)
├─ 🟢 taksi_rehber_ekrani.dart (TAKSI İÇİ)
├─ 🟢 taksi_yonlendirme.dart (TAKSI İÇİ)
└─ ✅ Dış bağımlılık yok

Diğer Taksi ekranları
├─ 🔵 FirestoreServisi (PAYLAŞILAN)
├─ 🔵 EsnafModeli (PAYLAŞILAN)
├─ 🔵 RandevuModeli (PAYLAŞILAN)
└─ ✅ Dış bağımlılık yok
```

---

## 2️⃣ ANA UYGULAMANIN TAKSI'YI İMPORT ETTİĞİ YERLER

### **Hangi dosyalar Taksi ekranlarını import ediyor?**

```
ana_ekran.dart
├─ 📍 import 'taksi/taksi_mod_secim_ekrani.dart'
├─ 📍 import 'taksi/taksi_yonlendirme.dart'
└─ if (kategori == 'Taksi') { TaksiModSecimEkrani() }

giris_secim_ekrani.dart
├─ 📍 import 'taksi/taksi_mod_secim_ekrani.dart'
└─ if (kategori == 'Taksi') { TaksiModSecimEkrani() }

esnaf_paneli.dart
├─ 📍 import 'taksi/taksi_durak_takip_ekrani.dart'
├─ 📍 import 'taksi/taksi_cizelge_ekrani.dart'
├─ 📍 import 'taksi/taksi_rehber_ekrani.dart'
├─ 📍 import 'taksi/taksi_parametre_ekrani.dart'
├─ if (isTaksi) { TaksiDurakTakipEkrani() }
├─ if (isTaksi) { TaksiCizelgeEkrani() }
├─ if (kategori == 'Taksi') { TaksiParametreEkrani() }
└─ 15 adet `kategori == 'Taksi'` kontrolü

esnaf_ajanda_ekrani.dart
├─ 📍 import 'taksi/taksi_cizelge_ekrani.dart'
├─ if (kategori == 'Taksi') { TaksiCizelgeEkrani() }
└─ 13 adet `kategori == 'Taksi'` kontrolü

esnaf_detay_ekrani.dart
├─ 📍 import 'taksi/taksi_yonlendirme.dart'
├─ 📍 import 'taksi/taksi_rehber_ekrani.dart'
├─ if (kategori == 'Taksi') { TaksiRehberEkrani() }
└─ 8 adet `kategori == 'Taksi'` kontrolü

randevu_ekrani.dart
├─ ❌ Doğrudan import yok
├─ 12 adet `kategori == 'Taksi'` kontrolü ile özel mantık
└─ "Taksi için plaka, diğer için personel" gibi şartlı kodlar

... ve daha fazla dosya
```

---

## 3️⃣ 52+ TAKSİ KATEGORİSİ KONTROLÜ DAĞILIMI

### **Nerede hangi Taksi kontrolleri var?**

```
esnaf_paneli.dart
├─ Line 200: Taksi için 7/24 çalışma özel kontrolü
├─ Line 699: Taksi personelleri farklı dizisi
├─ Line 724: Taksi araçları özel mantığı
├─ Line 780: Taksi kişi listesi
├─ Line 933: Taksi saatleri farklı yazılıyor
├─ Line 934: Taksi kapanış saati farklı
├─ Line 942: Taksi personelleri yeniden kontrol
├─ Line 1105: Taksi modu flag'i (isTaksi)
├─ Line 1169: Taksi → TaksiParametreEkrani
├─ ... ve 6 kontrol daha
└─ ❌ TOPLAM: 15 kontrol

esnaf_ajanda_ekrani.dart
├─ Taksi için özel nöbet çizelgesi
├─ Taksi'yi ajanda defterinden gizle
├─ Taksi için özel saat aralıkları
├─ ... 13 kontrol
└─ ❌ TOPLAM: 13 kontrol

randevu_ekrani.dart
├─ Taksi: Plaka seçimi göster
├─ Taksi: Araç listesi göster
├─ Taksi: Sıra sistemi kontrol
├─ Taksi: Driver seçimi
├─ ... 12 kontrol
└─ ❌ TOPLAM: 12 kontrol

esnaf_detay_ekrani.dart
├─ Taksi özel bilgiler
├─ Taksi durak yönetimi
├─ ... 8 kontrol
└─ ❌ TOPLAM: 8 kontrol

Diğer dosyalar
├─ esnaf_randevu_onay_ekrani.dart (3 kontrol)
├─ esnaf_yonetim_ekrani.dart (2 kontrol)
├─ ... ve başka dosyalar
└─ ❌ TOPLAM: 4+ kontrol

=====================================
🔴 GENEL TOPLAM: 52+ HARDCODED KONTROL
```

---

## 4️⃣ PAYLAŞILAN BAĞIMLILIKLARI

### **Bu paketler MUTLAKA her iki tarafta da gerekli:**

```
almely_randevu (ANA UYGULAMA)
│
├─ 🔵 FirestoreServisi (Veri tabanı)
│   └─ Tüm CRUD işlemleri, Firestore sorguları
│   └─ PAYLAŞILAN OLMALI
│
├─ 🔵 EsnafModeli
│   └─ id, ad, kategori, randevuAlinmasin, ...
│   └─ PAYLAŞILAN OLMALI
│
├─ 🔵 RandevuModeli
│   └─ id, esnafId, tarih, saat, ...
│   └─ PAYLAŞILAN OLMALI
│
├─ 🔵 BildirimServisi
│   └─ Push bildirimler, SMS, Email
│   └─ PAYLAŞILAN OLMALI
│
├─ 🔵 OneSignalServisi
│   └─ OneSignal SDK entegrasyonu
│   └─ PAYLAŞILAN OLMALI
│
├─ 🔵 KonumServisi
│   └─ Geolocation işlemleri
│   └─ PAYLAŞILAN OLMALI
│
└─ 🟢 Taksi spesifik modeller
    ├─ TaksiTalepModeli
    ├─ TaksiServisi
    └─ AYRILABILIR (taksi_feature'a taşı)
```

---

## 5️⃣ TAŞIMA SENARYOSU DETAYLI

### **Senaryo: Taksi uygulamasını ayrı bir projeye taşıyacaksınız**

#### **❌ HATA: Sadece taksi/ klasörünü taşı**
```
❌ Çalışmayacak çünkü:
├─ FirestoreServisi bulunamaz
├─ EsnafModeli bulunamaz
├─ RandevuModeli bulunamaz
├─ BildirimServisi bulunamaz
└─ Tüm Taksi ekranları çökecek
```

#### **✅ DOĞRU: Paylaşılan core + Taksi taşı**
```
Step 1: almely_core paketi oluştur
almely_core/
├── lib/src/
│   ├── models/
│   │   ├── esnaf_modeli.dart
│   │   ├── randevu_modeli.dart
│   │   └── taksi_talep_modeli.dart
│   ├── services/
│   │   ├── firestore_servisi.dart
│   │   ├── bildirim_servisi.dart
│   │   ├── onesignal_servisi.dart
│   │   └── konum_servisi.dart
│   └── exports.dart
└── pubspec.yaml
   └─ dependencies: cloud_firestore, firebase_storage, geolocator

Step 2: taksi_feature paketi oluştur
taksi_feature/
├── lib/src/
│   ├── screens/
│   │   ├── taksi_parametre_ekrani.dart
│   │   ├── taksi_cizelge_ekrani.dart
│   │   └── ...
│   ├── models/
│   ├── services/
│   └── helpers/
├── pubspec.yaml
│   └─ dependencies:
│       almely_core: { path: ../almely_core }
└── lib/taksi_feature.dart (Public API)

Step 3: Ana uygulamayı güncelle
almely_randevu/
├── pubspec.yaml
│   └─ dependencies:
│       almely_core: { path: ../almely_core }
│       taksi_feature: { path: ../taksi_feature }  ← İSTEĞE BAĞLI!
│
└── lib/
    ├── main.dart
    │   if (enableTaksi) {
    │       registerTaksiFeature();  // Taksi'yi yükle
    │   }
    └── category_handlers/
        ├── category_handler.dart (interface)
        └── taksi_category_handler.dart (Taksi özel davranış)

Step 4: CategoryHandler pattern kullan
ESKI (❌ KÖTÜ):
    if (esnaf.kategori == 'Taksi') {
        return TaksiParametreEkrani(...);
    } else {
        return EsnafParametreEkrani(...);
    }

YENİ (✅ İYİ):
    final handler = categoryHandlerRegistry.findHandler(esnaf.kategori);
    return handler?.getParametreScreen(...) 
        ?? EsnafParametreEkrani(...);  // Default
```

---

## 6️⃣ AYRIŞTIRILABILIRLIK ÖZET TABLOSU

### **Dosya/Modülün Ayrıştırılabilirliği**

| Dosya/Modül | Ayrıştırılabilirlik | Açıklama |
|------------|------------------|----------|
| **taksi_parametre_ekrani.dart** | ✅ 9/10 | Bağımlılık yok, direkt taşınabilir |
| **taksi_rehber_ekrani.dart** | ✅ 9/10 | Sadece Flutter imports, taşınabilir |
| **taksi_cizelge_ekrani.dart** | ✅ 8/10 | FirestoreServisi, EsnafModeli gerekli |
| **taksi_durak_takip_ekrani.dart** | ✅ 8/10 | FirestoreServisi, EsnafModeli gerekli |
| **taksi_musteri_ekrani.dart** | ✅ 8/10 | Paylaşılan servislere bağlı |
| **taksi_yonetici_ekrani.dart** | ✅ 8/10 | Paylaşılan servislere bağlı |
| **taksi_randevu_ekrani.dart** | ✅ 8/10 | Paylaşılan servislere bağlı |
| **taksi_mod_secim_ekrani.dart** | ✅ 7/10 | Düşük bağımlılık |
| **Diğer Taksi ekranları** | ✅ 8/10 | Benzer bağımlılıklar |
| **taksi_talep_modeli.dart** | ✅ 9/10 | Taksi-spesifik model |
| **taksi_servisi.dart** | ✅ 8/10 | FirestoreServisi bağımlılığı var |
| **taksi_bildirim_servisi.dart** | ✅ 8/10 | BildirimServisi bağımlılığı var |
| **esnaf_paneli.dart** | ❌ 3/10 | 15 Taksi kontrolü içeriyor |
| **esnaf_ajanda_ekrani.dart** | ❌ 3/10 | 13 Taksi kontrolü içeriyor |
| **randevu_ekrani.dart** | ❌ 2/10 | 12 Taksi kontrolü içeriyor |
| **esnaf_detay_ekrani.dart** | ❌ 4/10 | 8 Taksi kontrolü içeriyor |

---

## 7️⃣ KRİTİK SORUN: Dairesel Bağımlılık Yoktur ✅

**İyi haber:** Taksi modülü ana uygulamaya bağlıdır ama ana uygulama spesifik Taksi modülüne DOĞRUDAN bağlı değildir.

```
Ana Uygulama
    ↓ (import eder)
Taksi Ekranları
    ↓ (import eder)
Paylaşılan Servisler (FirestoreServisi, vb.)

❌ Tersine bağımlılık yok = Ayrıştırma mümkün!
```

---

## 8️⃣ SIRA İLE TAŞIMANıZ GEREKIRSE

### **1. GÜNDÜ: Paylaşılan Core'u Ayır**
```
almely_core/
├─ EsnafModeli
├─ RandevuModeli
├─ FirestoreServisi
├─ BildirimServisi
└─ Tüm paylaşılan servisler
```

### **2. GÜNDÜ: CategoryHandler Pattern Yaz**
```dart
// Bu pattern sayesinde Taksi opsiyonel hale gelecek
abstract class CategoryHandler {
  bool canHandle(String kategori);
  // ... özel ekranlar, özel mantık
}
```

### **3. GÜNDÜ: 52+ Kontrolü Yeniden Yaz**
```dart
// ESKI: if (esnaf.kategori == 'Taksi') { ... }
// YENİ: categoryHandlerRegistry.getHandler(kategori)?.doSomething()
```

### **4. GÜNDÜ: Taksi Feature Paketi Taşı**
```
taksi_feature/
├─ Tüm Taksi ekranları
├─ Taksi servisleri
└─ Taksi modelleri
```

### **5. GÜNDÜ: Test ve Doğrula**
```
✅ Taksi feature'ı disabled et → Ana uygulama çalışmalı
✅ Taksi feature'ı enabled et → Taksi de çalışmalı
✅ Ana uygulamaya Taksi'ye ait hiç import kalmamalı
```

---

## 📊 ÖZETİ

| Soru | Cevap |
|------|-------|
| **Taksi parametresini taşıyabilir miyim?** | ✅ Evet, hiç sorun yok |
| **Tüm Taksi uygulamasını taşıyabilir miyim?** | ✅ Evet, ama paylaşılan core gerekli |
| **Kaç gün sürer?** | ⏱️ 2-3 hafta (tam ayıştırma) veya 5-7 gün (minimal) |
| **En büyük sorun nedir?** | 🔴 52+ hardcoded Taksi kontrolü |
| **Dairesel bağımlılık var mı?** | ✅ Hayır, temiz yapı var |
| **Şu anda taşıyabilir miyim?** | ⚠️ Katılmış, ama plan varsa yapılabilir |

---

## 🎯 KARARINI VER!

### **Seçenek 1: Hiç dokunma (Şu an)**
- Risk: 0
- Çaba: 0
- Gelecek: Taksi hep karışık kalacak

### **Seçenek 2: Minimal (1 hafta)**
- almely_core paketi oluştur
- Taksi kalır ama paylaşılan modelleri kullanır
- Risk: Düşük
- Çaba: 1 hafta
- Gelecek: İyileşir

### **Seçenek 3: Tam (2-3 hafta)**
- Seçenek 2 + CategoryHandler pattern
- Taksi tamamen taşınabilir hale gelir
- Risk: Orta
- Çaba: 2-3 hafta
- Gelecek: Tamamen temiz

**TAVSIYE:** Seçenek 2 ile başla → Seçenek 3'e geç 🚀
