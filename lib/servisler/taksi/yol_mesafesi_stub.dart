import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mobil / masaüstü: Google Directions REST; olmazsa OSRM.
Future<Map<String, dynamic>?> yolMesafesiHesapla({
  required double originLat,
  required double originLon,
  required double destLat,
  required double destLon,
  String? googleApiKey,
}) async {
  if (googleApiKey != null && googleApiKey.isNotEmpty) {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLon'
        '&destination=$destLat,$destLon'
        '&mode=driving&language=tr&region=tr'
        '&key=$googleApiKey',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final routes = data['routes'] as List?;
          if (routes != null && routes.isNotEmpty) {
            final legs = routes.first['legs'] as List?;
            if (legs != null && legs.isNotEmpty) {
              final leg = legs.first as Map;
              final dist = leg['distance'] as Map?;
              final dur = leg['duration'] as Map?;
              final meters = (dist?['value'] as num?)?.toDouble();
              final seconds = (dur?['value'] as num?)?.toDouble();
              if (meters != null) {
                return {
                  'meters': meters,
                  'seconds': seconds ?? 0.0,
                  'distanceText': dist?['text']?.toString() ?? '',
                  'durationText': dur?['text']?.toString() ?? '',
                };
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  // OSRM yedek (açık rota)
  try {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLon,$originLat;$destLon,$destLat'
      '?overview=false',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final routes = data['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final r = routes.first as Map;
        final meters = (r['distance'] as num?)?.toDouble();
        final seconds = (r['duration'] as num?)?.toDouble();
        if (meters != null) {
          return {
            'meters': meters,
            'seconds': seconds ?? 0.0,
            'distanceText': '',
            'durationText': '',
          };
        }
      }
    }
  } catch (_) {}

  return null;
}

Future<Map<String, double>?> placeIdKoordinatGetir(
  String placeId, {
  String? googleApiKey,
}) async {
  if (placeId.isEmpty || googleApiKey == null || googleApiKey.isEmpty) {
    return null;
  }
  try {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry'
      '&key=$googleApiKey',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body);
    if (data['status'] != 'OK') return null;
    final loc = data['result']?['geometry']?['location'];
    if (loc is! Map) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lon = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return {'lat': lat, 'lon': lon};
  } catch (_) {
    return null;
  }
}
