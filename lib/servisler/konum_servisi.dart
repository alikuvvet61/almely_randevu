import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geo;

class KonumServisi {
  static const String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  /// Mevcut GPS konumunu alır ve profesyonel formatta adres bilgilerini döndürür.
  Future<Map<String, String>?> konumuVeAdresiGetir() async {
    try {
      final Position pos = await _konumYetkisiAl();

      // 1. Google Geocoding API ile en detaylı adresi çekmeyi dene
      final Map<String, dynamic>? googleData = await _fetchGoogleGeocode(pos.latitude, pos.longitude);
      
      if (googleData != null && googleData['status'] == 'OK') {
        final List results = googleData['results'] as List;
        if (results.isNotEmpty) {
          // Google'ın döndürdüğü sonuçlar arasından 'street_address' tipinde olanı bulalım.
          // Bu tip genellikle en doğru cadde ve bina numarası bilgisini içerir.
          Map<String, dynamic>? selectedResult;
          for (final res in results) {
            if (res is Map<String, dynamic>) {
              final List types = (res['types'] as List?) ?? [];
              if (types.contains('street_address')) {
                selectedResult = res;
                break;
              }
            }
          }

          // Eğer tam bir sokak adresi bulunamazsa, en alakalı (ilk) sonucu baz al.
          selectedResult ??= results[0] as Map<String, dynamic>;
          final List components = (selectedResult['address_components'] as List?) ?? [];

          // Adres bileşenlerini ayıklıyoruz
          String mahalle = _parcaBul(components, "neighborhood");
          if (mahalle.isEmpty) mahalle = _parcaBul(components, "sublocality_level_1");
          
          String cadde = _parcaBul(components, "route");
          String no = _parcaBul(components, "street_number");
          String pk = _parcaBul(components, "postal_code");
          String ilce = _parcaBul(components, "administrative_area_level_2");
          String il = _parcaBul(components, "administrative_area_level_1");
          String ulke = _parcaBul(components, "country");

          return {
            'enlem': pos.latitude.toString(),
            'boylam': pos.longitude.toString(),
            'il': il,
            'ilce': ilce,
            'tamAdres': _formatliAdresOlustur(mahalle, cadde, no, pk, ilce, il, ulke),
          };
        }
      }
      
      // Google API başarısız olursa Native Geocoder'ı (yedek) kullan
      return await _nativeGeocodeYedek(pos);
    } catch (e) {
      debugPrint("Konum servisi hatası: $e");
      return {'hata': 'Konum alınamadı: $e'};
    }
  }

  /// Koordinatlardan sadece Google API kullanarak adres metni döndürür.
  Future<String?> googleAdresGetir(double lat, double lon) async {
    try {
      final Map<String, dynamic>? googleData = await _fetchGoogleGeocode(lat, lon);
      if (googleData != null && googleData['status'] == 'OK') {
        final List results = googleData['results'] as List;
        if (results.isNotEmpty) {
          Map<String, dynamic>? selectedResult;
          for (final res in results) {
            if (res is Map<String, dynamic> && (res['types'] as List).contains('street_address')) {
              selectedResult = res;
              break;
            }
          }
          selectedResult ??= results[0] as Map<String, dynamic>;
          final List components = (selectedResult['address_components'] as List?) ?? [];

          String m = _parcaBul(components, "neighborhood");
          if (m.isEmpty) m = _parcaBul(components, "sublocality_level_1");
          String r = _parcaBul(components, "route");
          String n = _parcaBul(components, "street_number");
          String p = _parcaBul(components, "postal_code");
          String d = _parcaBul(components, "administrative_area_level_2");
          String s = _parcaBul(components, "administrative_area_level_1");
          String c = _parcaBul(components, "country");

          return _formatliAdresOlustur(m, r, n, p, d, s, c);
        }
      }
    } catch (e) {
      debugPrint("googleAdresGetir hatası: $e");
    }
    return null;
  }

  /// Google Geocoding API'ye HTTP isteği atar.
  Future<Map<String, dynamic>?> _fetchGoogleGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$_googleApiKey&language=tr'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> _nativeGeocodeYedek(Position pos) async {
    try {
      await geo.setLocaleIdentifier("tr_TR");
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        geo.Placemark p = placemarks[0];
        return {
          'enlem': pos.latitude.toString(),
          'boylam': pos.longitude.toString(),
          'il': p.administrativeArea ?? "",
          'ilce': p.subAdministrativeArea ?? "",
          'tamAdres': _formatliAdresOlustur(
            p.subLocality ?? p.locality ?? "",
            p.thoroughfare ?? "",
            p.subThoroughfare ?? "",
            p.postalCode ?? "",
            p.subAdministrativeArea ?? "",
            p.administrativeArea ?? "",
            p.country ?? ""
          ),
        };
      }
    } catch (_) {}
    return {'hata': 'Adres çözülemedi.'};
  }

  String _formatliAdresOlustur(String mah, String yol, String no, String pk, String ilce, String il, String ulke) {
    // Format: "Derecik, Atatürk Caddesi No:150/A, 61170 Akçaabat/Trabzon, Türkiye"
    
    String sMah = mah.replaceAll(RegExp(r' Mahallesi| Mah\.| Mah', caseSensitive: false), "").trim();
    String sNo = no.replaceAll(RegExp(r'No[:\s\.]*', caseSensitive: false), "").trim();
    
    List<String> parcalar = [];
    
    if (sMah.isNotEmpty) parcalar.add(sMah);
    
    String caddeNo = yol.trim();
    if (sNo.isNotEmpty) caddeNo += " No:$sNo";
    if (caddeNo.isNotEmpty) parcalar.add(caddeNo);
    
    if (pk.isNotEmpty) parcalar.add(pk);
    
    String yer = "";
    if (ilce.isNotEmpty) yer = ilce;
    if (il.isNotEmpty) yer = yer.isNotEmpty ? "$yer/$il" : il;
    if (yer.isNotEmpty) parcalar.add(yer);
    
    if (ulke.isNotEmpty) parcalar.add(ulke);

    return parcalar.join(", ");
  }

  String _parcaBul(List components, String tip) {
    try {
      final component = components.firstWhere(
        (c) => c is Map<String, dynamic> && (c['types'] as List).contains(tip),
        orElse: () => null,
      );
      return component != null ? (component['long_name'] as String? ?? "") : "";
    } catch (e) { return ""; }
  }

  Future<Position> _konumYetkisiAl() async {
    bool s = await Geolocator.isLocationServiceEnabled();
    if (!s) throw 'Lütfen GPS servisini açın.';
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) throw 'Konum izni reddedildi.';
    }
    return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation));
  }
}