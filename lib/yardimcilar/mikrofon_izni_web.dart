import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool _izinVar = false;
Future<bool>? _bekleyen;

/// İzin penceresini tıklamanın içinde açar. Söz tanıma bundan sonra başlar.
Future<bool> mikrofonIzniHemenIste() {
  if (_izinVar) return Future<bool>.value(true);
  final suren = _bekleyen;
  if (suren != null) return suren;
  try {
    final istek = web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart
        .then((stream) async {
      final parcalar = stream.getTracks().toDart;
      for (final parca in parcalar) {
        parca.stop();
      }
      _izinVar = true;
      return true;
    }).catchError((_) => false);
    _bekleyen = istek.whenComplete(() => _bekleyen = null);
    return _bekleyen!;
  } catch (_) {
    return Future<bool>.value(false);
  }
}
