import 'package:cloud_firestore/cloud_firestore.dart';
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

  final ValueNotifier<List<Map<String, dynamic>>> _seciliHizmetlerNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _seciliSaatNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliPersonelNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliTarihNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliKanalNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _saatKendimSececegimNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _aramaYapiliyorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _musaitlikBulunamadiNotifier = ValueNotifier(false);

  List<RandevuModeli> _sonRandevular = [];

  late Stream<EsnafModeli> _esnafStream;
  Stream<DocumentSnapshot>? _ajandaStream;
  Stream<List<RandevuModeli>>? _randevularStream;

  @override
  void initState() {
    super.initState();
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);

    if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      if (widget.esnaf.kanallar!.length == 1) {
        _seciliKanalNotifier.value = widget.esnaf.kanallar!.first.toString();
      }
    } else {
      _seciliKanalNotifier.value = "";
    }

    if (widget.kullaniciTel != null) {
      _telController.text = widget.kullaniciTel!;
    }

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
      _ajandaStream = _firestoreServisi.gunlukAjandaGetir(widget.esnaf.id, tarih, kanal);
      _randevularStream = _firestoreServisi.randevulariGetir(widget.esnaf.id, tarih);
      if (mounted) setState(() {});
    }
  }

  Future<void> _enYakinMusaitligiBul(EsnafModeli esnaf) async {
    final hizmetler = _seciliHizmetlerNotifier.value;
    if (hizmetler.isEmpty || _saatKendimSececegimNotifier.value) return;

    if (_aramaYapiliyorNotifier.value) return;
    _aramaYapiliyorNotifier.value = true;
    _musaitlikBulunamadiNotifier.value = false;

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

      List<String> docIds = taranacakTarihler.map((tarih) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        String k = (seciliKanal != null && seciliKanal.trim().isNotEmpty) ? seciliKanal.trim() : "";
        return k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
      }).toList();

      final ajandaSnaplerFuture = FirebaseFirestore.instance.collection('esnaflar')
          .doc(esnaf.id).collection('ajanda')
          .where(FieldPath.documentId, whereIn: docIds)
          .get();

      final results = await Future.wait([
        randevularSnapFuture.timeout(const Duration(seconds: 10)),
        ajandaSnaplerFuture.timeout(const Duration(seconds: 10))
      ]);

      final randevularSnap = results[0] as QuerySnapshot;
      final ajandaSnapler = results[1] as QuerySnapshot;

      final tumBlokRandevulari = randevularSnap.docs
          .map((doc) => RandevuModeli.fromFirestore(doc))
          .where((r) => r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
          .toList();

      Map<String, Map<String, dynamic>> ajandaHaritasi = {};
      for (var doc in ajandaSnapler.docs) {
        ajandaHaritasi[doc.id] = doc.data() as Map<String, dynamic>;
      }

      for (var tarih in taranacakTarihler) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        String k = (seciliKanal != null && seciliKanal.trim().isNotEmpty) ? seciliKanal.trim() : "";
        String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;

        final Map<String, dynamic>? ajandaVerisi = ajandaHaritasi[docId];
        final gununRandevulari = tumBlokRandevulari.where((r) =>
        r.tarih.year == tarih.year && r.tarih.month == tarih.month && r.tarih.day == tarih.day
        ).toList();

        final slotlar = _slotlariUret(esnaf, ajandaVerisi);

        for (var s in slotlar) {
          if (_saatMusaitMi(esnaf, s, gununRandevulari, toplamSure, ajandaVerisi: ajandaVerisi, hedefTarih: tarih)) {
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

    for (var item in aktifler) {
      final parcalar = item.toString().split('_');
      if (parcalar.isNotEmpty) {
        if (kanal != null && kanal.isNotEmpty) {
          if (parcalar.length <= 1 || parcalar[1] != kanal) continue;
        } else {
          if (parcalar.length > 1) continue;
        }

        try {
          DateTime t = DateFormat('yyyy-MM-dd').parse(parcalar[0]);
          if (t.isAtSameMomentAs(bugun) || t.isAfter(bugun)) {
            if (!tarihler.any((d) => d.year == t.year && d.month == t.month && d.day == t.day)) {
              tarihler.add(t);
            }
          }
        } catch (e) { debugPrint("Tarih parse hatası: $e"); }
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
    String acilis = calisma['acilis'] ?? "09:00";
    String kapanis = calisma['kapanis'] ?? "18:00";
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

  String? _saatNedenKapali(EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi, {Map<String, dynamic>? ajandaVerisi, DateTime? hedefTarih}) {
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
          kapaliSlotlarMap[s.toString()] = "Kapalı";
        }
      }
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

    final tarih = hedefTarih ?? _seciliTarihNotifier.value;
    if (tarih != null && tarih.day == DateTime.now().day && tarih.month == DateTime.now().month && tarih.year == DateTime.now().year) {
      int simdiDakika = DateTime.now().hour * 60 + DateTime.now().minute;
      if (sBaslangic <= simdiDakika) return "Geçmiş saat";
    }

    final kanal = _seciliKanalNotifier.value;
    for (var r in randevular) {
      if (kanal != null && kanal.isNotEmpty && r.randevuKanali != kanal) continue;
      int rBaslangic = _saatiDakikayaCevir(r.saat);
      if (rBaslangic < acilisDakika) rBaslangic += 1440;
      int rBitis = rBaslangic + r.sure;
      if (sBaslangic < rBitis && rBaslangic < sBitis) return "Dolu";
    }
    return null;
  }

  bool _saatMusaitMi(EsnafModeli esnaf, String slot, List<RandevuModeli> randevular, int hizmetSuresi, {Map<String, dynamic>? ajandaVerisi, DateTime? hedefTarih}) {
    return _saatNedenKapali(esnaf, slot, randevular, hizmetSuresi, ajandaVerisi: ajandaVerisi, hedefTarih: hedefTarih) == null;
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

    final yeniRandevu = RandevuModeli(
      id: '',
      esnafId: esnaf.id,
      esnafAdi: esnaf.isletmeAdi,
      kullaniciAd: _adController.text,
      kullaniciTel: _telController.text,
      tarih: tarih,
      saat: saat,
      sure: toplamSure,
      hizmetAdi: hizmetler.map((h) => h['isim']).join(' + '),
      randevuKanali: kanal,
      calisanPersonel: personel,
      durum: durm,
    );

    try {
      await _firestoreServisi.randevuEkle(yeniRandevu);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Text(durm == 'Onaylandı' ? "Randevunuz onaylandı." : "Onay bekliyor.", textAlign: TextAlign.center),
          actions: [TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("TAMAM"))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Randevu Al")),
      body: StreamBuilder<EsnafModeli>(
        stream: _esnafStream,
        builder: (context, esnafSnapshot) {
          if (esnafSnapshot.connectionState == ConnectionState.waiting && !esnafSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final esnaf = esnafSnapshot.data ?? widget.esnaf;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("1. Hizmet Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: _seciliHizmetlerNotifier,
                  builder: (context, seciliHizmetler, _) {
                    return Wrap(
                      spacing: 10,
                      children: (esnaf.hizmetler ?? []).map((h) {
                        bool secili = seciliHizmetler.any((element) => element['isim'] == h['isim']);
                        return FilterChip(
                          label: Text("${h['isim']} (${h['sure']} dk)"),
                          selected: secili,
                          onSelected: (val) {
                            List<Map<String, dynamic>> yeniListe = List.from(seciliHizmetler);
                            if (val) {
                              yeniListe.add(Map<String, dynamic>.from(h));
                            } else {
                              yeniListe.removeWhere((element) => element['isim'] == h['isim']);
                            }
                            _seciliHizmetlerNotifier.value = yeniListe;
                            _seciliSaatNotifier.value = null;
                            _saatKendimSececegimNotifier.value = false; // Seçim değişince modu sıfırla
                            _updateStreams(); // Saatlerin hemen yüklenmesini sağla
                            _enYakinMusaitligiBul(esnaf);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),

                ValueListenableBuilder<bool>(
                    valueListenable: _aramaYapiliyorNotifier,
                    builder: (context, aramaYapiliyor, _) {
                      return ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _seciliHizmetlerNotifier,
                          builder: (context, seciliHizmetler, _) {
                            if (seciliHizmetler.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 15),
                                const Divider(height: 40),
                                const Text("2. Tarih ve Kanal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 10),
                                _tarihSeciciWidget(esnaf),
                                const Divider(height: 40),
                                const Text("3. Randevu Saati", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 10),
                                ValueListenableBuilder<bool>(
                                  valueListenable: _musaitlikBulunamadiNotifier,
                                  builder: (context, bulunamadi, _) {
                                    if (bulunamadi) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 20),
                                        child: Center(
                                          child: Text(
                                            "Seçilen hizmetlerin toplam süresine uygun boş randevu saati bulunamadı.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }
                                    if (aramaYapiliyor) {
                                      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                                    }
                                    return _saatSecimiBolumuWidget(esnaf);
                                  },
                                ),
                              ],
                            );
                          }
                      );
                    }
                ),

                const SizedBox(height: 30),
                const Text("İletişim Bilgileriniz", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(controller: _adController, decoration: const InputDecoration(labelText: "Ad Soyad", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      bottomSheet: ValueListenableBuilder<DateTime?>(
          valueListenable: _seciliTarihNotifier,
          builder: (context, tarih, _) {
            if (tarih == null) return const SizedBox.shrink();
            return StreamBuilder<DocumentSnapshot>(
                stream: _ajandaStream,
                builder: (context, snapshot) {
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _seciliHizmetlerNotifier,
                      builder: (context, hizmetler, _) {
                        return ValueListenableBuilder<String?>(
                            valueListenable: _seciliSaatNotifier,
                            builder: (context, saat, _) {
                              Map<String, dynamic>? ajanda;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                ajanda = snapshot.data!.data() as Map<String, dynamic>;
                              }
                              bool butonAktif = saat != null && hizmetler.isNotEmpty && _saatMusaitMi(widget.esnaf, saat, _sonRandevular, _getToplamSure(hizmetler), ajandaVerisi: ajanda);
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
                                    AnaButon(metin: "RANDEVUYU TAMAMLA", onPressed: butonAktif ? () => _randevuKaydet(widget.esnaf, ajanda) : null),
                                  ],
                                ),
                              );
                            }
                        );
                      }
                  );
                }
            );
          }
      ),
    );
  }

  Widget _tarihSeciciWidget(EsnafModeli esnaf) {
    return ValueListenableBuilder<DateTime?>(
        valueListenable: _seciliTarihNotifier,
        builder: (context, seciliTarih, _) {
          List<DateTime> aktifTarihler = _getAktifTarihler(esnaf);
          if (aktifTarihler.isEmpty) return const Center(child: Text("Müsait tarih yok."));
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

  Widget _saatSecimiBolumuWidget(EsnafModeli esnaf) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ajandaStream,
      builder: (context, ajandaSnapshot) {
        return StreamBuilder<List<RandevuModeli>>(
          stream: _randevularStream,
          builder: (context, randevuSnapshot) {
            if (ajandaSnapshot.connectionState == ConnectionState.waiting || randevuSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            _sonRandevular = randevuSnapshot.data ?? [];
            Map<String, dynamic>? ajandaVerisi;
            if (ajandaSnapshot.hasData && ajandaSnapshot.data!.exists) {
              ajandaVerisi = ajandaSnapshot.data!.data() as Map<String, dynamic>;
            }

            final slotlar = _slotlariUret(esnaf, ajandaVerisi);
            if (slotlar.isEmpty) return const Center(child: Text("Çalışma saati bulunamadı."));

            return ValueListenableBuilder<String?>(
                valueListenable: _seciliSaatNotifier,
                builder: (context, seciliSaat, _) {
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _seciliHizmetlerNotifier,
                      builder: (context, hizmetler, _) {
                        int toplamSure = _getToplamSure(hizmetler);

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                          itemCount: slotlar.length,
                          itemBuilder: (context, index) {
                            String saat = slotlar[index];
                            String? nedenKapali = _saatNedenKapali(esnaf, saat, _sonRandevular, toplamSure, ajandaVerisi: ajandaVerisi);
                            bool musait = nedenKapali == null;
                            bool secili = seciliSaat == saat;

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
                                    Text(saat, style: TextStyle(color: secili ? Colors.white : (musait ? Colors.black : Colors.grey), fontWeight: musait ? FontWeight.bold : FontWeight.normal)),
                                    if (nedenKapali != null && nedenKapali.isNotEmpty)
                                      Text(nedenKapali, style: const TextStyle(color: Colors.red, fontSize: 9, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            );
                          },
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