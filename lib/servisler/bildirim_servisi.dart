// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // [YENİ] kIsWeb için gerekli
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../main.dart';
import 'onesignal_servisi.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/esnaf_modeli.dart';
import '../yardimcilar/hatirlatma_sablonlari.dart';
import 'taksi/taksi_iptal_bedeli.dart';

class BildirimServisi {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Set<String> _syncedIds = {}; 
  static StreamSubscription? _randevuAboneligi; // Mevcut aboneliği takip etmek için
  static bool _isSyncing = false; // Senkronizasyon kilidi
  static bool _isHatirlatmaSyncing = false;
  static bool _dialogOpen = false; // Aynı anda yalnızca bir modal olsun
  static final Set<String> _girisKontroluCalisiyor = {}; // Aynı telefon için çift çalışmayı engelle

  static Future<void> initialize({BuildContext? context}) async {
    await OneSignalServisi.initialize(context: context);
  }

  // Açık diyalog yoksa diyalog göstermek için yardımcı metot
  static void _safeShowDialog(BuildContext context, WidgetBuilder builder) {
    if (_dialogOpen) {
      debugPrint('ℹ️ BildirimServisi: Dialog zaten açık, yeni dialog atlandı.');
      return;
    }
    _dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: builder,
    ).then((_) {
      _dialogOpen = false;
      debugPrint('ℹ️ BildirimServisi: Dialog kapatıldı.');
    }).catchError((e) {
      _dialogOpen = false;
      debugPrint('❌ Dialog then hatası: $e');
    });
  }

  static void _safePopDialog(BuildContext context) {
    if (!_dialogOpen) return;
    try {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      debugPrint('❌ Dialog pop hatası: $e');
    }
    // _dialogOpen, showDialog.then geri çağırımında sıfırlanacak
  }

  /// [YENİ] Giriş kontrolleri ve kullanıcı bilgilendirme
  static Future<void> girisKontrolleri(String telefon, {BuildContext? context, bool esnafMi = false, String? esnafId}) async {
    final islemAnahtari = '${esnafMi ? 'esnaf' : 'musteri'}:$telefon:${esnafId ?? 'null'}';
    if (_girisKontroluCalisiyor.contains(islemAnahtari)) {
      debugPrint('ℹ️ girisKontrolleri zaten çalışıyor: $islemAnahtari');
      return;
    }
    _girisKontroluCalisiyor.add(islemAnahtari);

    try {
      // Hızlı ön kontrol: eğer hiçbir randevu/taksi talebi yoksa dialog göstermeyelim.
      String temizTel = _numaraTemizle(telefon);
      bool hasPending = false;

      try {
        if (esnafMi) {
          if (esnafId != null && esnafId.isNotEmpty) {
            // 1) İşletmenin onaylı/bekleyen randevusu var mı?
            final rSnap = await _db.collection('randevular')
                .where('esnafId', isEqualTo: esnafId)
                .where('durum', whereIn: ['Onaylandı', 'Onay bekliyor'])
                .limit(1)
                .get();
            if (rSnap.docs.isNotEmpty) hasPending = true;

            // 2) Taksi talepleri kontrolü (yeni talepler varsa göster)
            if (!hasPending) {
              final tSnap = await _db.collection('taksi_talepleri')
                .where('esnafId', isEqualTo: esnafId)
                .orderBy('olusturulmaTarihi', descending: true)
                .limit(1)
                .get();
              if (tSnap.docs.isNotEmpty) hasPending = true;
            }
          }
        } else {
          // Kullanıcı için kendi randevusu veya taksi talebi var mı?
          final rSnap = await _db.collection('randevular')
              .where('kullaniciTel', isEqualTo: temizTel)
              .where('durum', whereIn: ['Onaylandı', 'Onay bekliyor'])
              .limit(1)
              .get();
          if (rSnap.docs.isNotEmpty) hasPending = true;

          if (!hasPending) {
            final tSnap = await _db.collection('taksi_talepleri')
              .where('kullaniciTel', isEqualTo: temizTel)
              .limit(1)
              .get();
            if (tSnap.docs.isNotEmpty) hasPending = true;
          }
        }
      } catch (e) {
        // Eğer sorgularda hata olursa konservatif davran ve modali göster
        debugPrint('⚠️ Ön kontrol hatası: $e — dialog gösteriliyor.');
        hasPending = true;
      }

      if (!hasPending) {
        debugPrint('ℹ️ Ön kontrol: ilgili bildirim bulunamadı, dialog gösterilmeyecek. Arka planda sync başlatılıyor.');
        // Yine de eş zamanlı olarak dinleyiciyi başlat (kullanıcı/işletme token kaydı yapılmış olmalı)
        // Başlangıçta context gerekmez; arka planda sync yap
        syncAkilliTakipBildirimleri(telefon, null, esnafMi: esnafMi, esnafId: esnafId)
          .then((res) => debugPrint('📥 Arka plan sync tamamlandı: $res'))
          .catchError((err) => debugPrint('❌ Arka plan sync hata: $err'));
        syncRandevuHatirlatmalari(telefon, esnafMi: esnafMi, esnafId: esnafId)
          .then((res) => debugPrint('📥 Hatırlatma sync: $res'))
          .catchError((err) => debugPrint('❌ Hatırlatma sync hata: $err'));
        return;
      }

      // 1. Hoşgeldiniz mesajını göstermek için navigatorKey üzerinden güvenli context al
      final navCtx = navigatorKey.currentContext ?? context;
      if (navCtx == null) {
        // Eğer hiç context yoksa dialog gösterilemez; arka planda sessiz sync başlatıp çık
        debugPrint('⚠️ BildirimServisi: context yok, dialog atlanıyor. Arka planda sync başlatılıyor.');
        syncAkilliTakipBildirimleri(telefon, null, esnafMi: esnafMi, esnafId: esnafId)
          .then((res) => debugPrint('📥 Arka plan sync tamamlandı: $res'))
          .catchError((err) => debugPrint('❌ Arka plan sync hata: $err'));
        syncRandevuHatirlatmalari(telefon, esnafMi: esnafMi, esnafId: esnafId)
          .then((res) => debugPrint('📥 Hatırlatma sync: $res'))
          .catchError((err) => debugPrint('❌ Hatırlatma sync hata: $err'));
        return;
      }

      if (_dialogOpen) {
        debugPrint('ℹ️ BildirimServisi: giriş kontrolü zaten açık, yeni yükleme ekranı atlandı.');
        return;
      }

      _safeShowDialog(navCtx, (ctx) => AlertDialog(
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
      ));

    // 2. Arka planda senkronizasyonu başlat (engellemeden; kısa süre bekleyip diyaloğu kapat)
    debugPrint("🚀 Senkronizasyon Başlatılıyor (Tel: $telefon)...");
    final syncFuture = syncAkilliTakipBildirimleri(telefon, navCtx, esnafMi: esnafMi, esnafId: esnafId);
    // Hatırlatmalar arka planda (dialog süresini uzatmasın)
    syncRandevuHatirlatmalari(telefon, esnafMi: esnafMi, esnafId: esnafId)
      .then((res) => debugPrint('📥 Hatırlatma sync: $res'))
      .catchError((err) => debugPrint('❌ Hatırlatma sync hata: $err'));

    try {
      // Kısa bekleme: hızlı tamamlanırsa kullanıcı hemen bilgilendirilsin
      final sonuc = await syncFuture.timeout(const Duration(seconds: 5));
      debugPrint("🏁 Senkronizasyon Bitti (Hızlı): $sonuc");

      // 3. Diyaloğu kapat (navigatorKey üzerinden güvenli şekilde)
      final currentNavCtx = navigatorKey.currentContext;
      if (currentNavCtx != null) {
        _safePopDialog(currentNavCtx);
      }

      // 4. Sonuca göre (özellikle ALICI_YOK veya hiç randevu olmama durumu) uyarı göster (sadece web için)
      if (sonuc == "ALICI_YOK" && currentNavCtx != null && kIsWeb) {
        debugPrint("⚠️ ALICI_YOK Diyaloğu Tetikleniyor...");
        _safeShowDialog(currentNavCtx, (ctx) => AlertDialog(
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
        ));
      }
    } catch (e) {
      // Timeout veya hata: dialog'ı kapat ve sync'i arka planda tamamlamaya bırak
      debugPrint("⚠️ Senkronizasyon uzun sürüyor veya hataya uğradı: $e. Arka planda devam edecek.");
      final navCtxCatch = navigatorKey.currentContext;
      if (navCtxCatch != null) _safePopDialog(navCtxCatch);

      // Arka planda tamamlandığında log bas
      syncFuture.then((res) {
        debugPrint("🏁 Senkronizasyon (arka plan) tamamlandı: $res");
        // Eğer önemli bir uyarı varsa web üzerinde göster
        if (res == "ALICI_YOK" && navigatorKey.currentContext != null && kIsWeb) {
          final ctx = navigatorKey.currentContext!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _safeShowDialog(ctx, (ctx2) => AlertDialog(
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
                    onPressed: () => Navigator.pop(ctx2),
                    child: const Text("TAMAM"),
                  ),
                ),
              ],
            ));
          });
        }
      }).catchError((err) { debugPrint("❌ Arka plan sync hatası: $err"); });

      // Kullanıcıya kısa bilgi ver (snackbar)
      if (navigatorKey.currentContext != null) {
        final messenger = ScaffoldMessenger.maybeOf(navigatorKey.currentContext!);
        messenger?.showSnackBar(
          const SnackBar(content: Text('Bildirim kontrolü arka planda devam ediyor'), duration: Duration(seconds: 3))
        );
      }
    }
    } finally {
      _girisKontroluCalisiyor.remove(islemAnahtari);
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

  /// Esnafın yazdığı metni müşterinin telefonuna anlık bildirim olarak yollar.
  static Future<bool> musteriyeYaziGonder({
    required String kullaniciTel,
    required String isletmeAdi,
    required String metin,
  }) async {
    final yazi = metin.trim();
    if (yazi.isEmpty || kullaniciTel.trim().isEmpty) return false;
    final baslik = isletmeAdi.trim().isEmpty ? 'Randevu notu' : isletmeAdi.trim();
    return OneSignalServisi.bildirimGonderAnlik(
      baslik: baslik,
      icerik: yazi,
      telefon: kullaniciTel,
      ekVeri: {'type': 'esnaf_notu'},
    );
  }

  /// Ortak esnafta onay veya red anında şablon metnini müşteriye yollar.
  static Future<void> onayVeyaRedBildir({
    required RandevuModeli r,
    required EsnafModeli esnaf,
    required bool onay,
    String? neden,
  }) async {
    if (!HatirlatmaSablonlari.ortakEsnafMi(esnaf.kategori)) return;
    if (onay && !esnaf.onayBildirimAktif) return;
    if (!onay && !esnaf.redBildirimAktif) return;
    final baslik = onay ? HatirlatmaSablonlari.onayBaslik(esnaf) : HatirlatmaSablonlari.redBaslik(esnaf);
    final sablon = onay ? HatirlatmaSablonlari.onayIcerik(esnaf) : HatirlatmaSablonlari.redIcerik(esnaf);
    final icerik = HatirlatmaSablonlari.randevudanDoldur(
      sablon,
      r,
      isletmeAdi: esnaf.isletmeAdi,
      neden: neden ?? r.iptalNedeni,
    );
    if (icerik.trim().isEmpty) return;
    await OneSignalServisi.bildirimGonderAnlik(
      baslik: baslik,
      icerik: icerik,
      telefon: r.kullaniciTel,
      ekVeri: {'type': onay ? 'randevu_onay' : 'randevu_red', 'randevuId': r.id},
    );
  }

  static Future<void> _anlik(String tel, String baslik, String icerik) async {
    if (tel.trim().isEmpty) return;
    await bildirimGonder(baslik: baslik, icerik: icerik, kullaniciTel: tel);
  }

  /// Anlık taksi çağrısı: durak telefonu ve varsa sıradaki şoför.
  static Future<void> taksiCagriDustu({
    required EsnafModeli esnaf,
    String? soforTel,
    required String adres,
    String? talepId,
  }) async {
    if (!esnaf.taksiCagriBildirim) return;
    const baslik = 'Yeni taksi çağrısı';
    final icerik = adres.isEmpty ? 'Bir yolcu taksi istiyor.' : 'Yolcu çağırdı: $adres';
    final ek = <String, dynamic>{
      'action': 'taksi_cagri',
      'esnafId': esnaf.id,
      if ((talepId ?? '').isNotEmpty) 'talepId': talepId,
    };
    Future<void> gonder(String tel) => OneSignalServisi.bildirimGonderAnlik(
          baslik: baslik,
          icerik: icerik,
          telefon: tel,
          ekVeri: ek,
        );
    await gonder(esnaf.telefon);
    final sofor = (soforTel ?? '').trim();
    if (sofor.isNotEmpty && _numaraTemizle(sofor) != _numaraTemizle(esnaf.telefon)) {
      await gonder(sofor);
    }
  }

  static Future<void> taksiCagriReddedildi(String musteriTel) async {
    await _anlik(musteriTel, 'Taksi çıkarılamadı', 'Şu an araç çıkarılamadı. Biraz sonra tekrar deneyebilirsiniz.');
  }

  /// Yolcu, durak cevap vermeden Vazgeç dedi.
  static Future<void> taksiYolcuVazgecti({
    required EsnafModeli esnaf,
    String? soforTel,
    double iptalBedeli = 0,
  }) async {
    if (!esnaf.taksiCagriBildirim) return;
    const baslik = 'Yolcu vazgeçti';
    final icerik = iptalBedeli > 0 ? 'İptal bedeli ${taksiTlEtiket(iptalBedeli)}.' : 'Çağrı kapatıldı.';
    await _anlik(esnaf.telefon, baslik, icerik);
    final sofor = (soforTel ?? '').trim();
    if (sofor.isNotEmpty && _numaraTemizle(sofor) != _numaraTemizle(esnaf.telefon)) {
      await _anlik(sofor, baslik, icerik);
    }
  }

  static Future<void> taksiRezervasyonEsnafa({
    required EsnafModeli esnaf,
    required String saat,
    required String tarih,
  }) async {
    if (!esnaf.taksiRezervasyonEsnafBildirim) return;
    await _anlik(esnaf.telefon, 'Yeni taksi rezervasyonu', '$tarih saat $saat için rezervasyon geldi.');
  }

  static Future<void> taksiRezervasyonYolcuya({
    required EsnafModeli esnaf,
    required String musteriTel,
    required bool onaylandi,
    required String tarihSaat,
  }) async {
    if (!esnaf.taksiRezervasyonMusteriBildirim) return;
    await _anlik(
      musteriTel,
      onaylandi ? 'Taksi rezervasyonunuz onaylandı' : 'Taksi rezervasyonunuz reddedildi',
      onaylandi
          ? '${esnaf.isletmeAdi} · $tarihSaat rezervasyonunuz kesinleşti.'
          : '${esnaf.isletmeAdi} · $tarihSaat rezervasyonunuz kabul edilmedi.',
    );
  }

  static Future<void> taksiHatirlatmaPlanla({
    required String randevuId,
    required EsnafModeli esnaf,
    required String musteriTel,
    required DateTime baslangic,
  }) async {
    final dk = esnaf.taksiRezervasyonHatirlatmaDk;
    if (dk <= 0 || randevuId.isEmpty) return;
    final zaman = baslangic.subtract(Duration(minutes: dk));
    if (!zaman.isAfter(DateTime.now())) return;
    final id = await OneSignalServisi.bildirimPlanla(
      baslik: 'Taksi rezervasyonunuz yaklaşıyor',
      icerik: '${esnaf.isletmeAdi} · ${DateFormat('dd.MM.yyyy HH:mm').format(baslangic)} alışınıza $dk dakika kaldı.',
      zaman: zaman,
      telefon: musteriTel,
      randevuId: randevuId,
      ekVeri: {'action': 'taksi_hatirlatma', 'randevuId': randevuId, 'tel': musteriTel},
    );
    if (id != null && id != 'ALICI_YOK') {
      await _db.collection('randevular').doc(randevuId).update({'taksiHatirlatmaId': id});
    }
  }

  static Future<void> taksiHatirlatmaIptal(String randevuId) async {
    if (randevuId.isEmpty) return;
    final doc = await _db.collection('randevular').doc(randevuId).get();
    final id = doc.data()?['taksiHatirlatmaId'];
    if (id is String && id.isNotEmpty && !id.contains('İPTAL')) {
      await OneSignalServisi.bildirimIptalEt(id);
      await doc.reference.update({'taksiHatirlatmaId': '$id [İPTAL EDİLDİ]'});
    }
  }

  static Future<void> kiralamaYeniTalepEsnafa({
    required EsnafModeli esnaf,
    required String tarihSaat,
  }) async {
    if (!esnaf.kiralamaYeniTalepBildirim) return;
    await _anlik(esnaf.telefon, 'Yeni kiralama talebi', '$tarihSaat için rezervasyon geldi.');
  }

  static Future<void> kiralamaDurumMusteriye({
    required EsnafModeli esnaf,
    required String musteriTel,
    required bool onaylandi,
    required String tarihSaat,
  }) async {
    if (!esnaf.kiralamaOnayRedBildirim) return;
    await _anlik(
      musteriTel,
      onaylandi ? 'Kiralama rezervasyonunuz onaylandı' : 'Kiralama rezervasyonunuz reddedildi',
      onaylandi
          ? '${esnaf.isletmeAdi} · $tarihSaat rezervasyonunuz kesinleşti.'
          : '${esnaf.isletmeAdi} · $tarihSaat rezervasyonunuz kabul edilmedi.',
    );
  }

  static Future<void> acilDurumBildirimiGonder({
    required String baslik,
    required String icerik,
    required String hedefTel,
    Map<String, dynamic>? ekVeri,
    BuildContext? context,
  }) async {
    await OneSignalServisi.bildirimGonderAnlik(
      baslik: baslik,
      icerik: icerik,
      telefon: hedefTel,
      ekVeri: ekVeri,
      context: context,
    );
  }

  static String _numaraTemizle(String tel) {
    String temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (temiz.length >= 10) {
      temiz = temiz.substring(temiz.length - 10);
    }
    return temiz;
  }

  static DateTime? _randevuBaslangic(RandevuModeli r) {
    try {
      final p = r.saat.split(':');
      return DateTime(r.tarih.year, r.tarih.month, r.tarih.day, int.parse(p[0]), int.parse(p[1]));
    } catch (_) {
      return null;
    }
  }

  static bool _bildirimIdAktif(String? id) =>
      id != null && id.isNotEmpty && !id.contains('İPTAL');

  /// Onaylı randevu için öncesi/sonrası OneSignal hatırlatmalarını kurar.
  static Future<Map<String, dynamic>> randevuHatirlatmalariniKur({
    required RandevuModeli r,
    required EsnafModeli esnaf,
    String? randevuId,
  }) async {
    final sonuc = <String, dynamic>{'oncesi': false, 'sonrasi': false, 'hata': null};
    if (!esnaf.hatirlatmaAktif) return sonuc;
    if (r.durum != 'Onaylandı') return sonuc;

    final id = randevuId ?? r.id;
    if (id.isEmpty) return sonuc;

    final baslangic = _randevuBaslangic(r);
    if (baslangic == null) return sonuc;
    final bitis = baslangic.add(Duration(minutes: r.sure));
    final simdi = DateTime.now();
    final updateData = <String, dynamic>{};

    try {
      if (esnaf.hatirlatmaOnceAktif && !_bildirimIdAktif(r.oncesiBildirimId)) {
        final zaman = baslangic.subtract(Duration(minutes: esnaf.hatirlatmaOnceDk));
        if (zaman.isAfter(simdi)) {
          final icerik = HatirlatmaSablonlari.randevudanDoldur(
            HatirlatmaSablonlari.onceIcerik(esnaf),
            r,
            isletmeAdi: esnaf.isletmeAdi,
          );
          final nid = await OneSignalServisi.bildirimPlanla(
            baslik: HatirlatmaSablonlari.onceBaslik(esnaf),
            icerik: icerik,
            zaman: zaman,
            telefon: r.kullaniciTel,
            randevuId: id,
            ekVeri: {
              'action': 'randevu_hatirlatma_oncesi',
              'tel': r.kullaniciTel,
              'randevuId': id,
            },
          );
          if (nid != null && nid != 'ALICI_YOK') {
            updateData['oncesiBildirimId'] = nid;
            updateData['oncesiBildirimZamani'] = Timestamp.fromDate(zaman);
            sonuc['oncesi'] = true;
          } else if (nid == 'ALICI_YOK') {
            sonuc['hata'] = 'ALICI_YOK';
          }
        }
      }

      if (esnaf.hatirlatmaSonraAktif && !_bildirimIdAktif(r.sonrasiBildirimId)) {
        final zaman = bitis.add(Duration(minutes: esnaf.hatirlatmaSonraDk));
        if (zaman.isAfter(simdi)) {
          final icerik = HatirlatmaSablonlari.randevudanDoldur(
            HatirlatmaSablonlari.sonraIcerik(esnaf),
            r,
            isletmeAdi: esnaf.isletmeAdi,
          );
          final nid = await OneSignalServisi.bildirimPlanla(
            baslik: HatirlatmaSablonlari.sonraBaslik(esnaf),
            icerik: icerik,
            zaman: zaman,
            telefon: r.kullaniciTel,
            randevuId: id,
            ekVeri: {
              'action': 'randevu_hatirlatma_sonrasi',
              'tel': r.kullaniciTel,
              'randevuId': id,
            },
          );
          if (nid != null && nid != 'ALICI_YOK') {
            updateData['sonrasiBildirimId'] = nid;
            updateData['sonrasiBildirimZamani'] = Timestamp.fromDate(zaman);
            sonuc['sonrasi'] = true;
          } else if (nid == 'ALICI_YOK') {
            sonuc['hata'] = 'ALICI_YOK';
          }
        }
      }

      if (updateData.isNotEmpty) {
        await _db.collection('randevular').doc(id).update(updateData);
      }
    } catch (e) {
      debugPrint('❌ randevuHatirlatmalariniKur: $e');
      sonuc['hata'] = e.toString();
    }
    return sonuc;
  }

  static Future<void> randevuHatirlatmalariniIptal(RandevuModeli r) async {
    try {
      final updateData = <String, dynamic>{};
      if (_bildirimIdAktif(r.oncesiBildirimId)) {
        await OneSignalServisi.bildirimIptalEt(r.oncesiBildirimId!);
        updateData['oncesiBildirimId'] = '${r.oncesiBildirimId} [İPTAL EDİLDİ]';
      }
      if (_bildirimIdAktif(r.sonrasiBildirimId)) {
        await OneSignalServisi.bildirimIptalEt(r.sonrasiBildirimId!);
        updateData['sonrasiBildirimId'] = '${r.sonrasiBildirimId} [İPTAL EDİLDİ]';
      }
      if (updateData.isNotEmpty && r.id.isNotEmpty) {
        await _db.collection('randevular').doc(r.id).update(updateData);
      }
    } catch (e) {
      debugPrint('❌ randevuHatirlatmalariniIptal: $e');
    }
  }

  /// Eksik hatırlatmaları onaylı randevular için yeniden kurar (giriş sync).
  static Future<String> syncRandevuHatirlatmalari(
    String telefon, {
    bool esnafMi = false,
    String? esnafId,
  }) async {
    if (_isHatirlatmaSyncing) return 'BUSY';
    _isHatirlatmaSyncing = true;
    try {
      final temizGirisTel = _numaraTemizle(telefon);
      final snap = await _db
          .collection('randevular')
          .where('durum', isEqualTo: 'Onaylandı')
          .get();

      int kurulan = 0;
      bool aliciYok = false;

      for (final doc in snap.docs) {
        final r = RandevuModeli.fromFirestore(doc);
        if (esnafMi) {
          if (esnafId != null && r.esnafId != esnafId) continue;
        } else {
          if (_numaraTemizle(r.kullaniciTel) != temizGirisTel) continue;
        }

        final esDoc = await _db.collection('esnaflar').doc(r.esnafId).get();
        if (!esDoc.exists) continue;
        final esnaf = EsnafModeli.fromFirestore(esDoc);
        if (!esnaf.hatirlatmaAktif) continue;

        final res = await randevuHatirlatmalariniKur(r: r, esnaf: esnaf, randevuId: doc.id);
        if (res['oncesi'] == true || res['sonrasi'] == true) kurulan++;
        if (res['hata'] == 'ALICI_YOK') aliciYok = true;
      }

      debugPrint('✅ Hatırlatma sync: $kurulan randevu güncellendi');
      return aliciYok ? 'ALICI_YOK' : 'OK';
    } catch (e) {
      debugPrint('❌ syncRandevuHatirlatmalari: $e');
      return 'HATA';
    } finally {
      _isHatirlatmaSyncing = false;
    }
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
