import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'package:almely_randevu/servisler/taksi/nereye_arama.dart';
import 'package:almely_randevu/servisler/taksi/yol_mesafesi.dart';
import 'package:almely_randevu/widgets/ana_buton.dart';
import 'package:almely_randevu/yardimcilar/telefon_girdisi.dart';
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
  Timer? _nereyeDebounce;
  int _aramaIstekNo = 0;
  Position? _mevcutKullaniciKonumu;
  final FocusNode _nereyeFocus = FocusNode();
  List<_NereyeOneri> _nereyeOnerileri = [];
  bool _nereyeAraniyor = false;
  bool _nereyeAramaBittiBos = false;

  double? _guzergahKm;
  int? _guzergahSureDk;
  bool _mesafeYukleniyor = false;

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
    _nereyeController.addListener(_nereyeMetinDegisti);
    _nereyeFocus.addListener(() {
      if (!_nereyeFocus.hasFocus && mounted) {
        // Kısa gecikme: öneriye tıklamaya fırsat ver
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_nereyeFocus.hasFocus) {
            setState(() => _nereyeOnerileri = []);
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStreams();
      _otomatikMevcutKonumAl();
    });
  }

  @override
  void dispose() {
    _nereyeDebounce?.cancel();
    _taksiAjandaSub?.cancel();
    _randevularSub?.cancel();
    _nereyeFocus.dispose();
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

  void _nereyeMetinDegisti() {
    if (!mounted) return;
    setState(() {}); // buton aktifliği vb.

    final q = _nereyeController.text.trim();
    _nereyeDebounce?.cancel();

    // Maps gibi 1 harften itibaren öneri
    if (q.isEmpty) {
      setState(() {
        _nereyeOnerileri = [];
        _nereyeAraniyor = false;
        _nereyeAramaBittiBos = false;
        _guzergahMesafesiniSifirla();
      });
      return;
    }

    final cached = NereyeAramaci.onbellek[q.toLowerCase()];
    if (cached != null && cached.isNotEmpty) {
      setState(() => _nereyeOnerileri = cached.map(_oneriCevir).toList());
    }

    _nereyeDebounce = Timer(const Duration(milliseconds: 120), () {
      _nereyeAramayiCalistir(q);
    });
  }


  /// Otomatik Mevcut Konumu Alır — Taksi İstiyorum ile aynı adres formatı
  Future<void> _otomatikMevcutKonumAl() async {
    _konumYukleniyorNotifier.value = true;
    try {
      Position? position;
      // Web'de getLastKnownPosition desteklenmiyor
      if (!kIsWeb) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _mevcutKullaniciKonumu = position;

      final konumBilgisi =
          await _konumServisi.konumuVeAdresiGetir(mevcutPozisyon: position);
      if (konumBilgisi != null && konumBilgisi['hata'] == null) {
        _neredenController.text =
            konumBilgisi['tamAdres']?.toString() ?? 'Mevcut Konum';
      } else {
        final hata = konumBilgisi?['hata'] ?? 'Adres alınamadı';
        _neredenController.text = 'Konum Belirlenemedi ($hata)';
        debugPrint('Konum Alma Hatası: $hata');
      }
    } catch (e) {
      _neredenController.text = 'Konum Hatası: $e';
    } finally {
      _konumYukleniyorNotifier.value = false;
    }
  }


  double get _aramaLat =>
      _mevcutKullaniciKonumu?.latitude ?? widget.esnaf.konum.latitude;

  double get _aramaLon =>
      _mevcutKullaniciKonumu?.longitude ?? widget.esnaf.konum.longitude;


  void _guzergahMesafesiniSifirla() {
    _guzergahKm = null;
    _guzergahSureDk = null;
    _mesafeYukleniyor = false;
  }

  Future<void> _nereyeSecildi(_NereyeOneri o) async {
    _nereyeController.removeListener(_nereyeMetinDegisti);
    _nereyeController.text = o.etiket;
    _nereyeController.addListener(_nereyeMetinDegisti);
    setState(() {
      _nereyeOnerileri = [];
      _nereyeAraniyor = false;
      _nereyeAramaBittiBos = false;
      _mesafeYukleniyor = true;
      _guzergahKm = null;
      _guzergahSureDk = null;
    });
    _nereyeFocus.unfocus();

    double? dLat = o.lat;
    double? dLon = o.lon;

    // Google place_id varsa gerçek koordinat al
    if (o.placeId != null && o.placeId!.isNotEmpty) {
      final detay = await placeIdKoordinatGetir(
        o.placeId!,
        googleApiKey: _googleApiKey,
      );
      if (detay != null) {
        dLat = detay['lat'];
        dLon = detay['lon'];
      }
    }

    // Hâlâ yoksa adres metninden geocode (Nominatim)
    if (dLat == null || dLon == null) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(o.etiket)}'
          '&format=json&limit=1&countrycodes=tr',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data is List && data.isNotEmpty) {
            dLat = double.tryParse('${data.first['lat']}');
            dLon = double.tryParse('${data.first['lon']}');
          }
        }
    } catch (_) {}
    }

    final oLat = _mevcutKullaniciKonumu?.latitude ?? widget.esnaf.konum.latitude;
    final oLon = _mevcutKullaniciKonumu?.longitude ?? widget.esnaf.konum.longitude;

    if (dLat == null || dLon == null) {
      if (mounted) {
        setState(() {
          _mesafeYukleniyor = false;
        });
      }
      return;
    }

    final rota = await yolMesafesiHesapla(
      originLat: oLat,
      originLon: oLon,
      destLat: dLat,
      destLon: dLon,
      googleApiKey: _googleApiKey,
    );

    if (!mounted) return;
    if (rota == null) {
      setState(() => _mesafeYukleniyor = false);
      return;
    }

    final metres = (rota['meters'] as num).toDouble();
    final seconds = (rota['seconds'] as num?)?.toDouble() ?? 0;
    setState(() {
      _guzergahKm = metres / 1000.0;
      _guzergahSureDk = (seconds / 60).round().clamp(1, 999);
      _mesafeYukleniyor = false;
    });
  }


  _NereyeOneri _oneriCevir(NereyeOneri o) => _NereyeOneri(
        baslik: o.baslik,
        alt: o.alt,
        etiket: o.etiket,
        lat: o.lat,
        lon: o.lon,
        mesafeKm: o.mesafeKm,
        placeId: o.placeId,
      );

  /// Yazarken öneri — randevu ve çağrı aynı aramayı kullanır.
  Future<void> _nereyeAramayiCalistir(String sorgu) async {
    final q = sorgu.trim();
    if (q.isEmpty) return;

    final istekNo = ++_aramaIstekNo;
    if (mounted) {
      setState(() {
        _nereyeAraniyor = true;
        _nereyeAramaBittiBos = false;
      });
    }

    final arama = NereyeAramaci(
      enlem: _aramaLat,
      boylam: _aramaLon,
      il: widget.esnaf.il,
      ilce: widget.esnaf.ilce,
      esnafEnlem: widget.esnaf.konum.latitude,
      esnafBoylam: widget.esnaf.konum.longitude,
    );
    final liste = await arama.ara(
      q,
      iptal: () => !mounted || istekNo != _aramaIstekNo,
      kismi: (kismi) {
        if (!mounted || istekNo != _aramaIstekNo) return;
        setState(() => _nereyeOnerileri = kismi.map(_oneriCevir).toList());
      },
    );
    if (!mounted || istekNo != _aramaIstekNo) return;
    setState(() {
      _nereyeOnerileri = liste.map(_oneriCevir).toList();
      _nereyeAraniyor = false;
      _nereyeAramaBittiBos = liste.isEmpty;
    });
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
                child: TextField(
                  controller: _nereyeController,
                  focusNode: _nereyeFocus,
                  decoration: InputDecoration(
                    hintText: "Nereye? (Lise, Taksi Durağı, Mahalle, Cadde)",
                    border: InputBorder.none,
                    suffixIcon: _nereyeAraniyor
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                            ),
                          )
                        : (_nereyeController.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () {
                                  _nereyeController.clear();
                                  setState(() {
                                    _nereyeOnerileri = [];
                                    _nereyeAraniyor = false;
                                    _nereyeAramaBittiBos = false;
                                    _guzergahMesafesiniSifirla();
                                  });
                                },
                              )
                            : null),
                  ),
                ),
              ),
            ],
          ),
          if (_mesafeYukleniyor) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Yol mesafesi hesaplanıyor...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ] else if (_guzergahKm != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, color: Colors.indigo.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _guzergahSureDk != null
                          ? 'Yol mesafesi: ${_guzergahKm!.toStringAsFixed(1)} km · ~$_guzergahSureDk dk'
                          : 'Yol mesafesi: ${_guzergahKm!.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_nereyeOnerileri.isNotEmpty) ...[
            const SizedBox(height: 4),
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
              child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4), 
                          shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _nereyeOnerileri.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemBuilder: (ctx, i) {
                    final o = _nereyeOnerileri[i];
                    return ListTile(
                                dense: true,
                      leading: const Icon(Icons.place, color: Colors.redAccent, size: 22),
                      title: Text(
                        o.baslik,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: o.alt.isEmpty
                          ? null
                          : Text(
                              o.alt,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _nereyeSecildi(o),
                            );
                          },
                        ),
                      ),
                    ),
          ] else if (_nereyeAramaBittiBos &&
              _nereyeController.text.trim().isNotEmpty &&
              !_nereyeAraniyor) ...[
            const SizedBox(height: 8),
            Text(
              'Adres bulunamadı. Farklı yazmayı deneyin.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aracSeciciModulu() {
    if (!widget.esnaf.aracOdakliSistem) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Bu durakta plaka seçilmez. Rezervasyon “${widget.esnaf.isletmeAdi}” adına alınır; aracı durak ayırır.",
          style: TextStyle(fontSize: 13, height: 1.35, color: Colors.indigo.shade900),
        ),
      );
    }
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
          TextField(controller: _telController, keyboardType: TextInputType.phone, inputFormatters: TelefonGirdisi.bicim, decoration: const InputDecoration(labelText: "Telefon Numarası", hintText: "05xx xxx xx xx", prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())),
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
          final plakaZorunlu = widget.esnaf.aracOdakliSistem;
          bool guzergahEksik = _neredenController.text.isEmpty || _nereyeController.text.isEmpty;
          bool aktif = saat != null && (!plakaZorunlu || kanal != null) && !guzergahEksik;
          String butonMetni = saat == null
              ? "ZAMAN SEÇİNİZ"
              : (guzergahEksik ? "GÜZERGAH GİRİNİZ" : (plakaZorunlu && kanal == null ? "ARAÇ SEÇİNİZ" : "REZERVASYONU TAMAMLA"));
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
    final telefonMesaji = TelefonGirdisi.hata(_telController.text);
    if (telefonMesaji != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(telefonMesaji)));
      return;
    }
    _islemYapiliyorNotifier.value = true;
    try {
      final r = RandevuModeli(
        id: '', esnafId: widget.esnaf.id, esnafAdi: widget.esnaf.isletmeAdi, esnafTel: widget.esnaf.telefon,
        kullaniciAd: _adController.text, kullaniciTel: TelefonGirdisi.rakamlar(_telController.text),
        tarih: _seciliTarihNotifier.value!, saat: _seciliSaatNotifier.value!, sure: 30,
        hizmetAdi: "Taksi Rezervasyonu",
        randevuKanali: widget.esnaf.aracOdakliSistem ? _seciliKanalNotifier.value : widget.esnaf.isletmeAdi,
        durum: widget.esnaf.randevuOnayModu == 'Otomatik' ? 'Onaylandı' : 'Onay bekliyor',
        nereden: _neredenController.text, nereye: _nereyeController.text,
      );
      await _firestoreServisi.randevuEkle(r);
      final tarihSaat = '${DateFormat('dd.MM.yyyy').format(r.tarih)} ${r.saat}';
      await BildirimServisi.taksiRezervasyonEsnafa(
        esnaf: widget.esnaf,
        saat: r.saat,
        tarih: DateFormat('dd.MM.yyyy').format(r.tarih),
      );
      if (r.durum == 'Onaylandı') {
        await BildirimServisi.taksiRezervasyonYolcuya(
          esnaf: widget.esnaf,
          musteriTel: r.kullaniciTel,
          onaylandi: true,
          tarihSaat: tarihSaat,
        );
      }
      if (mounted) showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Başarılı"), content: const Text("Rezervasyon talebiniz alınmıştır."), actions: [TextButton(onPressed: () { Navigator.pop(c); Navigator.pop(context); }, child: const Text("TAMAM"))]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally { _islemYapiliyorNotifier.value = false; }
  }
}

/// Maps tarzı öneri: kalın başlık + gri alt adres; mesafe ile sıralanır.
class _NereyeOneri {
  final String baslik;
  final String alt;
  final String etiket;
  final double? lat;
  final double? lon;
  final double? mesafeKm;
  final String? placeId;
  const _NereyeOneri({
    required this.baslik,
    required this.alt,
    required this.etiket,
    this.lat,
    this.lon,
    this.mesafeKm,
    this.placeId,
  });
}
