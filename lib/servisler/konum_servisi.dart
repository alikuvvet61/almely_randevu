import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class KonumServisi {
  final String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  Future<Map<String, dynamic>?> konumuVeAdresiGetir() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return {'hata': 'Konum izni reddedildi.'};
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

      // 1. ADIM: Google Geocoding Deneniyor
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleApiKey&language=tr'
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final sonuc = _enDetayliGoogleSonucu(data['results'] as List);
            final girdi = _googleSonucunuGirdiYap(sonuc, position);
            // Sokak detayı yoksa Nominatim'e düş (sadece il/ilçe gelmesin)
            if (_adresDetayliMi(girdi['tamAdres']?.toString() ?? '')) {
              return girdi;
            }
          }
        }
      } catch (_) {}

      // 2. ADIM: [YEDEK] Nominatim (OSM) - Google kapalıyken veya kaba adres döndüğünde
      try {
        final osmUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'
        );
        final res = await http.get(osmUrl, headers: {'User-Agent': 'AlmelyRandevu_v2'});
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          return {
            'enlem': position.latitude.toStringAsFixed(7),
            'boylam': position.longitude.toStringAsFixed(7),
            'tamAdres': data['display_name'] ?? "Konum Belirlendi",
            'il': data['address']?['province'] ?? data['address']?['city'] ?? "",
            'ilce': data['address']?['district'] ?? data['address']?['town'] ?? "",
            'isMocked': position.isMocked,
          };
        }
      } catch (_) {}

      return {
        'enlem': position.latitude.toStringAsFixed(7),
        'boylam': position.longitude.toStringAsFixed(7),
        'tamAdres': "Konum Alındı (Adres Servisi Yanıt Vermedi)",
        'isMocked': position.isMocked,
      };
    } catch (e) {
      return {'hata': 'Konum hatası: $e'};
    }
  }

  /// "Ortahisar/Trabzon, Türkiye" gibi kaba adresleri ayırt eder.
  bool _adresDetayliMi(String adres) {
    final a = adres.trim();
    if (a.length < 25) return false;
    // Cadde/sokak/no ipucu veya virgülle ayrılmış birden fazla parça
    final lower = a.toLowerCase();
    if (lower.contains('cd') ||
        lower.contains('cad') ||
        lower.contains('sk') ||
        lower.contains('sok') ||
        lower.contains('no:') ||
        lower.contains('no ') ||
        RegExp(r'\d{5}').hasMatch(a)) {
      return true;
    }
    return a.split(',').length >= 3;
  }

  /// Sokak / bina seviyesindeki sonucu tercih eder (il/ilçe seviyesini atlar).
  dynamic _enDetayliGoogleSonucu(List results) {
    const tercihSirasi = [
      'street_address',
      'premise',
      'subpremise',
      'route',
      'intersection',
      'neighborhood',
      'sublocality',
      'sublocality_level_1',
      'postal_code',
    ];
    for (final tip in tercihSirasi) {
      for (final r in results) {
        if (r is! Map) continue;
        final types = (r['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (types.contains(tip)) return r;
      }
    }
    Map? enUzun;
    var maxLen = -1;
    for (final r in results) {
      if (r is! Map) continue;
      final len = (r['formatted_address']?.toString() ?? '').length;
      if (len > maxLen) {
        maxLen = len;
        enUzun = r;
      }
    }
    return enUzun ?? results.first;
  }

  Map<String, dynamic> _googleSonucunuGirdiYap(dynamic result, Position pos) {
    String tamAdres = result['formatted_address']?.toString() ?? '';
    tamAdres = tamAdres.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '').trim();
    String il = ""; String ilce = "";
    final addressComponents = result['address_components'] as List? ?? [];
    for (var component in addressComponents) {
      final types = component['types'] as List;
      if (types.contains('administrative_area_level_1')) il = component['long_name'];
      if (types.contains('administrative_area_level_2')) ilce = component['long_name'];
    }
    return {
      'enlem': pos.latitude.toStringAsFixed(7),
      'boylam': pos.longitude.toStringAsFixed(7),
      'il': il, 'ilce': ilce, 'tamAdres': tamAdres,
      'isMocked': pos.isMocked,
    };
  }
}
