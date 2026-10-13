import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../firestore_servisi.dart';
import 'places_autocomplete.dart';
import 'yol_mesafesi.dart';

/// Randevu ekranındaki Nereye araması. Çağrı penceresi de bunu kullanır.
class NereyeOneri {
  final String baslik;
  final String alt;
  final String etiket;
  final double? lat;
  final double? lon;
  final double? mesafeKm;
  final String? placeId;

  const NereyeOneri({
    required this.baslik,
    required this.alt,
    required this.etiket,
    this.lat,
    this.lon,
    this.mesafeKm,
    this.placeId,
  });
}

class NereyeAramaci {
  NereyeAramaci({
    required this.enlem,
    required this.boylam,
    required this.il,
    required this.ilce,
    required this.esnafEnlem,
    required this.esnafBoylam,
  });

  static const anahtar = 'AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8';
  static final Map<String, List<NereyeOneri>> onbellek = {};

  final double enlem;
  final double boylam;
  final String il;
  final String ilce;
  final double esnafEnlem;
  final double esnafBoylam;

  Future<List<NereyeOneri>> ara(
    String sorgu, {
    required bool Function() iptal,
    void Function(List<NereyeOneri>)? kismi,
  }) async {
    final q = sorgu.trim();
    if (q.isEmpty || iptal()) return const [];

    final sonuclar = <NereyeOneri>[];
    final yerelBag = _yerelBag();
    final yerelSorgu = yerelBag.isEmpty || _normalizeTr(q).contains(_normalizeTr(il)) ? q : '$q $yerelBag';

    void uiGuncelle() {
      if (iptal()) return;
      kismi?.call(_sirala(sonuclar, q).take(10).toList());
    }

    if (kIsWeb) {
      try {
        final googleWeb = await googlePlacesWebAutocomplete(input: q, lat: enlem, lon: boylam);
        if (!iptal()) {
          for (final item in googleWeb) {
            final placeId = item['placeId'] ?? '';
            _ekle(sonuclar, item['main'] ?? '', item['secondary'] ?? '', placeId: placeId.isEmpty ? null : placeId);
          }
          await _koordinatDoldur(sonuclar, iptal, uiGuncelle);
          uiGuncelle();
        }
      } catch (e) {
        debugPrint('Google Places web hatası: $e');
      }
      await Future.wait([
        _photon(q, sonuclar, iptal, uiGuncelle),
        if (yerelSorgu != q) _photon(yerelSorgu, sonuclar, iptal, uiGuncelle),
        _nominatim(q, sonuclar, iptal, uiGuncelle),
        if (yerelSorgu != q) _nominatim(yerelSorgu, sonuclar, iptal, uiGuncelle),
        _openMeteo(q, sonuclar, iptal, uiGuncelle),
      ]);
      await _koordinatDoldur(sonuclar, iptal, uiGuncelle);
    } else {
      final googleSayisi = await _googleAutocomplete(q, sonuclar, iptal, uiGuncelle);
      if (googleSayisi < 2 && !iptal()) {
        await Future.wait([
          _photon(q, sonuclar, iptal, uiGuncelle),
          if (yerelSorgu != q) _photon(yerelSorgu, sonuclar, iptal, uiGuncelle),
          _nominatim(q, sonuclar, iptal, uiGuncelle),
        ]);
      }
      await _koordinatDoldur(sonuclar, iptal, uiGuncelle);
    }

    if (iptal()) return const [];

    try {
      final yerel = await _zaman(FirestoreServisi().mekanArama(q), ms: 900) ?? [];
      if (!iptal()) {
        for (final s in yerel) {
          final parcalar = s.split(',').map((e) => e.trim()).toList();
          _ekle(
            sonuclar,
            parcalar.isNotEmpty ? parcalar.first : s,
            parcalar.length > 1 ? parcalar.sublist(1).join(', ') : '',
            lat: esnafEnlem,
            lon: esnafBoylam,
          );
        }
        uiGuncelle();
      }
    } catch (_) {}

    if (!iptal() && sonuclar.isEmpty) {
      await _photon(q, sonuclar, iptal, uiGuncelle);
    }

    if (!kIsWeb && !iptal() && sonuclar.length < 3) {
      try {
        final textUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/textsearch/json?'
          'query=${Uri.encodeComponent(q)}'
          '&language=tr&region=tr'
          '&location=$enlem,$boylam&radius=50000'
          '&key=$anahtar',
        );
        final res = await _zaman(http.get(textUrl), ms: 1800);
        if (res != null && res.statusCode == 200 && !iptal()) {
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
              _ekle(sonuclar, _metin(item['name']), _metin(item['formatted_address']), lat: rLat, lon: rLon);
            }
            uiGuncelle();
          }
        }
      } catch (e) {
        debugPrint('Google text search hatası: $e');
      }
    }

    if (iptal()) return const [];
    final finalListe = _sirala(sonuclar, q).take(10).toList();
    if (finalListe.isNotEmpty) {
      onbellek[q.toLowerCase()] = finalListe;
      if (onbellek.length > 40) onbellek.remove(onbellek.keys.first);
    }
    debugPrint('Nereye "$q" → ${finalListe.length} sonuç (mesafe sıralı)');
    return finalListe;
  }

  String _yerelBag() {
    final parcalar = [ilce.trim(), il.trim()].where((e) => e.isNotEmpty).toList();
    final tekil = <String>[];
    for (final p in parcalar) {
      if (!tekil.any((t) => _normalizeTr(t) == _normalizeTr(p))) tekil.add(p);
    }
    return tekil.join(' ');
  }

  void _ekle(List<NereyeOneri> hedef, String baslik, String alt, {double? lat, double? lon, String? placeId}) {
    baslik = _plusCodeTemizle(baslik);
    alt = _plusCodeTemizle(alt);
    if (baslik.isEmpty) return;
    final etiket = alt.isEmpty ? baslik : '$baslik, $alt';
    final mevcutIx = hedef.indexWhere((o) => _normalizeTr(o.etiket) == _normalizeTr(etiket));
    final mesafe = (lat != null && lon != null) ? Geolocator.distanceBetween(enlem, boylam, lat, lon) / 1000.0 : null;
    if (mevcutIx >= 0) {
      final eski = hedef[mevcutIx];
      final yeniDahaIyi = (eski.mesafeKm == null && mesafe != null) ||
          (eski.mesafeKm != null && mesafe != null && mesafe < eski.mesafeKm!) ||
          ((eski.placeId == null || eski.placeId!.isEmpty) && placeId != null && placeId.isNotEmpty);
      if (yeniDahaIyi) {
        hedef[mevcutIx] = NereyeOneri(
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
    hedef.add(NereyeOneri(baslik: baslik, alt: alt, etiket: etiket, lat: lat, lon: lon, mesafeKm: mesafe, placeId: placeId));
  }

  Future<void> _koordinatDoldur(List<NereyeOneri> sonuclar, bool Function() iptal, void Function() uiGuncelle) async {
    final adaylar = sonuclar.where((o) => (o.lat == null || o.lon == null) && o.placeId != null && o.placeId!.isNotEmpty).take(8).toList();
    if (adaylar.isEmpty) return;
    await Future.wait(adaylar.map((o) async {
      if (iptal()) return;
      final detay = await placeIdKoordinatGetir(o.placeId!, googleApiKey: anahtar);
      if (detay == null || iptal()) return;
      final dLat = detay['lat'];
      final dLon = detay['lon'];
      if (dLat == null || dLon == null) return;
      final mesafe = Geolocator.distanceBetween(enlem, boylam, dLat, dLon) / 1000.0;
      final ix = sonuclar.indexWhere((x) => identical(x, o) || (x.placeId == o.placeId && x.etiket == o.etiket));
      if (ix < 0) return;
      sonuclar[ix] = NereyeOneri(
        baslik: o.baslik,
        alt: o.alt,
        etiket: o.etiket,
        lat: dLat,
        lon: dLon,
        mesafeKm: mesafe,
        placeId: o.placeId,
      );
    }));
    if (!iptal()) uiGuncelle();
  }

  List<NereyeOneri> _sirala(List<NereyeOneri> liste, String sorgu) {
    final yerelIl = _normalizeTr(il);
    final kopya = List<NereyeOneri>.from(liste);
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
      final sa = _ilgililik(sorgu, a);
      final sb = _ilgililik(sorgu, b);
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

  int _ilgililik(String sorgu, NereyeOneri o) {
    final sk = _normalizeTr(sorgu).split(RegExp(r'\s+')).where((k) => k.length >= 2).toList();
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
    if (baslikHit == sk.length) score += 80;
    if (baslik.contains(sk.join(' '))) score += 40;
    return score;
  }

  Future<void> _photon(String q, List<NereyeOneri> sonuclar, bool Function() iptal, void Function() uiGuncelle) async {
    try {
      final url = Uri.parse('https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&limit=10&lang=default&lat=$enlem&lon=$boylam');
      final res = await _zaman(http.get(url), ms: 3000);
      if (res == null || res.statusCode != 200 || iptal()) return;
      final features = json.decode(res.body)['features'];
      if (features is! List) return;
      for (final f in features) {
        if (f is! Map) continue;
        final p = f['properties'];
        if (p is! Map) continue;
        final name = _metin(p['name']);
        if (name.isEmpty) continue;
        final alt = [_metin(p['street']), _metin(p['district']), _metin(p['city']), _metin(p['state']), _metin(p['country'])]
            .where((e) => e.isNotEmpty)
            .toSet()
            .join(', ');
        double? rLat;
        double? rLon;
        final geom = f['geometry'];
        if (geom is Map && geom['coordinates'] is List && (geom['coordinates'] as List).length >= 2) {
          final coords = geom['coordinates'] as List;
          rLon = double.tryParse(coords[0].toString());
          rLat = double.tryParse(coords[1].toString());
        }
        _ekle(sonuclar, name, alt, lat: rLat, lon: rLon);
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('Photon hatası: $e');
    }
  }

  Future<void> _nominatim(String q, List<NereyeOneri> sonuclar, bool Function() iptal, void Function() uiGuncelle) async {
    try {
      var urlStr = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&addressdetails=1&limit=10&countrycodes=tr';
      urlStr += '&viewbox=${boylam - 0.8},${enlem + 0.5},${boylam + 0.8},${enlem - 0.5}&bounded=0';
      final res = await _zaman(http.get(Uri.parse(urlStr)), ms: 3500);
      if (res == null || res.statusCode != 200 || iptal()) return;
      final data = json.decode(res.body);
      if (data is! List) return;
      for (final item in data) {
        if (item is! Map) continue;
        final display = _metin(item['display_name']);
        if (display.isEmpty) continue;
        final parcalar = display.split(',').map((e) => e.trim()).toList();
        _ekle(
          sonuclar,
          parcalar.isNotEmpty ? parcalar.first : display,
          parcalar.length > 1 ? parcalar.sublist(1).take(4).join(', ') : '',
          lat: double.tryParse(_metin(item['lat'])),
          lon: double.tryParse(_metin(item['lon'])),
        );
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('Nominatim hatası: $e');
    }
  }

  Future<void> _openMeteo(String q, List<NereyeOneri> sonuclar, bool Function() iptal, void Function() uiGuncelle) async {
    try {
      final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(q)}&count=10&language=tr&countryCode=TR');
      final res = await _zaman(http.get(url), ms: 3000);
      if (res == null || res.statusCode != 200 || iptal()) return;
      final results = json.decode(res.body)['results'];
      if (results is! List) return;
      for (final item in results) {
        if (item is! Map) continue;
        final name = _metin(item['name']);
        if (name.isEmpty) continue;
        final alt = [_metin(item['admin2']), _metin(item['admin1']), _metin(item['country'])].where((e) => e.isNotEmpty).join(', ');
        _ekle(
          sonuclar,
          name,
          alt,
          lat: double.tryParse(item['latitude']?.toString() ?? ''),
          lon: double.tryParse(item['longitude']?.toString() ?? ''),
        );
      }
      uiGuncelle();
    } catch (e) {
      debugPrint('OpenMeteo hatası: $e');
    }
  }

  Future<int> _googleAutocomplete(String q, List<NereyeOneri> sonuclar, bool Function() iptal, void Function() uiGuncelle) async {
    if (kIsWeb) return 0;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=${Uri.encodeComponent(q)}&components=country:tr&language=tr'
        '&location=$enlem,$boylam&radius=50000&key=$anahtar',
      );
      final res = await _zaman(http.get(url), ms: 1800);
      if (res == null || res.statusCode != 200 || iptal()) return 0;
      final data = json.decode(res.body);
      final predictions = data['predictions'];
      if (_metin(data['status']) != 'OK' || predictions is! List) return 0;
      var eklenen = 0;
      for (final item in predictions) {
        if (item is! Map) continue;
        final placeId = _metin(item['place_id']);
        final str = item['structured_formatting'];
        if (str is Map) {
          _ekle(sonuclar, _metin(str['main_text']), _metin(str['secondary_text']), placeId: placeId.isEmpty ? null : placeId);
        } else {
          final desc = _metin(item['description']);
          final parcalar = desc.split(',').map((e) => e.trim()).toList();
          _ekle(sonuclar, parcalar.isNotEmpty ? parcalar.first : desc, parcalar.length > 1 ? parcalar.sublist(1).join(', ') : '', placeId: placeId.isEmpty ? null : placeId);
        }
        eklenen++;
      }
      await _koordinatDoldur(sonuclar, iptal, uiGuncelle);
      uiGuncelle();
      return eklenen;
    } catch (e) {
      debugPrint('Google autocomplete hatası: $e');
      return 0;
    }
  }

  Future<T?> _zaman<T>(Future<T> future, {int ms = 1400}) async {
    try {
      return await future.timeout(Duration(milliseconds: ms));
    } catch (_) {
      return null;
    }
  }

  String _normalizeTr(String s) {
    var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().replaceAll('ş', 's').replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c');
    return t.replaceAll('\u0307', '');
  }

  String _metin(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return '';
    return s;
  }

  String _plusCodeTemizle(String name) => name.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '').trim();
}
