import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class KonumServisi {
  final String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  /// [mevcutPozisyon] verilirse GPS tekrar alınmaz (daha hızlı).
  Future<Map<String, dynamic>?> konumuVeAdresiGetir({Position? mevcutPozisyon}) async {
    try {
      Position position;
      if (mevcutPozisyon != null) {
        position = mevcutPozisyon;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            return {'hata': 'Konum izni reddedildi.'};
          }
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }

      // Tek Google isteği — eski uygulamadaki gibi formatted_address (mahalle dahil)
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&language=tr'
          '&key=$_googleApiKey',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final girdi = _googleSonucunuGirdiYap(data['results'] as List, position);
            if (!_kabaAdresMi(girdi['tamAdres']?.toString() ?? '')) {
              return girdi;
            }
          }
        }
      } catch (_) {}

      // Nominatim yedek (mahalle + yol)
      try {
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${position.latitude}&lon=${position.longitude}'
          '&zoom=18&addressdetails=1',
        );
        final res = await http
            .get(osmUrl, headers: {'User-Agent': 'AlmelyRandevu_v2'})
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final addr = data['address'];
          if (addr is Map) {
            final mahalle = (addr['suburb'] ??
                    addr['neighbourhood'] ??
                    addr['quarter'] ??
                    addr['residential'] ??
                    '')
                .toString();
            final yol = (addr['road'] ?? '').toString();
            final no = (addr['house_number'] ?? '').toString();
            final posta = (addr['postcode'] ?? '').toString();
            final ilce = (addr['district'] ??
                    addr['town'] ??
                    addr['county'] ??
                    '')
                .toString();
            final il = (addr['province'] ?? addr['city'] ?? addr['state'] ?? '')
                .toString();
            final cadde = yol.isEmpty
                ? ''
                : (no.isEmpty ? yol : '$yol No:$no');
            final parcalar = <String>[
              if (mahalle.isNotEmpty) mahalle,
              if (cadde.isNotEmpty) cadde,
              if (posta.isNotEmpty && ilce.isNotEmpty && il.isNotEmpty)
                '$posta $ilce/$il'
              else if (posta.isNotEmpty) posta
              else if (ilce.isNotEmpty && il.isNotEmpty) '$ilce/$il'
              else if (il.isNotEmpty) il,
              'Türkiye',
            ];
            if (mahalle.isNotEmpty || cadde.isNotEmpty) {
              return {
                'enlem': position.latitude.toStringAsFixed(7),
                'boylam': position.longitude.toStringAsFixed(7),
                'tamAdres': parcalar.join(', '),
                'il': il,
                'ilce': ilce,
                'isMocked': position.isMocked,
              };
            }
          }
        }
      } catch (_) {}

      return {
        'enlem': position.latitude.toStringAsFixed(7),
        'boylam': position.longitude.toStringAsFixed(7),
        'tamAdres': 'Konum Alındı (Adres Servisi Yanıt Vermedi)',
        'isMocked': position.isMocked,
      };
    } catch (e) {
      return {'hata': 'Konum hatası: $e'};
    }
  }

  bool _kabaAdresMi(String adres) {
    final a = adres.trim();
    if (a.isEmpty) return true;
    if (RegExp(r'^[^,/]+/[^,]+(,\s*Türkiye)?\s*$', caseSensitive: false).hasMatch(a)) {
      return true;
    }
    if (RegExp(r'^[^,]+,\s*Türkiye\s*$', caseSensitive: false).hasMatch(a)) {
      return true;
    }
    return false;
  }

  bool _poiMi(List<String> types, String formatted) {
    const poiTipler = {
      'establishment',
      'point_of_interest',
      'airport',
      'park',
      'store',
      'food',
      'health',
      'university',
      'school',
      'hospital',
      'tourist_attraction',
      'government',
    };
    // Saf premise (müessese) — street_address ile birlikteyse konut olabilir, bırak
    if (types.contains('premise') && !types.contains('street_address')) return true;
    if (types.any(poiTipler.contains)) return true;
    final lower = formatted.toLowerCase();
    return lower.contains('müdürlük') ||
        lower.contains('mudurlugu') ||
        lower.contains('hastanesi') ||
        lower.contains('üniversitesi') ||
        lower.contains('universitesi');
  }

  String _plusTemizle(String s) =>
      s.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '').trim();

  bool _merkezMi(String name) {
    final n = name.toLowerCase().trim();
    return n.contains('merkez');
  }

  /// Google'ın "Trabzon Merkez" dediği yer = Ortahisar ilçesi.
  String? _gercekIlce(String? ilce, String? il) {
    if (ilce == null || ilce.isEmpty) return ilce;
    if (!_merkezMi(ilce)) return ilce;
    final ilN = (il ?? '').toLowerCase().trim();
    if (ilN == 'trabzon') return 'Ortahisar';
    // "X Merkez" → ilçe adını Merkez'siz bırakma; bilinen eşleme yoksa olduğu gibi
    return ilce;
  }

  /// "Trabzon Merkez/Trabzon" → "Ortahisar/Trabzon" (fazla il yok)
  String _ilceIlYaz(String adres, String? ilce, String? il) {
    var gercekIlce = _gercekIlce(ilce, il);
    var gercekIl = il ?? '';

    if ((gercekIlce == null || _merkezMi(gercekIlce)) &&
        RegExp(r'Merkez\s*/\s*Trabzon', caseSensitive: false).hasMatch(adres)) {
      gercekIlce = 'Ortahisar';
      if (gercekIl.isEmpty) gercekIl = 'Trabzon';
    }

    if (gercekIlce == null || gercekIlce.isEmpty || gercekIl.isEmpty) {
      return adres;
    }

    final hedef = '$gercekIlce/$gercekIl';

    // "61030 Trabzon Merkez/Trabzon" → "61030 Ortahisar/Trabzon"
    adres = adres.replaceAllMapped(
      RegExp(
        r'(\d{4,5}\s+)?([^,/]*Merkez)\s*/\s*' + RegExp.escape(gercekIl),
        caseSensitive: false,
      ),
      (m) => '${m.group(1) ?? ''}$hedef',
    );

    // "61030 Trabzon/Trabzon" gibi kaba kalıntı
    if (!adres.toLowerCase().contains(gercekIlce.toLowerCase())) {
      adres = adres.replaceAllMapped(
        RegExp(
          r'(\d{4,5}\s+)?([^,/]+)\s*/\s*' + RegExp.escape(gercekIl),
          caseSensitive: false,
        ),
        (m) {
          final posta = m.group(1) ?? '';
          final sol = (m.group(2) ?? '').trim();
          if (sol.toLowerCase() == gercekIlce!.toLowerCase()) return m.group(0)!;
          if (_merkezMi(sol) || sol.toLowerCase() == gercekIl.toLowerCase()) {
            return '$posta$hedef';
          }
          return m.group(0)!;
        },
      );
    }

    // Ortahisar/Trabzon/Trabzon → Ortahisar/Trabzon
    adres = adres.replaceAll(
      RegExp(
        RegExp.escape(hedef) + r'\s*/\s*' + RegExp.escape(gercekIl),
        caseSensitive: false,
      ),
      hedef,
    );
    adres = adres.replaceAll(
      RegExp(
        r'/' + RegExp.escape(gercekIl) + r'\s*/\s*' + RegExp.escape(gercekIl),
        caseSensitive: false,
      ),
      '/$gercekIl',
    );

    if (!adres.toLowerCase().contains('türkiye')) {
      adres = '$adres, Türkiye';
    }
    return adres;
  }

  /// Eski uygulama gibi: sokak sonucunun formatted_address'i (Boztepe, İran Cd. No:…).
  Map<String, dynamic> _googleSonucunuGirdiYap(List results, Position pos) {
    String? mahalle;
    String? il;
    String? ilce;

    for (final r in results) {
      if (r is! Map) continue;
      final types = (r['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final comps = r['address_components'] as List? ?? [];
      for (final c in comps) {
        if (c is! Map) continue;
        final ct = (c['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final name = (c['long_name'] ?? '').toString();
        if (name.isEmpty) continue;
        if (ct.contains('neighborhood')) mahalle ??= name;
        if ((ct.contains('sublocality') || ct.contains('sublocality_level_1')) &&
            mahalle == null &&
            !_merkezMi(name)) {
          mahalle = name;
        }
        if (ct.contains('administrative_area_level_2')) {
          if (!_merkezMi(name)) {
            ilce = name;
          } else {
            ilce ??= name;
          }
        }
        if (ct.contains('administrative_area_level_1')) il ??= name;
      }
      if (types.contains('neighborhood')) {
        final fa = (r['formatted_address'] ?? '').toString();
        final ilk = fa.split(',').first.trim();
        if (ilk.isNotEmpty) mahalle ??= ilk;
      }
      if (types.contains('administrative_area_level_2')) {
        final fa = (r['formatted_address'] ?? '').toString();
        final ilk = fa.split(',').first.trim();
        if (ilk.isNotEmpty && !_merkezMi(ilk)) ilce = ilk;
      }
    }

    Map? sokakSonucu;
    for (final tip in ['street_address', 'route']) {
      for (final r in results) {
        if (r is! Map) continue;
        final types = (r['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final fa = _plusTemizle((r['formatted_address'] ?? '').toString());
        if (!types.contains(tip)) continue;
        if (_poiMi(types, fa) || _kabaAdresMi(fa)) continue;
        sokakSonucu = r;
        break;
      }
      if (sokakSonucu != null) break;
    }

    String tamAdres = '';
    if (sokakSonucu != null) {
      tamAdres = _plusTemizle((sokakSonucu['formatted_address'] ?? '').toString());
      if (mahalle != null &&
          mahalle.isNotEmpty &&
          !tamAdres.toLowerCase().contains(mahalle.toLowerCase())) {
        tamAdres = '$mahalle, $tamAdres';
      }
    } else if (mahalle != null) {
      final gIlce = _gercekIlce(ilce, il);
      final parcalar = <String>[
        mahalle,
        if (gIlce != null && il != null) '$gIlce/$il' else if (il != null) il,
        'Türkiye',
      ];
      tamAdres = parcalar.join(', ');
    }

    if (sokakSonucu != null) {
      final comps = sokakSonucu['address_components'] as List? ?? [];
      for (final c in comps) {
        if (c is! Map) continue;
        final ct = (c['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final name = (c['long_name'] ?? '').toString();
        if (ct.contains('administrative_area_level_2') && !_merkezMi(name)) {
          ilce = name;
        }
        if (ct.contains('administrative_area_level_1')) il ??= name;
      }
    }

    ilce = _gercekIlce(ilce, il);
    tamAdres = _ilceIlYaz(tamAdres, ilce, il);

    if ((ilce == null || _merkezMi(ilce)) &&
        tamAdres.toLowerCase().contains('ortahisar')) {
      ilce = 'Ortahisar';
      il ??= 'Trabzon';
    }

    if (tamAdres.isNotEmpty && !tamAdres.toLowerCase().contains('türkiye')) {
      tamAdres = '$tamAdres, Türkiye';
    }

    return {
      'enlem': pos.latitude.toStringAsFixed(7),
      'boylam': pos.longitude.toStringAsFixed(7),
      'il': il ?? '',
      'ilce': ilce ?? '',
      'tamAdres': tamAdres,
      'isMocked': pos.isMocked,
    };
  }
}
