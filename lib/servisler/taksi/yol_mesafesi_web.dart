import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> _osrmYedek({
  required double originLat,
  required double originLon,
  required double destLat,
  required double destLon,
}) async {
  try {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$originLon,$originLat;$destLon,$destLat'
      '?overview=false',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    final data = json.decode(res.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final r = routes.first as Map;
    final meters = (r['distance'] as num?)?.toDouble();
    final seconds = (r['duration'] as num?)?.toDouble();
    if (meters == null) return null;
    return {
      'meters': meters,
      'seconds': seconds ?? 0.0,
      'distanceText': '',
      'durationText': '',
    };
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _jsCallMap(
  String fnName,
  List<JSAny?> args,
) async {
  if (!globalContext.has(fnName)) return null;
  final completer = Completer<Map<String, dynamic>?>();

  final onSuccess = (JSAny? raw) {
    if (completer.isCompleted) return;
    try {
      final decoded = raw?.dartify();
      final map = decoded is String
          ? json.decode(decoded)
          : decoded;
      if (map is Map) {
        completer.complete(Map<String, dynamic>.from(map));
      } else {
        completer.complete(null);
      }
    } catch (_) {
      completer.complete(null);
    }
  }.toJS;

  final onError = (JSAny? err) {
    if (!completer.isCompleted) completer.complete(null);
  }.toJS;

  try {
    globalContext.callMethodVarArgs(fnName.toJS, [...args, onSuccess, onError]);
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () => null,
  );
}

/// Web: Google Directions JS; olmazsa OSRM.
Future<Map<String, dynamic>?> yolMesafesiHesapla({
  required double originLat,
  required double originLon,
  required double destLat,
  required double destLon,
  String? googleApiKey,
}) async {
  final g = await _jsCallMap('getDrivingRoute', [
    originLat.toJS,
    originLon.toJS,
    destLat.toJS,
    destLon.toJS,
  ]);
  if (g != null && g['meters'] != null) {
    return {
      'meters': (g['meters'] as num).toDouble(),
      'seconds': (g['seconds'] as num?)?.toDouble() ?? 0.0,
      'distanceText': g['distanceText']?.toString() ?? '',
      'durationText': g['durationText']?.toString() ?? '',
    };
  }
  return _osrmYedek(
    originLat: originLat,
    originLon: originLon,
    destLat: destLat,
    destLon: destLon,
  );
}

Future<Map<String, double>?> placeIdKoordinatGetir(
  String placeId, {
  String? googleApiKey,
}) async {
  if (placeId.isEmpty) return null;
  final g = await _jsCallMap('getPlaceLatLng', [placeId.toJS]);
  if (g == null) return null;
  final lat = (g['lat'] as num?)?.toDouble();
  final lon = (g['lon'] as num?)?.toDouble();
  if (lat == null || lon == null) return null;
  return {'lat': lat, 'lon': lon};
}
