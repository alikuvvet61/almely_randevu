import 'dart:async';
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
        // Kanal seçiliyse: Ya bu kanala özel tarih ya da genel tarih (alt çizgisiz)
        if (s.endsWith("_$kanal") || !s.contains('_')) {
          tarihUygun = true;
        }
      } else {
        // Kanal seçili değilse: Sadece genel tarihleri göster
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
        // Ajanda kaydı yoksa şablona bak (Taksi için)
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
      // Sadece bugünse saat kontrolü yap
      // Araç kiralama için 30, diğerleri için 10 dk tolerans
      int tolerans = esnaf.kategori == 'Araç Kiralama' ? 30 : 10;
      if (sBaslangic.isBefore(simdi.subtract(Duration(minutes: tolerans)))) {
        return "Geçmiş saat";
      }
    } else if (seciliGun.isBefore(bugun)) {
      // Geçmiş bir günse direkt kapalı
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

      // 10 Dakika Kuralı: Manuel onaylı esnaflarda, 'Onay bekliyor' randevuları
      // oluşturulma üzerinden 10dk geçtikten sonra boş kabul et
      if (r.durum == 'Onay bekliyor' &&
          esnaf.randevuOnayModu == 'Manuel' &&
          r.olusturulmaTarihi != null) {
        if (DateTime.now().difference(r.olusturulmaTarihi!).inMinutes >= 10) {
          continue; // Bu randevuyu çakışma kontrolüne dahil etme (saat boşalsın)
        }
      }

      final rSaParcalar = r.saat.split(':');
      DateTime rBas = DateTime(r.tarih.year, r.tarih.month, r.tarih.day,
          int.parse(rSaParcalar[0]), int.parse(rSaParcalar[1]));
      DateTime rBit = rBas.add(Duration(minutes: r.sure));
      if (sBaslangic.isBefore(rBit) && sBitis.isAfter(rBas)) {
        return r.durum == 'Onaylandı' ? "Dolu" : "Rezerve";
      }

      // Bakım süresi ile çakışma (Sadece Araç Kiralama için)
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
      hizmetAdi: hAdi,
      randevuKanali: kanal,
      calisanPersonel: aracModu ? null : personel,
      durum: durm,
      akilliTakipAktif: akilliTakipModu,
      bildirimZamani: bildirimZamani,
    );

    try {
      await _firestoreServisi.randevuEkle(yeniRandevu);

      // Akıllı Takip Bildirimi Programla (Cihaz yerelinde)
      if (akilliTakipModu && bildirimZamani != null) {
        BildirimServisi.saatliBildirimKur(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          baslik: "Kiralama Süreniz Doluyor",
          icerik:
              "Kiralama süreniz ${esnaf.akilliTakipSuresi ~/ 60} saat ${esnaf.akilliTakipSuresi % 60 > 0 ? '${esnaf.akilliTakipSuresi % 60} dk ' : ''}sonra bitiyor. Uzatmak ister misiniz?",
          zaman: bildirimZamani,
        );
      }

      // Esnafa Bildirim Gönder
      BildirimServisi.bildirimGonder(
          kullaniciTel: esnaf.telefon,
          baslik: "Yeni Randevu Talebi",
          icerik:
              "${_adController.text} isimli kullanıcı $saat saati için randevu aldı.");
      
      // Müşteriye Bildirim Gönder (Uygulama kapalı olsa bile Firestore'dan tetiklenmesi için)
      BildirimServisi.bildirimGonder(
        kullaniciTel: _telController.text,
        baslik: _isAracKiralama ? "Araç Kiralama Rezervasyonu" : "Randevu Onayı",
        icerik: _isAracKiralama
            ? "${esnaf.isletmeAdi} üzerinden $saat saati için araç kiralama talebiniz oluşturuldu."
            : "${esnaf.isletmeAdi} işletmesinden $saat saati için randevunuz oluşturuldu.",
      );
      
      if (!mounted) {
        return;
      }

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
                child: const Text("TAMAM"))
          ],
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
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
                    // --- SEKTÖREL AKIŞ ---

                    if (!_isAracKiralama) ...[
                      // Adım 1: Hizmet Seçimi
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
                                String hIsim =
                                    h['isim'].toString().toLowerCase();
                                if (hIsim.contains("kesim") ||
                                    hIsim.contains("sakal")) {
                                  ikon = Icons.content_cut;
                                }
                                if (hIsim.contains("boya")) {
                                  ikon = Icons.color_lens;
                                }
                                if (hIsim.contains("yikama")) {
                                  ikon = Icons.local_car_wash;
                                }

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
                                      List<Map<String, dynamic>> yeniListe =
                                          List.from(seciliHizmetler);
                                      if (val == true) {
                                        yeniListe.add(
                                            Map<String, dynamic>.from(h));
                                      } else {
                                        yeniListe.removeWhere((element) =>
                                            element['isim'] == h['isim']);
                                      }
                                      _seciliHizmetlerNotifier.value =
                                          yeniListe;
                                      _updateStreams();

                                      if (yeniListe.length == 1 && val == true) {
                                        _sonrakiAdimaGit(150);
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
                      // Adım 2 & 3 & 4: Kanal/Personel, Tarih, Saat
                      ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _seciliHizmetlerNotifier,
                        builder: (context, seciliHizmetler, _) {
                          if (seciliHizmetler.isEmpty) {
                            return const SliverToBoxAdapter(
                                child: SizedBox.shrink());
                          }

                          bool isTaksi = esnaf.kategori == 'Taksi';
                          bool aracModu = isTaksi && esnaf.aracOdakliSistem;
                          bool personelModu = !aracModu &&
                              esnaf.randevularPersonelAdinaAlinsin;
                          bool kanalSecilmeli = !personelModu &&
                              !aracModu &&
                              (esnaf.kanallar?.length ?? 0) > 1;

                          return SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    if (aracModu ||
                                        personelModu ||
                                        kanalSecilmeli) ...[
                                      ValueListenableBuilder<String?>(
                                        valueListenable:
                                            _seciliPersonelNotifier,
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
                                    ] else if (esnaf.kanallar != null &&
                                        esnaf.kanallar!.isNotEmpty)
                                      _seciliBilgiKarti("Seçilen Bölüm",
                                          _seciliKanalNotifier.value ?? ""),
                                  ],
                                ),
                              ),
                              ValueListenableBuilder<String?>(
                                valueListenable: _seciliKanalNotifier,
                                builder: (context, kanal, _) {
                                  bool kanalGerekli = aracModu ||
                                      personelModu ||
                                      kanalSecilmeli;
                                  bool kanalSecili =
                                      kanal != null && kanal.isNotEmpty;

                                  if (kanalGerekli && !kanalSecili) {
                                    return const SliverToBoxAdapter(
                                        child: SizedBox.shrink());
                                  }

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
                                          if (tarih == null) {
                                            return const SliverToBoxAdapter(
                                                child: SizedBox.shrink());
                                          }
                                          return SliverMainAxisGroup(
                                            slivers: [
                                              SliverToBoxAdapter(
                                                  child: _adimBasligi(
                                                      "4", "Saat Seçin")),
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
                      // Adım 1: Zaman (Elite)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _adimBasligi("1", "Alış ve İade Bilgileri"),
                            _aracKiralamaZamanSecici(esnaf),
                          ],
                        ),
                      ),
                      // Adım 2: Araç Seçimi
                      ValueListenableBuilder<String?>(
                          valueListenable: _seciliBitisSaatiNotifier,
                          builder: (context, bitSaat, _) {
                            if (bitSaat == null || bitSaat.isEmpty) {
                              return const SliverToBoxAdapter(
                                  child: SizedBox.shrink());
                            }
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

                    // Adım Son: İletişim Bilgileri (Ortak)
                    ValueListenableBuilder<String?>(
                      valueListenable: _seciliKanalNotifier,
                      builder: (context, seciliKanal, _) {
                        bool gorunur = false;
                        if (_isAracKiralama) {
                          gorunur = seciliKanal != null && seciliKanal.isNotEmpty;
                        } else {
                          gorunur = _seciliSaatNotifier.value != null;
                        }

                        if (!gorunur) {
                          return const SliverToBoxAdapter(
                              child: SizedBox.shrink());
                        }

                        return SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 30),
                              _adimBasligi(_isAracKiralama ? "3" : "5",
                                  "İletişim Bilgileri"),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: Colors.grey.shade200)),
                                child: Column(
                                  children: [
                                    TextField(
                                        controller: _adController,
                                        decoration: const InputDecoration(
                                            labelText: "Ad Soyad",
                                            prefixIcon:
                                                Icon(Icons.person_outline),
                                            border: OutlineInputBorder())),
                                    const SizedBox(height: 15),
                                    TextField(
                                        controller: _telController,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                            labelText: "Telefon Numarası",
                                            prefixIcon:
                                                Icon(Icons.phone_outlined),
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
            if (tarih == null) {
              return const SizedBox.shrink();
            }
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
                                          final toplamSure = _getToplamSure(
                                              hizmetler, widget.esnaf);
                                          bool musait = saat != null &&
                                              _saatMusaitMi(
                                                  widget.esnaf,
                                                  saat,
                                                  _sonRandevular,
                                                  toplamSure,
                                                  ajandaVerisi:
                                                      _gununAjandaVerisi);

                                          bool butonAktif = saat != null &&
                                              (_isAracKiralama ||
                                                  hizmetler.isNotEmpty) &&
                                              musait;

                                          if (_isAracKiralama) {
                                            if (kanal == null ||
                                                kanal.isEmpty) {
                                              butonAktif = false;
                                            }
                                            if (toplamSure <= 0) {
                                              butonAktif = false;
                                            }
                                          }

                                          String butonMetni =
                                              "RANDEVUYU TAMAMLA";
                                          if (_isAracKiralama) {
                                            if (toplamSure <= 0) {
                                              butonMetni =
                                                  "ZAMAN ARALIĞI SEÇİN";
                                            } else if (kanal == null ||
                                                kanal.isEmpty) {
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
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 10),
                                                    child:
                                                        ValueListenableBuilder<
                                                            bool>(
                                                      valueListenable:
                                                          _saatKendimSececegimNotifier,
                                                      builder: (context,
                                                          kendimSectim, _) {
                                                        String saatGosterim =
                                                            saat;
                                                        if (widget.esnaf
                                                            .slotAralikliGoster) {
                                                          final calisma =
                                                              _gununAjandaVerisi ??
                                                                  widget.esnaf
                                                                      .calismaSaatleri;
                                                          int slotDakika =
                                                              (calisma?['slotDakika'] ??
                                                                      30)
                                                                  .toInt();
                                                          int basDakika =
                                                              _saatiDakikayaCevir(
                                                                  saat);
                                                          int bitDakika =
                                                              basDakika +
                                                                  (toplamSure >
                                                                          0
                                                                      ? toplamSure
                                                                      : slotDakika);
                                                          saatGosterim =
                                                              "$saat - ${_dakikaFormatli(bitDakika % 1440)}";
                                                        }
                                                        bool isSelected =
                                                            kendimSectim ||
                                                                _isAracKiralama;
                                                        String prefix =
                                                            _isAracKiralama
                                                                ? "Araç Alış Saatini"
                                                                : "Randevu saatini";
                                                        return Text(
                                                          isSelected
                                                              ? "$prefix $saatGosterim olarak seçtiniz"
                                                              : "Size uygun en yakın randevu saati $saatGosterim olarak belirlendi.",
                                                          textAlign: TextAlign
                                                              .center,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                               color: Colors
                                                                  .blue),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                AnaButon(
                                                    metin: butonMetni,
                                                    onPressed: butonAktif
                                                        ? () => _randevuKaydet(
                                                            widget.esnaf,
                                                            _gununAjandaVerisi)
                                                        : null),
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
              int dGun = 0, dSaat = 0;
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
                } else {
                  hataVar = true;
                }
              }

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2C),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Konnektör Çizgisi
                        Positioned(
                          top: 75, // Gün kutularının ortası hizası
                          left: 50,
                          right: 50,
                          child: Container(
                            height: 2,
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _eliteTarihKarti(
                                "ALIŞ TARİHİ", basT, basS, true),
                            // Orta Kutu (Toplam Süre)
                            Column(
                              children: [
                                Container(
                                  width: 110,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 15,
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("TOPLAM SÜRE",
                                          style: TextStyle(
                                              color: Colors.indigo,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5)),
                                      const SizedBox(height: 10),
                                      if (!hataVar && dGun > 0) ...[
                                        Text(dGun.toString(),
                                            style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                                height: 1.0)),
                                        const Text("GÜN",
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                      ],
                                      if (!hataVar && dGun > 0 && dSaat > 0)
                                        const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          child: Text("ve",
                                              style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle: FontStyle.italic)),
                                        ),
                                      if (!hataVar && dSaat > 0) ...[
                                        Text(dSaat.toString(),
                                            style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                                height: 1.0)),
                                        const Text("SAAT",
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                      ],
                                      if (hataVar || (dGun == 0 && dSaat == 0))
                                        const Text("--",
                                            style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                    hataVar
                                        ? "Geçersiz aralık!"
                                        : "Lütfen süreyi onaylayın.",
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            _eliteTarihKarti(
                                "İADE TARİHİ", bitT, bitS, false),
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

  Widget _eliteTarihKarti(
      String etiket, DateTime? tarih, String? saat, bool alisMi) {
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
        Text(etiket,
            style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _tarihSec(alisMi),
          child: Container(
            width: 100,
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(gunText,
                    style: TextStyle(
                        fontSize: tarih == null ? 18 : 32,
                        fontWeight: FontWeight.w900,
                        color: tarih == null ? Colors.blue : Colors.black)),
                if (tarih != null) ...[
                  Text(ay,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(yil,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(gunAdi,
                      style: const TextStyle(
                          color: Colors.indigo,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
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
            decoration: BoxDecoration(
              color: saat == null ? Colors.white12 : Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(saat ?? "--:--",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Future<void> _tarihSec(bool alisMi) async {
    if (!mounted) {
      return;
    }
    final initialDate = alisMi
        ? DateTime.now()
        : (_seciliTarihNotifier.value ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );

    if (!mounted) {
      return;
    }

    if (picked != null) {
      if (alisMi) {
        _seciliTarihNotifier.value = picked;
        // Zaman seçimi değiştiğinde eski seçimleri temizle ki initialTime tekrar hesaplansın
        _seciliSaatNotifier.value = null;
        _saatKendimSececegimNotifier.value = false;

        // 1. Alış Günü -> Alış Saati'ni aç
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          _saatSec(picked, true);
        });
      } else {
        _seciliBitisTarihiNotifier.value = picked;
        _seciliBitisSaatiNotifier.value = null;

        // 3. İade Günü -> İade Saati'ni aç
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          _saatSec(picked, false);
        });
      }
      _seciliKanalNotifier.value = null;
    }
  }

  Future<void> _saatSec(DateTime? tarih, bool alisMi) async {
    if (!mounted) {
      return;
    }
    if (tarih == null) {
      return;
    }
    final val =
        alisMi ? _seciliSaatNotifier.value : _seciliBitisSaatiNotifier.value;

    // Varsayılan saati belirle
    TimeOfDay initialTime;
    if (val != null) {
      initialTime = TimeOfDay(
          hour: int.parse(val.split(':')[0]),
          minute: int.parse(val.split(':')[1]));
    } else {
      // Eğer İade Saati seçiliyorsa ve Alış Saati zaten belliyse ve günler aynıysa
      if (!alisMi &&
          _seciliSaatNotifier.value != null &&
          _seciliTarihNotifier.value != null &&
          tarih.year == _seciliTarihNotifier.value!.year &&
          tarih.month == _seciliTarihNotifier.value!.month &&
          tarih.day == _seciliTarihNotifier.value!.day) {
        // Alış saatinden 1 saat sonrasını varsayılan yap
        int alisH = int.parse(_seciliSaatNotifier.value!.split(':')[0]);
        int alisM = int.parse(_seciliSaatNotifier.value!.split(':')[1]);
        initialTime = TimeOfDay(hour: (alisH + 1) % 24, minute: alisM);
      } else {
        final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final secili = DateFormat('yyyy-MM-dd').format(tarih);

        if (bugun == secili) {
          // Bugünse şimdiki saat
          initialTime = TimeOfDay.now();
        } else {
          // Gelecek günse mesai başlangıcı
          final calisma = _gununAjandaVerisi ?? widget.esnaf.calismaSaatleri;
          String acilis = "09:00";
          if (calisma != null) {
            if (calisma['acilis'] != null && calisma['acilis'] != "00:00") {
              acilis = calisma['acilis'];
            } else if (widget.esnaf.calismaSaatleri?['acilis'] != null &&
                widget.esnaf.calismaSaatleri?['acilis'] != "00:00") {
              acilis = widget.esnaf.calismaSaatleri!['acilis'];
            }
          }
          initialTime = TimeOfDay(
              hour: int.parse(acilis.split(':')[0]),
              minute: int.parse(acilis.split(':')[1]));
        }
      }
    }

    final t = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (!mounted) {
      return;
    }

    if (t != null) {
      final s =
          "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

      // Geçmiş zaman veya yetersiz süre kontrolü
      final DateTime secilenTamZaman = DateTime(
          tarih.year, tarih.month, tarih.day, t.hour, t.minute);
      
      if (alisMi) {
        // Alış saati kontrolü: Tolerans payı ile (Kiralama: 30dk)
        int tolerans = widget.esnaf.kategori == 'Araç Kiralama' ? 30 : 10;
        if (secilenTamZaman.isBefore(DateTime.now().subtract(Duration(minutes: tolerans)))) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Geçmiş bir saat seçemezsiniz (Max $tolerans dk tolerans)."), backgroundColor: Colors.red)
          );
          return;
        }
        _seciliSaatNotifier.value = s;
        _saatKendimSececegimNotifier.value = true;
        // 2. Alış Saati -> İade Günü'nü aç
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          _tarihSec(false);
        });
      } else {
        // İade saati kontrolü: Alıştan en az 1 saat sonra olmalı
        if (_seciliTarihNotifier.value != null && _seciliSaatNotifier.value != null) {
          final alisParca = _seciliSaatNotifier.value!.split(':');
          final DateTime alisZamani = DateTime(
            _seciliTarihNotifier.value!.year,
            _seciliTarihNotifier.value!.month,
            _seciliTarihNotifier.value!.day,
            int.parse(alisParca[0]),
            int.parse(alisParca[1]),
          );
          
          if (secilenTamZaman.difference(alisZamani).inMinutes < 60) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Kiralama süresi en az 1 saat olmalıdır."), backgroundColor: Colors.red)
            );
            return;
          }
        }
        _seciliBitisSaatiNotifier.value = s;
      }
      _seciliKanalNotifier.value = null;
    }
  }

  Widget _seciliBilgiKarti(String baslik, String icerik) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
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
          Text("$baslik: ",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Text(icerik,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
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
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  baslik,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
              onTap: () {
                _aramaYapiliyorNotifier.value = false;
                _seciliTarihNotifier.value = aktifler[i];
              },
              child: Container(
                margin: const EdgeInsets.all(5),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: aktifler[i] == seciliTarih
                        ? Colors.blue
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10)),
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
        final List<dynamic> kanallar = esnaf.kanallar ?? [];
        if (esnaf.kategori == 'Araç Kiralama') {
          final hizmetler = _seciliHizmetlerNotifier.value;
          final toplamSure = _getToplamSure(hizmetler, esnaf);
          final basSaat = _seciliSaatNotifier.value;

          return Column(
            children: kanallar.map((k) {
              String ad = "";
              String resim = "";
              String plaka = "";

              if (k is Map) {
                ad = k['ad']?.toString() ??
                    k['plaka']?.toString() ??
                    k['marka']?.toString() ??
                    "İsimsiz Araç";
                resim = k['resim']?.toString() ?? "";
                plaka = k['plaka']?.toString() ?? "";
              } else {
                // Eğer veri String geliyorsa ve içinde { } varsa temizlemeye çalışalım
                String s = k.toString();
                if (s.contains('{')) {
                  // Basit bir temizleme mantığı
                  ad = s
                      .split(',')
                      .firstWhere((e) => e.contains('ad:'), orElse: () => s)
                      .replaceAll('{', '')
                      .replaceAll('ad:', '')
                      .trim();
                  plaka = s.contains('plaka:')
                      ? s
                          .split('plaka:')[1]
                          .split(',')[0]
                          .replaceAll('}', '')
                          .trim()
                      : "";
                } else {
                  ad = s;
                }
              }

              bool secili = seciliKanal == ad;
              String? nedenKapali;
              bool blocked = false;

              if (basSaat != null && toplamSure > 0) {
                nedenKapali = _saatNedenKapali(esnaf, basSaat, _sonRandevular,
                    toplamSure,
                    ajandaVerisi: _gununAjandaVerisi, kanalFiltresi: ad);
                blocked = nedenKapali != null;
                if (nedenKapali == "Bakım ve Temizlik Sürecinde" &&
                    esnaf.bakimSurecindeRandevuAlinsin) {
                  blocked = false;
                }
              }

              return GestureDetector(
                onTap: blocked ? null : () => _seciliKanalNotifier.value = ad,
                child: Opacity(
                  opacity: blocked ? 0.6 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: secili ? Colors.orange : Colors.grey.shade200,
                        width: secili ? 2 : 1,
                      ),
                      boxShadow: [
                        if (secili)
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: resim.isNotEmpty
                                  ? () => _resimGoster(resim, ad)
                                  : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: resim.isNotEmpty
                                    ? Image.network(resim,
                                        width: 100, height: 70, fit: BoxFit.cover)
                                    : Container(
                                        width: 100,
                                        height: 70,
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.directions_car,
                                            color: Colors.grey),
                                      ),
                              ),
                            ),
                            if (nedenKapali != null)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: blocked
                                        ? Colors.black54
                                        : Colors.blue.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                        nedenKapali.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: (nedenKapali.length) > 10
                                                ? 8
                                                : 12)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: blocked
                                      ? Colors.grey.shade200
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(plaka,
                                    style: TextStyle(
                                        color: blocked
                                            ? Colors.grey
                                            : Colors.blue.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        if (secili)
                          const Icon(Icons.check_circle, color: Colors.orange),
                        if (blocked)
                          const Icon(Icons.block, color: Colors.red, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }

        final List<dynamic> rawListe = personelModu
            ? (esnaf.personeller ?? [])
            : (aracModu ? esnaf.araclar : (esnaf.kanallar ?? []));

        List<dynamic> liste = List.from(rawListe);

        // Taksi için Filtreleme ve Sıralama
        if (esnaf.kategori == 'Taksi') {
          final tarih = _seciliTarihNotifier.value;
          if (tarih != null && _taksiAjandaVerisi != null) {
            String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
            var gunlukVeri = _taksiAjandaVerisi![tarihKey] as Map<String, dynamic>?;
            if (gunlukVeri != null) {
              if (esnaf.istirahatliAraclariGizle) {
                liste.removeWhere((item) {
                  String k = aracModu ? (item['plaka'] ?? "") : (item is Map ? (item['ad'] ?? item['plaka'] ?? "") : item.toString());
                  return gunlukVeri[k] == 'I';
                });
              }

              liste.sort((a, b) {
                String kA = aracModu ? (a['plaka'] ?? "") : (a is Map ? (a['ad'] ?? a['plaka'] ?? "") : a.toString());
                String kB = aracModu ? (b['plaka'] ?? "") : (b is Map ? (b['ad'] ?? b['plaka'] ?? "") : b.toString());
                
                String dA = gunlukVeri[kA] ?? "";
                String dB = gunlukVeri[kB] ?? "";

                // 1. Durum Önceliği (Nöbetçi > Çalışan > Diğerleri)
                int sA = dA == 'N' ? 0 : (dA == 'C' ? 1 : 2);
                int sB = dB == 'N' ? 0 : (dB == 'C' ? 1 : 2);
                if (sA != sB) return sA.compareTo(sB);

                // 2. Nöbet Sırası (Map verisi ise)
                if (a is Map && b is Map) {
                  int n1 = a['nobetSirasi'] ?? 999999;
                  int n2 = b['nobetSirasi'] ?? 999999;
                  if (n1 != n2) return n1.compareTo(n2);
                  
                  // 3. Sıra Zamanı
                  int t1 = a['siraZamani'] ?? 0;
                  int t2 = b['siraZamani'] ?? 0;
                  if (t1 != t2) return t1.compareTo(t2);
                }

                return kA.compareTo(kB);
              });
            }
          }
        }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: liste.map((item) {
                  String ad = "";
                  String kanalDegeri = "";
                  String? durumEtiketi;
                  Color chipColor = Colors.indigo;

                  if (personelModu) {
                    ad = item['isim']?.toString() ?? "";
                    kanalDegeri = item['kanal']?.toString() ?? "";
                  } else if (aracModu) {
                    ad = item['plaka']?.toString() ?? "";
                    kanalDegeri = ad;
                  } else {
                    ad = item is Map
                        ? (item['ad'] ?? item['plaka'] ?? "")
                        : item.toString();
                    kanalDegeri = ad;
                  }

                  if (esnaf.kategori == 'Taksi' && _taksiAjandaVerisi != null) {
                    final tarih = _seciliTarihNotifier.value;
                    if (tarih != null) {
                      String tK = DateFormat('yyyy-MM-dd').format(tarih);
                      var gV = _taksiAjandaVerisi![tK] as Map<String, dynamic>?;
                      String d = gV?[kanalDegeri] ?? "";
                      if (d == 'N') {
                        durumEtiketi = "Nöbetçi";
                        chipColor = Colors.orange.shade700;
                      }
                    }
                  }

                  bool secili = personelModu
                      ? (_seciliPersonelNotifier.value == ad)
                      : (seciliKanal == kanalDegeri);

                  return ChoiceChip(
                    avatar: personelModu
                        ? CircleAvatar(
                            backgroundColor:
                                secili ? Colors.white24 : Colors.indigo.shade50,
                            child: Text(ad.isNotEmpty ? ad[0] : "?",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: secili
                                        ? Colors.white
                                        : Colors.indigo)),
                          )
                        : null,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ad),
                        if (durumEtiketi != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(durumEtiketi,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    selected: secili,
                    selectedColor: chipColor,
                    labelStyle: TextStyle(
                        color: secili ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      if (val) {
                        _aramaYapiliyorNotifier.value = true;
                        _otomatikAramaSayaci = 0;
                        if (personelModu) {
                          _seciliPersonelNotifier.value = ad;
                          _seciliKanalNotifier.value = kanalDegeri;
                        } else {
                          _seciliKanalNotifier.value = kanalDegeri;
                        }
                        _seciliSaatNotifier.value = null;
                        _sonrakiAdimaGit(100);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
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
          if (aramaYapiliyor) {
            return const SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text("Size en uygun saatler aranıyor...",
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 15),
                        Expanded(
                            child: Text(
                                "Üzgünüz, bu tarih için uygun boşluk bulunamadı. Lütfen başka bir gün seçin.",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<String?>(
                valueListenable: _seciliSaatNotifier,
                builder: (context, seciliSaat, _) {
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: esnaf.slotAralikliGoster ? 3 : 4,
                      childAspectRatio: esnaf.slotAralikliGoster ? 2.5 : 2.0,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (c, i) {
                        final slot = slotlar[i];
                        final nedenKapali = _saatNedenKapali(
                            esnaf, slot, _sonRandevular, toplamSure,
                            ajandaVerisi: _gununAjandaVerisi);
                        bool musait = nedenKapali == null;
                        if (nedenKapali == "Bakım ve Temizlik Sürecinde" &&
                            esnaf.bakimSurecindeRandevuAlinsin) {
                          musait = true;
                        }

                        String saatText = slot;
                        if (esnaf.slotAralikliGoster) {
                          int basDakika = _saatiDakikayaCevir(slot);
                          int slotDakika =
                              (esnaf.calismaSaatleri?['slotDakika'] ?? 30)
                                  .toInt();
                          int bitDakika = basDakika +
                              (toplamSure > 0 ? toplamSure : slotDakika);
                          saatText =
                              "$slot - ${_dakikaFormatli(bitDakika % 1440)}";
                        }

                        return InkWell(
                          onTap: musait
                              ? () {
                                  _seciliSaatNotifier.value = slot;
                                  _saatKendimSececegimNotifier.value = true;
                                  _sonrakiAdimaGit(150);
                                }
                              : null,
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: seciliSaat == slot
                                    ? Colors.blue
                                    : (musait
                                        ? Colors.white
                                        : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: musait
                                        ? Colors.blue.shade100
                                        : Colors.transparent)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  saatText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: musait
                                        ? (seciliSaat == slot
                                            ? Colors.white
                                            : Colors.black)
                                        : Colors.grey.shade500,
                                    decoration:
                                        musait ? null : TextDecoration.lineThrough,
                                    fontSize:
                                        esnaf.slotAralikliGoster ? 11 : 14,
                                  ),
                                ),
                                if (nedenKapali != null && nedenKapali.isNotEmpty)
                                  Text(nedenKapali,
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 9,
                                          overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: slotlar.length,
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }
}
