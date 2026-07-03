import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';
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

  final ValueNotifier<List<Map<String, dynamic>>> _seciliHizmetlerNotifier =
      ValueNotifier([]);
  final ValueNotifier<String?> _seciliSaatNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliBitisSaatiNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliPersonelNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliTarihNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliBitisTarihiNotifier =
      ValueNotifier(null);
  final ValueNotifier<String?> _seciliKanalNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _saatKendimSececegimNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _aramaYapiliyorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _musaitlikBulunamadiNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _islemYapiliyorNotifier = ValueNotifier(false);

  List<RandevuModeli> _sonRandevular = [];
  Map<String, dynamic>? _gununAjandaVerisi;
  Map<String, dynamic>? _taksiAjandaVerisi;
  int _otomatikAramaSayaci = 0;
  StreamSubscription? _ajandaSub;
  StreamSubscription? _taksiAjandaSub;
  StreamSubscription? _randevularSub;

  late Stream<EsnafModeli> _esnafStream;

  bool get _isAracKiralama => widget.esnaf.kategori == 'Araç Kiralama';

  @override
  void initState() {
    super.initState();
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);

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
    } else if (widget.esnaf.kanallar != null &&
        widget.esnaf.kanallar!.isNotEmpty) {
      if (widget.esnaf.kanallar!.length == 1) {
        final k = widget.esnaf.kanallar!.first;
        if (k is Map) {
          _seciliKanalNotifier.value = k['ad']?.toString() ??
              k['plaka']?.toString() ??
              k['aracTuru']?.toString() ??
              k.toString();
        } else {
          _seciliKanalNotifier.value = k.toString();
        }
      }
    } else {
      _seciliKanalNotifier.value = "";
    }

    if (widget.kullaniciTel != null) {
      _telController.text = widget.kullaniciTel!;
    }

    _seciliKanalNotifier.addListener(_onKanalChanged);
    _seciliTarihNotifier.addListener(_updateStreams);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aramaYapiliyorNotifier.value = true;
      _onKanalChanged();
    });
  }

  void _onKanalChanged() {
    if (!_isAracKiralama) {
      _otomatikTarihSec(widget.esnaf);
    }
    _updateStreams();
  }

  void _otomatikTarihSec(EsnafModeli esnaf) {
    final aktifler = _getAktifTarihler(esnaf);
    if (aktifler.isNotEmpty) {
      if (_seciliTarihNotifier.value == null ||
          !aktifler.any((d) =>
              d.year == _seciliTarihNotifier.value!.year &&
              d.month == _seciliTarihNotifier.value!.month &&
              d.day == _seciliTarihNotifier.value!.day)) {
        _seciliTarihNotifier.value = aktifler.first;
      }
    } else {
      if (!_isAracKiralama) {
        _seciliTarihNotifier.value = null;
      }
    }
  }

  void _otomatikSaatSec(EsnafModeli esnaf) {
    if (_isAracKiralama) {
      return;
    }

    final slotlar = _slotlariUret(esnaf, _gununAjandaVerisi);
    final hizmetler = _seciliHizmetlerNotifier.value;
    final toplamSure = _getToplamSure(hizmetler, esnaf);

    for (var s in slotlar) {
      if (_saatMusaitMi(esnaf, s, _sonRandevular, toplamSure,
          ajandaVerisi: _gununAjandaVerisi)) {
        _seciliSaatNotifier.value = s;
        _aramaYapiliyorNotifier.value = false;
        return;
      }
    }
    _seciliSaatNotifier.value = null;

    if (_aramaYapiliyorNotifier.value && _otomatikAramaSayaci < 7) {
      _otomatikAramaSayaci++;
      _sonrakiGunuSec();
    } else {
      _aramaYapiliyorNotifier.value = false;
      if (_otomatikAramaSayaci >= 7) {
        _musaitlikBulunamadiNotifier.value = true;
      }
    }
  }

  void _sonrakiGunuSec() {
    final aktifler = _getAktifTarihler(widget.esnaf);
    final suanki = _seciliTarihNotifier.value;
    if (suanki == null || aktifler.isEmpty) {
      return;
    }

    int idx = aktifler.indexWhere((d) =>
        d.year == suanki.year && d.month == suanki.month && d.day == suanki.day);

    if (idx != -1 && idx < aktifler.length - 1) {
      _seciliTarihNotifier.value = aktifler[idx + 1];
    } else {
      _aramaYapiliyorNotifier.value = false;
      _musaitlikBulunamadiNotifier.value = true;
    }
  }

  void _updateStreams() {
    final tarih = _seciliTarihNotifier.value;
    final kanal = _seciliKanalNotifier.value;
    if (tarih != null) {
      _ajandaSub?.cancel();
      _taksiAjandaSub?.cancel();
      _randevularSub?.cancel();

      _ajandaSub = _firestoreServisi
          .gunlukAjandaSnapStream(widget.esnaf.id, tarih, kanal)
          .listen((snap) {
        if (mounted) {
          if (snap.exists) {
            setState(() {
              _gununAjandaVerisi = snap.data() as Map<String, dynamic>?;
            });
            _otomatikSaatSec(widget.esnaf);
          } else {
            _firestoreServisi
                .gunlukAjandaSnapStream(widget.esnaf.id, tarih, null)
                .first
                .then((genelSnap) {
              if (mounted) {
                if (genelSnap.exists) {
                  setState(() {
                    _gununAjandaVerisi =
                        genelSnap.data() as Map<String, dynamic>?;
                  });
                } else {
                  setState(() {
                    _gununAjandaVerisi = null;
                  });
                }
                _otomatikSaatSec(widget.esnaf);
              }
            });
          }
        }
      });

      if (widget.esnaf.kategori == 'Taksi') {
        _taksiAjandaSub = _firestoreServisi
            .taksiAjandasiSnapStream(widget.esnaf.id, tarih)
            .listen((snap) {
          if (mounted) {
            setState(() {
              _taksiAjandaVerisi = snap.data() as Map<String, dynamic>?;
            });
          }
        });
      }

      int pencere = _isAracKiralama ? 30 : 0;
      _randevularSub = _firestoreServisi
          .randevulariGetir(widget.esnaf.id, tarih, pencereGun: pencere)
          .listen((list) {
        if (mounted) {
          setState(() {
            _sonRandevular = list;
          });
          _otomatikSaatSec(widget.esnaf);
        }
      });
    }
  }

  @override
  void dispose() {
    _seciliKanalNotifier.removeListener(_onKanalChanged);
    _seciliTarihNotifier.removeListener(_updateStreams);
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
    _seciliBitisTarihiNotifier.dispose();
    _seciliBitisSaatiNotifier.dispose();
    _saatKendimSececegimNotifier.dispose();
    _aramaYapiliyorNotifier.dispose();
    _musaitlikBulunamadiNotifier.dispose();
    super.dispose();
  }

  int _getToplamSure(List<Map<String, dynamic>> hizmetler, EsnafModeli esnaf) {
    if (esnaf.kategori == 'Araç Kiralama') {
      DateTime? basTarih = _seciliTarihNotifier.value;
      String? basSaat = _seciliSaatNotifier.value;
      DateTime? bitTarih = _seciliBitisTarihiNotifier.value;
      String? bitSaat = _seciliBitisSaatiNotifier.value;

      if (basTarih == null ||
          basSaat == null ||
          bitTarih == null ||
          bitSaat == null) {
        return 0;
      }

      final start = DateTime(
          basTarih.year,
          basTarih.month,
          basTarih.day,
          int.parse(basSaat.split(':')[0]),
          int.parse(basSaat.split(':')[1]));
      final end = DateTime(
          bitTarih.year,
          bitTarih.month,
          bitTarih.day,
          int.parse(bitSaat.split(':')[0]),
          int.parse(bitSaat.split(':')[1]));

      final farkDk = end.difference(start).inMinutes;
      if (farkDk <= 0) {
        return 0;
      }

      bool isDaily = farkDk > 1440 || basTarih.day != bitTarih.day;

      if (isDaily) {
        return ((farkDk / 1440).ceil() * 1440);
      } else {
        return farkDk;
      }
    }
    int toplam = 0;
    for (var h in hizmetler) {
      toplam += int.tryParse(h['sure'].toString()) ?? 0;
    }
    return toplam;
  }

  List<DateTime> _getAktifTarihler(EsnafModeli esnaf) {
    // [CANLI YAPI] Eğer esnaf 'Ben ayarlayacağım' demediyse, dinamik takvim uret
    if (!esnaf.ajandayiKendimAyarlayacagim) {
      List<DateTime> tarihler = [];
      final bugun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final gunler = esnaf.calismaSaatleri?['gunler'] as Map<String, dynamic>? ?? {};
      
      // Esnafın belirlediği maksimum gün kadar ileriye git (Varsayılan 30 gün)
      int maxGun = esnaf.maksimumRandevuGunu;

      for (int i = 0; i < maxGun; i++) {
        final t = bugun.add(Duration(days: i));
        String gunAdi = DateFormat('EEEE', 'tr_TR').format(t);
        
        // Çalışılmayan günleri atla (Esnaf Profil ayarlarından gelir)
        if (gunler.containsKey(gunAdi) && gunler[gunAdi] == false) continue;

        // Bugün için mesai bittiyse atla
        if (i == 0) {
          final calisma = esnaf.calismaSaatleri;
          if (calisma != null) {
            String kapanis = calisma['kapanis'] ?? "18:00";
            if (kapanis != "00:00" && kapanis != "24:00") {
              int kDk = _saatiDakikayaCevir(kapanis);
              int suanDk = DateTime.now().hour * 60 + DateTime.now().minute;
              if (suanDk >= kDk - 30) continue;
            }
          }
        }
        tarihler.add(t);
      }
      return tarihler;
    }

    final aktifler = esnaf.aktifGunler ?? [];
    List<DateTime> tarihler = [];
    final bugun =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final kanal = _seciliKanalNotifier.value;
    final gunler =
        esnaf.calismaSaatleri?['gunler'] as Map<String, dynamic>? ?? {};

    for (var item in aktifler) {
      final s = item.toString();
      bool tarihUygun = false;

      if (kanal != null && kanal.isNotEmpty) {
        if (s.endsWith("_$kanal") || !s.contains('_')) {
          tarihUygun = true;
        }
      } else {
        if (!s.contains('_')) {
          tarihUygun = true;
        }
      }

      if (!tarihUygun) {
        continue;
      }

      try {
        DateTime t = DateFormat('yyyy-MM-dd').parse(s.split('_')[0]);
        String gunAdi = DateFormat('EEEE', 'tr_TR').format(t);
        if (gunler.containsKey(gunAdi) && gunler[gunAdi] == false) {
          continue;
        }

        if (t.isAtSameMomentAs(bugun)) {
          final calisma = esnaf.calismaSaatleri;
          if (calisma != null) {
            String kapanis = calisma['kapanis'] ?? "18:00";
            if (kapanis != "00:00" && kapanis != "24:00") {
              int kDk = _saatiDakikayaCevir(kapanis);
              int suanDk = DateTime.now().hour * 60 + DateTime.now().minute;
              if (suanDk >= kDk - 30) {
                continue;
              }
            }
          }
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
    try {
      final parcalar = saat.split(':');
      return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
    } catch (e) {
      return 0;
    }
  }

  List<String> _slotlariUret(
      EsnafModeli esnaf, Map<String, dynamic>? ajandaVerisi) {
    List<String> slotlar = [];
    final calisma = ajandaVerisi ?? esnaf.calismaSaatleri;
    if (calisma == null) {
      return [];
    }

    String acilis = calisma['acilis'] ?? "09:00";
    String kapanis = calisma['kapanis'] ?? "18:00";
    bool is724 = (acilis == kapanis) ||
        (acilis == "00:00" && kapanis == "00:00") ||
        (calisma['is724'] == true);

    if (is724) {
      kapanis = acilis;
    }

    int slotAraligi = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;
    if (slotAraligi <= 0) {
      return [];
    }

    try {
      DateTime current = DateFormat("HH:mm").parse(acilis);
      DateTime end = DateFormat("HH:mm").parse(kapanis);
      if (is724 || end.isBefore(current) || end.isAtSameMomentAs(current)) {
        end = end.add(const Duration(days: 1));
      }
      while (current.isBefore(end)) {
        slotlar.add(DateFormat("HH:mm").format(current));
        current = current.add(Duration(minutes: slotAraligi));
      }
    } catch (e) {
      debugPrint("Slot üretme hatası: $e");
    }
    return slotlar;
  }

  String _dakikaFormatli(int toplamDakika) {
    int saat = (toplamDakika ~/ 60) % 24;
    int dakika = toplamDakika % 60;
    return "${saat.toString().padLeft(2, '0')}:${min(59, dakika).toString().padLeft(2, '0')}";
  }

  int min(int a, int b) => a < b ? a : b;

  String? _saatNedenKapali(
      EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi,
      {Map<String, dynamic>? ajandaVerisi,
      DateTime? hedefTarih,
      Map<String, dynamic>? hariciTaksiAjandasi,
      String? kanalFiltresi}) {
    final tarih = hedefTarih ?? _seciliTarihNotifier.value;
    final kanal = kanalFiltresi ?? _seciliKanalNotifier.value;
    if (tarih == null) {
      return "Tarih seçilmedi";
    }

    if (esnaf.kategori == 'Taksi' && kanal != null && kanal.isNotEmpty) {
      String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
      final taksiVerisi = hariciTaksiAjandasi ?? _taksiAjandaVerisi;
      var gunlukVeri = taksiVerisi?[tarihKey] as Map<String, dynamic>?;
      if (gunlukVeri != null && gunlukVeri.containsKey(kanal)) {
        String durum = gunlukVeri[kanal];
        if (durum == 'I') {
          return "İstirahatte";
        }
        if (durum == 'N' &&
            esnaf.nobetBaslangic != null &&
            esnaf.nobetBitis != null) {
          int sDk = _saatiDakikayaCevir(slot);
          int nBas = _saatiDakikayaCevir(esnaf.nobetBaslangic!);
          int nBit = _saatiDakikayaCevir(esnaf.nobetBitis!);
          bool musait = nBit > nBas
              ? (sDk >= nBas && sDk < nBit)
              : (sDk >= nBas || sDk < nBit);
          if (!musait) {
            return "Mesai Dışı";
          }
        }
      } else {
        final arac = esnaf.araclar.cast<Map<String, dynamic>?>().firstWhere(
              (a) => a?['plaka'] == kanal,
              orElse: () => null,
            );
        if (arac != null) {
          String gunAdi = DateFormat('EEEE', 'tr_TR').format(tarih);
          bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
          if (!calisiyor) {
            return "İstirahatte";
          }
        }
      }
    }

    final calisma = ajandaVerisi ?? esnaf.calismaSaatleri;
    if (calisma == null) {
      return "Çalışma saati yok";
    }

    int slotDakika = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;

    if (ajandaVerisi != null &&
        ajandaVerisi['ogleBaslangic'] != null &&
        ajandaVerisi['ogleBitis'] != null) {
      int sDk = _saatiDakikayaCevir(slot);
      int oBasDk = _saatiDakikayaCevir(ajandaVerisi['ogleBaslangic']);
      int oBitDk = _saatiDakikayaCevir(ajandaVerisi['ogleBitis']);
      if (sDk >= oBasDk && sDk < oBitDk) {
        return "Öğle Arası";
      }
    }

    final slotParcalar = slot.split(':');
    DateTime sBaslangic = DateTime(tarih.year, tarih.month, tarih.day,
        int.parse(slotParcalar[0]), int.parse(slotParcalar[1]));

    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final seciliGun = DateTime(tarih.year, tarih.month, tarih.day);

    if (seciliGun.isAtSameMomentAs(bugun)) {
      int tolerans = esnaf.kategori == 'Araç Kiralama' ? 30 : 10;
      if (sBaslangic.isBefore(simdi.subtract(Duration(minutes: tolerans)))) {
        return "Geçmiş saat";
      }
    } else if (seciliGun.isBefore(bugun)) {
      return "Geçmiş tarih";
    }

    int kontrolSuresi = hizmetSuresi > 0 ? hizmetSuresi : slotDakika;
    DateTime sBitis = sBaslangic.add(Duration(minutes: kontrolSuresi));

    if (esnaf.kategori != 'Araç Kiralama' &&
        (calisma['acilis'] != "00:00" || calisma['kapanis'] != "00:00")) {
      String kapanis = calisma['kapanis'] ?? "18:00";
      DateTime kZaman = DateTime(
          tarih.year,
          tarih.month,
          tarih.day,
          int.parse(kapanis.split(':')[0]),
          int.parse(kapanis.split(':')[1]));
      if (kapanis == "00:00" ||
          kapanis == "24:00" ||
          kZaman.isBefore(DateTime(
              tarih.year,
              tarih.month,
              tarih.day,
              int.parse((calisma['acilis'] ?? "09:00").split(':')[0])))) {
        kZaman = kZaman.add(const Duration(days: 1));
      }
      if (sBitis.isAfter(kZaman)) {
        return "";
      }
    }

    for (var r in randevular) {
      if (kanal != null && kanal.isNotEmpty && r.randevuKanali != kanal) {
        continue;
      }

      if (r.durum == 'Onay bekliyor' &&
          esnaf.randevuOnayModu == 'Manuel' &&
          r.olusturulmaTarihi != null) {
        if (DateTime.now().difference(r.olusturulmaTarihi!).inMinutes >= 10) {
          continue;
        }
      }

      final rSaParcalar = r.saat.split(':');
      DateTime rBas = DateTime(r.tarih.year, r.tarih.month, r.tarih.day,
          int.parse(rSaParcalar[0]), int.parse(rSaParcalar[1]));
      DateTime rBit = rBas.add(Duration(minutes: r.sure));
      if (sBaslangic.isBefore(rBit) && sBitis.isAfter(rBas)) {
        return r.durum == 'Onaylandı' ? "Dolu" : "Rezerve";
      }

      if (esnaf.kategori == 'Araç Kiralama' && esnaf.bakimTemizlikSuresi > 0) {
        DateTime rBakimBit =
            rBit.add(Duration(minutes: esnaf.bakimTemizlikSuresi));
        if (sBaslangic.isBefore(rBakimBit) && sBitis.isAfter(rBit)) {
          return "Bakım ve Temizlik Sürecinde";
        }
      }
    }
    return null;
  }

  bool _saatMusaitMi(
      EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi,
      {Map<String, dynamic>? ajandaVerisi,
      DateTime? hedefTarih,
      Map<String, dynamic>? hariciTaksiAjandasi,
      String? kanalFiltresi}) {
    String? neden = _saatNedenKapali(esnaf, slot, randevular, hizmetSuresi,
        ajandaVerisi: ajandaVerisi,
        hedefTarih: hedefTarih,
        hariciTaksiAjandasi: hariciTaksiAjandasi,
        kanalFiltresi: kanalFiltresi);

    if (neden == "Bakım ve Temizlik Sürecinde" &&
        esnaf.bakimSurecindeRandevuAlinsin) {
      return true;
    }

    return neden == null;
  }

  Future<void> _randevuKaydet(EsnafModeli esnaf, Map<String, dynamic>? ajanda) async {
    if (_islemYapiliyorNotifier.value) return;
    _islemYapiliyorNotifier.value = true;

    final hizmetler = _seciliHizmetlerNotifier.value;
    final saat = _seciliSaatNotifier.value;
    final tarih = _seciliTarihNotifier.value;
    final personel = _seciliPersonelNotifier.value;
    final kanal = _seciliKanalNotifier.value;

    if (_adController.text.isEmpty ||
        _telController.text.isEmpty ||
        (hizmetler.isEmpty && !_isAracKiralama) ||
        saat == null ||
        tarih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      return;
    }

    int toplamSure = _getToplamSure(hizmetler, esnaf);

    // [YENİ] Minimum Randevu Süresi Kontrolü
    if (toplamSure < esnaf.minimumRandevuSuresi) {
      String sureMetni = esnaf.minimumRandevuSuresi >= 60 
          ? "${esnaf.minimumRandevuSuresi ~/ 60} saat" 
          : "${esnaf.minimumRandevuSuresi} dakika";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Bu dükkan için minimum randevu süresi $sureMetni olarak belirlenmiştir."),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    if (!_saatMusaitMi(esnaf, saat, _sonRandevular, toplamSure,
        ajandaVerisi: ajanda)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Seçtiğiniz saat kiralama süresi için uygun değil veya dolu."),
          backgroundColor: Colors.red));
      return;
    }

    String durm =
        esnaf.randevuOnayModu == 'Otomatik' ? 'Onaylandı' : 'Onay bekliyor';
    final isTaksi = esnaf.kategori == 'Taksi';
    final aracModu = isTaksi && esnaf.aracOdakliSistem;

    String hAdi = _isAracKiralama
        ? "${toplamSure > 1440 ? 'Günlük' : 'Saatlik'} Kiralama"
        : hizmetler.map((h) => h['isim']).join(' + ');

    bool akilliTakipModu = esnaf.kategori == 'Araç Kiralama' && esnaf.akilliTakipModu;
    DateTime? bildirimZamani;
    
    if (akilliTakipModu) {
      final DateTime bitisZamani = DateTime(
        tarih.year,
        tarih.month,
        tarih.day,
        int.parse(saat.split(':')[0]),
        int.parse(saat.split(':')[1]),
      ).add(Duration(minutes: toplamSure));
      bildirimZamani = bitisZamani.subtract(Duration(minutes: esnaf.akilliTakipSuresi));
    }

    // Telefon numarasını temizle (Consistency için)
    String temizTel = _telController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (temizTel.startsWith('0')) temizTel = temizTel.substring(1);

    final yeniRandevu = RandevuModeli(
      id: '',
      esnafId: esnaf.id,
      esnafAdi: esnaf.isletmeAdi,
      esnafTel: esnaf.telefon,
      kullaniciAd: _adController.text,
      kullaniciTel: temizTel,
      tarih: tarih,
      saat: saat,
      sure: toplamSure,
      hizmetAdi: hAdi,
      randevuKanali: kanal,
      calisanPersonel: aracModu ? null : personel,
      durum: durm,
      akilliTakipAktif: akilliTakipModu,
      bildirimZamani: bildirimZamani,
    );

    try {
      // Randevuyu ekle ve sonucunu al (Bildirim durumu için)
      final String? resHata = await _firestoreServisi.randevuEkle(yeniRandevu);
      
      _islemYapiliyorNotifier.value = false;

      if (!mounted) return;

      String tarihFormat = DateFormat('dd.MM.yyyy').format(tarih);
      String saatGosterim = saat;
      if (esnaf.slotAralikliGoster) {
        final calisma = ajanda ?? esnaf.calismaSaatleri;
        int slotAraligi = (calisma?['slotDakika'] ?? 30).toInt();
        int baslangicDakika = _saatiDakikayaCevir(saat);
        int bitisDakika = baslangicDakika + slotAraligi;
        saatGosterim = "$saat - ${_dakikaFormatli(bitisDakika % 1440)}";
      }

      String yaklasikIbaresi = esnaf.kategori == 'Halı Saha' ? '' : 'yaklaşık ';
      String sureMetni = "$toplamSure dk";
      if (_isAracKiralama) {
        int gun = toplamSure ~/ 1440;
        int sa = (toplamSure % 1440) ~/ 60;
        if (gun > 0 && sa > 0) {
          sureMetni = "$gun Gün $sa Saat";
        } else if (gun > 0) {
          sureMetni = "$gun Gün";
        } else if (sa > 0) {
          sureMetni = "$sa Saat";
        }
      }

      String baslik = _isAracKiralama ? "Araç kiralama rezervasyonunuz" : "Randevunuz";
      String sureEtiket = _isAracKiralama ? "Kiralama süreniz" : "Randevu süreniz";
      String mesaj = durm == 'Onaylandı'
          ? "$baslik $tarihFormat tarihinde saat $saatGosterim olarak onaylanmıştır. $sureEtiket $yaklasikIbaresi$sureMetni sürecektir. ${esnaf.isletmeAdi} olarak teşekkür ederiz."
          : "$baslik $tarihFormat tarihinde saat $saatGosterim için alınmıştır. $sureEtiket $yaklasikIbaresi$sureMetni sürecektir. ${esnaf.isletmeAdi} olarak teşekkür ederiz. Onay bekleniyor.";

      // [YENİ] Bildirim uyarısı ekle
      if (resHata == "ALICI_YOK") {
        mesaj += "\n\n⚠️ DİKKAT: Bildirimlerin telefonunuza ulaşması için bir kez mobil uygulamadan giriş yapmalısınız!";
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Icon(
            resHata == "ALICI_YOK" ? Icons.warning_amber_rounded : Icons.check_circle, 
            color: resHata == "ALICI_YOK" ? Colors.orange : Colors.green, 
            size: 60
          ),
          content: Text(mesaj, textAlign: TextAlign.center),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("TAMAM"))
          ],
        ),
      );
    } catch (e) {
      _islemYapiliyorNotifier.value = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
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
                shape: BoxShape.circle),
            child: Text(no,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(baslik,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: aktif ? Colors.black87 : Colors.grey)),
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
            const Text("Randevu Al",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.esnaf.isletmeAdi,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: StreamBuilder<EsnafModeli>(
        stream: _esnafStream,
        builder: (context, esnafSnapshot) {
          if (esnafSnapshot.connectionState == ConnectionState.waiting &&
              !esnafSnapshot.hasData) {
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
                    if (!_isAracKiralama) ...[
                      SliverToBoxAdapter(
                          child: _adimBasligi("1", "Hizmet Seçin")),
                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _seciliHizmetlerNotifier,
                        builder: (context, seciliHizmetler, _) {
                          final hizmetler = esnaf.hizmetler ?? [];
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final h = hizmetler[index];
                                bool secili = seciliHizmetler.any(
                                    (element) => element['isim'] == h['isim']);

                                IconData ikon = Icons.auto_awesome;
                                String hIsim = h['isim'].toString().toLowerCase();
                                if (hIsim.contains("kesim") || hIsim.contains("sakal")) ikon = Icons.content_cut;
                                if (hIsim.contains("boya")) ikon = Icons.color_lens;
                                if (hIsim.contains("yikama")) ikon = Icons.local_car_wash;

                                bool showPrice = h['ucretGoster'] ?? false;
                                double ucret = (h['ucret'] ?? 0).toDouble();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: secili
                                              ? Colors.indigo
                                              : Colors.grey.shade200)),
                                  child: CheckboxListTile(
                                    secondary: Icon(ikon,
                                        color: secili
                                            ? Colors.indigo
                                            : Colors.grey),
                                    title: Text(h['isim']),
                                    subtitle: Row(
                                      children: [
                                        Text("${h['sure']} Dakika"),
                                        if (showPrice) ...[
                                          const Text(" • "),
                                          Text(
                                            ucret > 0
                                                ? "${ucret.toStringAsFixed(0)} TL"
                                                : "Ücretsiz",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: ucret > 0
                                                    ? Colors.green
                                                    : Colors.blue),
                                          ),
                                        ],
                                      ],
                                    ),
                                    value: secili,
                                    onChanged: (val) {
                                      List<Map<String, dynamic>> yeniListe = List.from(seciliHizmetler);
                                      if (val == true) {
                                        yeniListe.add(Map<String, dynamic>.from(h));
                                      } else {
                                        yeniListe.removeWhere((element) => element['isim'] == h['isim']);
                                      }
                                      _seciliHizmetlerNotifier.value = yeniListe;
                                      _updateStreams();
                                      if (yeniListe.length == 1 && val == true) _sonrakiAdimaGit(150);
                                    },
                                  ),
                                );
                              },
                              childCount: hizmetler.length,
                            ),
                          );
                        },
                      ),
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
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    if (aracModu || personelModu || kanalSecilmeli) ...[
                                      ValueListenableBuilder<String?>(
                                        valueListenable: _seciliPersonelNotifier,
                                        builder: (context, personel, _) {
                                          return _adimBasligi(
                                              "2",
                                              (personelModu && personel != null)
                                                  ? "Personel: $personel"
                                                  : (personelModu
                                                      ? "Personel Seçimi"
                                                      : "Bölüm / Masa Seçimi"));
                                        },
                                      ),
                                      _kanalSeciciWidget(esnaf),
                                    ] else if (esnaf.kanallar != null && esnaf.kanallar!.isNotEmpty)
                                      _seciliBilgiKarti("Seçilen Bölüm", _seciliKanalNotifier.value ?? ""),
                                  ],
                                ),
                              ),
                              ValueListenableBuilder<String?>(
                                valueListenable: _seciliKanalNotifier,
                                builder: (context, kanal, _) {
                                  bool kanalGerekli = aracModu || personelModu || kanalSecilmeli;
                                  bool kanalSecili = kanal != null && kanal.isNotEmpty;
                                  if (kanalGerekli && !kanalSecili) return const SliverToBoxAdapter(child: SizedBox.shrink());
                                  return SliverMainAxisGroup(
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Column(
                                          children: [
                                            _adimBasligi("3", "Tarih Seçin"),
                                            _tarihSeciciWidget(esnaf),
                                          ],
                                        ),
                                      ),
                                      ValueListenableBuilder<DateTime?>(
                                        valueListenable: _seciliTarihNotifier,
                                        builder: (context, tarih, _) {
                                          if (tarih == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                                          return SliverMainAxisGroup(
                                            slivers: [
                                              SliverToBoxAdapter(child: _adimBasligi("4", "Saat Seçin")),
                                              _saatSecimiBolumuSliver(esnaf),
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

                    if (_isAracKiralama) ...[
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _adimBasligi("1", "Alış ve İade Bilgileri"),
                            _aracKiralamaZamanSecici(esnaf),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<String?>(
                          valueListenable: _seciliBitisSaatiNotifier,
                          builder: (context, bitSaat, _) {
                            if (bitSaat == null || bitSaat.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                            return SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _adimBasligi("2", "Araç Seçiniz"),
                                  _kanalSeciciWidget(esnaf),
                                ],
                              ),
                            );
                          }),
                    ],

                    ValueListenableBuilder<String?>(
                      valueListenable: _seciliKanalNotifier,
                      builder: (context, seciliKanal, _) {
                        bool gorunur = false;
                        if (_isAracKiralama) {
                          gorunur = seciliKanal != null && seciliKanal.isNotEmpty;
                        } else {
                          gorunur = _seciliSaatNotifier.value != null;
                        }
                        if (!gorunur) return const SliverToBoxAdapter(child: SizedBox.shrink());
                        return SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              _adimBasligi(_isAracKiralama ? "3" : "5", "İletişim Bilgileri"),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey.shade200)),
                                child: Column(
                                  children: [
                                    TextField(
                                        controller: _adController,
                                        decoration: const InputDecoration(
                                            labelText: "Ad Soyad",
                                            prefixIcon: Icon(Icons.person_outline),
                                            border: OutlineInputBorder())),
                                    const SizedBox(height: 15),
                                    TextField(
                                        controller: _telController,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                            labelText: "Telefon Numarası",
                                            prefixIcon: Icon(Icons.phone_outlined),
                                            border: OutlineInputBorder())),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                        return ValueListenableBuilder<DateTime?>(
                            valueListenable: _seciliBitisTarihiNotifier,
                            builder: (context, bitTarih, _) {
                              return ValueListenableBuilder<String?>(
                                  valueListenable: _seciliBitisSaatiNotifier,
                                  builder: (context, bitSaat, _) {
                                    return ValueListenableBuilder<String?>(
                                        valueListenable: _seciliKanalNotifier,
                                        builder: (context, kanal, _) {
                                          final toplamSure = _getToplamSure(hizmetler, widget.esnaf);
                                          bool musait = saat != null &&
                                              _saatMusaitMi(widget.esnaf, saat, _sonRandevular, toplamSure, ajandaVerisi: _gununAjandaVerisi);
                                          bool butonAktif = saat != null && (_isAracKiralama || hizmetler.isNotEmpty) && musait;

                                          if (_isAracKiralama) {
                                            if (kanal == null || kanal.isEmpty) butonAktif = false;
                                            if (toplamSure <= 0) butonAktif = false;
                                          }

                                          String butonMetni = "RANDEVUYU TAMAMLA";
                                          if (_isAracKiralama) {
                                            if (toplamSure <= 0) {
                                              butonMetni = "ZAMAN ARALIĞI SEÇİN";
                                            } else if (kanal == null || kanal.isEmpty) {
                                              butonMetni = "ARAÇ SEÇİNİZ";
                                            } else if (!musait) {
                                              butonMetni = "SEÇİLEN ARAÇ DOLU";
                                            }
                                          }

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
                                                        String saatGosterim = saat;
                                                        if (widget.esnaf.slotAralikliGoster) {
                                                          final calisma = _gununAjandaVerisi ?? widget.esnaf.calismaSaatleri;
                                                          int slotDakika = (calisma?['slotDakika'] ?? 30).toInt();
                                                          int basDakika = _saatiDakikayaCevir(saat);
                                                          int bitDakika = basDakika + (toplamSure > 0 ? toplamSure : slotDakika);
                                                          saatGosterim = "$saat - ${_dakikaFormatli(bitDakika % 1440)}";
                                                        }
                                                        bool isSelected = kendimSectim || _isAracKiralama;
                                                        String prefix = _isAracKiralama ? "Araç Alış Saatini" : "Randevu saatini";
                                                        return Text(
                                                          isSelected
                                                              ? "$prefix $saatGosterim olarak seçtiniz"
                                                              : "Size uygun en yakın randevu saati $saatGosterim olarak belirlendi.",
                                                          textAlign: TextAlign.center,
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ValueListenableBuilder<bool>(
                                                  valueListenable: _islemYapiliyorNotifier,
                                                  builder: (context, islemYapiliyor, _) {
                                                    if (islemYapiliyor) {
                                                      return const Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 20),
                                                        child: Center(child: CircularProgressIndicator()),
                                                      );
                                                    }
                                                    return AnaButon(
                                                        metin: butonMetni,
                                                        onPressed: butonAktif
                                                            ? () => _randevuKaydet(widget.esnaf, _gununAjandaVerisi)
                                                            : null);
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        });
                                  });
                            });
                      });
                });
          }),
    );
  }

  Widget _aracKiralamaZamanSecici(EsnafModeli esnaf) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _seciliTarihNotifier,
      builder: (context, basT, _) => ValueListenableBuilder<DateTime?>(
        valueListenable: _seciliBitisTarihiNotifier,
        builder: (context, bitT, _) => ValueListenableBuilder<String?>(
          valueListenable: _seciliSaatNotifier,
          builder: (context, basS, _) => ValueListenableBuilder<String?>(
            valueListenable: _seciliBitisSaatiNotifier,
            builder: (context, bitS, _) {
              int dGun = 0, dSaat = 0, dDakika = 0;
              bool hataVar = false;
              if (basT != null && bitT != null) {
                final start = DateTime(
                    basT.year,
                    basT.month,
                    basT.day,
                    int.parse((basS ?? "10:00").split(':')[0]),
                    int.parse((basS ?? "10:00").split(':')[1]));
                final end = DateTime(
                    bitT.year,
                    bitT.month,
                    bitT.day,
                    int.parse((bitS ?? "10:00").split(':')[0]),
                    int.parse((bitS ?? "10:00").split(':')[1]));
                int diff = end.difference(start).inMinutes;
                if (diff > 0) {
                  dGun = diff ~/ 1440;
                  dSaat = (diff % 1440) ~/ 60;
                  dDakika = diff % 60;
                } else {
                  hataVar = true;
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 75,
                          left: 50,
                          right: 50,
                          child: Container(height: 2, color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _eliteTarihKarti("ALIŞ TARİHİ", basT, basS, true),
                            Column(
                              children: [
                                Container(
                                  width: 110,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15)],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("TOPLAM SÜRE",
                                          style: TextStyle(color: Colors.indigo, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 10),
                                      if (!hataVar && dGun > 0) ...[
                                        Text(dGun.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, height: 1.0)),
                                        const Text("GÜN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ],
                                      if (!hataVar && dGun > 0 && dSaat > 0)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text("ve", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                        ),
                                      if (!hataVar && dSaat > 0) ...[
                                        Text(dSaat.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, height: 1.0)),
                                        const Text("SAAT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ],
                                      if (!hataVar && dSaat > 0 && dDakika > 0)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text("ve", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                        ),
                                      if (!hataVar && dDakika > 0 && dGun == 0) ...[
                                        Text(dDakika.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, height: 1.0)),
                                        const Text("DAKİKA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ],
                                      if (hataVar || (dGun == 0 && dSaat == 0 && dDakika == 0))
                                        const Text("--", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(hataVar ? "Geçersiz aralık!" : "Lütfen süreyi onaylayın.", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            _eliteTarihKarti("İADE TARİHİ", bitT, bitS, false),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _eliteTarihKarti(String etiket, DateTime? tarih, String? saat, bool alisMi) {
    String gunText = "Seçiniz";
    String ay = "";
    String yil = "";
    String gunAdi = "";
    if (tarih != null) {
      gunText = tarih.day.toString();
      ay = DateFormat('MMMM', 'tr_TR').format(tarih).toUpperCase();
      yil = tarih.year.toString();
      gunAdi = DateFormat('EEEE', 'tr_TR').format(tarih);
    }

    return Column(
      children: [
        Text(etiket, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _tarihSec(alisMi),
          child: Container(
            width: 100, height: 120,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(gunText, style: TextStyle(fontSize: tarih == null ? 18 : 32, fontWeight: FontWeight.w900, color: tarih == null ? Colors.blue : Colors.black)),
                if (tarih != null) ...[
                  Text(ay, style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(yil, style: const TextStyle(color: Colors.black54, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(gunAdi, style: const TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        InkWell(
          onTap: () => _saatSec(tarih, alisMi),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: saat == null ? Colors.white12 : Colors.white24, borderRadius: BorderRadius.circular(10)),
            child: Text(saat ?? "--:--", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Future<void> _tarihSec(bool alisMi) async {
    final initialDate = alisMi ? DateTime.now() : (_seciliTarihNotifier.value ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null && mounted) {
      if (alisMi) {
        _seciliTarihNotifier.value = picked;
        _seciliSaatNotifier.value = null;
        _saatKendimSececegimNotifier.value = false;
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _saatSec(picked, true); });
      } else {
        _seciliBitisTarihiNotifier.value = picked;
        _seciliBitisSaatiNotifier.value = null;
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _saatSec(picked, false); });
      }
      _seciliKanalNotifier.value = null;
    }
  }

  Future<void> _saatSec(DateTime? tarih, bool alisMi) async {
    if (tarih == null) return;
    final val = alisMi ? _seciliSaatNotifier.value : _seciliBitisSaatiNotifier.value;
    TimeOfDay initialTime;
    if (val != null) {
      initialTime = TimeOfDay(hour: int.parse(val.split(':')[0]), minute: int.parse(val.split(':')[1]));
    } else {
      if (!alisMi && _seciliSaatNotifier.value != null && _seciliTarihNotifier.value != null && tarih.isAtSameMomentAs(_seciliTarihNotifier.value!)) {
        int alisH = int.parse(_seciliSaatNotifier.value!.split(':')[0]);
        int alisM = int.parse(_seciliSaatNotifier.value!.split(':')[1]);
        initialTime = TimeOfDay(hour: (alisH + 1) % 24, minute: alisM);
      } else {
        initialTime = TimeOfDay.now();
      }
    }
    final t = await showTimePicker(context: context, initialTime: initialTime);
    if (t != null && mounted) {
      final s = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
      if (alisMi) {
        _seciliSaatNotifier.value = s;
        _saatKendimSececegimNotifier.value = true;
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _tarihSec(false); });
      } else {
        _seciliBitisSaatiNotifier.value = s;
      }
      _seciliKanalNotifier.value = null;
    }
  }

  Widget _seciliBilgiKarti(String baslik, String icerik) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
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

  void _resimGoster(String url, String baslik) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 4.0,
                child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(url, fit: BoxFit.contain)),
              ),
            ),
            Positioned(top: 10, right: 10, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)))),
          ],
        ),
      ),
    );
  }

  Widget _tarihSeciciWidget(EsnafModeli esnaf) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _seciliTarihNotifier,
      builder: (context, seciliTarih, _) {
        List<DateTime> aktifler = _getAktifTarihler(esnaf);
        return SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: aktifler.length,
            itemBuilder: (c, i) => InkWell(
              onTap: () { _aramaYapiliyorNotifier.value = false; _seciliTarihNotifier.value = aktifler[i]; },
              child: Container(
                margin: const EdgeInsets.all(5), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: aktifler[i] == seciliTarih ? Colors.blue : Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(aktifler[i].day.toString()),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _kanalSeciciWidget(EsnafModeli esnaf) {
    bool isTaksi = esnaf.kategori == 'Taksi';
    bool aracModu = isTaksi && esnaf.aracOdakliSistem;
    bool personelModu = !aracModu && esnaf.randevularPersonelAdinaAlinsin;

    return ValueListenableBuilder<String?>(
      valueListenable: _seciliKanalNotifier,
      builder: (context, seciliKanal, _) {
        // [GÜNCELLEME] Pasif (aktif olmayan) araçları listeden çıkarıyoruz
        List<dynamic> kanallar = esnaf.kanallar ?? [];
        if (esnaf.kategori == 'Araç Kiralama') {
          kanallar = kanallar.where((k) {
            if (k is Map) return k["aktif"] ?? true;
            return true;
          }).toList();

          final hizmetler = _seciliHizmetlerNotifier.value;
          final toplamSure = _getToplamSure(hizmetler, esnaf);
          final basSaat = _seciliSaatNotifier.value;

          return Column(
            children: kanallar.map((k) {
              String ad = ""; String resim = ""; String plaka = "";
              if (k is Map) {
                ad = k['ad']?.toString() ?? k['plaka']?.toString() ?? k['marka']?.toString() ?? "İsimsiz Araç";
                resim = k['resim']?.toString() ?? ""; plaka = k['plaka']?.toString() ?? "";
              } else {
                ad = k.toString();
              }
              bool secili = seciliKanal == ad;
              String? nedenKapali; bool blocked = false;
              String iadeBilgisi = "";

              if (basSaat != null && toplamSure > 0) {
                nedenKapali = _saatNedenKapali(esnaf, basSaat, _sonRandevular, toplamSure, ajandaVerisi: _gununAjandaVerisi, kanalFiltresi: ad);
                blocked = nedenKapali != null;
                if (nedenKapali == "Bakım ve Temizlik Sürecinde" && esnaf.bakimSurecindeRandevuAlinsin) blocked = false;

                // [YENİ] İade saatini hesapla
                if (blocked) {
                  final iadeZamani = _getAracIadeZamani(ad, basSaat, toplamSure);
                  if (iadeZamani != null) {
                    iadeBilgisi = "İade: ${DateFormat('dd MMM HH:mm', 'tr_TR').format(iadeZamani)}";
                  }
                }
              }
              return GestureDetector(
                onTap: blocked ? null : () => _seciliKanalNotifier.value = ad,
                child: Opacity(
                  opacity: blocked ? 0.6 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: secili ? Colors.orange : Colors.grey.shade200, width: secili ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(onTap: resim.isNotEmpty ? () => _resimGoster(resim, ad) : null, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: resim.isNotEmpty ? Image.network(resim, width: 100, height: 70, fit: BoxFit.cover) : Container(width: 100, height: 70, color: Colors.grey.shade100, child: const Icon(Icons.directions_car)))),
                            if (nedenKapali != null) Positioned.fill(child: Container(decoration: BoxDecoration(color: blocked ? Colors.black54 : Colors.blue.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(nedenKapali.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8))))),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                          const SizedBox(height: 4), 
                          Row(
                            children: [
                              Text(plaka, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                              if (iadeBilgisi.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.access_time, size: 12, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(iadeBilgisi, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          )
                        ])),
                        if (secili) const Icon(Icons.check_circle, color: Colors.orange),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }

        final List<dynamic> liste = personelModu ? (esnaf.personeller ?? []) : (aracModu ? esnaf.araclar : (esnaf.kanallar ?? []));
        return Wrap(
          spacing: 10, runSpacing: 10,
          children: liste.map((item) {
            String ad = ""; String kanalDegeri = "";
            if (personelModu) { ad = item['isim']?.toString() ?? ""; kanalDegeri = item['kanal']?.toString() ?? ""; }
            else if (aracModu) { ad = item['plaka']?.toString() ?? ""; kanalDegeri = ad; }
            else { ad = item is Map ? (item['ad'] ?? item['plaka'] ?? "") : item.toString(); kanalDegeri = ad; }
            bool secili = personelModu ? (_seciliPersonelNotifier.value == ad) : (seciliKanal == kanalDegeri);
            return ChoiceChip(
              label: Text(ad), selected: secili,
              onSelected: (val) {
                if (val) {
                  _aramaYapiliyorNotifier.value = true;
                  if (personelModu) { _seciliPersonelNotifier.value = ad; _seciliKanalNotifier.value = kanalDegeri; }
                  else { _seciliKanalNotifier.value = kanalDegeri; }
                  _seciliSaatNotifier.value = null; _sonrakiAdimaGit(100);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _saatSecimiBolumuSliver(EsnafModeli esnaf) {
    final slotlar = _slotlariUret(esnaf, _gununAjandaVerisi);
    final hizmetler = _seciliHizmetlerNotifier.value;
    final toplamSure = _getToplamSure(hizmetler, esnaf);

    return ValueListenableBuilder<bool>(
      valueListenable: _aramaYapiliyorNotifier,
      builder: (context, aramaYapiliyor, _) {
        if (aramaYapiliyor) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2.0, mainAxisSpacing: 10, crossAxisSpacing: 10),
          delegate: SliverChildBuilderDelegate((c, i) {
            final slot = slotlar[i];
            final neden = _saatNedenKapali(esnaf, slot, _sonRandevular, toplamSure, ajandaVerisi: _gununAjandaVerisi);
            bool musait = neden == null;
            return InkWell(
              onTap: musait ? () { _seciliSaatNotifier.value = slot; _saatKendimSececegimNotifier.value = true; _sonrakiAdimaGit(150); } : null,
              child: Container(
                decoration: BoxDecoration(color: _seciliSaatNotifier.value == slot ? Colors.blue : (musait ? Colors.white : Colors.grey.shade200), borderRadius: BorderRadius.circular(5)),
                child: Center(child: Text(slot, style: TextStyle(color: musait ? Colors.black : Colors.grey))),
              ),
            );
          }, childCount: slotlar.length),
        );
      },
    );
  }

  // [YENİ] Dolu aracın iade zamanını hesaplayan yardımcı fonksiyon
  DateTime? _getAracIadeZamani(String plaka, String basSaat, int toplamSure) {
    try {
      final tarih = _seciliTarihNotifier.value;
      if (tarih == null) return null;

      final slotParcalar = basSaat.split(':');
      DateTime sBaslangic = DateTime(tarih.year, tarih.month, tarih.day,
          int.parse(slotParcalar[0]), int.parse(slotParcalar[1]));
      DateTime sBitis = sBaslangic.add(Duration(minutes: toplamSure));

      for (var r in _sonRandevular) {
        if (r.randevuKanali != plaka) continue;
        if (r.durum != 'Onaylandı' && r.durum != 'Onay bekliyor') continue;

        final rSaParcalar = r.saat.split(':');
        DateTime rBas = DateTime(r.tarih.year, r.tarih.month, r.tarih.day,
            int.parse(rSaParcalar[0]), int.parse(rSaParcalar[1]));
        DateTime rBit = rBas.add(Duration(minutes: r.sure));

        // Eğer seçili zaman dilimi ile bu randevu çakışıyorsa, iade saati bu randevunun bitişidir
        if (sBaslangic.isBefore(rBit) && sBitis.isAfter(rBas)) {
          return rBit;
        }
      }
    } catch (e) {
      debugPrint("İade saati hesaplama hatası: $e");
    }
    return null;
  }
}
