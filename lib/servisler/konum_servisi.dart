import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class KonumServisi {
  final String _googleApiKey = "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8";

  /// Google Geocoding API kullanarak profesyonel konum ve adres getirir.
  Future<Map<String, String>?> konumuVeAdresiGetir() async {
    try {
      // 1. İzin Kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'hata': 'Konum izni reddedildi.'};
        }
      }

      // 2. Mevcut Konumu Al
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      // 3. Google Geocoding API Sorgusu
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleApiKey&language=tr'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          String tamAdres = result['formatted_address'];
          
          // Plus Code'u temizle (Örn: XJG3+7M, gibi ifadeleri kaldırır)
          // Adresi bozmadan sadece karmaşık dijital kodu temizler.
          tamAdres = tamAdres.replaceAll(RegExp(r'[A-Z0-9]{4,}\+[A-Z0-9]{2,},?\s?'), '');
          
          String il = "";
          String ilce = "";

          // Adres bileşenlerini ayıkla
          final addressComponents = result['address_components'] as List;
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('administrative_area_level_1')) {
              il = component['long_name'];
            }
            if (types.contains('administrative_area_level_2')) {
              ilce = component['long_name'];
            }
          }

          return {
            'enlem': position.latitude.toStringAsFixed(7),
            'boylam': position.longitude.toStringAsFixed(7),
            'il': il,
            'ilce': ilce,
            'tamAdres': tamAdres,
          };
        } else {
          return {'hata': 'Google Adres Bulunamadı: ${data['status']}'};
        }
      } else {
        return {'hata': 'Google API Hatası: ${response.statusCode}'};
      }
    } catch (e) {
      return {'hata': 'Konum işlemi sırasında hata oluştu: $e'};
    }
  }
}
