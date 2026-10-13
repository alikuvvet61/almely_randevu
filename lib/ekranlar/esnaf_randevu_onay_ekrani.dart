import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/yardimcilar/hizmet_paketi.dart';
import 'package:almely_randevu/yardimcilar/hatirlatma_sablonlari.dart';
import 'package:almely_randevu/widgets/musteri_notu_dialogu.dart';
import 'package:almely_randevu/widgets/musteri_bildirim_dialogu.dart';
import 'dart:async';

class EsnafRandevuYonetimEkrani extends StatefulWidget {
  final String esnafId;
  final EsnafModeli? esnaf; // Esnaf nesnesini opsiyonel olarak alalım
  const EsnafRandevuYonetimEkrani({super.key, required this.esnafId, this.esnaf});

  @override
  State<EsnafRandevuYonetimEkrani> createState() => _EsnafRandevuYonetimEkraniState();
}

class _EsnafRandevuYonetimEkraniState extends State<EsnafRandevuYonetimEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  EsnafModeli? _esnaf;
  bool _gecmisTarihleriBelirtildi = false;
  Map<String, String> _musteriNotlari = {};
  StreamSubscription<Map<String, String>>? _notDinleyici;

  @override
  void initState() {
    super.initState();
    _esnaf = widget.esnaf;

    // [YENİ] Esnaf için bu sayfada da canlı bildirim dinleyiciyi mühürleyelim
    if (_esnaf != null) {
      BildirimServisi.bildirimDinle(_esnaf!.telefon);
      BildirimServisi.syncAkilliTakipBildirimleri(_esnaf!.telefon, null, esnafMi: true, esnafId: _esnaf!.id);
      BildirimServisi.syncRandevuHatirlatmalari(_esnaf!.telefon, esnafMi: true, esnafId: _esnaf!.id);
    } else {
       _esnafYukle().then((_) {
         if (mounted && _esnaf != null) {
           BildirimServisi.bildirimDinle(_esnaf!.telefon);
           BildirimServisi.syncAkilliTakipBildirimleri(_esnaf!.telefon, null, esnafMi: true, esnafId: _esnaf!.id);
           BildirimServisi.syncRandevuHatirlatmalari(_esnaf!.telefon, esnafMi: true, esnafId: _esnaf!.id);
         }
       });
    }

    if (_esnaf == null) {
      _esnafYukle();
    }
    _notDinleyici = _firestoreServisi.musteriNotlariDinle(widget.esnafId).listen((notlar) {
      if (!mounted) return;
      setState(() => _musteriNotlari = notlar);
    });
  }

  @override
  void dispose() {
    _notDinleyici?.cancel();
    super.dispose();
  }

  Future<void> _esnafYukle() async {
    final e = await _firestoreServisi.esnafGetirDoc(widget.esnafId);
    if (e != null && mounted) {
      setState(() {
        _esnaf = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Randevu Yönetimi"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Bekleyen"),
              Tab(text: "Onaylanan"),
              Tab(text: "İptal/Red"),
            ],
            indicatorColor: Colors.blue,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
          ),
        ),
        body: TabBarView(
          children: [
            _randevuListesi('Onay bekliyor'),
            _randevuListesi('Onaylandı'),
            _randevuListesi('Red/İptal'),
          ],
        ),
      ),
    );
  }

  Widget _randevuListesi(String durumFiltresi) {
    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.esnafTumRandevulariGetir(widget.esnafId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final hepsi = snapshot.data ?? [];
        List<RandevuModeli> liste;
        
        if (durumFiltresi == 'Red/İptal') {
          liste = hepsi.where((r) => r.durum == 'Reddedildi' || r.durum == 'İptal Edildi' || r.durum == 'Gelmedi').toList();
        } else {
          liste = hepsi.where((r) => r.durum == durumFiltresi).toList();
        }

        // Tarihe göre sırala ve saate göre (Eski en üstte, saat artan sırada)
        liste.sort((a, b) {
          int cmp = a.tarih.compareTo(b.tarih);
          if (cmp != 0) return cmp;
          return a.saat.compareTo(b.saat);
        });

        if (liste.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  durumFiltresi == 'Onay bekliyor' 
                    ? Icons.hourglass_empty 
                    : (durumFiltresi == 'Onaylandı' ? Icons.check_circle_outline : Icons.history), 
                  size: 80, 
                  color: Colors.grey.withValues(alpha: 0.3)
                ),
                const SizedBox(height: 20),
                Text(
                  "$durumFiltresi randevunuz bulunmuyor", 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
                ),
              ],
            ),
          );
        }

        // "Red/İptal" tabında checkbox ve filtreleme
        bool isRedIptalTab = durumFiltresi == 'Red/İptal';
        
        // Checkbox kapalıysa ve "Red/İptal" tab'ı ise, geçmiş randevuları gizle
        List<RandevuModeli> filtreliListe = liste;
        if (isRedIptalTab && !_gecmisTarihleriBelirtildi) {
          final simdi = DateTime.now();
          filtreliListe = liste.where((r) {
            try {
              final saatParcalar = r.saat.split(':');
              final randevuTamZaman = DateTime(
                r.tarih.year,
                r.tarih.month,
                r.tarih.day,
                int.parse(saatParcalar[0]),
                int.parse(saatParcalar[1]),
              );
              return randevuTamZaman.isAfter(simdi);
            } catch (e) {
              return true;
            }
          }).toList();
        }

        // Red/İptal tab'ında checkbox göster
        if (isRedIptalTab) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Checkbox(
                      value: _gecmisTarihleriBelirtildi,
                      onChanged: (value) {
                        setState(() {
                          _gecmisTarihleriBelirtildi = value ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Geçmiş randevuları da göster",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtreliListe.length,
                  itemBuilder: (context, i) {
                    final r = filtreliListe[i];
                    return _randevuKarti(r);
                  },
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtreliListe.length,
          itemBuilder: (context, i) {
            final r = filtreliListe[i];
            return _randevuKarti(r);
          },
        );
      },
    );
  }

  String _musteriNotu(RandevuModeli r) {
    final anahtar = _firestoreServisi.musteriTelefonAnahtari(r.kullaniciTel);
    if (anahtar.isEmpty) return '';
    return _musteriNotlari[anahtar] ?? '';
  }

  Future<void> _notuDuzenle(RandevuModeli r) {
    return musteriNotuDuzenle(
      context: context,
      firestore: _firestoreServisi,
      esnafId: widget.esnafId,
      telefon: r.kullaniciTel,
      ad: r.kullaniciAd,
      mevcutNot: _musteriNotu(r),
    );
  }

  Widget _randevuKarti(RandevuModeli r) {
    Color durumRenk = Colors.orange;
    if (r.durum == 'Onaylandı') durumRenk = Colors.green;
    if (r.durum == 'Reddedildi' || r.durum == 'İptal Edildi') durumRenk = Colors.red;

    // Randevu tarih ve saatinin geçmiş olup olmadığını kontrol et
    final simdi = DateTime.now();
    final saatParcalar = r.saat.split(':');
    final randevuTamZaman = DateTime(
      r.tarih.year,
      r.tarih.month,
      r.tarih.day,
      int.parse(saatParcalar[0]),
      int.parse(saatParcalar[1]),
    );
    final randevuGecmis = randevuTamZaman.isBefore(simdi);

    bool sureDoldu = false;
    int kalanDakika = 10;
    if (r.durum == 'Onay bekliyor' && r.olusturulmaTarihi != null) {
      int gecen = simdi.difference(r.olusturulmaTarihi!).inMinutes;
      sureDoldu = gecen >= 10;
      kalanDakika = 10 - gecen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: randevuGecmis ? Colors.grey.withValues(alpha: 0.05) : (sureDoldu ? Colors.red.withValues(alpha: 0.02) : Colors.white),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (sureDoldu && r.durum == 'Onay bekliyor') 
              ? Colors.red.withValues(alpha: 0.1) 
              : Colors.grey.withValues(alpha: 0.06),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minTileHeight: 64, 
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              (sureDoldu && r.durum == 'Onay bekliyor') ? Icons.timer_off : Icons.person, 
              color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red : Colors.blue,
              size: 28,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  r.kullaniciAd, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 17,
                    color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red.shade900 : Colors.black87
                  )
                ),
              ),
              _durumRozeti(r.durum, durumRenk),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${DateFormat('dd MMM yyyy, EEEE', 'tr_TR').format(r.tarih)} - ${r.saat}",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                  ),
                ],
              ),
              if (r.durum == 'Onay bekliyor')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sureDoldu ? "⚠️ SÜRE DOLDU" : "⏳ Kalan: $kalanDakika dk",
                    style: TextStyle(
                      color: sureDoldu ? Colors.red : Colors.orange, 
                      fontSize: 14, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.paketAdi != null && r.paketAdi!.isNotEmpty
                      ? '${r.hizmetAdi} · ${r.sure} dk · ${r.paketAdi}'
                      : '${r.hizmetAdi} · ${r.sure} dk',
                  style: TextStyle(color: Colors.indigo.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (r.sadakatYuzde > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${r.sadakatSira}. randevu · %${r.sadakatYuzde} indirim',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              if (_musteriNotu(r).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _musteriNotu(r),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.teal.shade800, fontSize: 13),
                  ),
                ),
            ],
          ),
          children: [
            const Divider(height: 1, indent: 4, endIndent: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  _onayDetayi(r),
                  _bilgiSatiri(Icons.phone, r.kullaniciTel),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.sticky_note_2_outlined, color: Colors.teal),
                    title: Text(
                      _musteriNotu(r).isEmpty ? 'Müşteri notu yok' : _musteriNotu(r),
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _notuDuzenle(r),
                  ),
                  _bilgiSatiri(
                    Icons.content_cut,
                    r.paketAdi != null && r.paketAdi!.isNotEmpty ? "${r.hizmetAdi} · ${r.paketAdi}" : r.hizmetAdi,
                  ),
                  if (r.randevuKanali != null)
                    _bilgiSatiri(Icons.layers, "Kanal: ${r.randevuKanali}"),
                  if (r.calisanPersonel != null)
                    _bilgiSatiri(Icons.person_outline, "Personel: ${r.calisanPersonel}"),
                  
                  if (r.seriId != null && r.seriId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: Colors.blue.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text("Periyodik Randevu Serisi", style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                  if (r.iptalNedeni != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Neden: ${r.iptalNedeni}", 
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => musteriyeBildirimDialogu(
                        context: context,
                        telefon: r.kullaniciTel,
                        ad: r.kullaniciAd,
                        isletmeAdi: _esnaf?.isletmeAdi ?? '',
                      ),
                      icon: const Icon(Icons.notifications_outlined, size: 18),
                      label: const Text('Kullanıcıya bildirim gönder'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (r.durum == 'Onaylandı' && (_esnaf?.hatirlatmaAktif ?? false))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _whatsappHatirlat(r, once: true),
                              icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                              label: const Text("WhatsApp hatırlat", style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Metni kopyala',
                            onPressed: () => _whatsappHatirlat(r, once: true, sadeceKopyala: true),
                            icon: Icon(Icons.copy, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      if (r.durum == 'Onaylandı') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _gelmediOnay(context, r),
                            icon: const Icon(Icons.person_off_outlined, size: 18),
                            label: const Text("Gelmedi", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange,
                              side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _iptalDialog(context, r),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text("İptal Et", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                      if (r.durum == 'Onay bekliyor') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reddetDialog(context, r),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Reddet", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final onayKapali = sureDoldu && (_esnaf?.sureDolanOnaylanmasin ?? true);
                              if (onayKapali) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("10 dakikalık onay süresi doldu. Bu randevu onaylanamaz."),
                                ));
                                return;
                              }
                              if (sureDoldu) {
                                if (!mounted) return;
                                bool? devamEt = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text("Zaman Aşımı"),
                                    content: const Text("Bu randevunun 10 dakikalık onay süresi dolduğu için ilgili saat diğer müşterilere açılmış olabilir. Yine de onaylamak istiyor musunuz?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        child: const Text("Evet, Onayla"),
                                      ),
                                    ],
                                  ),
                                );
                                if (devamEt != true) return;
                              }

                              if (!mounted) return;
                              // [GÖRSEL YÜKLEME]: İşlem bitene kadar kum saati döner
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(color: Colors.white),
                                      const SizedBox(height: 20),
                                      const Text(
                                        "Randevunuz Onaylanıyor,\nLütfen Bekleyin...",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              // Context'i asenkron işlemden önce alalım
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                              
                              final res = await _firestoreServisi.randevuDurumGuncelle(
                                r.id, 
                                'Onaylandı',
                                aliciTel: r.kullaniciTel,
                                esnafAdi: r.esnafAdi,
                                tarihSaat: "$tarihFormat ${r.saat}",
                                context: null,
                              );

                              final eksikHam = res['eksikAjanda'];
                              if (eksikHam is List && eksikHam.isNotEmpty && mounted) {
                                final gunler = eksikHam.map((e) => DateTime.fromMillisecondsSinceEpoch((e as num).toInt())).toList();
                                final ornek = gunler.take(6).map((g) => DateFormat('dd.MM.yyyy').format(g)).join(', ');
                                final kalan = gunler.length > 6 ? '\nve ${gunler.length - 6} gün daha' : '';
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Ajanda oluşturulmamış'),
                                    content: Text(
                                      'Ajandası olmayan günler:\n$ornek$kalan\n\n'
                                      'Bu günlerin ajandası oluşturulmamış. Oluşturulacak.',
                                    ),
                                    actions: [
                                      ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
                                    ],
                                  ),
                                );
                              }

                              if (mounted) {
                                Navigator.pop(context); // Kum saatini kapat

                                // [YENİ] Bildirimleri hemen senkronize et (Arka randevuları kontrol etmesi için)
                                if (_esnaf != null) {
                                BildirimServisi.syncAkilliTakipBildirimleri(_esnaf!.telefon, null, esnafMi: true, esnafId: _esnaf!.id);
                                BildirimServisi.syncRandevuHatirlatmalari(_esnaf!.telefon, esnafMi: true, esnafId: _esnaf!.id);
                                }

                                String msg = "Randevu onaylandı";
                                Color bgColor = Colors.green;
                                
                                if (res['alarmKuruldu'] == true) {
                                  msg += " ve Gecikme Alarmı ${res['alarmSaati']} için kuruldu.";
                                  bgColor = Colors.blue.shade800;
                                } else if (res['hatirlatmaKuruldu'] == true) {
                                  msg += " · Hatırlatmalar planlandı.";
                                } else if (res['hata'] == "ALICI_YOK") {
                                  msg = "Randevu onaylandı ancak BİLDİRİM KURULAMADI! 🔴\nBildirimlerin oluşması için Telefonunuzdan Esnaf Ekranına birkez giriş yapmalısınız.";
                                  bgColor = Colors.red.shade900;
                                }
                                
                                scaffoldMessenger.clearSnackBars();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: bgColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 8), // Mesajın okunması için süreyi uzattım
                                  )
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Onayla", style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durumRozeti(String durum, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.1)),
      ),
      child: Text(
        durum,
        style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _onayDetayi(RandevuModeli r) {
    final paketId = r.paketKayitId;
    final paketVar = (paketId != null && paketId.isNotEmpty) || (r.paketAdi != null && r.paketAdi!.isNotEmpty);
    if (!paketVar) return const SizedBox.shrink();
    final birim = HizmetPaketi.hakBirimi(_esnaf?.kategori);
    if (paketId == null || paketId.isEmpty) {
      return _onayKutusu('${r.paketAdi}. Bu geliş 1 $birim.');
    }
    return FutureBuilder<MusteriPaketKaydi?>(
      future: _firestoreServisi.paketKaydiGetir(paketId),
      builder: (context, snap) {
        final p = snap.data;
        if (p != null && p.toplamSeans > 0) {
          final siraNo = (p.toplamSeans - p.kalanSeans).clamp(1, p.toplamSeans);
          final sira = birim == 'ders' ? '$siraNo. ders' : '$siraNo. seans';
          var metin = '${p.paketAdi}. Bu geliş $sira. Kalan ${p.kalanSeans} / ${p.toplamSeans} $birim.';
          if (siraNo == 1 && p.toplamSeans > 1) {
            final sonrakiler = HizmetPaketi.haftalikPlan(r.tarih, p.toplamSeans, bitis: p.bitis).skip(1).toList();
            if (sonrakiler.isNotEmpty) {
              final yaz = sonrakiler.map((g) => '${DateFormat('d MMM', 'tr_TR').format(g)} ${r.saat}').join(', ');
              metin += '\nSonraki $birim: $yaz.';
            }
          }
          return _onayKutusu(metin);
        }
        if (r.paketAdi != null && r.paketAdi!.isNotEmpty) {
          return _onayKutusu('${r.paketAdi}. Bu geliş 1 $birim.');
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _onayKutusu(String metin) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Text(
        metin,
        style: TextStyle(fontSize: 14, height: 1.35, color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(ikon, size: 20, color: Colors.grey.shade600), const SizedBox(width: 10), Expanded(child: Text(metin, style: const TextStyle(fontSize: 15)))]),
  );

  void _reddetDialog(BuildContext context, RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Randevuyu Reddet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen bir reddetme nedeni seçin:"),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          final navigator = Navigator.of(c);
                          String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                          await _firestoreServisi.randevuIptalEt(
                            r.id, 
                            nedenler[index],
                            aliciTel: r.kullaniciTel,
                            esnafAdi: r.esnafAdi,
                            tarihSaat: "$tarihFormat ${r.saat}",
                            durumBildir: true,
                          );
                          if (context.mounted && navigator.mounted) {
                            // [YENİ] İptal sonrası bildirimleri onar
                            if (_esnaf != null) {
                               BildirimServisi.syncAkilliTakipBildirimleri(_esnaf!.telefon, null, esnafMi: true, esnafId: _esnaf!.id);
                            }
                            navigator.pop();
                          }
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

  Future<void> _gelmediOnay(BuildContext context, RandevuModeli r) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Müşteri gelmedi"),
        content: Text(
          "${r.kullaniciAd} (${r.saat}) için gelmedi notu düşülsün mü? Randevu kapanır, saat yeniden açılır. "
          "Kara liste eşiği dolmuşsa bu telefon yeni randevu alamaz.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Gelmedi")),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    await _firestoreServisi.randevuDurumGuncelle(r.id, 'Gelmedi', iptalNedeni: 'Gelmedi');
    final esik = _esnaf?.karaListeEsik ?? 0;
    final kayit = await _firestoreServisi.musteriCezaNotuIsle(
      esnafId: r.esnafId,
      telefon: r.kullaniciTel,
      ad: r.kullaniciAd,
      tip: 'gelmedi',
      esik: esik,
    );
    if (!context.mounted) return;
    final mesaj = kayit.karaListede
        ? "Gelmedi notu işlendi. Müşteri kara listeye alındı (${kayit.toplam})."
        : "Gelmedi notu işlendi (${kayit.gelmedi} gelmedi, ${kayit.gecIptal} geç iptal).";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  void _iptalDialog(BuildContext context, RandevuModeli r) async {
    final bagli = await _firestoreServisi.bagliRandevulariGetir(r);
    if (!context.mounted) return;
    List<RandevuModeli> hedefler = [r];
    if (bagli.length > 1) {
      final secim = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Randevuyu İptal Et"),
          content: Text("Bu kayda bağlı ${bagli.length} randevu var. Sadece bunu mu, bağlıların hepsini mi iptal edelim?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
            TextButton(onPressed: () => Navigator.pop(ctx, 'secili'), child: const Text("Sadece bunu")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'hepsi'), child: const Text("Bağlıların hepsini")),
          ],
        ),
      );
      if (secim == null || !context.mounted) return;
      hedefler = secim == 'hepsi' ? bagli : [r];
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Randevuyu İptal Et", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen bir iptal nedeni seçin:"),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          final navigator = Navigator.of(c);
                          for (final hedef in hedefler) {
                            await _firestoreServisi.randevuDurumGuncelle(
                              hedef.id,
                              'İptal Edildi',
                              iptalNedeni: nedenler[index],
                              aliciTel: hedef.kullaniciTel,
                              esnafAdi: hedef.esnafAdi,
                              tarihSaat: "${DateFormat('dd.MM.yyyy').format(hedef.tarih)} ${hedef.saat}",
                            );
                          }
                          if (context.mounted && navigator.mounted) {
                            if (_esnaf != null) {
                              BildirimServisi.syncAkilliTakipBildirimleri(_esnaf!.telefon, null, esnafMi: true, esnafId: _esnaf!.id);
                            }
                            navigator.pop();
                          }
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

  Future<void> _whatsappHatirlat(RandevuModeli r, {required bool once, bool sadeceKopyala = false}) async {
    final esnaf = _esnaf;
    if (esnaf == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final sablon = once
        ? HatirlatmaSablonlari.onceIcerik(esnaf)
        : HatirlatmaSablonlari.sonraIcerik(esnaf);
    final metin = HatirlatmaSablonlari.randevudanDoldur(sablon, r, isletmeAdi: esnaf.isletmeAdi);

    await Clipboard.setData(ClipboardData(text: metin));
    if (!mounted) return;

    if (sadeceKopyala) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Hatırlatma metni panoya kopyalandı")),
      );
      return;
    }

    final url = Uri.parse(HatirlatmaSablonlari.whatsappUrl(r.kullaniciTel, metin));
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("WhatsApp açılamadı; metin panoya kopyalandı")),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("WhatsApp hatası: $e")),
        );
      }
    }
  }
}
