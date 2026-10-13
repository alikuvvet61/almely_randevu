import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class TaksiCagriSesi {
  web.AudioContext? _ctx;
  web.OscillatorNode? _osc;

  void baslat() {
    if (_osc != null) return;
    try {
      final ctx = web.AudioContext();
      _ctx = ctx;
      ctx.resume();
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 880;
      gain.gain.value = 0.06;
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      _osc = osc;
      _tarayiciBildir();
    } catch (e) {
      debugPrint('Zil açılamadı: $e');
    }
  }

  void durdur() {
    try {
      _osc?.stop();
      _ctx?.close();
    } catch (_) {}
    _osc = null;
    _ctx = null;
  }

  void _tarayiciBildir() {
    try {
      if (web.Notification.permission == 'granted') {
        web.Notification('Yeni taksi çağrısı');
        return;
      }
      if (web.Notification.permission == 'default') {
        web.Notification.requestPermission();
      }
    } catch (e) {
      debugPrint('Tarayıcı bildirimi: $e');
    }
  }
}
