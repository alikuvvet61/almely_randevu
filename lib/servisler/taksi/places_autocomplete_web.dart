import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: Maps JavaScript Places AutocompleteService (CORS sorunu yok).
Future<List<Map<String, String>>> googlePlacesWebAutocomplete({
  required String input,
  required double lat,
  required double lon,
}) async {
  if (input.trim().isEmpty) return const [];
  if (!globalContext.has('placesAutocomplete')) return const [];

  final completer = Completer<List<Map<String, String>>>();

  void finish(List<Map<String, String>> list) {
    if (!completer.isCompleted) completer.complete(list);
  }

  final onSuccess = (JSAny? raw) {
    final list = <Map<String, String>>[];
    try {
      final asString = raw?.dartify();
      final decoded = asString is String ? json.decode(asString) : asString;
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          list.add({
            'main': '${item['main'] ?? ''}',
            'secondary': '${item['secondary'] ?? ''}',
            'description': '${item['description'] ?? ''}',
            'placeId': '${item['placeId'] ?? ''}',
          });
        }
      }
    } catch (_) {}
    finish(list);
  }.toJS;

  final onError = (JSAny? err) {
    finish(const []);
  }.toJS;

  try {
    // callAsFunction en fazla 4 arg alır; 5 arg için callMethodVarArgs
    globalContext.callMethodVarArgs('placesAutocomplete'.toJS, [
      input.toJS,
      lat.toJS,
      lon.toJS,
      onSuccess,
      onError,
    ]);
  } catch (_) {
    finish(const []);
  }

  return completer.future.timeout(
    const Duration(seconds: 4),
    onTimeout: () => const [],
  );
}
