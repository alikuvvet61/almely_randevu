import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // [YENİ] kIsWeb için gerekli
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
  static bool _isSyncing = false; // Senkronizasyon kilidi

  static Future<void> initialize({BuildContext? context}) async {
    await OneSignalServisi.initialize(context: context);
  }

  /// [YENİ] Giriş kontrolleri ve kullanıcı bilgilendirme
  static Future<void> girisKontrolleri(String telefon, BuildContext context, {bool esnafMi = false, String? esnafId}) async {
    // 1. "Hoşgeldiniz..." mesajını ekranın ORTASINDA göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              esnafMi
                ? "Hoşgeldiniz\nBildirim kontrolleri yapılıyor.\nLütfen Bekleyiniz."
                : "Hoşgeldiniz\nBildirimleriniz gözden geçiriliyor.\nLütfen Bekleyiniz.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    // 2. Arka planda senkronizasyonu başlat
    // [HATA AYIKLAMA]: Sonucu açıkça loglayalım
    debugPrint("🚀 Senkronizasyon Başlatılıyor (Tel: $telefon)...");
    final sonuc = await syncAkilliTakipBildirimleri(telefon, context, esnafMi: esnafMi, esnafId: esnafId);
    debugPrint("🏁 Senkronizasyon Bitti. Sonuç: $sonuc");

    // 3. Diyaloğu kapat (context hala mounted ise)
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 4. Sonuca göre (özellikle ALICI_YOK veya hiç randevu olmama durumu) uyarı göster
    // [YENİ]: Sadece Web üzerinde ALICI_YOK uyarısı gösterilsin (Telefonda zaten mühürleme yapılıyor)
    if (sonuc == "ALICI_YOK" && context.mounted && kIsWeb) {
      debugPrint("⚠️ ALICI_YOK Diyaloğu Tetikleniyor...");
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
          title: const Text("Bildirim Uyarısı", textAlign: TextAlign.center),
          content: Text(
            esnafMi
              ? "Hoşgeldiniz\nBildirim kontrollerinin yapılabilmesi için\nTelefonunuzdan giriş yapmalısınız"
              : "Hoşgeldiniz\nBildirimlerinizin telefonunuza gelebilmesi için\nTelefonunuzdan giriş yapmalısınız",
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("TAMAM"),
              ),
            ),
          ],
        ),
      );
    }
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

  static Future<String?> syncAkilliTakipBildirimleri(String telefon, BuildContext? context, {bool esnafMi = false, String? esnafId}) async {
    if (_isSyncing) return "BUSY";
    _isSyncing = true;
    try {
      final simdi = DateTime.now();
      final bugunSifir = DateTime(simdi.year, simdi.month, simdi.day);
      String temizGirisTel = _numaraTemizle(telefon);
      
      _syncedIds.clear();

      await Future.delayed(const Duration(seconds: 1));

      final snap = await _db.collection('randevular')
          .where('durum', whereIn: ['Onaylandı', 'Onay bekliyor'])
          .get();

      if (snap.docs.isEmpty) {
        // [KRİTİK]: Randevu yoksa bile mühürleme kontrolü yapmalıyiz
        bool aliciVar = await OneSignalServisi.aliciVarMi(telefon);
        return aliciVar ? "OK" : "ALICI_YOK";
      }

      String? hedefEsnafId = esnafId;
      int onarilanSayisi = 0;
      bool aliciYokHatasiVar = false;

      for (var doc in snap.docs) {
        final r = RandevuModeli.fromFirestore(doc);

        if (r.tarih.isBefore(bugunSifir)) continue;

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

         // --- [REVİZE] KARŞILIKLI KONTROL MANTIĞI ---
         bool kendisiIcinUzatmaYasak = false;

         // Aynı esnaf, aynı kanal (araç) ve aynı gün için TÜM AKTİF randevuları al (Onaylı veya Bekleyen)
         final tumRandevular = snap.docs
             .map((d) => RandevuModeli.fromFirestore(d))
             .where((randevu) =>
                randevu.esnafId == r.esnafId &&
                randevu.randevuKanali == r.randevuKanali &&
                randevu.tarih.year == r.tarih.year &&
                randevu.tarih.month == r.tarih.month &&
                randevu.tarih.day == r.tarih.day &&
                (randevu.durum == 'Onaylandı' || randevu.durum == 'Onay bekliyor'))
             .toList();

         for (var diger in tumRandevular) {
           if (diger.id == r.id) continue;

           final digerBaslangic = DateTime(
               diger.tarih.year, diger.tarih.month, diger.tarih.day,
               int.parse(diger.saat.split(':')[0]),
               int.parse(diger.saat.split(':')[1]));
           final digerBitis = digerBaslangic.add(Duration(minutes: diger.sure));

           // 1. ÖNÜNDEKİ randevuyu kontrol et (r'den önce olan)
           // Eğer bizim randevumuz (r), önceki randevunun (diger) uzamasını engelliyorsa
           if (digerBaslangic.isBefore(baslangic)) {
             // Boşluk kontrolü: Önceki bitiş + minRandevuSuresi bizim başlangıcı geçiyor mu?
             final minBoslukSonu = digerBitis.add(Duration(minutes: esnaf.minimumRandevuSuresi));
             if (baslangic.isBefore(minBoslukSonu)) {
               // Önceki randevunun uzatmasını İPTAL ET
               if (diger.uzatmaBildirimId != null) {
                 final bool iptal = await OneSignalServisi.bildirimIptalEt(diger.uzatmaBildirimId!);
                 if (iptal) {
                   await _db.collection('randevular').doc(diger.id).update({'uzatmaBildirimId': null});
                   debugPrint("🗑️  Önceki Randevu (${diger.id}) Uzatması İptal: Çünkü ${r.id} aradaki boşluğu kapatıyor.");
                 }
               }
             }
           }

           // 2. ARKASINDAKİ randevuyu kontrol et (r'den sonra olan)
           // Eğer arkadaki randevu (diger), bizim (r) uzamamızı engelliyorsa
           if (digerBaslangic.isAfter(bitis) || digerBaslangic.isAtSameMomentAs(bitis)) {
             final minBoslukSonu = bitis.add(Duration(minutes: esnaf.minimumRandevuSuresi));
             if (digerBaslangic.isBefore(minBoslukSonu)) {
               kendisiIcinUzatmaYasak = true;
               debugPrint("🚫 Kendi Uzatması Yasak: Çünkü ${diger.id} arkada boşluk bırakmıyor.");
             }
           }
         }

         // [İPTAL] Eğer arkada randevu varsa ve kendi uzatma bildirimi planlanmışsa, iptal et
         if (kendisiIcinUzatmaYasak && r.uzatmaBildirimId != null) {
            final bool iptalBasarili = await OneSignalServisi.bildirimIptalEt(r.uzatmaBildirimId!);
            if (iptalBasarili) {
              await doc.reference.update({'uzatmaBildirimId': null});
            }
         }

         // [ALICI_YOK KONTROLÜ] Planlanmış olsa bile alıcıyı kontrol et (Mühürleme denetimi)
         if (!kendisiIcinUzatmaYasak && r.uzatmaBildirimId != null) {
            bool aliciVar = await OneSignalServisi.aliciVarMi(r.kullaniciTel);
            if (!aliciVar) aliciYokHatasiVar = true;
         }


        // 1. ESNAF İÇİN ONARMA (Kritik Gecikme Bildirimi)
        if (r.durum == 'Onaylandı') {
           final DateTime gecikmeZamani = bitis.add(const Duration(minutes: 1));
           if (gecikmeZamani.isAfter(simdi)) {

              // [PROFESYONEL]: Sadece arkasında müşteri bekliyorsa kritik alarm kur!
              RandevuModeli? siradakiRandevu;
              try {
                siradakiRandevu = tumRandevular.firstWhere((sr) {
                  final srBas = DateTime(sr.tarih.year, sr.tarih.month, sr.tarih.day,
                      int.parse(sr.saat.split(':')[0]), int.parse(sr.saat.split(':')[1]));
                  // Mevcut randevu bittikten sonraki 2 saat içinde başka randevu var mı?
                  return srBas.isAfter(bitis) && srBas.isBefore(bitis.add(const Duration(hours: 2)));
                });
              } catch (_) {}

              if (siradakiRandevu != null) {
                // [VERİMLİLİK]: Bildirim zaten varsa, tekrar kurup paneli kalabalık etme!
                if (r.gecikmeBildirimId == null) {
                  String? id = await OneSignalServisi.bildirimPlanla(
                    baslik: "🔴 KRİTİK GECİKME: ${siradakiRandevu.kullaniciAd} (${siradakiRandevu.saat}) BEKLİYOR!",
                    icerik: "${r.randevuKanali} plakalı aracın iade saati ($bitisSaatiString) geçti! Lütfen aracı teslim alınız.",
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
                  } else if (id == "ALICI_YOK") {
                    aliciYokHatasiVar = true;
                  }
                }
              } else {
                // Arkada müşteri yoksa varsa mevcut alarmı temizle (Gereksiz kalabalık yapmasın)
                if (r.gecikmeBildirimId != null) {
                  await OneSignalServisi.bildirimIptalEt(r.gecikmeBildirimId!);
                  await doc.reference.update({'gecikmeBildirimId': null});
                }
                debugPrint("ℹ️ Gecikme Alarmı İptal/Kurulmadı: ${r.randevuKanali} arkasında bekleyen müşteri yok.");
              }
           }
        }

          // 2. MÜŞTERİ İÇİN ONARMA (Uzatma Bildirimi)
          if (!kendisiIcinUzatmaYasak) {
             final DateTime uzatmaZamani = bitis.subtract(Duration(minutes: esnaf.akilliTakipSuresi));
             if (uzatmaZamani.isAfter(simdi)) {
                // [VERİMLİLİK]: Bildirim zaten kuruluysa dokunma!
                if (r.uzatmaBildirimId == null) {
                  String? id = await OneSignalServisi.bildirimPlanla(
                    baslik: "Kiralama Süreniz Doluyor",
                    icerik: "${r.randevuKanali} için kiralama süreniz ${esnaf.akilliTakipSuresi} dakika sonra bitiyor. Uzatmak ister misiniz?",
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
                  } else if (id == "ALICI_YOK") {
                    aliciYokHatasiVar = true;
                  }
                }
             }
          }
      }

      if (onarilanSayisi > 0 && context != null && context.mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text("Bildirimleriniz oluştu ✅"),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      }

      // [YENİ] Eğer randevu olmasına rağmen hiiiç bildirim planlanmadıysa ve alıcı yoksa da uyaralım
      if (onarilanSayisi == 0 && aliciYokHatasiVar == false) {
        // En az bir randevu için planlama teşebbüsü oldu mu kontrol et
        // (Eğer randevu varsa ama hepsi geçmişse veya uzatma yasağına takılmışsa buraya girer)
      }

      return aliciYokHatasiVar ? "ALICI_YOK" : "OK";
    } catch (e) {
      debugPrint("Senkronizasyon Hatası: $e");
      return "HATA";
    } finally {
      _isSyncing = false;
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
