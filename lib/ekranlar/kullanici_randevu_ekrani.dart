import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'giris_secim_ekrani.dart';
import '../servisler/bildirim_servisi.dart';
import '../servisler/onesignal_servisi.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/esnaf_modeli.dart';
import '../widgets/medya_goruntuleyici.dart';
import 'kaza_bildirim_ekrani.dart';

class KullaniciRandevuEkrani extends StatefulWidget {
  final String telefon;
  final String? seciliRandevuId; // [YENİ] Bildirimden gelen ID

  const KullaniciRandevuEkrani({
    super.key, 
    required this.telefon, 
    this.seciliRandevuId, // [YENİ]
  });

  @override
  State<KullaniciRandevuEkrani> createState() => _KullaniciRandevuEkraniState();
}

class _KullaniciRandevuEkraniState extends State<KullaniciRandevuEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  final ValueNotifier<DateTime> _suAnkiZaman = ValueNotifier(DateTime.now());
  Timer? _merkeziTimer;

  @override
  void initState() {
    super.initState();

    // [YENİ] Web ve Mobil'de canlı bildirim dinleyiciyi mühürleyelim
    BildirimServisi.bildirimDinle(widget.telefon, context: context);

    _merkeziTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _merkeziTimer != null && _merkeziTimer!.isActive) {
        _suAnkiZaman.value = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _merkeziTimer?.cancel();
    _merkeziTimer = null;
    _suAnkiZaman.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Randevularım"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => _cikisYap(context),
              tooltip: "Çıkış Yap",
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
             tabs: [
               Tab(text: "Mevcut"),
               Tab(text: "Geçmiş"),
             ],
             indicatorColor: Colors.blue,
             labelStyle: TextStyle(fontWeight: FontWeight.bold),
           ),
        ),
        body: StreamBuilder<List<RandevuModeli>>(
          stream: _firestoreServisi.kullaniciRandevulariniGetir(widget.telefon),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final tumRandevular = snapshot.data ?? [];
            final simdi = DateTime.now();

            List<RandevuModeli> mevcutler = [];
            List<RandevuModeli> gecmisler = [];

            for (var r in tumRandevular) {
              // Randevunun başlangıç saatini hesapla
              DateTime rBas = _randevuZamaniHesapla(r);

              // Araç kiralama ise iADE saatini hesapla, değilse başlangıç saatini kullan
              DateTime referansZaman;
              if (r.randevuKanali != null && r.randevuKanali!.isNotEmpty) {
                // Araç kiralama randevusu: iADE saatine göre filtrele
                referansZaman = rBas.add(Duration(minutes: r.sure));
              } else {
                // Diğer hizmetler: başlangıç saatine göre filtrele
                referansZaman = rBas;
              }

              if (referansZaman.isAfter(simdi)) {
                mevcutler.add(r);
              } else {
                gecmisler.add(r);
              }
            }

            mevcutler.sort((a, b) => _randevuZamaniHesapla(b).compareTo(_randevuZamaniHesapla(a)));
            gecmisler.sort((a, b) => _randevuZamaniHesapla(b).compareTo(_randevuZamaniHesapla(a)));

            return TabBarView(
              children: [
                _randevuListesi(context, mevcutler, false),
                _randevuListesi(context, gecmisler, true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _randevuListesi(BuildContext context, List<RandevuModeli> liste, bool gecmisMi) {
    if (liste.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(gecmisMi ? Icons.history : Icons.calendar_today_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 20),
            Text(gecmisMi ? "Geçmiş randevunuz bulunmuyor." : "Mevcut randevunuz bulunmuyor.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final r = liste[i];
        // [KRİTİK] Eğer bildirimden gelen ID bu randevu ise, kartı açık başlat
        bool baslangictaAcik = widget.seciliRandevuId != null && r.id == widget.seciliRandevuId;
        
        return _randevuKarti(context, r, gecmisMi, baslangictaAcik: baslangictaAcik);
      },
    );
  }

  Widget _randevuKarti(BuildContext context, RandevuModeli r, bool gecmisMi, {bool baslangictaAcik = false}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: baslangictaAcik, // [YENİ] Bildirimden gelindiyse otomatik aç
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.business, color: Colors.blue),
        ),
        title: Text(r.esnafAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            // Randevu Zamanı
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Randevu Zamanı: ${DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(_randevuZamaniHesapla(r))}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Onaylanma Zamanı + Badge
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Onaylanma Zamanı: ${r.guncellemeTarihi != null ? DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(r.guncellemeTarihi!) : '-'}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                _durumRozeti(r.durum),
              ],
            ),
            // Rededilme Zamanı (sadece rededilmişse görünsün)
            if (r.durum == 'Reddedildi')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Rededilme Zamanı: ${r.reddedilmeTarihi != null ? DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(r.reddedilmeTarihi!) : '-'}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            // Rededilme Nedeni
            if (r.durum == 'Reddedildi' && r.iptalNedeni != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  "Neden: ${r.iptalNedeni}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 4),
            if (!gecmisMi && r.durum != 'İptal Edildi')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _kalanSureWidget(_randevuZamaniHesapla(r)),
              ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Hizmet ve Araç bilgileri (başlık stili iade ile uyumlu)
                _bilgiSatiri(Icons.content_cut, "Hizmet: ${r.hizmetAdi}", bold: true),
                if (r.randevuKanali != null)
                  _bilgiSatiri(Icons.layers, r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+')) ? "Araç: ${r.randevuKanali}" : "Bölüm: ${r.randevuKanali}", bold: true),
                if (r.calisanPersonel != null && (r.randevuKanali == null || !r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+'))))
                  _bilgiSatiri(Icons.person, "Personel: ${r.calisanPersonel}", bold: true),

                const Divider(height: 32),
                // BİTİŞ ZAMANI VE UZATMA BİLGİSİ (İade zamanı gösterir)
                _bitisVeUzatmaBilgisi(r),
                
                // [YENİ] GÖRSEL KANIT GALERİSİ
                if (r.teslimatGorselleri.isNotEmpty || r.iadeGorselleri.isNotEmpty) ...[
                  const Divider(height: 32),
                  _kanitGalerisi(context, r),
                ],
                
                const SizedBox(height: 16),
                if (!gecmisMi && r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
                  Column(
                    children: [
                      _akilliTakipButonu(context, r),
                      const SizedBox(height: 8),
                      // [YENİ] ACİL KAZA / HASAR BİLDİRİM BUTONU (Sadece Onaylı Araç Kiralama İçin)
                      if (r.durum == 'Onaylandı' && r.randevuKanali != null && r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+')))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => KazaBildirimEkrani(randevu: r))),
                              icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              label: const Text("🚨 ACİL: KAZA / HASAR BİLDİR"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _randevuIptalDialog(context, r),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text("Randevuyu İptal Et"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            elevation: 0,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kalanSureWidget(DateTime randevuZamani) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _suAnkiZaman,
      builder: (context, simdi, child) {
        final fark = randevuZamani.difference(simdi);
        if (fark.isNegative) return const SizedBox.shrink();

        String metin = "";
        Color renk = Colors.blue;
        bool saniyeGoster = false;

        if (fark.inDays > 0) {
          metin = "${fark.inDays} gün ${fark.inHours % 24} sa";
          renk = Colors.blueGrey;
        } else {
          saniyeGoster = true;
          final saat = fark.inHours.toString().padLeft(2, '0');
          final dakika = (fark.inMinutes % 60).toString().padLeft(2, '0');
          final saniye = (fark.inSeconds % 60).toString().padLeft(2, '0');
          metin = "$saat:$dakika:$saniye";
          renk = fark.inHours < 1 ? Colors.red : Colors.orange;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: renk.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saniyeGoster)
                Opacity(
                  opacity: (simdi.second % 2 == 0) ? 1.0 : 0.5,
                  child: Icon(Icons.timer_outlined, size: 14, color: renk),
                ),
              if (saniyeGoster) const SizedBox(width: 6),
              Text(
                metin,
                style: TextStyle(
                  color: renk,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(metin, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  Widget _durumRozeti(String durum) {
    Color renk = Colors.orange;
    if (durum == 'Onaylandı') renk = Colors.green;
    if (durum == 'Reddedildi' || durum == 'İptal Edildi') renk = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Text(durum, style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  DateTime _randevuZamaniHesapla(RandevuModeli r) {
    try {
      final baslangicSaati = r.saat.split('-')[0].trim();
      final parcalar = baslangicSaati.split(':');
      return DateTime(r.tarih.year, r.tarih.month, r.tarih.day, int.parse(parcalar[0]), int.parse(parcalar[1]));
    } catch (e) {
      return r.tarih;
    }
  }

  void _cikisYap(BuildContext context) async {
    final devamEt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Hesabınızdan çıkış yapılacak ve bildirim alımı durdurulacaktır. Devam etmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Evet, Çıkış Yap"),
          ),
        ],
      ),
    );

    if (devamEt == true) {
      BildirimServisi.servisiDurdur();
      await OneSignalServisi.oturumuKapat();
      
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (c) => const GirisSecimSayfasi()),
        (route) => false,
      );
    }
  }

  Widget _bitisVeUzatmaBilgisi(RandevuModeli r) {
    final baslangic = _randevuZamaniHesapla(r);
    final bitis = baslangic.add(Duration(minutes: r.sure));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer_off, size: 16, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text(
              "İade Zamanı: ${DateFormat('dd MMMM HH:mm', 'tr_TR').format(bitis)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        if (r.uzatmaSuresi > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.more_time, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "+${r.uzatmaSuresi ~/ 60} Saat Ek Süre Tanımlandı",
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${DateFormat('HH:mm').format(bitis.subtract(Duration(minutes: r.uzatmaSuresi)))} ile ${DateFormat('HH:mm').format(bitis)} arası",
                        style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _akilliTakipButonu(BuildContext context, RandevuModeli r) {
    if (!r.akilliTakipAktif) return const SizedBox.shrink();

    return StreamBuilder<EsnafModeli>(
      stream: _firestoreServisi.esnafGetir(r.esnafId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final esnaf = snapshot.data!;

        return FutureBuilder<int>(
          future: _firestoreServisi.randevuMaksimumUzatmaDk(r),
          builder: (context, musaitlik) {
            final int maksDk = musaitlik.data ?? 0;
            final bool musait = maksDk >= 60; // En az 1 saat boşluk olmalı

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: musait ? () => _uzatmaSecenekleriDialog(context, r, esnaf, maksDk) : null,
                icon: Icon(musait ? Icons.auto_awesome : Icons.block, size: 18),
                label: Text(musait 
                  ? "Süreyi Uzat (Saatlik ${esnaf.saatlikUzatmaUcreti.toStringAsFixed(0)} TL)" 
                  : "Uzatma Müsait Değil"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: musait ? Colors.green : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _uzatmaSecenekleriDialog(BuildContext context, RandevuModeli r, EsnafModeli esnaf, int maksDk) {
    // Maksimum kaç saat uzatılabilir?
    int maksSaat = maksDk ~/ 60;
    if (maksSaat > 12) maksSaat = 12; // Güvenlik için maks 12 saat gösterelim

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // [YENİ] Web ve büyük listeler için kaydırma kilidini açar
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7), // Ekranın %70'ini kaplasın
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ne kadar uzatmak istersiniz?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Aracınız şu an müsait. İstediğiniz süreyi seçebilirsiniz.", style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Expanded( // Flexible yerine Expanded ve scroll kilidi çözümü
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(), // [KRİTİK] Kaydırmayı zorunlu kılar
                itemCount: maksSaat,
                itemBuilder: (ctx, index) {
                  int saat = index + 1;
                  double ucret = saat * esnaf.saatlikUzatmaUcreti;
                  return ListTile(
                    leading: const Icon(Icons.timer, color: Colors.blue),
                    title: Text("$saat Saat Uzat"),
                    trailing: Text("${ucret.toStringAsFixed(0)} TL", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    onTap: () {
                      // [YENİ] Onay Mekanizması
                      showDialog(
                        context: context,
                        builder: (confirmCtx) => AlertDialog(
                          title: const Text("Uzatma Onayı"),
                          content: Text("$saat Saat uzatma işlemini ${ucret.toStringAsFixed(0)} TL karşılığında onaylıyor musunuz?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text("Vazgeç")),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () async {
                                Navigator.pop(confirmCtx); // Onay kutusunu kapat
                                Navigator.pop(c); // BottomSheet'i kapat
                                
                                await _firestoreServisi.randevuUzat(r.id, saat * 60);
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Süreniz $saat saat başarıyla uzatıldı! Bir sonraki hatırlatma kuruldu."),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 4),
                                    )
                                  );
                                }
                              },
                              child: const Text("Onayla ve Uzat"),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _randevuIptalDialog(BuildContext context, RandevuModeli r) {
    // ... mevcut kod ...
  }

  Widget _kanitGalerisi(BuildContext context, RandevuModeli r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 18, color: Colors.blueGrey),
            SizedBox(width: 10),
            Text("Teslimat ve İade Kanıtları", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        if (r.teslimatGorselleri.isNotEmpty) ...[
          const Text("🚗 Teslimat Anı", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _medyaYatayListe(r.teslimatGorselleri),
          const SizedBox(height: 15),
        ],
        if (r.iadeGorselleri.isNotEmpty) ...[
          const Text("✅ İade Anı", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _medyaYatayListe(r.iadeGorselleri),
        ],
      ],
    );
  }

  Widget _medyaYatayListe(List<String> urls) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (c, i) {
          final url = urls[i];
          bool isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('video');
          return GestureDetector(
            onTap: () => _kanitGoster(urls, i),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isVideo 
                  ? Container(color: Colors.black87, child: const Center(child: Icon(Icons.videocam, color: Colors.white)))
                  : Image.network(url, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }

  void _kanitGoster(List<String> tumu, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MedyaGoruntuleyici(gorseller: tumu, baslangicIndex: index),
      ),
    );
  }
}
