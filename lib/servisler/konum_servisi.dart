import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class KonumServisi {
  static const String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  Future<Map<String, String>?> konumuVeAdresiGetir() async {
    Position? pos;
    try {
      pos = await _konumYetkisiAl();

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_googleApiKey&language=tr'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          var components = data['results'][0]['address_components'];

          // MAHALLE ICIN TUM OLASILIKLARI TARIYORUZ
          String mah = _parcaBul(components, "sublocality_level_1");
          if (mah.isEmpty) mah = _parcaBul(components, "neighborhood");
          if (mah.isEmpty) mah = _parcaBul(components, "sublocality");
          if (mah.isEmpty) mah = _parcaBul(components, "administrative_area_level_4");
          if (mah.isEmpty) mah = _parcaBul(components, "locality");

          String cad = _parcaBul(components, "route");
          String no = _parcaBul(components, "street_number");
          String ilce = _parcaBul(components, "administrative_area_level_2");
          String il = _parcaBul(components, "administrative_area_level_1");
          String pk = _parcaBul(components, "postal_code");

          return {
            'enlem': pos.latitude.toString(),
            'boylam': pos.longitude.toString(),
            'il': il,
            'ilce': ilce,
            'tamAdres': _formatliAdresOlustur(mah, cad, no, pk, ilce, il),
          };
        }
      }
      return await _nominatimYedek(pos);
    } catch (e) {
      if (pos != null) return await _nominatimYedek(pos);
      return {'hata': 'Konum veya Adres hatası: $e'};
    }
  }

  String _formatliAdresOlustur(String m, String r, String h, String pk, String d, String p) {
    List<String> parcalar = [];

    // Mahalle isminde gereksiz "Hastane ismi" gibi detaylar varsa temizleyip sadece mahalle ismini alalım
    if (m.isNotEmpty) {
      String temizMah = m.split(',').last.replaceAll(RegExp(r' Mahallesi| Mah\.', caseSensitive: false), "").trim();
      parcalar.add("$temizMah Mah.");
    }

    // Sokak/Cadde bilgisini ekle
    if (r.isNotEmpty) {
      parcalar.add(r.contains("Cad") || r.contains("Sok") || r.contains("Sk") ? r : "$r Sk.");
    }

    // Kapı Numarası
    if (h.isNotEmpty) {
      parcalar.add("No: $h");
    }

    String anaGovde = parcalar.join(", ");
    return "$anaGovde $d / $p".trim();
  }

  String _parcaBul(List components, String tip) {
    try {
      final component = components.firstWhere(
            (c) => (c['types'] as List).contains(tip),
        orElse: () => null,
      );
      return component != null ? component['long_name'] : "";
    } catch (_) { return ""; }
  }

  Future<Map<String, String>> _nominatimYedek(Position pos) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'AlmElyApp'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final a = data['address'] as Map<String, dynamic>;

        String mah = a['suburb'] ?? a['neighbourhood'] ?? a['village'] ?? "";
        String cad = a['road'] ?? "";
        String no = a['house_number'] ?? "";
        String ilce = a['district'] ?? a['town'] ?? a['city_district'] ?? "";
        String il = a['province'] ?? a['state'] ?? "";
        String pk = a['postcode'] ?? "";

        return {
          'enlem': pos.latitude.toString(),
          'boylam': pos.longitude.toString(),
          'il': il,
          'ilce': ilce,
          'tamAdres': _formatliAdresOlustur(mah, cad, no, pk, ilce, il),
        };
      }
    } catch (_) {}
    return {'hata': 'Adres cozulemedi.'};
  }

  Future<Position> _konumYetkisiAl() async {
    bool s = await Geolocator.isLocationServiceEnabled();
    if (!s) throw 'Lutfen GPS servisini acin.';

    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) throw 'Izin reddedildi.';
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    return await Geolocator.getCurrentPosition(locationSettings: settings);
  }
}