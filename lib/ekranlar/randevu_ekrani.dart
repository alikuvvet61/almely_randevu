import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/bekleme_listesi_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/bildirim_servisi.dart'; // [YENİ] Bildirim kontrolleri için gerekli
import '../widgets/ana_buton.dart';
import '../widgets/hizmet_paket_secici.dart';
import '../yardimcilar/hizmet_paketi.dart';
import '../yardimcilar/telefon_girdisi.dart';

class RandevuEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;
  final bool yoneticiModu;

  const RandevuEkrani({
    super.key,
    required this.esnaf,
    this.kullaniciTel,
    this.yoneticiModu = false,
  });

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
  final ValueNotifier<bool> _tekrarlayanNotifier = ValueNotifier(false);
  final ValueNotifier<String> _tekrarTipiNotifier = ValueNotifier('Haftalık');
  final ValueNotifier<int> _tekrarSayisiNotifier = ValueNotifier(4);
  final ValueNotifier<PaketSecimi?> _paketSecimNotifier = ValueNotifier(null);
  final ValueNotifier<String> _paketTelNotifier = ValueNotifier('');

  List<RandevuModeli> _sonRandevular = [];
  Map<String, dynamic>? _gununAjandaVerisi;
  StreamSubscription? _ajandaSub;
  StreamSubscription? _randevularSub;

  late Stream<EsnafModeli> _esnafStream;

  bool get _isAracKiralama => widget.esnaf.kategori == 'Araç Kiralama';

  String _randevuTel() {
    final ham = _telController.text.trim().isNotEmpty ? _telController.text : (widget.kullaniciTel ?? '');
    var t = ham.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.startsWith('0')) t = t.substring(1);
    return t;
  }

  bool _onGorusmeRandevusuAlindi(List<RandevuModeli> randevular, List<String> ilkAdlar) {
    if (ilkAdlar.isEmpty) return false;
    const acik = {'Onaylandı', 'Tamamlandı'};
    for (final r in randevular) {
      if (r.esnafId != widget.esnaf.id) continue;
      if (!ilkAdlar.any((a) => a.toLowerCase() == r.hizmetAdi.toLowerCase())) continue;
      if (!acik.contains(r.durum)) continue;
      return true;
    }
    return false;
  }

  bool _onGorusmeOnayBekliyor(List<RandevuModeli> randevular, List<String> ilkAdlar) {
    if (ilkAdlar.isEmpty) return false;
    const bekleyen = {'Onay bekliyor', 'Beklemede'};
    for (final r in randevular) {
      if (r.esnafId != widget.esnaf.id) continue;
      if (!ilkAdlar.any((a) => a.toLowerCase() == r.hizmetAdi.toLowerCase())) continue;
      if (bekleyen.contains(r.durum)) return true;
    }
    return false;
  }

  bool _onGorusmesiGecti(List<RandevuModeli> randevular, List<String> ilkAdlar) {
    if (ilkAdlar.isEmpty) return true;
    final simdi = DateTime.now();
    for (final r in randevular) {
      if (r.esnafId != widget.esnaf.id) continue;
      if (!ilkAdlar.any((a) => a.toLowerCase() == r.hizmetAdi.toLowerCase())) continue;
      if (r.durum != 'Onaylandı' && r.durum != 'Tamamlandı') continue;
      final p = r.saat.split(':');
      final saat = int.tryParse(p.isNotEmpty ? p[0] : '') ?? 0;
      final dk = int.tryParse(p.length > 1 ? p[1] : '') ?? 0;
      final bas = DateTime(r.tarih.year, r.tarih.month, r.tarih.day, saat, dk);
      if (!bas.isAfter(simdi)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);

    if (widget.esnaf.randevularPersonelAdinaAlinsin) {
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
    _paketTelNotifier.value = _telController.text;
    _telController.addListener(() {
      _paketTelNotifier.value = _telController.text;
    });

    _seciliKanalNotifier.addListener(_onKanalChanged);
    _seciliTarihNotifier.addListener(_updateStreams);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aramaYapiliyorNotifier.value = true;
      _onKanalChanged();
    });
  }

  int _saatAramaNesli = 0;

  void _onKanalChanged() {
    if (!_isAracKiralama) {
      _otomatikTarihSec(widget.esnaf);
      // Tarih değişmese bile (aynı gün) saat araması yeniden çalışmalı
      _updateStreams();
      _otomatikSaatSec(widget.esnaf);
    }
  }

  void _otomatikTarihSec(EsnafModeli esnaf) {
    final aktifler = _getAktifTarihler(esnaf);
    if (aktifler.isNotEmpty) {
      final hedef = aktifler.first;
      final mevcut = _seciliTarihNotifier.value;
      final ayniGun = mevcut != null &&
          mevcut.year == hedef.year &&
          mevcut.month == hedef.month &&
          mevcut.day == hedef.day;
      if (!ayniGun) {
        _seciliTarihNotifier.value = hedef;
      }
    } else {
      _aramaYapiliyorNotifier.value = false;
    }
  }

  void _otomatikSaatSec(EsnafModeli esnaf) {
    if (_seciliTarihNotifier.value == null) {
      _aramaYapiliyorNotifier.value = false;
      return;
    }
    if (_saatKendimSececegimNotifier.value) {
      _aramaYapiliyorNotifier.value = false;
      return;
    }

    final hizmetler = _seciliHizmetlerNotifier.value;
    if (hizmetler.isEmpty) {
      // Hizmet seçilene kadar spinner'da kalmasın
      _aramaYapiliyorNotifier.value = false;
      return;
    }

    final nesil = ++_saatAramaNesli;
    _aramaYapiliyorNotifier.value = true;
    _musaitlikBulunamadiNotifier.value = false;

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || nesil != _saatAramaNesli) return;
      final slotlar = _slotlariUret(esnaf, _gununAjandaVerisi);
      final hizmetSuresi = _getToplamSure(hizmetler, esnaf);

      String? bulunanSaat;
      for (var s in slotlar) {
        if (_saatMusaitMi(esnaf, s, _sonRandevular, hizmetSuresi,
            ajandaVerisi: _gununAjandaVerisi)) {
          bulunanSaat = s;
          break;
        }
      }

      if (bulunanSaat != null) {
        _seciliSaatNotifier.value = bulunanSaat;
      } else {
        _seciliSaatNotifier.value = null;
        _musaitlikBulunamadiNotifier.value = true;
      }
      _aramaYapiliyorNotifier.value = false;
    });
  }

  void _updateStreams() {
    final tarih = _seciliTarihNotifier.value;
    if (tarih == null) return;

    _ajandaSub?.cancel();
    _randevularSub?.cancel();

    _ajandaSub = _firestoreServisi.ajandaGetir(
      widget.esnaf.id,
      tarih,
      kanal: _seciliKanalNotifier.value,
    ).listen((event) {
      if (mounted) {
        final birlesik = Map<String, dynamic>.from(widget.esnaf.calismaSaatleri ?? {});
        if (event != null) {
          for (final anahtar in ['acilis', 'kapanis', 'slotDakika', 'slotAraligi', 'is724', 'ogleBaslangic', 'ogleBitis', 'kapaliSlotlar']) {
            if (event[anahtar] != null) birlesik[anahtar] = event[anahtar];
          }
        }
        setState(() {
          _gununAjandaVerisi = birlesik;
        });
        _otomatikSaatSec(widget.esnaf);
      }
    });

    _randevularSub = _firestoreServisi.randevulariGetir(widget.esnaf.id, tarih).listen((event) {
      if (mounted) {
        setState(() {
          _sonRandevular = event;
        });
        _otomatikSaatSec(widget.esnaf);
      }
    });
  }

  @override
  void dispose() {
    _ajandaSub?.cancel();
    _randevularSub?.cancel();
    _adController.dispose();
    _telController.dispose();
    _scrollController.dispose();
    _seciliHizmetlerNotifier.dispose();
    _seciliSaatNotifier.dispose();
    _seciliBitisSaatiNotifier.dispose();
    _seciliPersonelNotifier.dispose();
    _seciliTarihNotifier.dispose();
    _seciliBitisTarihiNotifier.dispose();
    _seciliKanalNotifier.dispose();
    _saatKendimSececegimNotifier.dispose();
    _aramaYapiliyorNotifier.dispose();
    _musaitlikBulunamadiNotifier.dispose();
    _islemYapiliyorNotifier.dispose();
    _tekrarlayanNotifier.dispose();
    _tekrarTipiNotifier.dispose();
    _tekrarSayisiNotifier.dispose();
    _paketSecimNotifier.dispose();
    _paketTelNotifier.dispose();
    super.dispose();
  }

  int _getToplamSure(List<Map<String, dynamic>> hizmetler, EsnafModeli esnaf) {
    if (_isAracKiralama) {
      final basT = _seciliTarihNotifier.value;
      final bitT = _seciliBitisTarihiNotifier.value;
      final basS = _seciliSaatNotifier.value;
      final bitS = _seciliBitisSaatiNotifier.value;

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
        return diff > 0 ? diff : 0;
      }
      return 0;
    }

    int toplam = 0;
    for (var h in hizmetler) {
      toplam += (h['sure'] as num).toInt();
    }

    return toplam;
  }

  List<DateTime> _getAktifTarihler(EsnafModeli esnaf) {
    List<DateTime> tarihler = [];
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);

    if (!esnaf.ajandayiKendimAyarlayacagim) {
      for (int i = 0; i < esnaf.maksimumRandevuGunu; i++) {
        tarihler.add(bugun.add(Duration(days: i)));
      }
      return tarihler;
    }

    if (esnaf.aktifGunler != null) {
      for (var gun in esnaf.aktifGunler!) {
        try {
          String tStr = gun.toString().split('_')[0];
          DateTime t = DateFormat('yyyy-MM-dd').parse(tStr);
          if (t.isAfter(bugun.subtract(const Duration(seconds: 1)))) {
            if (!tarihler.any((d) =>
                d.year == t.year && d.month == t.month && d.day == t.day)) {
              tarihler.add(t);
            }
          }
        } catch (e) {
          debugPrint("Tarih parse hatası: $e");
        }
      }
    }
    tarihler.sort();
    return tarihler;
  }

  int _saatiDakikayaCevir(String saat) {
    final p = saat.split(':');
    if (p.length != 2) return 0;
    return int.parse(p[0]) * 60 + int.parse(p[1]);
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
      int acilisDk = _saatiDakikayaCevir(acilis);
      int kapanisDk = _saatiDakikayaCevir(kapanis);

      // [KESİN TAKVİM MANTIĞI]: Gece yarısını geçen dükkanlar için
      if (kapanisDk < acilisDk || is724) {
        // 1. Dünün devamı olan gece yarısı slotları (00:00'dan Kapanış'a kadar)
        // Bu slotlar takvimde 'Bugün'ün sabahıdır
        int currentDk = 0;
        int targetEnd = is724 ? acilisDk : kapanisDk;
        while (currentDk < targetEnd) {
          slotlar.add(_dakikaFormatli(currentDk));
          currentDk += slotAraligi;
        }

        // 2. Bugünün asıl mesai slotları (Açılış'tan Gece Yarısı'na kadar)
        currentDk = acilisDk;
        while (currentDk < 1440) {
          if (!slotlar.contains(_dakikaFormatli(currentDk))) {
            slotlar.add(_dakikaFormatli(currentDk));
          }
          currentDk += slotAraligi;
        }
      } else {
        // Normal mesai saatleri (Örn: 09:00 - 22:00)
        int currentDk = acilisDk;
        while (currentDk < kapanisDk) {
          slotlar.add(_dakikaFormatli(currentDk));
          currentDk += slotAraligi;
        }
      }
    } catch (e) {
      debugPrint("Slot üretme hatası: $e");
    }
    return slotlar;
  }

  String _dakikaFormatli(int toplamDakika) {
    int h = toplamDakika ~/ 60;
    int m = toplamDakika % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  int min(int a, int b) => a < b ? a : b;

  String? _saatNedenKapali(
      EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi,
      {Map<String, dynamic>? ajandaVerisi,
      DateTime? hedefTarih,
      String? kanalFiltresi}) {
    final tarih = hedefTarih ?? _seciliTarihNotifier.value;
    final kanal = kanalFiltresi ?? _seciliKanalNotifier.value;
    if (tarih == null) {
      return "Tarih seçilmedi";
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
    final gun = DateTime(tarih.year, tarih.month, tarih.day);
    final yoneticiGecmiseYazabilir = widget.yoneticiModu && esnaf.yoneticiGecmiseRandevu;
    if (!yoneticiGecmiseYazabilir && (gun.isBefore(bugun) || (gun == bugun && !sBaslangic.isAfter(simdi)))) {
      return "Geçmiş";
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

    final kapaliNeden = _kapatilmisSaatNedeni(calisma, slot, kontrolSuresi, slotDakika);
    if (kapaliNeden != null) return kapaliNeden;

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

      // [YENİ]: Gece Mesaisi Çakışma Kontrolü Zekası
      String acilis = calisma['acilis'] ?? "09:00";
      int acilisDk = _saatiDakikayaCevir(acilis);
      if (_saatiDakikayaCevir(r.saat) < acilisDk) {
         rBas = rBas.add(const Duration(days: 1));
      }

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

  String? _kapatilmisSaatNedeni(Map<String, dynamic> calisma, String slot, int hizmetSuresi, int slotDakika) {
    final raw = calisma['kapaliSlotlar'];
    if (raw is! Map || raw.isEmpty) return null;
    final bas = _saatiDakikayaCevir(slot);
    final adim = slotDakika > 0 ? slotDakika : 30;
    final bit = bas + (hizmetSuresi > 0 ? hizmetSuresi : adim);
    for (var dk = bas; dk < bit; dk += adim) {
      final saat = _dakikaFormatli(dk % 1440);
      if (!raw.containsKey(saat)) continue;
      final neden = raw[saat];
      if (neden is String && neden.trim().isNotEmpty && neden != 'Belirtilmedi') return neden;
      return 'Kapalı';
    }
    return null;
  }

  bool _saatMusaitMi(
      EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi,
      {Map<String, dynamic>? ajandaVerisi,
      DateTime? hedefTarih,
      String? kanalFiltresi}) {
    return _saatNedenKapali(esnaf, slot, randevular, hizmetSuresi,
            ajandaVerisi: ajandaVerisi,
            hedefTarih: hedefTarih,
            kanalFiltresi: kanalFiltresi) ==
        null;
  }

  Future<void> _randevuKaydet(EsnafModeli esnaf, Map<String, dynamic>? ajanda) async {
    if (_islemYapiliyorNotifier.value) return;
    _islemYapiliyorNotifier.value = true;

    final hizmetler = _seciliHizmetlerNotifier.value;
    final saat = _seciliSaatNotifier.value;
    final tarih = _seciliTarihNotifier.value;
    final personel = _seciliPersonelNotifier.value;
    final kanal = _seciliKanalNotifier.value;

    if (_adController.text.trim().isEmpty ||
        _telController.text.trim().isEmpty ||
        (hizmetler.isEmpty && !_isAracKiralama) ||
        saat == null ||
        tarih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      _islemYapiliyorNotifier.value = false; // [KRİTİK] Hata durumunda butonu tekrar aktif et
      return;
    }
    final telefonMesaji = TelefonGirdisi.hata(_telController.text);
    if (telefonMesaji != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(telefonMesaji)));
      _islemYapiliyorNotifier.value = false;
      return;
    }

    int toplamSure = _getToplamSure(hizmetler, esnaf);

    if (_isAracKiralama && toplamSure < esnaf.minimumRandevuSuresi) {
      String sureMetni = esnaf.minimumRandevuSuresi >= 60
          ? "${esnaf.minimumRandevuSuresi ~/ 60} saat"
          : "${esnaf.minimumRandevuSuresi} dakika";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Bu dükkan için minimum randevu süresi $sureMetni olarak belirlenmiştir."),
        backgroundColor: Colors.orange.shade800,
      ));
      _islemYapiliyorNotifier.value = false;
      return;
    }

    if (!_saatMusaitMi(esnaf, saat, _sonRandevular, toplamSure,
        ajandaVerisi: ajanda)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Seçtiğiniz saat kiralama süresi için uygun değil veya dolu."),
          backgroundColor: Colors.red));
      _islemYapiliyorNotifier.value = false;
      return;
    }

    String durm =
        esnaf.randevuOnayModu == 'Otomatik' ? 'Onaylandı' : 'Onay bekliyor';

    String hAdi = "";
    if (_isAracKiralama) {
      hAdi = "${toplamSure > 1440 ? 'Günlük' : 'Saatlik'} Kiralama";
    } else {
      hAdi = hizmetler.map((h) => h['isim']).join(' + ');
    }

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

    String temizTel = _telController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (temizTel.startsWith('0')) temizTel = temizTel.substring(1);

    try {
    if (!widget.yoneticiModu && esnaf.randevuSadeceYonetici) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Randevular yalnızca işletme tarafından verilir."),
          backgroundColor: Colors.red,
        ));
      }
      _islemYapiliyorNotifier.value = false;
      return;
    }

    if (!widget.yoneticiModu && esnaf.sadeceOnGorusme) {
      final disari = hizmetler.any((h) => !HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(h)));
      if (disari) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("Şu an yalnızca ön görüşme randevusu alınabilir."),
            backgroundColor: Colors.orange.shade800,
          ));
        }
        _islemYapiliyorNotifier.value = false;
        return;
      }
    }

    if (!widget.yoneticiModu) {
      final tum = esnaf.hizmetler ?? [];
      final ilkAdlar = tum
          .where((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)))
          .map((e) => (e['isim'] ?? '').toString())
          .toList();
      final onGorusmeSecili = hizmetler.any((h) => HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(h)));
      if (ilkAdlar.isNotEmpty && onGorusmeSecili) {
        final gecmis = await _firestoreServisi.kullaniciRandevulariniBirKezGetir(temizTel).timeout(const Duration(seconds: 20));
        if (_onGorusmeOnayBekliyor(gecmis, ilkAdlar)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text("Ön görüşme randevunuz onay bekliyor. Onaylanmadan yenisi alınamaz."),
              backgroundColor: Colors.orange.shade800,
            ));
          }
          _islemYapiliyorNotifier.value = false;
          return;
        }
      }
    }

    if (!widget.yoneticiModu && !esnaf.sadeceOnGorusme) {
      final tum = esnaf.hizmetler ?? [];
      final ilkAdlar = tum
          .where((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)))
          .map((e) => (e['isim'] ?? '').toString())
          .toList();
      final kontrolSecili = hizmetler.any((h) => !HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(h)));
      if (ilkAdlar.isNotEmpty && kontrolSecili) {
        final gecmis = await _firestoreServisi.kullaniciRandevulariniBirKezGetir(temizTel).timeout(const Duration(seconds: 20));
        if (!_onGorusmeRandevusuAlindi(gecmis, ilkAdlar)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text("Ön görüşme randevusu onaylanmadan diğer hizmetler açılmaz."),
              backgroundColor: Colors.orange.shade800,
            ));
          }
          _islemYapiliyorNotifier.value = false;
          return;
        }
      }
    }

    if (!widget.yoneticiModu && esnaf.onGorusmeZorunlu && !esnaf.sadeceOnGorusme) {
      final tum = esnaf.hizmetler ?? [];
      final ilkAdlar = tum
          .where((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)))
          .map((e) => (e['isim'] ?? '').toString())
          .toList();
      final kontrolSecili = hizmetler.any((h) => !HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(h)));
      if (ilkAdlar.isNotEmpty && kontrolSecili) {
        final gecmis = await _firestoreServisi.kullaniciRandevulariniBirKezGetir(temizTel).timeout(const Duration(seconds: 20));
        if (!_onGorusmesiGecti(gecmis, ilkAdlar)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text("Kontrol ve paket, ön görüşme saati geçmeden açılmaz."),
              backgroundColor: Colors.orange.shade800,
            ));
          }
          _islemYapiliyorNotifier.value = false;
          return;
        }
      }
    }

    if (!_isAracKiralama && esnaf.karaListeEsik > 0) {
      final ceza = await _firestoreServisi.musteriCezaGetir(esnaf.id, temizTel);
      if (ceza != null && ceza.karaListede) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              "Bu işletme yeni randevu almanızı kapattı (geç iptal / gelmedi: ${ceza.toplam}). Esnafla iletişime geçin.",
            ),
            backgroundColor: Colors.red.shade800,
          ));
        }
        _islemYapiliyorNotifier.value = false;
        return;
      }
    }
    } catch (e) {
      _islemYapiliyorNotifier.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
      return;
    }

    final bool tekrarlayan = !_isAracKiralama && _tekrarlayanNotifier.value;
    final String tekrarTipi = _tekrarTipiNotifier.value;
    final int maxHafta = (esnaf.maksimumRandevuGunu ~/ 7).clamp(2, 52);
    final int maxGunTekrar = esnaf.maksimumRandevuGunu.clamp(2, 90);
    final int tekrarSayisi = tekrarTipi == 'Günlük'
        ? _tekrarSayisiNotifier.value.clamp(2, maxGunTekrar)
        : _tekrarSayisiNotifier.value.clamp(2, maxHafta);
    final String? seriId = tekrarlayan
        ? 'SERI_${DateTime.now().millisecondsSinceEpoch}_$temizTel'
        : null;

    String? paketKayitId;
    String? paketAdi;
    String? olusturulanPaketId;
    var hakDusuldu = false;
    final secim = _paketSecimNotifier.value;
    final paketUygun = HizmetPaketi.uygunMu(esnaf.kategori) &&
        !tekrarlayan &&
        hizmetler.length == 1 &&
        !HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(hizmetler.first)) &&
        secim != null &&
        secim.hizmetAdi == hizmetler.first['isim']?.toString();

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
      calisanPersonel: personel,
      durum: durm,
      seriId: seriId,
      akilliTakipAktif: akilliTakipModu,
      bildirimZamani: bildirimZamani,
    );

    try {
      if (paketUygun) {
        if (secim.tur == 'al' && secim.tanimId != null) {
          final tanim = HizmetPaketi.aktifTanimlar(Map<String, dynamic>.from(hizmetler.first))
              .where((p) => p.id == secim.tanimId)
              .firstOrNull;
          if (tanim == null) {
            throw Exception('Paket artık satışta değil.');
          }
          olusturulanPaketId = await _firestoreServisi.paketSatinAl(
            esnafId: esnaf.id,
            esnafAdi: esnaf.isletmeAdi,
            kullaniciTel: temizTel,
            hizmetAdi: secim.hizmetAdi,
            tanim: tanim,
          );
          paketKayitId = olusturulanPaketId;
          paketAdi = tanim.ad;
        } else if (secim.tur == 'hak' && secim.kayitId != null) {
          final ok = await _firestoreServisi.paketSeansDus(secim.kayitId!);
          if (!ok) {
            throw Exception('Paket hakkınız kalmadı veya süresi doldu.');
          }
          hakDusuldu = true;
          paketKayitId = secim.kayitId;
          paketAdi = secim.ad;
        }
      }

      final kaydedilecek = yeniRandevu.copyWith(paketKayitId: paketKayitId, paketAdi: paketAdi);
      // Randevuyu ekle ve sonucunu al (Bildirim durumu için)
      final String? resHata = await _firestoreServisi.randevuEkle(kaydedilecek);

      int eklenen = 1;
      final List<String> atlanan = [];

      if (tekrarlayan && seriId != null) {
        final maxGun = esnaf.maksimumRandevuGunu;
        final limitGun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
            .add(Duration(days: maxGun));

        for (int i = 1; i < tekrarSayisi; i++) {
          final eklenecekGun = tekrarTipi == 'Günlük' ? i : i * 7;
          final gelecek = DateTime(tarih.year, tarih.month, tarih.day).add(Duration(days: eklenecekGun));
          if (gelecek.isAfter(limitGun)) {
            atlanan.add('${DateFormat('dd.MM.yyyy').format(gelecek)} (pencere dışı)');
            continue;
          }

          final cakisma = await _firestoreServisi.randevuCakisiyorMu(
            esnafId: esnaf.id,
            tarih: gelecek,
            saat: saat,
            sure: toplamSure,
            kanal: (kanal != null && kanal.isNotEmpty) ? kanal : null,
          );
          if (cakisma) {
            atlanan.add(DateFormat('dd.MM.yyyy').format(gelecek));
            continue;
          }

          await _firestoreServisi.randevuEkle(kaydedilecek.copyWith(tarih: gelecek, seriId: seriId), onayBildir: false);
          eklenen++;
        }
      }
      
      _islemYapiliyorNotifier.value = false;

      // [YENİ] Randevu alındıktan hemen sonra arka planda bildirim kontrollerini tetikle
      if (mounted) {
        BildirimServisi.syncAkilliTakipBildirimleri(
          widget.kullaniciTel ?? temizTel, 
          null, // Diyalog göstermesin (arka planda sessiz çalışsın)
          esnafMi: false
        );
        BildirimServisi.syncRandevuHatirlatmalari(
          widget.kullaniciTel ?? temizTel,
          esnafMi: false,
        );
      }

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

      if (paketAdi != null && paketAdi.isNotEmpty) {
        final birim = HizmetPaketi.hakBirimi(esnaf.kategori);
        final sira = birim == 'ders' ? '1. dersinizi alacaksınız' : '1. seansınızı alacaksınız';
        if (secim?.tur == 'al') {
          mesaj += '\n\n$paketAdi açıldı. $tarihFormat saat $saatGosterim gelişinde $sira.';
        } else {
          mesaj += '\n\n$tarihFormat saat $saatGosterim gelişinde paketten 1 $birim düştü.';
        }
      }

      if (tekrarlayan) {
        final gunAd = DateFormat('EEEE', 'tr_TR').format(tarih);
        mesaj += "\n\n🔁 Tekrarlayan seri: $eklenen kayıt oluşturuldu"
            " (${tekrarTipi == 'Haftalık' ? 'her $gunAd' : 'günlük'} $saat).";
        if (atlanan.isNotEmpty) {
          mesaj += "\nAtlanan (dolu/uygunsuz): ${atlanan.join(', ')}";
        }
      }

      // [YENİ] Bildirim uyarısı ekle
      if (resHata == "ALICI_YOK") {
        mesaj += "\n\n⚠️ DİKKAT: Bildirimlerin telefonunuza ulaşması için bir kez mobil uygulamadan giriş yapmalısınız!";
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Icon(
              resHata == "ALICI_YOK" ? Icons.warning_amber_rounded : Icons.check_circle,
              color: resHata == "ALICI_YOK" ? Colors.orange : Colors.green,
              size: 60,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mesaj, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text("TAMAM"),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    } catch (e) {
      if (olusturulanPaketId != null) {
        await _firestoreServisi.paketKaydiSil(olusturulanPaketId);
      } else if (hakDusuldu && paketKayitId != null) {
        await _firestoreServisi.paketSeansIade(paketKayitId);
      }
      _islemYapiliyorNotifier.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  void _sonrakiAdimaGit(double offset) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset + offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _tekrarlayanRandevuBolumu(EsnafModeli esnaf) {
    List<int> haftaSecenekleri() {
      final maxHafta = (esnaf.maksimumRandevuGunu ~/ 7).clamp(2, 52);
      const tercih = [2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 26, 36, 40, 48, 52];
      final liste = tercih.where((h) => h <= maxHafta).toList();
      if (liste.isEmpty) return [2];
      if (!liste.contains(maxHafta) && maxHafta >= 2) liste.add(maxHafta);
      liste.sort();
      return liste;
    }

    List<int> gunSecenekleri() {
      final maxGun = esnaf.maksimumRandevuGunu.clamp(2, 90);
      const tercih = [2, 3, 4, 5, 6, 7, 14, 21, 30, 45, 60, 90];
      final liste = tercih.where((d) => d <= maxGun).toList();
      if (liste.isEmpty) return [2];
      if (!liste.contains(maxGun) && maxGun >= 2) liste.add(maxGun);
      liste.sort();
      return liste;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _tekrarlayanNotifier,
      builder: (context, tekrarlayan, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text("Tekrarlayan randevu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(
                "Sadık müşteri: aynı gün/saati düzenli tekrarla (ör. her Pazartesi 10:00). En fazla ${esnaf.maksimumRandevuGunu} gün ileriye kadar.",
                style: const TextStyle(fontSize: 12),
              ),
              value: tekrarlayan,
              onChanged: (v) {
                _tekrarlayanNotifier.value = v ?? false;
                if (v == true) _paketSecimNotifier.value = null;
              },
            ),
            if (tekrarlayan) ...[
              ValueListenableBuilder<String>(
                valueListenable: _tekrarTipiNotifier,
                builder: (context, tip, _) {
                  return DropdownButtonFormField<String>(
                    key: ValueKey('tekrar_tip_$tip'),
                    initialValue: tip,
                    decoration: const InputDecoration(
                      labelText: "Tekrar aralığı",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Haftalık', child: Text('Haftalık (aynı gün)')),
                      DropdownMenuItem(value: 'Günlük', child: Text('Günlük')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      _tekrarTipiNotifier.value = v;
                      final secenekler = v == 'Günlük' ? gunSecenekleri() : haftaSecenekleri();
                      if (!secenekler.contains(_tekrarSayisiNotifier.value)) {
                        _tekrarSayisiNotifier.value = secenekler.contains(4) ? 4 : secenekler.first;
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: _tekrarTipiNotifier,
                builder: (context, tip, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: _tekrarSayisiNotifier,
                    builder: (context, sayi, _) {
                      final secenekler = tip == 'Günlük' ? gunSecenekleri() : haftaSecenekleri();
                      final gecerli = secenekler.contains(sayi) ? sayi : (secenekler.contains(4) ? 4 : secenekler.first);
                      if (gecerli != sayi) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_tekrarSayisiNotifier.value != gecerli) {
                            _tekrarSayisiNotifier.value = gecerli;
                          }
                        });
                      }
                      final maxHafta = (esnaf.maksimumRandevuGunu ~/ 7).clamp(2, 52);
                      return DropdownButtonFormField<int>(
                        key: ValueKey('tekrar_sayi_${tip}_$gecerli'),
                        initialValue: gecerli,
                        decoration: InputDecoration(
                          labelText: tip == 'Günlük'
                              ? 'Kaç gün boyunca tekrar edilsin?'
                              : 'Kaç hafta boyunca tekrar edilsin?',
                          helperText: tip == 'Haftalık'
                              ? 'İşletme penceresi: en fazla $maxHafta hafta (${esnaf.maksimumRandevuGunu} gün)'
                              : 'İşletme penceresi: en fazla ${esnaf.maksimumRandevuGunu} gün',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: secenekler
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('$e ${tip == 'Günlük' ? 'gün' : 'hafta'}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _tekrarSayisiNotifier.value = v;
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<DateTime?>(
                valueListenable: _seciliTarihNotifier,
                builder: (context, tarih, _) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: _seciliSaatNotifier,
                    builder: (context, saat, _) {
                      return ValueListenableBuilder<String>(
                        valueListenable: _tekrarTipiNotifier,
                        builder: (context, tip, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable: _tekrarSayisiNotifier,
                            builder: (context, sayi, _) {
                              if (tarih == null || saat == null) {
                                return Text(
                                  'Önce tarih ve saat seçin. Seri en fazla ${esnaf.maksimumRandevuGunu} gün ileriye kadar oluşturulur.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                );
                              }
                              final gunAd = DateFormat('EEEE', 'tr_TR').format(tarih);
                              final ozet = tip == 'Haftalık'
                                  ? '$sayi hafta boyunca her $gunAd saat $saat'
                                  : '$sayi gün boyunca her gün saat $saat';
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Özet: $ozet\n(Pencere: ${esnaf.maksimumRandevuGunu} gün; dolu günler atlanır.)',
                                  style: TextStyle(fontSize: 12, color: Colors.indigo.shade900, height: 1.35),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _adimBasligi(String no, String baslik, {bool aktif = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: aktif ? Colors.indigo : Colors.grey.shade300,
                shape: BoxShape.circle),
            child: Text(no,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
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
          if (!widget.yoneticiModu && (esnaf.randevuAlinmasin || esnaf.randevuSadeceYonetici)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  esnaf.randevuSadeceYonetici
                      ? "Randevular yalnızca işletme tarafından verilir."
                      : "Bu işletme şu an randevu almıyor.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }

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
                        if (esnaf.sadeceOnGorusme)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                "Bu işletme şu an yalnızca ön görüşme randevusu alıyor.",
                                style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ValueListenableBuilder<String>(
                          valueListenable: _paketTelNotifier,
                          builder: (context, tel, child) {
                        final onGorusmeHizmetiVar = (esnaf.hizmetler ?? []).any(
                          (e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)),
                        );
                        return StreamBuilder<List<RandevuModeli>>(
                          stream: onGorusmeHizmetiVar && !widget.yoneticiModu && tel.trim().isNotEmpty && _randevuTel().isNotEmpty
                              ? _firestoreServisi.kullaniciRandevulariniGetir(_randevuTel())
                              : Stream.value(const <RandevuModeli>[]),
                          builder: (context, randevuSnap) {
                            final gecmis = randevuSnap.data ?? [];
                            return ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _seciliHizmetlerNotifier,
                          builder: (context, seciliHizmetler, _) {
                            final hamHizmetler = esnaf.hizmetler ?? [];
                            final ilkHam = hamHizmetler
                                .where((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)))
                                .toList();
                            final ilkAdlar = ilkHam.map((e) => (e['isim'] ?? '').toString()).toList();
                            final alindi = widget.yoneticiModu || _onGorusmeRandevusuAlindi(gecmis, ilkAdlar);
                            final onayBekliyor = !widget.yoneticiModu && _onGorusmeOnayBekliyor(gecmis, ilkAdlar);
                            final sadeceIlk = !widget.yoneticiModu && (esnaf.sadeceOnGorusme || (ilkHam.isNotEmpty && !alindi));
                            final hizmetler = HizmetPaketi.onGorusmeBasa(sadeceIlk ? ilkHam : hamHizmetler);
                            final ilkler = hizmetler
                                .where((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)))
                                .toList();
                            final gordu = _onGorusmesiGecti(gecmis, ilkAdlar);
                            return SliverMainAxisGroup(
                              slivers: [
                                if (onayBekliyor)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        "Ön görüşme randevunuz onay bekliyor. Onaylanmadan yenisi alınamaz.",
                                        style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                if (sadeceIlk && !onayBekliyor && !esnaf.sadeceOnGorusme && !widget.yoneticiModu)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        "Diğer hizmetler, ön görüşme randevusu onaylandıktan sonra görünür.",
                                        style: TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                SliverList(
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
                                  final harita = Map<String, dynamic>.from(h as Map);
                                  final ilkGorusme = HizmetPaketi.ilkGorusmeMi(harita);
                                  final paketVar = !ilkGorusme && HizmetPaketi.aktifTanimlar(harita).isNotEmpty;
                                  final fiyatKartta = showPrice && !paketVar;
                                  final kilitli = (ilkGorusme && onayBekliyor) ||
                                      (esnaf.onGorusmeZorunlu &&
                                      ilkler.isNotEmpty &&
                                      !HizmetPaketi.ilkGorusmeMi(harita) &&
                                      !gordu);

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
                                      title: Text(h['isim'], style: TextStyle(color: kilitli ? Colors.grey : null)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text("${h['sure']} Dakika", style: TextStyle(color: kilitli ? Colors.grey : null)),
                                              if (fiyatKartta) ...[
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
                                          if (kilitli && ilkGorusme)
                                            const Text(
                                              "Onay bekleyen ön görüşmeniz var.",
                                              style: TextStyle(fontSize: 12, color: Colors.orange),
                                            )
                                          else if (kilitli)
                                            const Text(
                                              "Ön görüşmeniz yok. Önce ön görüşme alın.",
                                              style: TextStyle(fontSize: 12, color: Colors.orange),
                                            ),
                                        ],
                                      ),
                                      value: secili && !kilitli,
                                      onChanged: (val) {
                                        if (kilitli) {
                                          if (ilkGorusme) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Ön görüşme randevunuz onay bekliyor. Onaylanmadan yenisi alınamaz.")),
                                            );
                                            return;
                                          }
                                          _seciliHizmetlerNotifier.value = [Map<String, dynamic>.from(ilkler.first as Map)];
                                          _paketSecimNotifier.value = null;
                                          _updateStreams();
                                          _otomatikSaatSec(widget.esnaf);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Kontrol ve paket, ön görüşmeden sonra açılır. Ön görüşme seçildi.")),
                                          );
                                          return;
                                        }
                                        List<Map<String, dynamic>> yeniListe = List.from(seciliHizmetler);
                                        if (val == true) {
                                          yeniListe.add(Map<String, dynamic>.from(h));
                                        } else {
                                          yeniListe.removeWhere((element) => element['isim'] == h['isim']);
                                        }
                                        _seciliHizmetlerNotifier.value = yeniListe;
                                        _paketSecimNotifier.value = null;
                                        _updateStreams();
                                        _otomatikSaatSec(widget.esnaf);
                                        if (yeniListe.length == 1 && val == true) _sonrakiAdimaGit(150);
                                      },
                                    ),
                                  );
                                },
                                childCount: hizmetler.length,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _seciliHizmetlerNotifier,
                          builder: (context, seciliHizmetler, _) {
                            if (seciliHizmetler.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                            bool personelModu = esnaf.randevularPersonelAdinaAlinsin;
                            bool kanalSecilmeli = !personelModu && (esnaf.kanallar?.length ?? 0) > 1;

                            return SliverMainAxisGroup(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Column(
                                    children: [
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _tekrarlayanNotifier,
                                        builder: (context, tekrar, _) {
                                          return ValueListenableBuilder<String>(
                                            valueListenable: _paketTelNotifier,
                                            builder: (context, tel, _) {
                                              return HizmetPaketSecici(
                                                esnaf: esnaf,
                                                seciliHizmetler: seciliHizmetler,
                                                tekrarlayan: tekrar,
                                                telefon: tel.trim().isNotEmpty ? tel : (widget.kullaniciTel ?? ''),
                                                secim: _paketSecimNotifier,
                                                firestore: _firestoreServisi,
                                                tekUcret: (seciliHizmetler.first['ucret'] as num?)?.toDouble() ?? 0,
                                                tekUcretGoster: seciliHizmetler.first['ucretGoster'] == true,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      if (personelModu || kanalSecilmeli) ...[
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
                                    bool kanalGerekli = personelModu || kanalSecilmeli;
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
                      valueListenable: _seciliSaatNotifier,
                      builder: (context, seciliSaat, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: _seciliKanalNotifier,
                          builder: (context, seciliKanal, _) {
                            bool gorunur = false;
                            if (_isAracKiralama) {
                              gorunur = seciliKanal != null && seciliKanal.isNotEmpty;
                            } else {
                              gorunur = seciliSaat != null;
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
                                            inputFormatters: TelefonGirdisi.bicim,
                                            decoration: const InputDecoration(
                                                labelText: "Telefon Numarası",
                                                hintText: "05xx xxx xx xx",
                                                prefixIcon: Icon(Icons.phone_outlined),
                                                border: OutlineInputBorder())),
                                        if (!_isAracKiralama) _sadakatKutusu(widget.esnaf),
                                        if (!_isAracKiralama) ...[
                                          const SizedBox(height: 16),
                                          _tekrarlayanRandevuBolumu(widget.esnaf),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

                                          return ValueListenableBuilder<bool>(
                                            valueListenable: _tekrarlayanNotifier,
                                            builder: (context, tekrarlayan, _) {
                                          String butonMetni = "RANDEVUYU TAMAMLA";
                                          if (_isAracKiralama) {
                                            if (toplamSure <= 0) {
                                              butonMetni = "ZAMAN ARALIĞI SEÇİN";
                                            } else if (kanal == null || kanal.isEmpty) {
                                              butonMetni = "ARAÇ SEÇİNİZ";
                                            } else if (!musait) {
                                              butonMetni = "SEÇİLEN ARAÇ KİRALANDI";
                                            }
                                          } else if (tekrarlayan) {
                                            butonMetni = "TEKRARLAYAN SERİYİ OLUŞTUR";
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
                                                        
                                                        // [YENİ] Profesyonel Gece Yarısı Metni
                                                        String gosterimMetni = isSelected
                                                              ? "$prefix $saatGosterim olarak seçtiniz"
                                                              : "Size uygun en yakın randevu saati $saatGosterim olarak belirlendi.";

                                                        if (isSelected && !(_isAracKiralama) && widget.esnaf.kategori == 'Halı Saha') {
                                                           final int sDk = _saatiDakikayaCevir(saat);
                                                           if (sDk >= 0 && sDk < 360) {
                                                              final DateTime dunyaGunu = tarih;
                                                              final DateTime oncekiGun = dunyaGunu.subtract(const Duration(days: 1));
                                                              final String formatOnce = DateFormat('d MMMM', 'tr_TR').format(oncekiGun);
                                                              final String formatBugun = DateFormat('d MMMM', 'tr_TR').format(dunyaGunu);
                                                              gosterimMetni = "Randevunuz $formatOnce'yi $formatBugun'e bağlayan gece gerçekleşecektir.";
                                                           }
                                                        }

                                                        return Text(
                                                          gosterimMetni,
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
                                                        child: Center(
                                                          child: SizedBox(
                                                            width: 36,
                                                            height: 36,
                                                            child: CircularProgressIndicator(strokeWidth: 3),
                                                          ),
                                                        ),
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
                                            },
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

  Widget _sadakatKutusu(EsnafModeli esnaf) {
    if (!esnaf.sadakatAktif || esnaf.sadakatAdet < 2 || esnaf.sadakatYuzde <= 0) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<String>(
      valueListenable: _paketTelNotifier,
      builder: (context, _, __) {
        final tel = _randevuTel();
        if (tel.length < 10) return const SizedBox.shrink();
        return FutureBuilder<int>(
          key: ValueKey(tel),
          future: _firestoreServisi.onayliRandevuSayisi(esnaf.id, tel),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final onayli = snap.data!;
            final siradaki = onayli + 1;
            final denk = siradaki % esnaf.sadakatAdet == 0;
            final otomatik = esnaf.randevuOnayModu == 'Otomatik';
            final yazi = denk
                ? (otomatik
                    ? 'Bu randevu $siradaki. onaylı kaydınız olur. Kasada %${esnaf.sadakatYuzde} indirim uygulanır. Paket hakkı değişmez.'
                    : 'Onaylı randevunuz $onayli. Bu kayıt onaylanırsa $siradaki. olur ve kasada %${esnaf.sadakatYuzde} indirim uygulanır. Paket hakkı değişmez.')
                : 'Onaylı randevunuz $onayli. Her ${esnaf.sadakatAdet}. onaylı randevuda kasada %${esnaf.sadakatYuzde} indirim vardır.';
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(yazi, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
            );
          },
        );
      },
    );
  }

  Widget _tarihSeciciWidget(EsnafModeli esnaf) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _seciliTarihNotifier,
      builder: (context, seciliTarih, _) {
        List<DateTime> aktifler = _getAktifTarihler(esnaf);
        return _AyTakvimi(
          gunler: aktifler,
          secili: seciliTarih,
          pencereGun: esnaf.maksimumRandevuGunu,
          otomatik: !esnaf.ajandayiKendimAyarlayacagim,
          onSec: (gun) {
            _saatKendimSececegimNotifier.value = false;
            _aramaYapiliyorNotifier.value = true;
            _seciliTarihNotifier.value = gun;
            _updateStreams();
            _otomatikSaatSec(esnaf);
          },
        );
      },
    );
  }

  Widget _kanalSeciciWidget(EsnafModeli esnaf) {
    bool personelModu = esnaf.randevularPersonelAdinaAlinsin;

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

        final List<dynamic> hamListe = personelModu ? (esnaf.personeller ?? []) : (esnaf.kanallar ?? []);
        List<dynamic> liste = List.from(hamListe);

        return Wrap(
          spacing: 10, runSpacing: 10,
          children: liste.map((item) {
            String ad = ""; String kanalDegeri = "";
            if (personelModu) { ad = item['isim']?.toString() ?? ""; kanalDegeri = item['kanal']?.toString() ?? ""; }
            else { ad = item is Map ? (item['ad'] ?? item['plaka'] ?? "") : item.toString(); kanalDegeri = ad; }
            bool secili = personelModu ? (_seciliPersonelNotifier.value == ad) : (seciliKanal == kanalDegeri);
            return ChoiceChip(
              label: Text(ad), selected: secili,
              onSelected: (val) {
                if (val) {
                  _saatKendimSececegimNotifier.value = false;
                  _aramaYapiliyorNotifier.value = true;
                  if (personelModu) { _seciliPersonelNotifier.value = ad; _seciliKanalNotifier.value = kanalDegeri; }
                  else { _seciliKanalNotifier.value = kanalDegeri; }
                  _seciliSaatNotifier.value = null;
                  _updateStreams();
                  _otomatikSaatSec(esnaf);
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
    final slotlar = _slotlariUret(esnaf, _gununAjandaVerisi);
    final hizmetler = _seciliHizmetlerNotifier.value;
    final toplamSure = _getToplamSure(hizmetler, esnaf);

    // [YENİ] Slotları Gruplandır (Gece vs Gündüz)
    final geceSlotlari = slotlar.where((s) => _saatiDakikayaCevir(s) < 360).toList();
    final gunduzSlotlari = slotlar.where((s) => _saatiDakikayaCevir(s) >= 360).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: _aramaYapiliyorNotifier,
      builder: (context, aramaYapiliyor, _) {
        if (aramaYapiliyor) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        
        return ValueListenableBuilder<String?>(
          valueListenable: _seciliSaatNotifier,
          builder: (context, seciliSaat, _) {
            return SliverMainAxisGroup(
              slivers: [
                // 1. GECE YARISI BÖLÜMÜ
                if (geceSlotlari.isNotEmpty && esnaf.kategori == 'Halı Saha') ...[
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder<DateTime?>(
                      valueListenable: _seciliTarihNotifier,
                      builder: (context, tarih, _) {
                        if (tarih == null) return const SizedBox.shrink();
                        final DateTime dunyaGunu = tarih;
                        final DateTime oncekiGun = dunyaGunu.subtract(const Duration(days: 1));
                        final String formatOnce = DateFormat('EEEE', 'tr_TR').format(oncekiGun);
                        final String formatBugun = DateFormat('EEEE', 'tr_TR').format(dunyaGunu);
                        
                        return _vakitBasligi(
                          Icons.nightlight_round, 
                          "Gece Yarısı: $formatOnce'yi $formatBugun'e bağlayan gece", 
                          Colors.indigo.shade700
                        );
                      },
                    ),
                  ),
                  _saatGridiUret(esnaf, geceSlotlari, seciliSaat, toplamSure),
                ],

                // 2. GÜNDÜZ & AKŞAM BÖLÜMÜ
                if (gunduzSlotlari.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _vakitBasligi(
                      Icons.wb_sunny_rounded, 
                      "Gündüz & Akşam Seansları", 
                      Colors.orange.shade800
                    ),
                  ),
                  _saatGridiUret(esnaf, gunduzSlotlari, seciliSaat, toplamSure),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _vakitBasligi(IconData ikon, String baslik, Color renk) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 12),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: renk),
          const SizedBox(width: 10),
          Text(baslik, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 15),
          Expanded(child: Divider(color: renk.withValues(alpha: 0.2), thickness: 1)),
        ],
      ),
    );
  }

  Future<void> _beklemeListesiDialog(EsnafModeli esnaf, String slot, int toplamSure, String neden) async {
    final tarih = _seciliTarihNotifier.value;
    if (tarih == null) return;

    if (_adController.text.trim().isEmpty || _telController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bekleme listesi için önce ad ve telefon girin."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final telefonMesaji = TelefonGirdisi.hata(_telController.text);
    if (telefonMesaji != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(telefonMesaji), backgroundColor: Colors.orange));
      return;
    }

    final tarihStr = DateFormat('dd.MM.yyyy').format(tarih);
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Bekleme listesi"),
        content: Text(
          "$tarihStr saat $slot ($neden).\n\n"
          "Bu saat boşalırsa size uygulama bildirimi gönderilir. Yazılmak ister misiniz?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("Yazıl"),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    String temizTel = _telController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (temizTel.startsWith('0')) temizTel = temizTel.substring(1);

    String hAdi = _seciliHizmetlerNotifier.value.map((h) => h['isim']).join(' + ');
    if (hAdi.isEmpty) hAdi = 'Randevu';

    final kayit = BeklemeListesiModeli(
      id: '',
      esnafId: esnaf.id,
      esnafAdi: esnaf.isletmeAdi,
      tarih: tarih,
      saat: slot,
      sureDk: toplamSure > 0 ? toplamSure : esnaf.minimumRandevuSuresi,
      randevuKanali: _seciliKanalNotifier.value,
      calisanPersonel: _seciliPersonelNotifier.value,
      kullaniciAd: _adController.text.trim(),
      kullaniciTel: temizTel,
      hizmetAdi: hAdi,
    );

    final hata = await _firestoreServisi.beklemeListesineEkle(kayit);
    if (!mounted) return;
    if (hata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bekleme listesine yazıldınız. Slot boşalınca bildirim gelir."),
          backgroundColor: Colors.green,
        ),
      );
    } else if (hata == 'ZATEN_VAR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu saat için zaten bekleme listesindesiniz."),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bekleme listesine eklenemedi."), backgroundColor: Colors.red),
      );
    }
  }

  Widget _saatGridiUret(EsnafModeli esnaf, List<String> list, String? seciliSaat, int toplamSure) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: esnaf.slotAralikliGoster ? 3 : 4,
          childAspectRatio: 1.8, // [GÜNCELLEME] Dikey alan için oran biraz artırıldı
          mainAxisSpacing: 10,
          crossAxisSpacing: 10),
      delegate: SliverChildBuilderDelegate((c, i) {
        final slot = list[i];
        String slotMetni = slot;
        if (esnaf.slotAralikliGoster) {
          final calisma = _gununAjandaVerisi ?? esnaf.calismaSaatleri;
          int slotDakika = (calisma?['slotDakika'] ?? 30).toInt();
          int baslangicDakika = _saatiDakikayaCevir(slot);
          int bitisDakika = baslangicDakika + slotDakika;
          slotMetni = "$slot - ${_dakikaFormatli(bitisDakika % 1440)}";
        }

        final neden = _saatNedenKapali(esnaf, slot, _sonRandevular, toplamSure, ajandaVerisi: _gununAjandaVerisi);
        bool musait = neden == null;
        final String? beklemeNedeni =
            (!_isAracKiralama && (neden == 'Dolu' || neden == 'Rezerve')) ? neden : null;
        final bool beklemeUygun = beklemeNedeni != null;
        final int slotDk = _saatiDakikayaCevir(slot);
        final bool geceMi = slotDk >= 0 && slotDk < 360;

        return InkWell(
          onTap: () {
            if (musait) {
              _seciliSaatNotifier.value = slot;
              _saatKendimSececegimNotifier.value = true;
              _sonrakiAdimaGit(150);
            } else if (beklemeNedeni != null) {
              _beklemeListesiDialog(esnaf, slot, toplamSure, beklemeNedeni);
            }
          },
          child: Container(
            decoration: BoxDecoration(
                color: seciliSaat == slot 
                    ? Colors.blue 
                    : (!musait 
                        ? (beklemeUygun ? Colors.orange.shade50 : Colors.grey.shade200)
                    : (geceMi ? Colors.indigo.shade50 : (slotDk >= 1080 ? Colors.orange.shade50 : Colors.white))),
                borderRadius: BorderRadius.circular(8),
                border: beklemeUygun ? Border.all(color: Colors.orange.shade200) : null),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (geceMi) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nightlight_round, size: 10, color: seciliSaat == slot ? Colors.white70 : Colors.indigo.shade400),
                        const SizedBox(width: 4),
                        Text("Gece", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: seciliSaat == slot ? Colors.white70 : Colors.indigo.shade300)),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (!geceMi && slotDk >= 1080) ...[ 
                    Icon(Icons.wb_twilight_rounded, size: 10, color: seciliSaat == slot ? Colors.white70 : Colors.orange.shade700),
                    const SizedBox(height: 2),
                  ],
                  Text(slotMetni,
                      style: TextStyle(
                          color: musait ? (seciliSaat == slot ? Colors.white : Colors.black) : (beklemeUygun ? Colors.orange.shade900 : Colors.grey),
                          fontSize: seciliSaat == slot ? 14 : 12,
                          fontWeight: seciliSaat == slot ? FontWeight.w900 : FontWeight.bold)),
                  if (beklemeNedeni != null)
                    Text(beklemeNedeni, style: TextStyle(fontSize: 9, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  if (!musait && neden == 'Geçmiş')
                    const Text('Geçmiş', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      }, childCount: list.length),
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

class _AyTakvimi extends StatefulWidget {
  final List<DateTime> gunler;
  final DateTime? secili;
  final int pencereGun;
  final bool otomatik;
  final ValueChanged<DateTime> onSec;

  const _AyTakvimi({
    required this.gunler,
    required this.secili,
    required this.pencereGun,
    required this.otomatik,
    required this.onSec,
  });

  @override
  State<_AyTakvimi> createState() => _AyTakvimiState();
}

class _AyTakvimiState extends State<_AyTakvimi> {
  late DateTime _ay;

  @override
  void initState() {
    super.initState();
    _ay = _aySinirla(_baslangicAy());
  }

  @override
  void didUpdateWidget(covariant _AyTakvimi oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sinir = _aySinirla(_ay);
    if (sinir.year != _ay.year || sinir.month != _ay.month) {
      _ay = sinir;
    }
  }

  DateTime _baslangicAy() {
    final s = widget.secili;
    if (s != null) return DateTime(s.year, s.month);
    if (widget.gunler.isNotEmpty) {
      return DateTime(widget.gunler.first.year, widget.gunler.first.month);
    }
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  DateTime _ilkAy() {
    if (widget.gunler.isEmpty) {
      final n = DateTime.now();
      return DateTime(n.year, n.month);
    }
    final g = widget.gunler.first;
    return DateTime(g.year, g.month);
  }

  DateTime _sonAy() {
    if (widget.gunler.isEmpty) return _ilkAy();
    final g = widget.gunler.last;
    return DateTime(g.year, g.month);
  }

  DateTime _aySinirla(DateTime ay) {
    final a = DateTime(ay.year, ay.month);
    final ilk = _ilkAy();
    final son = _sonAy();
    if (a.isBefore(ilk)) return ilk;
    if (a.isAfter(son)) return son;
    return a;
  }

  bool _ayniGun(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _eslesen(DateTime gun) {
    for (final g in widget.gunler) {
      if (_ayniGun(g, gun)) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ilk = DateTime(_ay.year, _ay.month, 1);
    final gunSayisi = DateTime(_ay.year, _ay.month + 1, 0).day;
    final bos = ilk.weekday - 1;
    final satir = ((bos + gunSayisi) / 7).ceil();
    final ayAd = DateFormat('MMMM yyyy', 'tr_TR').format(_ay);
    final buAy = DateTime(_ay.year, _ay.month);
    final ileri = buAy.isBefore(_sonAy());
    final geri = buAy.isAfter(_ilkAy());
    final aciklama = widget.gunler.isEmpty
        ? 'Seçilebilir gün yok.'
        : widget.otomatik
            ? 'Bugünden itibaren ${widget.pencereGun} gün. Sonraki ay için sağ oka basın.'
            : 'Yalnızca ajandası açılmış günler seçilir.';

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: geri
                  ? () => setState(() => _ay = DateTime(_ay.year, _ay.month - 1))
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                ayAd,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            IconButton(
              onPressed: ileri
                  ? () => setState(() => _ay = DateTime(_ay.year, _ay.month + 1))
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Text(aciklama, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz']
              .map((g) => Expanded(
                    child: Center(
                      child: Text(
                        g,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < satir; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                _hucre(r * 7 + c, bos, gunSayisi),
            ],
          ),
      ],
    );
  }

  Widget _hucre(int index, int bos, int gunSayisi) {
    final gunNo = index - bos + 1;
    if (gunNo < 1 || gunNo > gunSayisi) {
      return const Expanded(child: SizedBox(height: 40));
    }
    final gun = DateTime(_ay.year, _ay.month, gunNo);
    final uygun = _eslesen(gun);
    final secili = widget.secili != null && _ayniGun(widget.secili!, gun);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: uygun == null ? null : () => widget.onSec(uygun),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: secili ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$gunNo',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: secili
                    ? Colors.white
                    : (uygun == null ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
