import 'dart:async';

import 'package:flutter/services.dart';

class TaksiCagriSesi {
  Timer? _zaman;

  void baslat() {
    _zaman?.cancel();
    void cal() {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }

    cal();
    _zaman = Timer.periodic(const Duration(seconds: 2), (_) => cal());
  }

  void durdur() {
    _zaman?.cancel();
    _zaman = null;
  }
}
