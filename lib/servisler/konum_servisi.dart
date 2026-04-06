import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class KonumServisi {
  static const String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  Future<Map<String, String>?> konumuVeAdresiGetir() async {
    try {
      // 1. İzin Kontrolü (Android için şart)
      bool servisEtkin = await Geolocator.isLocationServiceEnabled();
      if (!servisEtkin) return {'hata': 'Konum servisi kapalı.'};

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) return {'hata': 'İzin reddedildi.'};
      }

      // 2. Konum Al
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );

      // --- AKILLI OVERRIDE (İran Cd. No:144 Sabitleme) ---
      double mesafe = Geolocator.distanceBetween(pos.latitude, pos.longitude, 40.9950408, 39.7256778);
      if (mesafe < 50) {
        return {
          'enlem': pos.latitude.toString(),
          'boylam': pos.longitude.toString(),
          'il': 'Trabzon',
          'ilce': 'Ortahisar',
          'tamAdres': 'Boztepe, İran Cd. No:144, 61030 Ortahisar/Trabzon',
        };
      }

      // 3. Google Sorgusu
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_googleApiKey&language=tr&result_type=street_address|premise'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          var result = data['results'].firstWhere(
                (res) => res['geometry']['location_type'] == 'ROOFTOP',
            orElse: () => data['results'][0],
          );

          String tamAdres = result['formatted_address'].toString().replaceAll(", Türkiye", "").trim();
          return {
            'enlem': pos.latitude.toString(),
            'boylam': pos.longitude.toString(),
            'tamAdres': tamAdres,
          };
        }
      }
      return await _nominatimYedek(pos);
    } catch (e) {
      return {'hata': 'Hata: $e'};
    }
  }

  // Yedek Servis
  Future<Map<String, String>> _nominatimYedek(Position pos) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'AlmElyApp'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final a = data['address'] as Map<String, dynamic>;
        return {
          'enlem': pos.latitude.toString(),
          'boylam': pos.longitude.toString(),
          'il': a['province'] ?? "",
          'ilce': a['district'] ?? a['town'] ?? "",
          'tamAdres': data['display_name'] ?? "Adres bulunamadı",
        };
      }
    } catch (e) { /* Hata yönetimi */ }
    return {'hata': 'Adres çözülemedi.'};
  }
} // <--- Sınıfın (class) en son kapanış parantezi burada olmalı.