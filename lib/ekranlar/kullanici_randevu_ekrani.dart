import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/esnaf_modeli.dart';

class KullaniciRandevuEkrani extends StatefulWidget {
  final String telefon;
  const KullaniciRandevuEkrani({super.key, required this.telefon});

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
          bottom: const TabBar(
            tabs: [
              Tab(text: "Yaklaşanlar"),
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

            List<RandevuModeli> yaklasanlar = [];
            List<RandevuModeli> gecmisler = [];

            for (var r in tumRandevular) {
              DateTime rZaman = _randevuZamaniHesapla(r);
              if (rZaman.isAfter(simdi.subtract(const Duration(hours: 1)))) {
                yaklasanlar.add(r);
              } else {
                gecmisler.add(r);
              }
            }

            yaklasanlar.sort((a, b) => _randevuZamaniHesapla(a).compareTo(_randevuZamaniHesapla(b)));
            gecmisler.sort((a, b) => _randevuZamaniHesapla(b).compareTo(_randevuZamaniHesapla(a)));

            return TabBarView(
              children: [
                _randevuListesi(context, yaklasanlar, false),
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
            Text(gecmisMi ? "Geçmiş randevunuz bulunmuyor." : "Yaklaşan randevunuz bulunmuyor.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liste.length,
      itemBuilder: (context, i) => _randevuKarti(context, liste[i], gecmisMi),
    );
  }

  Widget _randevuKarti(BuildContext context, RandevuModeli r, bool gecmisMi) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
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
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${DateFormat('dd MMMM yyyy', 'tr_TR').format(r.tarih)} - ${r.saat}",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (!gecmisMi && r.durum != 'İptal Edildi')
                  _kalanSureWidget(_randevuZamaniHesapla(r)),
              ],
            ),
            const SizedBox(height: 4),
            _durumRozeti(r.durum),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _bilgiSatiri(Icons.content_cut, "Hizmet: ${r.hizmetAdi}"),
                if (r.randevuKanali != null)
                  _bilgiSatiri(Icons.layers, r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+')) ? "Araç: ${r.randevuKanali}" : "Bölüm: ${r.randevuKanali}"),
                if (r.calisanPersonel != null && !r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+')))
                  _bilgiSatiri(Icons.person, "Personel: ${r.calisanPersonel}"),
                
                const Divider(height: 32),
                // BİTİŞ ZAMANI VE UZATMA BİLGİSİ
                _bitisVeUzatmaBilgisi(r),
                
                const SizedBox(height: 16),
                if (!gecmisMi && r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
                  Column(
                    children: [
                      _akilliTakipButonu(context, r),
                      const SizedBox(height: 8),
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

  Widget _bilgiSatiri(IconData ikon, String metin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(metin, style: const TextStyle(fontSize: 14))),
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
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Randevu İptal Nedeni", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('kullanici'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          await _firestoreServisi.randevuIptalEt(r.id, nedenler[index]);
                          if (context.mounted) Navigator.pop(c);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          ],
        ),
      ),
    );
  }
}
