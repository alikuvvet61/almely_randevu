import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../widgets/ana_buton.dart';

class RandevuEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;
  const RandevuEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<RandevuEkrani> createState() => _RandevuEkraniState();
}

class _RandevuEkraniState extends State<RandevuEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _adController = TextEditingController();
  final _telController = TextEditingController();
  final _scrollController = ScrollController();

  final ValueNotifier<List<Map<String, dynamic>>> _seciliHizmetlerNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _seciliSaatNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliPersonelNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliTarihNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliKanalNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _saatKendimSececegimNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _aramaYapiliyorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _musaitlikBulunamadiNotifier = ValueNotifier(false);

  List<RandevuModeli> _sonRandevular = [];
  Map<String, dynamic>? _gununAjandaVerisi;
  Map<String, dynamic>? _taksiAjandaVerisi;
  StreamSubscription? _ajandaSub;
  StreamSubscription? _taksiAjandaSub;
  StreamSubscription? _randevularSub;

  late Stream<EsnafModeli> _esnafStream;

  @override
  void initState() {
    super.initState();
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);

    // Otomatik personel/kanal/araç seçimi (Tek seçenek varsa)
    if (widget.esnaf.aracOdakliSistem && widget.esnaf.kategori == 'Taksi') {
      if (widget.esnaf.araclar.length == 1) {
        final a = widget.esnaf.araclar.first;
        _seciliKanalNotifier.value = a['plaka']?.toString();
      }
    } else if (widget.esnaf.randevularPersonelAdinaAlinsin) {
      if ((widget.esnaf.personeller?.length ?? 0) == 1) {
        final p = widget.esnaf.personeller!.first;
        _seciliPersonelNotifier.value = p['isim']?.toString();
        _seciliKanalNotifier.value = p['kanal']?.toString();
      }
    } else if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      if (widget.esnaf.kanallar!.length == 1) {
        _seciliKanalNotifier.value = widget.esnaf.kanallar!.first.toString();
      }
    } else {
      _seciliKanalNotifier.value = "";
    }

    if (widget.kullaniciTel != null) {
      _telController.text = widget.kullaniciTel!;
    }

    _seciliKanalNotifier.addListener(_updateStreams);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otomatikTarihSec(widget.esnaf);
      _updateStreams();
    });
  }

  void _otomatikTarihSec(EsnafModeli esnaf) {
    final aktifler = _getAktifTarihler(esnaf);
    if (aktifler.isNotEmpty) {
      if (_seciliTarihNotifier.value == null || !aktifler.any((d) => d.year == _seciliTarihNotifier.value!.year && d.month == _seciliTarihNotifier.value!.month && d.day == _seciliTarihNotifier.value!.day)) {
        _seciliTarihNotifier.value = aktifler.first;
      }
    } else {
      _seciliTarihNotifier.value = null;
    }
  }

  void _updateStreams() {
    final tarih = _seciliTarihNotifier.value;
    final kanal = _seciliKanalNotifier.value;
    if (tarih != null) {
      _ajandaSub?.cancel();
      _taksiAjandaSub?.cancel();
      _randevularSub?.cancel();

      _ajandaSub = _firestoreServisi.gunlukAjandaSnapStream(widget.esnaf.id, tarih, kanal).listen((snap) {
        if (mounted) {
          if (snap.exists) {
            setState(() {
              _gununAjandaVerisi = snap.data() as Map<String, dynamic>?;
            });
          } else {
            // EĞER KANALA ÖZEL AJANDA YOKSA GENEL AJANDAYA BAK (FALLBACK)
            _firestoreServisi.gunlukAjandaSnapStream(widget.esnaf.id, tarih, null).first.then((genelSnap) {
              if (mounted) {
                if (genelSnap.exists) {
                  setState(() {
                    _gununAjandaVerisi = genelSnap.data() as Map<String, dynamic>?;
                  });
                } else {
                  setState(() {
                    _gununAjandaVerisi = null;
                  });
                }
              }
            });
          }
        }
      });

      if (widget.esnaf.kategori == 'Taksi') {
        _taksiAjandaSub = _firestoreServisi.taksiAjandasiSnapStream(widget.esnaf.id, tarih).listen((snap) {
          if (mounted) {
            setState(() {
              _taksiAjandaVerisi = snap.data() as Map<String, dynamic>?;
            });
          }
        });
      }

      _randevularSub = _firestoreServisi.randevulariGetir(widget.esnaf.id, tarih).listen((list) {
        if (mounted) {
          setState(() {
            _sonRandevular = list;
          });
        }
      });
    }
  }

  Future<void> _enYakinMusaitligiBul(EsnafModeli esnaf) async {
    final hizmetler = _seciliHizmetlerNotifier.value;
    if (hizmetler.isEmpty || _saatKendimSececegimNotifier.value) return;

    // Eğer personel odaklı randevu aktifse ve henüz personel seçilmemişse işlem yapma
    if (esnaf.randevularPersonelAdinaAlinsin && _seciliPersonelNotifier.value == null) {
      return;
    }

    if (_aramaYapiliyorNotifier.value) return;
    _aramaYapiliyorNotifier.value = true;

    try {
      int toplamSure = _getToplamSure(hizmetler);
      final aktifTarihler = _getAktifTarihler(esnaf);
      final seciliKanal = _seciliKanalNotifier.value;

      final seciliTarih = _seciliTarihNotifier.value;
      List<DateTime> taranacakTarihler = List.from(aktifTarihler);
      if (seciliTarih != null) {
        taranacakTarihler.removeWhere((d) => d.year == seciliTarih.year && d.month == seciliTarih.month && d.day == seciliTarih.day);
        taranacakTarihler.insert(0, seciliTarih);
      }
      taranacakTarihler = taranacakTarihler.take(10).toList();

      if (taranacakTarihler.isEmpty) {
        if (mounted) _aramaYapiliyorNotifier.value = false;
        return;
      }

      final DateTime baslangic = taranacakTarihler.reduce((a, b) => a.isBefore(b) ? a : b);
      final DateTime bitis = taranacakTarihler.reduce((a, b) => a.isAfter(b) ? a : b).add(const Duration(days: 1));

      final randevularSnapFuture = FirebaseFirestore.instance.collection('randevular')
          .where('esnafId', isEqualTo: esnaf.id)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
          .where('tarih', isLessThan: Timestamp.fromDate(bitis))
          .get();

      List<String> docIds = [];
      Set<String> taksiAyKeys = {};
      for (var tarih in taranacakTarihler) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        String k = (seciliKanal != null && seciliKanal.trim().isNotEmpty) ? seciliKanal.trim() : "";
        docIds.add(k.isNotEmpty ? "${tarihStr}_$k" : tarihStr);
        if (esnaf.kategori == 'Taksi') {
          taksiAyKeys.add(DateFormat('yyyy-MM').format(tarih));
        }
      }

      final ajandaSnaplerFuture = FirebaseFirestore.instance.collection('esnaflar')
          .doc(esnaf.id).collection('ajanda')
          .where(FieldPath.documentId, whereIn: docIds)
          .get();

      Future<QuerySnapshot?> taksiAjandaSnaplerFuture = Future.value(null);
      if (taksiAyKeys.isNotEmpty) {
        taksiAjandaSnaplerFuture = FirebaseFirestore.instance.collection('esnaflar')
            .doc(esnaf.id).collection('taksi_ajanda')
            .where(FieldPath.documentId, whereIn: taksiAyKeys.toList())
            .get();
      }

      final results = await Future.wait([
        randevularSnapFuture.timeout(const Duration(seconds: 20)),
        ajandaSnaplerFuture.timeout(const Duration(seconds: 20)),
        taksiAjandaSnaplerFuture.timeout(const Duration(seconds: 20)),
      ]);

      final randevularSnap = results[0] as QuerySnapshot;
      final ajandaSnapler = results[1] as QuerySnapshot;
      final taksiAjandaSnapler = results[2];

      final tumBlokRandevulari = randevularSnap.docs
          .map((doc) => RandevuModeli.fromFirestore(doc))
          .where((r) => r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
          .toList();

      Map<String, Map<String, dynamic>> ajandaHaritasi = {};
      for (var doc in ajandaSnapler.docs) {
        ajandaHaritasi[doc.id] = doc.data() as Map<String, dynamic>;
      }

      Map<String, dynamic> tumTaksiAjandaVerisi = {};
      if (taksiAjandaSnapler != null) {
        for (var doc in taksiAjandaSnapler.docs) {
          tumTaksiAjandaVerisi.addAll(doc.data() as Map<String, dynamic>);
        }
      }

      for (var tarih in taranacakTarihler) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        final String k = (seciliKanal != null && seciliKanal.trim().isNotEmpty) ? seciliKanal.trim() : "";
        String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
        
        // Kanala özel veri yoksa Genel veriyi kullan (Fallback)
        var ajandaVerisi = ajandaHaritasi[docId] ?? ajandaHaritasi[tarihStr];

        final gununRandevulari = tumBlokRandevulari.where((r) =>
        r.tarih.year == tarih.year && r.tarih.month == tarih.month && r.tarih.day == tarih.day
        ).toList();

        final slotlar = _slotlariUret(esnaf, ajandaVerisi);

        for (var s in slotlar) {
          if (_saatMusaitMi(esnaf, s, gununRandevulari, toplamSure, ajandaVerisi: ajandaVerisi, hedefTarih: tarih, hariciTaksiAjandasi: tumTaksiAjandaVerisi)) {
            if (mounted) {
              _seciliTarihNotifier.value = tarih;
              _updateStreams();
              _seciliSaatNotifier.value = s;
              _musaitlikBulunamadiNotifier.value = false;
              setState(() {}); // Arama bittiğinde UI'ı güncelle
            }
            _aramaYapiliyorNotifier.value = false;
            return;
          }
        }
      }

      if (mounted) _musaitlikBulunamadiNotifier.value = true;
    } catch (e) {
      debugPrint("Müsaitlik arama hatası: $e");
    } finally {
      if (mounted) _aramaYapiliyorNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _seciliKanalNotifier.removeListener(_updateStreams);
    _ajandaSub?.cancel();
    _taksiAjandaSub?.cancel();
    _randevularSub?.cancel();
    _adController.dispose();
    _telController.dispose();
    _seciliHizmetlerNotifier.dispose();
    _seciliSaatNotifier.dispose();
    _seciliPersonelNotifier.dispose();
    _seciliTarihNotifier.dispose();
    _seciliKanalNotifier.dispose();
    _saatKendimSececegimNotifier.dispose();
    _aramaYapiliyorNotifier.dispose();
    _musaitlikBulunamadiNotifier.dispose();
    super.dispose();
  }

  int _getToplamSure(List<Map<String, dynamic>> hizmetler) {
    int toplam = 0;
    for (var h in hizmetler) {
      toplam += int.tryParse(h['sure'].toString()) ?? 0;
    }
    return toplam;
  }

  List<DateTime> _getAktifTarihler(EsnafModeli esnaf) {
    final aktifler = esnaf.aktifGunler ?? [];
    List<DateTime> tarihler = [];
    final bugun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final kanal = _seciliKanalNotifier.value;
    final gunler = esnaf.calismaSaatleri?['gunler'] as Map<String, dynamic>? ?? {};

    for (var item in aktifler) {
      final s = item.toString();
      if (kanal != null && kanal.isNotEmpty) {
        if (!s.endsWith("_$kanal")) continue;
      } else {
        if (s.contains('_')) continue;
      }

      try {
        DateTime t = DateFormat('yyyy-MM-dd').parse(s.split('_')[0]);

        // Günlük çalışma programı kontrolü (KAPALI ise engelle)
        String gunAdi = DateFormat('EEEE', 'tr_TR').format(t);
        if (gunler.containsKey(gunAdi) && gunler[gunAdi] == false) {
          continue;
        }

        if (t.isAtSameMomentAs(bugun) || t.isAfter(bugun)) {
          tarihler.add(t);
        }
      } catch (e) {
        debugPrint("Tarih parse hatası: $e");
      }
    }
    tarihler.sort();
    return tarihler;
  }


  int _saatiDakikayaCevir(String saat) {
    final parcalar = saat.split(':');
    return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
  }

  String _dakikaFormatli(int toplamDakika) {
    int saat = (toplamDakika ~/ 60) % 24;
    int dakika = toplamDakika % 60;
    return "${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}";
  }

  List<String> _slotlariUret(EsnafModeli esnaf, Map<String, dynamic>? ajandaVerisi) {
    List<String> slotlar = [];
    final calisma = ajandaVerisi ?? esnaf.calismaSaatleri;
    if (calisma == null) return [];
    
    // 7/24 Modu Kontrolü: acilis ve kapanis ikisi de "00:00" ise veya ayniysa
    String acilis = calisma['acilis'] ?? "09:00";
    String kapanis = calisma['kapanis'] ?? "18:00";
    bool is724 = (acilis == "00:00" && kapanis == "00:00") || (calisma['is724'] == true);
    
    if (is724) {
      acilis = "00:00";
      kapanis = "24:00";
    }

    int slotAraligi = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;

    if (slotAraligi <= 0) return [];

    try {
      DateTime current = DateFormat("HH:mm").parse(acilis);
      DateTime end = DateFormat("HH:mm").parse(kapanis == "24:00" ? "00:00" : kapanis);
      if (end.isBefore(current) || kapanis == "00:00" || kapanis == "24:00") end = end.add(const Duration(days: 1));
      
      while (current.isBefore(end)) {
        slotlar.add(DateFormat("HH:mm").format(current));
        current = current.add(Duration(minutes: slotAraligi));
      }
    } catch (e) { debugPrint("Slot üretme hatası: $e"); }
    return slotlar;
  }

  String? _saatNedenKapali(EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi, {Map<String, dynamic>? ajandaVerisi, DateTime? hedefTarih, Map<String, dynamic>? hariciTaksiAjandasi}) {
    final tarih = hedefTarih ?? _seciliTarihNotifier.value;
    final kanal = _seciliKanalNotifier.value;

    // TAKSİ ÖZEL KONTROLÜ
    if (esnaf.kategori == 'Taksi' && tarih != null && kanal != null && kanal.isNotEmpty) {
      String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
      final taksiVerisi = hariciTaksiAjandasi ?? _taksiAjandaVerisi;
      var gunlukVeri = taksiVerisi?[tarihKey] as Map<String, dynamic>?;
      if (gunlukVeri != null && gunlukVeri.containsKey(kanal)) {
        String durum = gunlukVeri[kanal];
        if (durum == 'I') return "İstirahatte";
        
        // Nöbetçi Araçlar İçin Saat Kısıtlaması
        if (durum == 'N' && esnaf.nobetBaslangic != null && esnaf.nobetBaslangic != "Seçilmedi" && esnaf.nobetBitis != null && esnaf.nobetBitis != "Seçilmedi") {
          int sDk = _saatiDakikayaCevir(slot);
          int nBas = _saatiDakikayaCevir(esnaf.nobetBaslangic!);
          int nBit = _saatiDakikayaCevir(esnaf.nobetBitis!);
          
          // Nöbetçi araç sadece nöbet saatleri arasında çalışabilir
          bool musait = false;
          if (nBit > nBas) {
            // Normal aralık (örn: 08:00 - 20:00)
            musait = sDk >= nBas && sDk < nBit;
          } else {
            // Gece aşan aralık (örn: 20:00 - 08:00)
            musait = sDk >= nBas || sDk < nBit;
          }
          
          if (!musait) return "Mesai Dışı";
        }
      } else {
        // Ajanda kaydı yoksa şablona bak
        final arac = esnaf.araclar.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['plaka'] == kanal,
          orElse: () => null,
        );
        if (arac != null) {
          String gunAdi = DateFormat('EEEE', 'tr_TR').format(tarih);
          bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
          if (!calisiyor) return "İstirahatte";
        }
      }
    }

    final calisma = ajandaVerisi ?? esnaf.calismaSaatleri;
    if (calisma == null) return "Çalışma saati yok";

    int slotDakika = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;

    Map<String, dynamic> kapaliSlotlarMap = {};
    if (ajandaVerisi != null && ajandaVerisi.containsKey('kapaliSlotlar')) {
      var raw = ajandaVerisi['kapaliSlotlar'];
      if (raw is Map) {
        kapaliSlotlarMap = Map<String, dynamic>.from(raw);
      } else if (raw is List) {
        for (var s in raw) {
          kapaliSlotlarMap[s.toString()] = "Belirtilmedi";
        }
      }
    }

    // Öğle arası kontrolü
    if (ajandaVerisi != null && ajandaVerisi['ogleBaslangic'] != null && ajandaVerisi['ogleBitis'] != null) {
      int sDk = _saatiDakikayaCevir(slot);
      int oBasDk = _saatiDakikayaCevir(ajandaVerisi['ogleBaslangic']);
      int oBitDk = _saatiDakikayaCevir(ajandaVerisi['ogleBitis']);
      if (sDk >= oBasDk && sDk < oBitDk) return "Öğle Arası";
    }

    int sBaslangic = _saatiDakikayaCevir(slot);
    int acilisDakika = _saatiDakikayaCevir(calisma['acilis'] ?? "09:00");
    if (sBaslangic < acilisDakika) sBaslangic += 1440;

    int kontrolSuresi = hizmetSuresi > 0 ? hizmetSuresi : slotDakika;
    int sBitis = sBaslangic + kontrolSuresi;

    for (int t = sBaslangic; t < sBitis; t += slotDakika) {
      String kontrolSaati = _dakikaFormatli(t % 1440);
      if (kapaliSlotlarMap.containsKey(kontrolSaati)) {
        return kapaliSlotlarMap[kontrolSaati].toString();
      }
    }

    String kapanis = calisma['kapanis'] ?? "18:00";
    int kMin = _saatiDakikayaCevir(kapanis == "24:00" ? "00:00" : kapanis);
    if (kMin <= acilisDakika || kapanis == "00:00" || kapanis == "24:00") kMin += 1440;
    if (sBitis > kMin) return "";

    if (tarih != null && tarih.day == DateTime.now().day && tarih.month == DateTime.now().month && tarih.year == DateTime.now().year) {
      int simdiDakika = DateTime.now().hour * 60 + DateTime.now().minute;
      if (sBaslangic <= simdiDakika) return "Geçmiş saat";
    }

    for (var r in randevular) {
      if (kanal != null && kanal.isNotEmpty && r.randevuKanali != kanal) continue;

      // 10 Dakika Kuralı: Manuel onaylı esnaflarda, 'Onay bekliyor' randevuları 
      // oluşturulma üzerinden 10dk geçtikten sonra boş kabul et
      if (r.durum == 'Onay bekliyor' && esnaf.randevuOnayModu == 'Manuel' && r.olusturulmaTarihi != null) {
        if (DateTime.now().difference(r.olusturulmaTarihi!).inMinutes >= 10) {
          continue; // Bu randevuyu çakışma kontrolüne dahil etme (saat boşalsın)
        }
      }

      int rBaslangic = _saatiDakikayaCevir(r.saat);
      if (rBaslangic < acilisDakika) rBaslangic += 1440;
      int rBitis = rBaslangic + r.sure;
      if (sBaslangic < rBitis && rBaslangic < sBitis) {
        return r.durum == 'Onaylandı' ? "Dolu" : "Rezerve";
      }
    }
    return null;
  }

  bool _saatMusaitMi(EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi, {Map<String, dynamic>? ajandaVerisi, DateTime? hedefTarih, Map<String, dynamic>? hariciTaksiAjandasi}) {
    return _saatNedenKapali(esnaf, slot, randevular, hizmetSuresi, ajandaVerisi: ajandaVerisi, hedefTarih: hedefTarih, hariciTaksiAjandasi: hariciTaksiAjandasi) == null;
  }

  Future<void> _randevuKaydet(EsnafModeli esnaf, Map<String, dynamic>? ajanda) async {
    final hizmetler = _seciliHizmetlerNotifier.value;
    final saat = _seciliSaatNotifier.value;
    final tarih = _seciliTarihNotifier.value;
    final personel = _seciliPersonelNotifier.value;
    final kanal = _seciliKanalNotifier.value;

    if (_adController.text.isEmpty || _telController.text.isEmpty || hizmetler.isEmpty || saat == null || tarih == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      return;
    }

    int toplamSure = _getToplamSure(hizmetler);

    if (!_saatMusaitMi(esnaf, saat, _sonRandevular, toplamSure, ajandaVerisi: ajanda)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seçtiğiniz saat hizmet süresi için uygun değil veya dolu."), backgroundColor: Colors.red));
      return;
    }

    String durm = esnaf.randevuOnayModu == 'Otomatik' ? 'Onaylandı' : 'Onay bekliyor';

    final isTaksi = esnaf.kategori == 'Taksi';
    final aracModu = isTaksi && esnaf.aracOdakliSistem;

    final yeniRandevu = RandevuModeli(
      id: '',
      esnafId: esnaf.id,
      esnafAdi: esnaf.isletmeAdi,
      esnafTel: esnaf.telefon,
      kullaniciAd: _adController.text,
      kullaniciTel: _telController.text,
      tarih: tarih,
      saat: saat,
      sure: toplamSure,
      hizmetAdi: hizmetler.map((h) => h['isim']).join(' + '),
      randevuKanali: kanal,
      calisanPersonel: aracModu ? null : personel,
      durum: durm,
    );

    try {
      await _firestoreServisi.randevuEkle(yeniRandevu);

      // Bildirim Gönder (Esnafa yeni randevu bildirimi)
      BildirimServisi.bildirimGonder(
        kullaniciTel: esnaf.telefon, // Esnafın telefonuna bildirim gider
        baslik: "Yeni Randevu Talebi",
        icerik: "${_adController.text} isimli kullanıcı $saat saati için randevu aldı.",
      );

      if (!mounted) return;

      String tarihFormat = DateFormat('dd.MM.yyyy').format(tarih);
      
      String saatGosterim = saat;
      if (esnaf.slotAralikliGoster) {
        final calisma = ajanda ?? esnaf.calismaSaatleri;
        int slotAraligi = calisma?['slotDakika'] ?? calisma?['slotAraligi'] ?? 30;
        int baslangicDakika = _saatiDakikayaCevir(saat);
        int bitisDakika = baslangicDakika + slotAraligi;
        saatGosterim = "$saat - ${_dakikaFormatli(bitisDakika % 1440)}";
      }

      String yaklasikIbaresi = esnaf.kategori == 'Halı Saha' ? '' : 'yaklaşık ';

      String mesaj = durm == 'Onaylandı'
          ? "Randevunuz $tarihFormat tarihinde saat $saatGosterim olarak onaylanmıştır. Randevu süreniz ${yaklasikIbaresi}$toplamSure dk sürecektir. ${esnaf.isletmeAdi} olarak teşekkür ederiz."
          : "Randevunuz $tarihFormat tarihinde saat $saatGosterim için alınmıştır. Randevu süreniz ${yaklasikIbaresi}$toplamSure dk sürecektir. ${esnaf.isletmeAdi} olarak teşekkür ederiz. Onay bekleniyor.";

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Text(mesaj, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("TAMAM"),
            )
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }


  void _sonrakiAdimaGit(double offset) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.offset + offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _adimBasligi(String no, String baslik, {bool aktif = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: aktif ? Colors.indigo : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Text(no, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(
            baslik,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: aktif ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Randevu Al", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.esnaf.isletmeAdi, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: StreamBuilder<EsnafModeli>(
        stream: _esnafStream,
        builder: (context, esnafSnapshot) {
          if (esnafSnapshot.connectionState == ConnectionState.waiting && !esnafSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final esnaf = esnafSnapshot.data ?? widget.esnaf;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(child: _adimBasligi("1", "Hizmet Seçin")),
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _seciliHizmetlerNotifier,
                      builder: (context, seciliHizmetler, _) {
                        final hizmetler = esnaf.hizmetler ?? [];
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final h = hizmetler[index];
                              bool secili = seciliHizmetler.any((element) => element['isim'] == h['isim']);

                              IconData ikon = Icons.auto_awesome;
                              String hIsim = h['isim'].toString().toLowerCase();
                              if (hIsim.contains("kesim") || hIsim.contains("sakal")) ikon = Icons.content_cut;
                              if (hIsim.contains("boya")) ikon = Icons.color_lens;
                              if (hIsim.contains("yikama")) ikon = Icons.local_car_wash;

                              bool showPrice = h['ucretGoster'] ?? false;
                              double ucret = (h['ucret'] ?? 0).toDouble();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: secili ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: secili ? Colors.indigo : Colors.grey.shade200),
                                ),
                                child: CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  secondary: Icon(ikon, color: secili ? Colors.indigo : Colors.grey),
                                  title: Text(h['isim'], style: TextStyle(fontWeight: secili ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: Row(
                                    children: [
                                      Text("${h['sure']} Dakika", style: const TextStyle(fontSize: 12)),
                                      if (showPrice) ...[
                                        const Text(" • ", style: TextStyle(fontSize: 12)),
                                        Text(
                                          ucret > 0 ? "${ucret.toStringAsFixed(0)} TL" : "Ücretsiz",
                                          style: TextStyle(
                                            fontSize: 12, 
                                            fontWeight: FontWeight.bold, 
                                            color: ucret > 0 ? Colors.green : Colors.blue
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  value: secili,
                                  activeColor: Colors.indigo,
                                  onChanged: (val) {
                                    List<Map<String, dynamic>> yeniListe = List.from(seciliHizmetler);
                                    if (val == true) {
                                      yeniListe.add(Map<String, dynamic>.from(h));
                                    } else {
                                      yeniListe.removeWhere((element) => element['isim'] == h['isim']);
                                    }
                                    _seciliHizmetlerNotifier.value = yeniListe;
                                    _seciliSaatNotifier.value = null;
                                    _saatKendimSececegimNotifier.value = false;
                                    _updateStreams();

                                    if (yeniListe.length == 1 && val == true) {
                                      _sonrakiAdimaGit(150);
                                    }

                                    if (!esnaf.randevularPersonelAdinaAlinsin || _seciliPersonelNotifier.value != null) {
                                      _enYakinMusaitligiBul(esnaf);
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: hizmetler.length,
                          ),
                        );
                      },
                    ),

                    // Adımları (2, 3, 4, 5) Hizmet seçimine bağla
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _seciliHizmetlerNotifier,
                      builder: (context, seciliHizmetler, _) {
                        if (seciliHizmetler.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                        bool isTaksi = esnaf.kategori == 'Taksi';
                        bool aracModu = isTaksi && esnaf.aracOdakliSistem;
                        bool personelModu = !aracModu && esnaf.randevularPersonelAdinaAlinsin;
                        bool kanalSecilmeli = !personelModu && !aracModu && (esnaf.kanallar?.length ?? 0) > 1;

                        return SliverMainAxisGroup(
                          slivers: [
                            // Adım 2: Personel / Araç / Bölüm Seçimi
                            SliverList(
                              delegate: SliverChildListDelegate([
                                if (aracModu || personelModu || kanalSecilmeli) ...[
                                  _adimBasligi("2", aracModu ? "Araç Seçimi" : (personelModu ? "Personel Seçimi" : "Bölüm / Masa Seçimi")),
                                  if (aracModu || personelModu)
                                    _personelSeciciWidget(esnaf)
                                  else
                                    _kanalSeciciWidget(esnaf),
                                ] else if (esnaf.kanallar != null && esnaf.kanallar!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _seciliBilgiKarti("Seçilen Bölüm", _seciliKanalNotifier.value ?? ""),
                                  ),
                              ]),
                            ),

                            // Adım 3: Tarih Seçimi (Personel/Kanal/Araç seçimine bağlı)
                            ValueListenableBuilder<String?>(
                              valueListenable: (aracModu || (isTaksi && personelModu)) ? _seciliKanalNotifier : (personelModu ? _seciliPersonelNotifier : _seciliKanalNotifier),
                              builder: (context, secim, _) {
                                bool secimGerekiyor = aracModu || personelModu || kanalSecilmeli;
                                if (secimGerekiyor && secim == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

                                return SliverMainAxisGroup(
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _adimBasligi("3", "Tarih Seçin"),
                                          _tarihSeciciWidget(esnaf),
                                        ],
                                      ),
                                    ),

                                    // Adım 4 & 5: Saat ve İletişim (Tarih seçimine bağlı)
                                    ValueListenableBuilder<DateTime?>(
                                      valueListenable: _seciliTarihNotifier,
                                      builder: (context, seciliTarih, _) {
                                        if (seciliTarih == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

                                        return SliverMainAxisGroup(
                                          slivers: [
                                            SliverToBoxAdapter(child: _adimBasligi("4", "Saat Seçin")),
                                            _saatSecimiBolumuSliver(esnaf),

                                            // Adım 5: İletişim Bilgileri (Saat seçimine bağlı)
                                            ValueListenableBuilder<String?>(
                                              valueListenable: _seciliSaatNotifier,
                                              builder: (context, seciliSaat, _) {
                                                if (seciliSaat == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                                                return SliverToBoxAdapter(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const SizedBox(height: 30),
                                                      _adimBasligi("5", "İletişim Bilgileri"),
                                                      Container(
                                                        padding: const EdgeInsets.all(20),
                                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                                                        child: Column(
                                                          children: [
                                                            TextField(
                                                              controller: _adController,
                                                              decoration: const InputDecoration(
                                                                labelText: "Ad Soyad",
                                                                prefixIcon: Icon(Icons.person_outline),
                                                                border: OutlineInputBorder(),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 15),
                                                            TextField(
                                                              controller: _telController,
                                                              keyboardType: TextInputType.phone,
                                                              decoration: const InputDecoration(
                                                                labelText: "Telefon Numarası",
                                                                prefixIcon: Icon(Icons.phone_outlined),
                                                                border: OutlineInputBorder(),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      bottomSheet: ValueListenableBuilder<DateTime?>(
          valueListenable: _seciliTarihNotifier,
          builder: (context, tarih, _) {
            if (tarih == null) return const SizedBox.shrink();
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _seciliHizmetlerNotifier,
                builder: (context, hizmetler, _) {
                  return ValueListenableBuilder<String?>(
                      valueListenable: _seciliSaatNotifier,
                      builder: (context, saat, _) {
                        bool butonAktif = saat != null && hizmetler.isNotEmpty && _saatMusaitMi(widget.esnaf, saat, _sonRandevular, _getToplamSure(hizmetler), ajandaVerisi: _gununAjandaVerisi);
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (saat != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _saatKendimSececegimNotifier,
                                    builder: (context, kendimSectim, _) {
                                      return Text(
                                        kendimSectim
                                            ? "Randevu saatini $saat olarak seçtiniz"
                                            : "Size uygun en yakın randevu saati $saat olarak belirlendi.",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                      );
                                    },
                                  ),
                                ),
                              AnaButon(metin: "RANDEVUYU TAMAMLA", onPressed: butonAktif ? () => _randevuKaydet(widget.esnaf, _gununAjandaVerisi) : null),
                            ],
                          ),
                        );
                      }
                  );
                }
            );
          }
      ),
    );
  }


  Widget _seciliBilgiKarti(String baslik, String icerik) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 10),
          Text("$baslik: ", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Text(icerik, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _tarihSeciciWidget(EsnafModeli esnaf) {
    return ValueListenableBuilder<String?>(
      valueListenable: _seciliKanalNotifier,
      builder: (context, kanal, _) {
        return ValueListenableBuilder<DateTime?>(
            valueListenable: _seciliTarihNotifier,
            builder: (context, seciliTarih, _) {
              List<DateTime> aktifTarihler = _getAktifTarihler(esnaf);
              if (aktifTarihler.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 40, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text("Seçili kriterlere uygun müsait tarih bulunamadı.", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)
                        ),
                        if (esnaf.kategori == 'Taksi' && kanal != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text("(Araç istirahatte olabilir)", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: aktifTarihler.length,
                  itemBuilder: (context, index) {
                    DateTime gun = aktifTarihler[index];
                    bool secili = seciliTarih != null && gun.day == seciliTarih.day && gun.month == seciliTarih.month && gun.year == seciliTarih.year;
                    return InkWell(
                      onTap: () {
                        _seciliTarihNotifier.value = gun;
                        _seciliSaatNotifier.value = null;
                        _updateStreams();
                      },
                      child: Container(
                        width: 60, margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(color: secili ? Colors.blue : Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('EE', 'tr_TR').format(gun), style: TextStyle(color: secili ? Colors.white : Colors.blueGrey)),
                            Text(gun.day.toString(), style: TextStyle(color: secili ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }
        );
      }
    );
  }

  Widget _kanalSeciciWidget(EsnafModeli esnaf) {
    return ValueListenableBuilder<String?>(
      valueListenable: _seciliKanalNotifier,
      builder: (context, seciliKanal, _) {
        final tarih = _seciliTarihNotifier.value;
        String tarihKey = tarih != null ? DateFormat('yyyy-MM-dd').format(tarih) : "";
        final taksiVerisi = _taksiAjandaVerisi;
        var gunlukVeri = (tarihKey.isNotEmpty && taksiVerisi != null) ? taksiVerisi[tarihKey] as Map<String, dynamic>? : null;

        List<dynamic> kanallar = List.from(esnaf.kanallar ?? []);

        // Taksi için Filtreleme ve Sıralama
        if (esnaf.kategori == 'Taksi' && gunlukVeri != null) {
          // İstirahatli ve gizlenmesi gerekenleri çıkar
          if (esnaf.istirahatliAraclariGizle) {
            kanallar.removeWhere((k) => gunlukVeri[k.toString()] == 'I');
          }

          // Sıralama: Nöbetçi > Çalışan > Diğerleri
          kanallar.sort((a, b) {
            String pA = a.toString();
            String pB = b.toString();
            String dA = gunlukVeri[pA] ?? "";
            String dB = gunlukVeri[pB] ?? "";

            int sA = dA == 'N' ? 0 : (dA == 'C' ? 1 : 2);
            int sB = dB == 'N' ? 0 : (dB == 'C' ? 1 : 2);

            if (sA != sB) return sA.compareTo(sB);
            return pA.compareTo(pB);
          });
        }

        return Wrap(
          spacing: 10,
          children: kanallar.map((k) {
            String plaka = k.toString();
            bool secili = seciliKanal == plaka;
            String? durumEtiketi;
            Color chipColor = Colors.indigo;

            if (esnaf.kategori == 'Taksi' && gunlukVeri != null) {
              String durum = gunlukVeri[plaka] ?? "";
              if (durum == 'N') {
                durumEtiketi = "Nöbetçi";
                chipColor = Colors.orange.shade700;
              } else if (durum == 'I') {
                durumEtiketi = "İstirahat";
              }
            }

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(plaka),
                  if (durumEtiketi != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                      child: Text(durumEtiketi, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ],
                ],
              ),
              selected: secili,
              selectedColor: chipColor,
              labelStyle: TextStyle(color: secili ? Colors.white : Colors.black87),
              onSelected: (val) {
                if (val) {
                  _seciliKanalNotifier.value = plaka;
                  _seciliSaatNotifier.value = null;
                  _otomatikTarihSec(esnaf);
                  _updateStreams();
                  _enYakinMusaitligiBul(esnaf);
                  _sonrakiAdimaGit(100);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _personelSeciciWidget(EsnafModeli esnaf) {
    final isTaksi = esnaf.kategori == 'Taksi';
    final aracModu = isTaksi && esnaf.aracOdakliSistem;
    final List<dynamic> liste = (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) ? esnaf.araclar : (esnaf.personeller ?? []);

    return ValueListenableBuilder<String?>(
      valueListenable: (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) ? _seciliKanalNotifier : _seciliPersonelNotifier,
      builder: (context, secili, _) {
        return Wrap(
          spacing: 10,
          children: liste.map((item) {
            String isim = (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) ? (item['plaka'] ?? "") : (item['isim'] ?? "");
            String kanal = (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) ? (item['plaka'] ?? "") : (item['kanal'] ?? "");
            bool seciliMi = secili == ((isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) ? kanal : isim);

            return ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: seciliMi ? Colors.white24 : Colors.indigo.shade50,
                child: Text(isim.isNotEmpty ? isim[0] : "?", style: TextStyle(fontSize: 10, color: seciliMi ? Colors.white : Colors.indigo)),
              ),
              label: Text(isim),
              selected: seciliMi,
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(color: seciliMi ? Colors.white : Colors.black87),
              onSelected: (val) {
                if (val) {
                  if (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin)) {
                    _seciliKanalNotifier.value = kanal;
                  } else {
                    _seciliPersonelNotifier.value = isim;
                    _seciliKanalNotifier.value = kanal;
                  }
                  _seciliSaatNotifier.value = null;
                  _otomatikTarihSec(esnaf);
                  _updateStreams();
                  _enYakinMusaitligiBul(esnaf);
                  _sonrakiAdimaGit(100);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _saatSecimiBolumuSliver(EsnafModeli esnaf) {
    return ValueListenableBuilder<bool>(
      valueListenable: _aramaYapiliyorNotifier,
      builder: (context, aramaYapiliyor, _) {
        if (aramaYapiliyor) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Size en uygun saatler aranıyor...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: _musaitlikBulunamadiNotifier,
          builder: (context, bulunamadi, _) {
            if (bulunamadi) {
              return SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 15),
                      Expanded(child: Text("Üzgünüz, bu tarih için uygun boşluk bulunamadı. Lütfen başka bir gün seçin.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              );
            }

            final slotlar = _slotlariUret(esnaf, _gununAjandaVerisi);
            if (slotlar.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Çalışma saati bulunamadı."))));

            return ValueListenableBuilder<String?>(
                valueListenable: _seciliSaatNotifier,
                builder: (context, seciliSaat, _) {
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _seciliHizmetlerNotifier,
                      builder: (context, hizmetler, _) {
                        int toplamSure = _getToplamSure(hizmetler);

                        return SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: esnaf.slotAralikliGoster ? 3 : 4,
                            childAspectRatio: esnaf.slotAralikliGoster ? 2.5 : 2.0,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              String saat = slotlar[index];
                              String? nedenKapali = _saatNedenKapali(esnaf, saat, _sonRandevular, toplamSure, ajandaVerisi: _gununAjandaVerisi);
                              bool musait = nedenKapali == null;
                              bool secili = seciliSaat == saat;

                              String saatText = saat;
                              if (esnaf.slotAralikliGoster) {
                                int basDakika = _saatiDakikayaCevir(saat);
                                int slotDakika = (esnaf.calismaSaatleri?['slotDakika'] ?? 30).toInt();
                                int bitDakika = basDakika + (toplamSure > 0 ? toplamSure : slotDakika);
                                saatText = "$saat - ${_dakikaFormatli(bitDakika % 1440)}";
                              }

                              return InkWell(
                                onTap: musait ? () {
                                  _seciliSaatNotifier.value = saat;
                                  _saatKendimSececegimNotifier.value = true;
                                } : null,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: secili ? Colors.blue : (musait ? Colors.white : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: secili ? Colors.blue : Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        saatText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: secili ? Colors.white : (musait ? Colors.black : Colors.grey),
                                          fontWeight: musait ? FontWeight.bold : FontWeight.normal,
                                          fontSize: esnaf.slotAralikliGoster ? 11 : 14,
                                        ),
                                      ),
                                      if (nedenKapali != null && nedenKapali.isNotEmpty)
                                        Text(nedenKapali, style: const TextStyle(color: Colors.red, fontSize: 9, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: slotlar.length,
                          ),
                        );
                      }
                  );
                }
            );
          },
        );
      },
    );
  }

}