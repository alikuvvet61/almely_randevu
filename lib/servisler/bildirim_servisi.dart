import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'onesignal_servisi.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/esnaf_modeli.dart';

class BildirimServisi {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Set<String> _syncedIds = {}; 
  static StreamSubscription? _randevuAboneligi; // Mevcut aboneliği takip etmek için

  static Future<void> initialize({BuildContext? context}) async {
    await OneSignalServisi.initialize(context: context);
  }

  static Future<void> tokenKaydet(String telefon, {String? role, BuildContext? context}) async {
    await OneSignalServisi.kullaniciyiKaydet(telefon, role: role, context: context);
  }

  static Future<void> bildirimGonder({
    required String baslik,
    required String icerik,
    required String kullaniciTel,
    BuildContext? context,
  }) async {
    await OneSignalServisi.bildirimGonderAnlik(
      baslik: baslik,
      icerik: icerik,
      telefon: kullaniciTel,
      context: context,
    );
  }

  static String _numaraTemizle(String tel) {
    String temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (temiz.length > 10) temiz = temiz.substring(temiz.length - 10);
    return temiz;
  }

  static Future<void> syncAkilliTakipBildirimleri(String telefon, BuildContext? context, {bool esnafMi = false, String? esnafId}) async {
    try {
      final simdi = DateTime.now();
      final bugunSifir = DateTime(simdi.year, simdi.month, simdi.day);
      String temizGirisTel = _numaraTemizle(telefon);
      
      _syncedIds.clear();

      // [GÜNCELLEME] OneSignal aboneliğinin oturması için kısa bir güvenli bekleme ekliyoruz.
      // Chrome'dan alınıp telefona geçildiğinde bu bekleme hayati önem taşır.
      await Future.delayed(const Duration(seconds: 1));

      // [GÜNCELLEME] Sadece 'Onaylandı' değil, 'Onay bekliyor' durumundaki randevuları da kontrol etmeliyiz.
      // Çünkü Chrome'dan alınan randevular henüz onaylanmamış olsa bile bildirimlerinin (uzatma) planlanması gerekir.
      final snap = await _db.collection('randevular')
          .where('durum', whereIn: ['Onaylandı', 'Onay bekliyor'])
          .get();

      if (snap.docs.isEmpty) return;

      String? hedefEsnafId = esnafId;
      int onarilanSayisi = 0;

      for (var doc in snap.docs) {
        final r = RandevuModeli.fromFirestore(doc);

        if (r.tarih.isBefore(bugunSifir)) continue;

        // [MANTIK GÜNCELLEMESİ]: Eğer esnaf giriş yaptıysa sadece kendi dükkanındaki randevuları onarır.
        // Eğer MÜŞTERİ giriş yaptıysa, sadece kendi aldığı randevuları onarır.
        if (esnafMi) {
          if (r.esnafId != hedefEsnafId) continue;
        } else {
          if (_numaraTemizle(r.kullaniciTel) != temizGirisTel) continue;
        }

        final baslangic = DateTime(r.tarih.year, r.tarih.month, r.tarih.day,
            int.parse(r.saat.split(':')[0]), int.parse(r.saat.split(':')[1]));
        final bitis = baslangic.add(Duration(minutes: r.sure));
        final String bitisSaatiString = DateFormat('HH:mm').format(bitis);

        final esDoc = await _db.collection('esnaflar').doc(r.esnafId).get();
        if (!esDoc.exists) continue;
        final esnaf = EsnafModeli.fromFirestore(esDoc);

        if (!esnaf.akilliTakipModu) continue;

        // [OTOMATİK ONARMA]: Eksik bildirimleri planla
        
        // 1. ESNAF İÇİN ONARMA (Kritik Gecikme Bildirimi)
        // [PROFESYONEL]: Müşteri giriş yaptığında bile esnafın gecikme bildirimini kurabilmeli (Karşılıklı tam koruma)
        if (r.durum == 'Onaylandı' && r.gecikmeBildirimId == null) {
           final DateTime gecikmeZamani = bitis.add(const Duration(minutes: 1));
           if (gecikmeZamani.isAfter(simdi)) {
              String? id = await OneSignalServisi.bildirimPlanla(
                baslik: "🔴 KRİTİK GECİKME ALARMI",
                icerik: "${r.randevuKanali} plakalı aracın iade saati ($bitisSaatiString) geçti!",
                zaman: gecikmeZamani,
                telefon: esnaf.telefon,
                randevuId: r.id,
                ekVeri: {
                  'action': 'kritik_gecikme',
                  'tel': esnaf.telefon,
                  'randevuId': r.id,
                },
              );
              if (id != null && id != "ALICI_YOK") {
                await doc.reference.update({'gecikmeBildirimId': id});
                onarilanSayisi++;
              } else if (id == "ALICI_YOK" && esnafMi) {
                // Sadece esnaf kendisi girmişse ve abonelik yoksa retry yap (müşteri esnaf için retry yapamaz)
                Future.delayed(const Duration(seconds: 2), () {
                  syncAkilliTakipBildirimleri(telefon, context, esnafMi: esnafMi, esnafId: esnafId);
                });
                return;
              }
           }
        }

        // 2. MÜŞTERİ İÇİN ONARMA (Uzatma Bildirimi)
        if (r.uzatmaBildirimId == null) {
           final DateTime uzatmaZamani = bitis.subtract(Duration(minutes: esnaf.akilliTakipSuresi));
           if (uzatmaZamani.isAfter(simdi)) {
              String? id = await OneSignalServisi.bildirimPlanla(
                baslik: "Kiralama Süreniz Doluyor",
                icerik: "${r.randevuKanali} için süreniz bitmek üzere.Uzatmak ister misiniz?",
                zaman: uzatmaZamani,
                telefon: r.kullaniciTel,
                randevuId: r.id,
                ekVeri: {
                  'action': 'uzatma_ekrani',
                  'tel': r.kullaniciTel,
                  'randevuId': r.id,
                },
              );
              if (id != null && id != "ALICI_YOK") {
                await doc.reference.update({'uzatmaBildirimId': id});
                onarilanSayisi++;
              } else if (id == "ALICI_YOK" && !esnafMi) {
                // Sadece müşteri kendisi girmişse ve abonelik yoksa retry yap
                Future.delayed(const Duration(seconds: 2), () {
                  syncAkilliTakipBildirimleri(telefon, context, esnafMi: esnafMi, esnafId: esnafId);
                });
                return;
              }
           }
        }
      }

      if (onarilanSayisi > 0 && context != null) {
        // [PROFESYONEL MESAJ]: context.mounted kontrolü ve SnackBar'ın her durumda görünmesi için temizleme
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: const Text("Bildirimleriniz oluştu ✅"),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
        }
      }
    } catch (e) {
      debugPrint("Senkronizasyon Hatası: $e");
    }
  }

  static String? _mevcutDinlenenTel; // Hangi numaranın dinlendiğini takip et

  static void bildirimDinle(String telefon, {BuildContext? context}) {
    String temizTel = _numaraTemizle(telefon);
    
    // [YENİ] Eğer aynı numara zaten dinleniyorsa, boşuna yeni dinleyici açma
    if (_mevcutDinlenenTel == temizTel && _randevuAboneligi != null) {
      debugPrint("ℹ️  BildirimServisi: $temizTel zaten dinleniyor, işlem atlandı.");
      return;
    }

    // Farklı bir numara geldiyse veya dinleyici yoksa eskisini temizle ve başlat
    _randevuAboneligi?.cancel();
    _mevcutDinlenenTel = temizTel;

    debugPrint("🎧 BildirimServisi: $temizTel için dinleyici başlatılıyor...");
    _randevuAboneligi = _db.collection('randevular')
      .where('kullaniciTel', isEqualTo: temizTel)
      .snapshots()
      .listen((snap) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final data = change.doc.data() as Map<String, dynamic>;
            if (context != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Randevu Durumu Güncellendi: ${data['durum']}"), backgroundColor: Colors.blueAccent)
              );
            }
          }
        }
      });
  }

  static void servisiDurdur() {
    _randevuAboneligi?.cancel();
    _randevuAboneligi = null;
    _mevcutDinlenenTel = null;
  }
}
