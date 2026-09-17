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
            return _googleSonucunuGirdiYap(data['results'][0], position);
          }
        }
      } catch (_) {}

      // 2. ADIM: [YEDEK] Nominatim (OSM) - Google kapalıyken adresinizi anında bulur
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

  Map<String, dynamic> _googleSonucunuGirdiYap(dynamic result, Position pos) {
    String tamAdres = result['formatted_address'];
    tamAdres = tamAdres.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '');
    String il = ""; String ilce = "";
    final addressComponents = result['address_components'] as List;
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
