import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'package:almely_randevu/widgets/ana_buton.dart';
import 'package:almely_randevu/widgets/sos_butonu.dart';

class TaksiRandevuEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const TaksiRandevuEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<TaksiRandevuEkrani> createState() => _TaksiRandevuEkraniState();
}

class _TaksiRandevuEkraniState extends State<TaksiRandevuEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _konumServisi = KonumServisi();

  final _adController = TextEditingController();
  final _telController = TextEditingController();
  final _neredenController = TextEditingController();
  final _nereyeController = TextEditingController();
  final _scrollController = ScrollController();

  final ValueNotifier<String?> _seciliSaatNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliTarihNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliKanalNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _islemYapiliyorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _konumYukleniyorNotifier = ValueNotifier(false);

  List<RandevuModeli> _sonRandevular = [];
  Map<String, dynamic>? _taksiAjandaVerisi;
  StreamSubscription? _taksiAjandaSub;
  StreamSubscription? _randevularSub;
  Timer? _debounceTimer;
  Position? _mevcutKullaniciKonumu;

  final String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8"; 

  @override
  void initState() {
    super.initState();

    if (widget.kullaniciTel != null) {
      _telController.text = widget.kullaniciTel!;
    }

    _seciliTarihNotifier.value = DateTime.now();
    _seciliTarihNotifier.addListener(_updateStreams);

    _neredenController.addListener(() { if (mounted) setState(() {}); });
    _nereyeController.addListener(() { if (mounted) setState(() {}); });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStreams();
      _otomatikMevcutKonumAl();
    });
  }

  @override
  void dispose() {
    _taksiAjandaSub?.cancel();
    _randevularSub?.cancel();
    _adController.dispose();
    _telController.dispose();
    _neredenController.dispose();
    _nereyeController.dispose();
    _scrollController.dispose();
    _seciliSaatNotifier.dispose();
    _seciliTarihNotifier.dispose();
    _seciliKanalNotifier.dispose();
    _islemYapiliyorNotifier.dispose();
    _konumYukleniyorNotifier.dispose();
    super.dispose();
  }

  /// Otomatik Mevcut Konumu Alır
  Future<void> _otomatikMevcutKonumAl() async {
    _konumYukleniyorNotifier.value = true;
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      _mevcutKullaniciKonumu = position;

      final konumBilgisi = await _konumServisi.konumuVeAdresiGetir();
      if (konumBilgisi != null && konumBilgisi['hata'] == null) {
        String tamAdres = konumBilgisi['tamAdres'] ?? "Mevcut Konum";
        _neredenController.text = tamAdres;
      } else {
        String hata = konumBilgisi?['hata'] ?? "Adres alınamadı";
        _neredenController.text = "Konum Belirlenemedi ($hata)";
        debugPrint("Konum Alma Hatası: $hata");
      }
    } catch (e) {
      _neredenController.text = "Konum Hatası: $e";
    } finally {
      _konumYukleniyorNotifier.value = false;
    }
  }

  /// Karma Arama: Google (Places) + Nominatim (OSM)
  Future<List<String>> _gelismisAdresArama(String sorgu) async {
    String q = sorgu.trim();
    if (q.length < 2) return [];

    List<String> sonuclar = [];

    // 1. ADIM: Yerel Firestore Mekan Araması
    try {
      final yerel = await _firestoreServisi.mekanArama(q);
      sonuclar.addAll(yerel);
    } catch (_) {}

    // 2. ADIM: Google Places Autocomplete
    String locationBias = "";
    if (_mevcutKullaniciKonumu != null) {
      locationBias = "&location=${_mevcutKullaniciKonumu!.latitude},${_mevcutKullaniciKonumu!.longitude}&radius=50000";
    }

    final googleUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
          'input=${Uri.encodeComponent(q)}'
          '&components=country:tr'
          '&language=tr'
          '$locationBias'
          '&key=$_googleApiKey',
    );

    try {
      final response = await http.get(googleUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          for (var item in data['predictions']) {
            final str = item['structured_formatting'];
            String full = str != null ? "${str['main_text']}, ${str['secondary_text']}" : (item['description'] ?? '');
            full = full.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '');
            if (full.isNotEmpty && !sonuclar.contains(full)) sonuclar.add(full);
          }
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint("Google Kısıtlaması Devam Ediyor, Yedek Servis Kullanılıyor...");
        }
      }
    } catch (_) {}

    // 3. ADIM: Nominatim (OpenStreetMap) - Papara Park / Hayal Vadisi gibi mekanları tam bulur
    if (sonuclar.length < 5) {
      try {
        // [İYİLEŞTİRME] Sorgunun sonuna "Trabzon" ekleyerek yerel sonuçları zorlayalım
        String searchContext = q.toLowerCase().contains("trabzon") ? q : "$q, Trabzon";
        
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?'
              'q=${Uri.encodeComponent(searchContext)}'
              '&format=json'
              '&addressdetails=1'
              '&limit=10'
              '&countrycodes=tr',
        );
        final res = await http.get(osmUrl, headers: {'User-Agent': 'AlmelyApp_V3'});
        if (res.statusCode == 200) {
          final List data = json.decode(res.body);
          for (var r in data) {
            String name = r['display_name'] ?? '';
            // Plus Code temizliği
            name = name.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '');
            if (name.isNotEmpty && !sonuclar.contains(name)) {
              sonuclar.add(name);
            }
          }
        }
      } catch (_) {}
    }

    return sonuclar.toSet().toList();
  }

  void _updateStreams() {
    final tarih = _seciliTarihNotifier.value;
    if (tarih == null) return;

    _taksiAjandaSub?.cancel();
    _randevularSub?.cancel();

    _taksiAjandaSub = _firestoreServisi.taksiCizelgesiGetir(widget.esnaf.id).listen((event) {
      if (mounted) {
        setState(() { _taksiAjandaVerisi = event; });
        _otomatikSaatSec();
      }
    });

    _randevularSub = _firestoreServisi.randevulariGetir(widget.esnaf.id, tarih).listen((event) {
      if (mounted) {
        setState(() { _sonRandevular = event; });
        _otomatikSaatSec();
      }
    });
  }

  void _otomatikSaatSec() {
    if (_seciliSaatNotifier.value != null) return;
    final simdi = DateTime.now();
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += 10) {
        final saatStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
        final d = DateTime(_seciliTarihNotifier.value!.year, _seciliTarihNotifier.value!.month, _seciliTarihNotifier.value!.day, h, m);
        if (d.isAfter(simdi.add(const Duration(minutes: 15)))) {
           if (widget.esnaf.araclar.any((a) => _saatMusaitMi(saatStr, a['plaka']))) {
             _seciliSaatNotifier.value = saatStr;
             return;
           }
        }
      }
    }
  }

  bool _saatMusaitMi(String saat, String plaka) {
    if (_taksiAjandaVerisi == null) return true;
    final gunKey = DateFormat('yyyy-MM-dd').format(_seciliTarihNotifier.value!);
    final gunlukPlan = _taksiAjandaVerisi![gunKey] ?? {};
    final durum = gunlukPlan[plaka]?.toString() ?? "";
    if (durum.contains('I')) return false;

    for (var r in _sonRandevular) {
      if (r.randevuKanali == plaka && r.saat == saat && r.durum != 'Reddedildi' && r.durum != 'İptal Edildi') {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text("${widget.esnaf.isletmeAdi} Rezervasyonu"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _adimBasligi("1", "Zaman Seçimi"),
            _zamanModulu(),
            const SizedBox(height: 25),
            _adimBasligi("2", "Güzergah Bilgileri"),
            _guzergahModulu(),
            const SizedBox(height: 25),
            _adimBasligi("3", "Araç ve Sürücü Seçimi"),
            _aracSeciciModulu(),
            const SizedBox(height: 25),
            _adimBasligi("4", "İletişim Bilgileri"),
            _iletisimModulu(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
      floatingActionButton: SosButonu(
        randevuId: "taksi_rezervasyon",
        esnafId: widget.esnaf.id,
        kullaniciTel: widget.kullaniciTel ?? "",
        baslatanRol: 'Yolcu',
        adminTel: widget.esnaf.telefon,
      ),
    );
  }

  Widget _adimBasligi(String no, String baslik) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: Colors.indigo, child: Text(no, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Text(baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _zamanModulu() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _seciliTarihNotifier,
      builder: (context, tarih, _) => ValueListenableBuilder<String?>(
        valueListenable: _seciliSaatNotifier,
        builder: (context, saat, _) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: tarih ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d != null) { _seciliTarihNotifier.value = d; _seciliSaatNotifier.value = null; }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TARİH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(children: [const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.indigo), const SizedBox(width: 8), Text(tarih == null ? "Seçiniz" : DateFormat('dd MMMM', 'tr_TR').format(tarih), style: const TextStyle(fontWeight: FontWeight.bold))]),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final initialTime = saat != null ? TimeOfDay(hour: int.parse(saat.split(':')[0]), minute: int.parse(saat.split(':')[1])) : TimeOfDay.now();
                    final t = await showTimePicker(context: context, initialTime: initialTime);
                    if (t != null) {
                      final s = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
                      _seciliSaatNotifier.value = s;
                      _seciliKanalNotifier.value = null;
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("SAAT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(children: [const Icon(Icons.access_time, size: 18, color: Colors.indigo), const SizedBox(width: 8), Text(saat ?? "Seçiniz", style: const TextStyle(fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guzergahModulu() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _konumYukleniyorNotifier,
            builder: (context, yukleniyor, _) => Row(
              children: [
                const Icon(Icons.my_location, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _neredenController, decoration: InputDecoration(hintText: yukleniyor ? "Mevcut konumunuz alınıyor..." : "Nereden (Alış Noktası)", border: InputBorder.none))),
                if (yukleniyor) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                else IconButton(icon: const Icon(Icons.gps_fixed, color: Colors.green, size: 20), onPressed: _otomatikMevcutKonumAl),
              ],
            ),
          ),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue val) async {
                    if (val.text.trim().length < 2) return const Iterable<String>.empty();
                    final completer = Completer<List<String>>();
                    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
                      final s = await _gelismisAdresArama(val.text);
                      completer.complete(s);
                    });
                    return await completer.future;
                  },
                  onSelected: (s) => _nereyeController.text = s,
                  fieldViewBuilder: (ctx, ctrl, fn, onSubmit) {
                    ctrl.addListener(() { _nereyeController.text = ctrl.text; });
                    return TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(hintText: "Nereye? (Lise, Taksi Durağı, Mahalle, Cadde)", border: InputBorder.none));
                  },
                  optionsViewBuilder: (ctx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8, 
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 72, 
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4), 
                          shrinkWrap: true,
                          itemCount: options.length, 
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final s = options.elementAt(i);
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6), 
                                  decoration: const BoxDecoration(color: Color(0xFFE8EAF6), shape: BoxShape.circle), 
                                  child: Text("${i + 1}", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 10))
                                ),
                                title: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                onTap: () => onSelected(s),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aracSeciciModulu() {
    return ValueListenableBuilder<String?>(
      valueListenable: _seciliSaatNotifier,
      builder: (context, saat, _) => ValueListenableBuilder<String?>(
        valueListenable: _seciliKanalNotifier,
        builder: (context, seciliPlaka, _) {
          if (saat == null) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Lütfen önce saat seçiniz.", style: TextStyle(color: Colors.grey))));
          final liste = widget.esnaf.araclar.where((a) => _saatMusaitMi(saat, a['plaka'])).toList();
          if (liste.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Bu saatte müsait araç bulunamadı.", style: TextStyle(color: Colors.red, fontSize: 13)));
          return Wrap(
            spacing: 10, runSpacing: 10,
            children: liste.map((a) {
              bool secili = seciliPlaka == a['plaka'];
              return ChoiceChip(label: Text(a['plaka']), selected: secili, onSelected: (val) => _seciliKanalNotifier.value = val ? a['plaka'] : null);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _iletisimModulu() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          TextField(controller: _adController, decoration: const InputDecoration(labelText: "Ad Soyad", prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon Numarası", prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return ValueListenableBuilder<String?>(
      valueListenable: _seciliSaatNotifier,
      builder: (context, saat, _) => ValueListenableBuilder<String?>(
        valueListenable: _seciliKanalNotifier,
        builder: (context, kanal, _) {
          bool guzergahEksik = _neredenController.text.isEmpty || _nereyeController.text.isEmpty;
          bool aktif = saat != null && kanal != null && !guzergahEksik;
          String butonMetni = saat == null ? "ZAMAN SEÇİNİZ" : (guzergahEksik ? "GÜZERGAH GİRİNİZ" : (kanal == null ? "ARAÇ SEÇİNİZ" : "REZERVASYONU TAMAMLA"));
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (saat != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text("Size uygun en yakın randevu saati $saat olarak belirlendi.", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                ValueListenableBuilder<bool>(valueListenable: _islemYapiliyorNotifier, builder: (ctx, yukleniyor, _) => yukleniyor ? const Center(child: CircularProgressIndicator()) : AnaButon(metin: butonMetni, onPressed: aktif ? _kaydet : null)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _kaydet() async {
    _islemYapiliyorNotifier.value = true;
    try {
      final r = RandevuModeli(
        id: '', esnafId: widget.esnaf.id, esnafAdi: widget.esnaf.isletmeAdi, esnafTel: widget.esnaf.telefon,
        kullaniciAd: _adController.text, kullaniciTel: _telController.text,
        tarih: _seciliTarihNotifier.value!, saat: _seciliSaatNotifier.value!, sure: 30,
        hizmetAdi: "Taksi Rezervasyonu", randevuKanali: _seciliKanalNotifier.value,
        durum: widget.esnaf.randevuOnayModu == 'Otomatik' ? 'Onaylandı' : 'Onay bekliyor',
        nereden: _neredenController.text, nereye: _nereyeController.text,
      );
      await _firestoreServisi.randevuEkle(r);
      if (mounted) showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Başarılı"), content: const Text("Rezervasyon talebiniz alınmıştır."), actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text("TAMAM"))]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally { _islemYapiliyorNotifier.value = false; }
  }
}
