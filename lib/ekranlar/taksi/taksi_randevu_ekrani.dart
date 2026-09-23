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
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'package:almely_randevu/servisler/taksi/places_autocomplete.dart';
import 'package:almely_randevu/servisler/taksi/yol_mesafesi.dart';
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
  Timer? _nereyeDebounce;
  int _aramaIstekNo = 0;
  Position? _mevcutKullaniciKonumu;
  final FocusNode _nereyeFocus = FocusNode();
  List<_NereyeOneri> _nereyeOnerileri = [];
  bool _nereyeAraniyor = false;
  bool _nereyeAramaBittiBos = false;
  final Map<String, List<_NereyeOneri>> _aramaOnbellegi = {};

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

    final cached = _aramaOnbellegi[q.toLowerCase()];
    if (cached != null && cached.isNotEmpty) {
      setState(() => _nereyeOnerileri = List.from(cached));
    }

    _nereyeDebounce = Timer(const Duration(milliseconds: 120), () {
      _nereyeAramayiCalistir(q);
    });
  }

  Future<T?> _zamanAsimli<T>(Future<T> future, {int ms = 1400}) async {
    try {
      return await future.timeout(Duration(milliseconds: ms));
    } catch (_) {
      return null;
    }
  }

  /// Otomatik Mevcut Konumu Alır — Taksi Çağır ile aynı adres formatı
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

  String _normalizeTr(String s) {
    // Türkçe İ/I önce düzeltilmeli; aksi halde toLowerCase web'de bozuk üretir
    var t = s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    // Birleşik nokta kalıntısı (i̇)
    t = t.replaceAll('\u0307', '');
    return t;
  }

  /// Web'de JSON alanları undefined gelebilir; her zaman güvenli String üret.
  String _metin(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return '';
    return s;
  }

  String _plusCodeTemizle(String name) =>
      name.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '').trim();

  double get _aramaLat =>
      _mevcutKullaniciKonumu?.latitude ?? widget.esnaf.konum.latitude;

  double get _aramaLon =>
      _mevcutKullaniciKonumu?.longitude ?? widget.esnaf.konum.longitude;

  /// İşletme il/ilçesi — sorguya eklenince yerel sonuçlar daha iyi gelir (sabit şehir yok).
  String get _yerelBag {
    final parcalar = <String>[
      widget.esnaf.ilce.trim(),
      widget.esnaf.il.trim(),
    ].where((e) => e.isNotEmpty).toList();
    final tekil = <String>[];
    for (final p in parcalar) {
      if (!tekil.any((t) => _normalizeTr(t) == _normalizeTr(p))) tekil.add(p);
    }
    return tekil.join(' ');
  }

  void _oneriEkle(
    List<_NereyeOneri> hedef,
    String baslik,
    String alt, {
    double? lat,
    double? lon,
    String? placeId,
  }) {
    baslik = _plusCodeTemizle(baslik);
    alt = _plusCodeTemizle(alt);
    if (baslik.isEmpty) return;
    final etiket = alt.isEmpty ? baslik : '$baslik, $alt';
    final mevcutIx = hedef.indexWhere(
      (o) => _normalizeTr(o.etiket) == _normalizeTr(etiket),
    );
    final mesafe = (lat != null && lon != null)
        ? Geolocator.distanceBetween(_aramaLat, _aramaLon, lat, lon) / 1000.0
        : null;

    if (mevcutIx >= 0) {
      final eski = hedef[mevcutIx];
      final yeniDahaIyi = (eski.mesafeKm == null && mesafe != null) ||
          (eski.mesafeKm != null && mesafe != null && mesafe < eski.mesafeKm!) ||
          ((eski.placeId == null || eski.placeId!.isEmpty) &&
              placeId != null &&
              placeId.isNotEmpty);
      if (yeniDahaIyi) {
        hedef[mevcutIx] = _NereyeOneri(
          baslik: baslik,
          alt: alt,
          etiket: etiket,
          lat: lat ?? eski.lat,
          lon: lon ?? eski.lon,
          mesafeKm: mesafe ?? eski.mesafeKm,
          placeId: (placeId != null && placeId.isNotEmpty) ? placeId : eski.placeId,
        );
      }
      return;
    }
    hedef.add(_NereyeOneri(
      baslik: baslik,
      alt: alt,
      etiket: etiket,
      lat: lat,
      lon: lon,
      mesafeKm: mesafe,
      placeId: placeId,
    ));
  }

  /// place_id'li Google sonuçlarına gerçek koordinat + mesafe doldur (sıralama için).
  Future<void> _placeIdlereKoordinatDoldur(
    List<_NereyeOneri> sonuclar,
    int istekNo,
    void Function() uiGuncelle,
  ) async {
    final adaylar = sonuclar
        .where((o) =>
            (o.lat == null || o.lon == null) &&
            o.placeId != null &&
            o.placeId!.isNotEmpty)
        .take(8)
        .toList();
    if (adaylar.isEmpty) return;

    await Future.wait(adaylar.map((o) async {
      if (istekNo != _aramaIstekNo) return;
      final detay = await placeIdKoordinatGetir(
        o.placeId!,
        googleApiKey: _googleApiKey,
      );
      if (detay == null || istekNo != _aramaIstekNo) return;
      final dLat = detay['lat'];
      final dLon = detay['lon'];
      if (dLat == null || dLon == null) return;
      final mesafe =
          Geolocator.distanceBetween(_aramaLat, _aramaLon, dLat, dLon) / 1000.0;
      final ix = sonuclar.indexWhere((x) => identical(x, o) ||
          (x.placeId == o.placeId && x.etiket == o.etiket));
      if (ix < 0) return;
      sonuclar[ix] = _NereyeOneri(
        baslik: o.baslik,
        alt: o.alt,
        etiket: o.etiket,
        lat: dLat,
        lon: dLon,
        mesafeKm: mesafe,
        placeId: o.placeId,
      );
    }));

    if (istekNo == _aramaIstekNo) uiGuncelle();
  }

  /// Sorgu kelimelerinin başlıkta/adreste geçme skoru (yüksek = daha ilgili).
  int _ilgililikSkoru(String sorgu, _NereyeOneri o) {
    final sk = _normalizeTr(sorgu)
        .split(RegExp(r'\s+'))
        .where((k) => k.length >= 2)
        .toList();
    if (sk.isEmpty) return 0;

    final baslik = _normalizeTr(o.baslik);
    final full = _normalizeTr('${o.baslik} ${o.alt}');
    var score = 0;
    var baslikHit = 0;

    for (final k in sk) {
      if (baslik.contains(k)) {
        baslikHit++;
        score += 12;
      } else if (full.contains(k)) {
        score += 3;
      }
    }

    // Tüm kelimeler başlıkta → "Kent Düğün Salonu" vs "Mutlu Kent Sokak"
    if (baslikHit == sk.length) score += 80;

    // Tam ifade (boşluksuz/yan yana) başlıkta
    final ifade = sk.join(' ');
    if (baslik.contains(ifade)) score += 40;

    return score;
  }

  /// 1) Mesafe  2) İsim eşleşmesi  3) Yerel il/ilçe
  List<_NereyeOneri> _mesafeyeGoreSirala(List<_NereyeOneri> liste, String sorgu) {
    final yerelIl = _normalizeTr(widget.esnaf.il);
    final kopya = List<_NereyeOneri>.from(liste);
    kopya.sort((a, b) {
      final ma = a.mesafeKm;
      final mb = b.mesafeKm;
      if (ma != null && mb != null) {
        final diff = ma.compareTo(mb);
        if (diff != 0) return diff;
      } else if (ma != null) {
        return -1;
      } else if (mb != null) {
        return 1;
      }

      final sa = _ilgililikSkoru(sorgu, a);
      final sb = _ilgililikSkoru(sorgu, b);
      if (sa != sb) return sb.compareTo(sa);

      if (yerelIl.isNotEmpty) {
        final aY = _normalizeTr('${a.baslik} ${a.alt}').contains(yerelIl);
        final bY = _normalizeTr('${b.baslik} ${b.alt}').contains(yerelIl);
        if (aY != bY) return aY ? -1 : 1;
      }
      return 0;
    });
    return kopya;
  }

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

  Future<void> _photonAra(
    String q,
    double lat,
    double lon,
    List<_NereyeOneri> sonuclar,
    int istekNo,
    void Function() uiGuncelle,
  ) async {
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?'
        'q=${Uri.encodeComponent(q)}'
        '&limit=10'
        '&lang=default'
        '&lat=$lat&lon=$lon',
      );
      final res = await _zamanAsimli(http.get(photonUrl), ms: 3000);
      if (res == null || res.statusCode != 200 || istekNo != _aramaIstekNo) {
        debugPrint('Photon başarısız: ${res?.statusCode}');
        return;
      }
      final data = json.decode(res.body);
      final features = data['features'];
      if (features is! List) return;
      for (final f in features) {
        if (f is! Map) continue;
        final p = f['properties'];
        if (p is! Map) continue;
        final name = _metin(p['name']);
        if (name.isEmpty) continue;
        final altParcalar = <String>[
          _metin(p['street']),
          _metin(p['district']),
          _metin(p['city']),
          _metin(p['state']),
          _metin(p['country']),
        ].where((e) => e.isNotEmpty).toList();
        double? rLat;
        double? rLon;
        final geom = f['geometry'];
        if (geom is Map) {
          final coords = geom['coordinates'];
          if (coords is List && coords.length >= 2) {
            rLon = double.tryParse(coords[0].toString());
            rLat = double.tryParse(coords[1].toString());
          }
        }
        _oneriEkle(
          sonuclar,
          name,
          altParcalar.toSet().join(', '),
          lat: rLat,
          lon: rLon,
        );
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('Photon hatası: $e');
    }
  }

  Future<void> _nominatimAra(
    String q,
    List<_NereyeOneri> sonuclar,
    int istekNo,
    void Function() uiGuncelle, {
    double? biasLat,
    double? biasLon,
  }) async {
    try {
      var urlStr =
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(q)}'
          '&format=json&addressdetails=1&limit=10&countrycodes=tr';
      if (biasLat != null && biasLon != null) {
        // Yakın sonuçları önceliklendir (silmez)
        urlStr +=
            '&viewbox=${biasLon - 0.8},${biasLat + 0.5},${biasLon + 0.8},${biasLat - 0.5}'
            '&bounded=0';
      }
      final res = await _zamanAsimli(http.get(Uri.parse(urlStr)), ms: 3500);
      if (res == null || res.statusCode != 200 || istekNo != _aramaIstekNo) {
        debugPrint('Nominatim başarısız: ${res?.statusCode}');
        return;
      }
      final data = json.decode(res.body);
      if (data is! List) return;
      for (final item in data) {
        if (item is! Map) continue;
        final display = _metin(item['display_name']);
        if (display.isEmpty) continue;
        final parcalar = display.split(',').map((e) => e.trim()).toList();
        final rLat = double.tryParse(_metin(item['lat']));
        final rLon = double.tryParse(_metin(item['lon']));
        _oneriEkle(
          sonuclar,
          parcalar.isNotEmpty ? parcalar.first : display,
          parcalar.length > 1 ? parcalar.sublist(1).take(4).join(', ') : '',
          lat: rLat,
          lon: rLon,
        );
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('Nominatim hatası: $e');
    }
  }

  Future<void> _openMeteoAra(
    String q,
    List<_NereyeOneri> sonuclar,
    int istekNo,
    void Function() uiGuncelle,
  ) async {
    try {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(q)}'
        '&count=10&language=tr&countryCode=TR',
      );
      final res = await _zamanAsimli(http.get(url), ms: 3000);
      if (res == null || res.statusCode != 200 || istekNo != _aramaIstekNo) return;
      final data = json.decode(res.body);
      final results = data['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map) continue;
        final name = _metin(item['name']);
        if (name.isEmpty) continue;
        final alt = [
          _metin(item['admin2']),
          _metin(item['admin1']),
          _metin(item['country']),
        ].where((e) => e.isNotEmpty).join(', ');
        final rLat = double.tryParse(item['latitude']?.toString() ?? '');
        final rLon = double.tryParse(item['longitude']?.toString() ?? '');
        _oneriEkle(sonuclar, name, alt, lat: rLat, lon: rLon);
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('OpenMeteo hatası: $e');
    }
  }

  Future<int> _googleAutocompleteAra(
    String q,
    double lat,
    double lon,
    List<_NereyeOneri> sonuclar,
    int istekNo,
    void Function() uiGuncelle,
  ) async {
    if (kIsWeb) return 0;
    try {
      final autoUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=${Uri.encodeComponent(q)}'
        '&components=country:tr'
        '&language=tr'
        '&location=$lat,$lon'
        '&radius=50000'
        '&key=$_googleApiKey',
      );
      final res = await _zamanAsimli(http.get(autoUrl), ms: 1800);
      if (res == null || res.statusCode != 200 || istekNo != _aramaIstekNo) {
        debugPrint('Autocomplete HTTP başarısız: ${res?.statusCode}');
        return 0;
      }
      final data = json.decode(res.body);
      final status = _metin(data['status']);
      final predictions = data['predictions'];
      if (status != 'OK' || predictions is! List) {
        debugPrint('Autocomplete status: $status ${data['error_message']}');
        return 0;
      }
      var eklenen = 0;
      for (final item in predictions) {
        if (item is! Map) continue;
        final placeId = _metin(item['place_id']);
        final str = item['structured_formatting'];
        if (str is Map) {
          _oneriEkle(
            sonuclar,
            _metin(str['main_text']),
            _metin(str['secondary_text']),
            placeId: placeId.isEmpty ? null : placeId,
          );
        } else {
          final desc = _metin(item['description']);
          final parcalar = desc.split(',').map((e) => e.trim()).toList();
          _oneriEkle(
            sonuclar,
            parcalar.isNotEmpty ? parcalar.first : desc,
            parcalar.length > 1 ? parcalar.sublist(1).join(', ') : '',
            placeId: placeId.isEmpty ? null : placeId,
          );
        }
        eklenen++;
      }
      await _placeIdlereKoordinatDoldur(sonuclar, istekNo, uiGuncelle);
      uiGuncelle();
      return eklenen;
    } catch (e) {
      debugPrint('Google autocomplete hatası: $e');
      return 0;
    }
  }

  /// Yazarken öneri — yakınlar önde, uzaklar listede kalır.
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

    final sonuclar = <_NereyeOneri>[];
    final lat = _aramaLat;
    final lon = _aramaLon;
    final yerelBag = _yerelBag;
    // Yerel bağlamlı sorgu (ör. "derecik merkez camii Akçaabat Trabzon")
    final yerelSorgu = yerelBag.isEmpty ||
            _normalizeTr(q).contains(_normalizeTr(widget.esnaf.il))
        ? q
        : '$q $yerelBag';

    void uiGuncelle() {
      if (!mounted || istekNo != _aramaIstekNo) return;
      setState(() => _nereyeOnerileri = _mesafeyeGoreSirala(sonuclar, q).take(10).toList());
    }

    if (kIsWeb) {
      // Web: önce Google JS Places (Maps ile aynı — Akçaabat Derecik Camii vb.)
      try {
        final googleWeb = await googlePlacesWebAutocomplete(
          input: q,
          lat: lat,
          lon: lon,
        );
        if (istekNo == _aramaIstekNo) {
          for (var i = 0; i < googleWeb.length; i++) {
            final item = googleWeb[i];
            final main = item['main'] ?? '';
            final secondary = item['secondary'] ?? '';
            final placeId = item['placeId'] ?? '';
            _oneriEkle(
              sonuclar,
              main,
              secondary,
              placeId: placeId.isEmpty ? null : placeId,
            );
          }
          await _placeIdlereKoordinatDoldur(sonuclar, istekNo, uiGuncelle);
          uiGuncelle();
        }
      } catch (e) {
        debugPrint('Google Places web hatası: $e');
      }

      // Yedek / ek sonuçlar
      await Future.wait([
        _photonAra(q, lat, lon, sonuclar, istekNo, uiGuncelle),
        if (yerelSorgu != q)
          _photonAra(yerelSorgu, lat, lon, sonuclar, istekNo, uiGuncelle),
        _nominatimAra(q, sonuclar, istekNo, uiGuncelle, biasLat: lat, biasLon: lon),
        if (yerelSorgu != q)
          _nominatimAra(yerelSorgu, sonuclar, istekNo, uiGuncelle, biasLat: lat, biasLon: lon),
        _openMeteoAra(q, sonuclar, istekNo, uiGuncelle),
      ]);
      // Tüm kaynaklardan sonra Google place_id kalanları doldur + yeniden sırala
      await _placeIdlereKoordinatDoldur(sonuclar, istekNo, uiGuncelle);
    } else {
      final googleSayisi =
          await _googleAutocompleteAra(q, lat, lon, sonuclar, istekNo, uiGuncelle);
      if (googleSayisi < 2 && istekNo == _aramaIstekNo) {
        await Future.wait([
          _photonAra(q, lat, lon, sonuclar, istekNo, uiGuncelle),
          if (yerelSorgu != q)
            _photonAra(yerelSorgu, lat, lon, sonuclar, istekNo, uiGuncelle),
          _nominatimAra(q, sonuclar, istekNo, uiGuncelle, biasLat: lat, biasLon: lon),
        ]);
      }
      await _placeIdlereKoordinatDoldur(sonuclar, istekNo, uiGuncelle);
    }

    if (istekNo != _aramaIstekNo) {
      if (mounted) setState(() => _nereyeAraniyor = false);
      return;
    }

    try {
      final yerel =
          await _zamanAsimli(_firestoreServisi.mekanArama(q), ms: 900) ?? [];
      if (istekNo == _aramaIstekNo) {
        for (final s in yerel) {
          final parcalar = s.split(',').map((e) => e.trim()).toList();
          // Yerel işletme → esnaf konumuna yakın say
          _oneriEkle(
            sonuclar,
            parcalar.isNotEmpty ? parcalar.first : s,
            parcalar.length > 1 ? parcalar.sublist(1).join(', ') : '',
            lat: widget.esnaf.konum.latitude,
            lon: widget.esnaf.konum.longitude,
          );
        }
        uiGuncelle();
      }
    } catch (_) {}

    if (istekNo == _aramaIstekNo && sonuclar.isEmpty) {
      await _photonAra(q, lat, lon, sonuclar, istekNo, uiGuncelle);
    }

    if (!kIsWeb && istekNo == _aramaIstekNo && sonuclar.length < 3) {
      try {
        final textUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json?'
          'query=${Uri.encodeComponent(q)}'
          '&language=tr&region=tr'
          '&location=$lat,$lon&radius=50000'
          '&key=$_googleApiKey',
        );
        final res = await _zamanAsimli(http.get(textUrl), ms: 1800);
        if (res != null && res.statusCode == 200 && istekNo == _aramaIstekNo) {
          final data = json.decode(res.body);
          final results = data['results'];
          if (data['status'] == 'OK' && results is List) {
            for (final item in results) {
              if (item is! Map) continue;
              final geo = item['geometry'];
              double? rLat;
              double? rLon;
              if (geo is Map) {
                final loc = geo['location'];
                if (loc is Map) {
                  rLat = double.tryParse(loc['lat']?.toString() ?? '');
                  rLon = double.tryParse(loc['lng']?.toString() ?? '');
                }
              }
              _oneriEkle(
                sonuclar,
                _metin(item['name']),
                _metin(item['formatted_address']),
                lat: rLat,
                lon: rLon,
              );
            }
            uiGuncelle();
          }
        }
      } catch (e) {
        debugPrint('Google text search hatası: $e');
      }
    }

    if (!mounted || istekNo != _aramaIstekNo) {
      if (mounted && istekNo == _aramaIstekNo) {
        setState(() => _nereyeAraniyor = false);
      }
      return;
    }

    final finalListe = _mesafeyeGoreSirala(sonuclar, q).take(10).toList();
    if (finalListe.isNotEmpty) {
      _aramaOnbellegi[q.toLowerCase()] = finalListe;
      if (_aramaOnbellegi.length > 40) {
        _aramaOnbellegi.remove(_aramaOnbellegi.keys.first);
      }
    }
    debugPrint('Nereye "$q" → ${finalListe.length} sonuç (mesafe sıralı)');
    setState(() {
      _nereyeOnerileri = finalListe;
      _nereyeAraniyor = false;
      _nereyeAramaBittiBos = finalListe.isEmpty;
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
