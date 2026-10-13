import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../yardimcilar/mikrofon_izni.dart';

/// Tek oturum. Tarayıcının o anki cümlesini olduğu gibi gösterir.
/// Söz durunca bir kez gönderir; eski cümlenin üstüne yazmaz, oturumu yeniden açmaz.
class KonusmaDinleyici {
  final void Function(String metin) onMetin;
  final void Function(String metin) onGonder;
  final void Function(bool dinliyor) onDinliyor;
  final void Function(String hata) onHata;

  final SpeechToText _speech = SpeechToText();
  Timer? _bekleme;
  Future<void>? _birakma;
  bool dinliyor = false;
  bool _gonderildi = false;
  bool _kapandi = false;
  bool _hazir = false;
  bool _yokSay = false;
  bool _basliyor = false;
  String _son = '';

  KonusmaDinleyici({
    required this.onMetin,
    required this.onGonder,
    required this.onDinliyor,
    required this.onHata,
  });

  Future<void> acKapa() async {
    if (_kapandi) return;
    if (dinliyor) {
      await bitir(_son);
      return;
    }
    if (_basliyor) return;
    _basliyor = true;
    final izin = await mikrofonIzniHemenIste();
    if (_kapandi) {
      _basliyor = false;
      return;
    }
    if (!izin) {
      _basliyor = false;
      onHata('Mikrofon açılamadı. Tarayıcı veya telefon izin vermeli.');
      return;
    }
    _gonderildi = false;
    _son = '';
    onMetin('');
    if (!_hazir) {
      _hazir = await _speech.initialize(onStatus: _durum);
    }
    if (!_hazir) {
      _basliyor = false;
      onHata('Mikrofon açılamadı. Tarayıcı veya telefon izin vermeli.');
      return;
    }
    await _motorBekle();
    if (_kapandi) {
      _basliyor = false;
      return;
    }
    _basliyor = false;
    _yokSay = true;
    _dinliyorAyarla(true);
    if (await _dinle()) {
      _yokSayiGecikmeliBirak();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_kapandi || _gonderildi || !dinliyor) return;
    await _motorBekle(zorla: true);
    if (_kapandi || _gonderildi || !dinliyor) return;
    if (await _dinle()) {
      _yokSayiGecikmeliBirak();
      return;
    }
    _yokSay = false;
    onHata('Mikrofon açılamadı. Tarayıcı veya telefon izin vermeli.');
    _dinliyorAyarla(false);
  }

  Future<void> bitir(String metin) async {
    if (_kapandi || _gonderildi) return;
    final temiz = metin.trim().isNotEmpty ? metin.trim() : _son.trim();
    _gonderildi = true;
    _bekleme?.cancel();
    _dinliyorAyarla(false);
    _motoruPlanla();
    if (temiz.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kapandi) return;
      onGonder(temiz);
    });
  }

  /// Bu cümleyi göndermeden bırakır. Motoru konuşma olayının içinden kesmez.
  void oturumuKes() {
    if (_kapandi) return;
    final konusuyordu = dinliyor;
    _gonderildi = true;
    _bekleme?.cancel();
    _son = '';
    if (konusuyordu) {
      onMetin('');
      _dinliyorAyarla(false);
    }
    _motoruPlanla();
  }

  /// Chrome, kapanmadan yeniden start edilirse ikinci dokunuşu reddeder.
  void _motoruPlanla() {
    if (_birakma != null) return;
    late final Future<void> islem;
    islem = _motoruDurdur().whenComplete(() {
      if (identical(_birakma, islem)) _birakma = null;
    });
    _birakma = islem;
  }

  Future<void> _motorBekle({bool zorla = false}) async {
    final suren = _birakma;
    if (suren != null) await suren;
    if (_kapandi) return;
    if (!zorla && !_speech.isListening) return;
    late final Future<void> islem;
    islem = _motoruDurdur(zorla: zorla).whenComplete(() {
      if (identical(_birakma, islem)) _birakma = null;
    });
    _birakma = islem;
    await islem;
  }

  Future<void> _motoruDurdur({bool zorla = false}) async {
    if (!_hazir) return;
    _yokSay = true;
    try {
      if (zorla || _speech.isListening) {
        await _speech.cancel().timeout(const Duration(milliseconds: 400));
      }
    } catch (_) {}
    final bitis = DateTime.now().add(const Duration(milliseconds: 500));
    while (_speech.isListening && DateTime.now().isBefore(bitis)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  void _yokSayiGecikmeliBirak() {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!_kapandi) _yokSay = false;
    });
  }

  void kapat() {
    _kapandi = true;
    _gonderildi = true;
    dinliyor = false;
    _bekleme?.cancel();
  }

  Future<bool> _dinle() async {
    if (_kapandi || _gonderildi || _speech.isListening) return false;
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'tr_TR',
          listenMode: ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(seconds: 45),
        ),
        onResult: (result) {
          if (_gonderildi || _kapandi) return;
          final cumle = result.recognizedWords.trim();
          if (cumle.isEmpty) return;
          _son = cumle;
          onMetin(_son);
          _bekleme?.cancel();
          _bekleme = Timer(const Duration(milliseconds: 1200), () {
            if (dinliyor && !_gonderildi) bitir(_son);
          });
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _durum(String status) {
    if (_kapandi || _gonderildi || _yokSay) return;
    if (status != 'done' && status != 'notListening') return;
    if (_son.trim().isEmpty && dinliyor) _dinliyorAyarla(false);
  }

  void _dinliyorAyarla(bool deger) {
    dinliyor = deger;
    onDinliyor(deger);
  }
}

class MicKaydi {
  Future<String> Function(String metin) onKomut;
  String? ipucu;
  bool eklendi = false;
  ModalRoute<dynamic>? route;

  MicKaydi(this.onKomut, this.ipucu);
}

/// Uygulamada tek yuvarlak mikrofon. Kayıtlar yalnızca komutu alır.
class YuzerMikrofon {
  static final List<MicKaydi> _yigin = [];
  static final ValueNotifier<int> degisim = ValueNotifier(0);
  static Offset oran = const Offset(0.82, 0.36);
  static void Function()? _sus;

  static final NavigatorObserver gozlemci = _YuzerMikrofonGozlemcisi();

  static MicKaydi? get aktif {
    for (var i = _yigin.length - 1; i >= 0; i--) {
      final kayit = _yigin[i];
      final route = kayit.route;
      if (route == null || route.isCurrent) return kayit;
    }
    return null;
  }

  static void sayfaDegisti() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      degisim.value++;
    });
  }

  static void ekle(BuildContext context, MicKaydi kayit) {
    if (kayit.eklendi) return;
    kayit.route = ModalRoute.of(context);
    kayit.eklendi = true;
    _yigin.add(kayit);
    sayfaDegisti();
  }

  static void cikar(MicKaydi kayit) {
    if (!_yigin.remove(kayit)) return;
    kayit.eklendi = false;
    kayit.route = null;
    if (_yigin.isEmpty) _sus?.call();
    sayfaDegisti();
  }

  /// Sayfa değişmeden önce açık cümleyi gönderilmeden keser.
  static void hepsiniKapat() => _sus?.call();
}

/// Navigator'ın üstünde tek mikrofon. Sayfa geçişinde kopyalanmaz.
class YuzerMikrofonKatmani extends StatelessWidget {
  final Widget child;

  const YuzerMikrofonKatmani({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const _YuzerMic(),
      ],
    );
  }
}

class _YuzerMikrofonGozlemcisi extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => YuzerMikrofon.sayfaDegisti();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => YuzerMikrofon.sayfaDegisti();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => YuzerMikrofon.sayfaDegisti();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => YuzerMikrofon.sayfaDegisti();
}

class _YuzerMic extends StatefulWidget {
  const _YuzerMic();

  @override
  State<_YuzerMic> createState() => _YuzerMicState();
}

class _YuzerMicState extends State<_YuzerMic> with SingleTickerProviderStateMixin {
  late final KonusmaDinleyici _dinleyici;
  late final AnimationController _nabiz;
  MicKaydi? _goren;
  MicKaydi? _hedef;
  String _balon = '';
  bool _dinliyor = false;
  Timer? _cevapTimer;

  @override
  void initState() {
    super.initState();
    _nabiz = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _dinleyici = KonusmaDinleyici(
      onMetin: (metin) {
        if (!mounted) return;
        setState(() => _balon = metin);
      },
      onGonder: (metin) async {
        final kayit = _hedef;
        if (kayit == null) return;
        if (kayit.route != null && !kayit.route!.isCurrent) return;
        final cevap = await kayit.onKomut(metin);
        if (!mounted || YuzerMikrofon.aktif != kayit) return;
        final yazi = cevap.trim();
        if (yazi.isEmpty) return;
        setState(() => _balon = yazi);
        _cevapTimer?.cancel();
        _cevapTimer = Timer(const Duration(seconds: 4), () {
          if (mounted && !_dinliyor) setState(() => _balon = '');
        });
      },
      onDinliyor: (dinliyor) {
        if (!mounted) return;
        setState(() {
          _dinliyor = dinliyor;
          if (dinliyor) _balon = '';
        });
        if (dinliyor) {
          _nabiz.repeat(reverse: true);
        } else {
          _nabiz.stop();
          _nabiz.value = 0;
        }
      },
      onHata: (hata) {
        if (!mounted) return;
        setState(() => _balon = hata);
      },
    );
    YuzerMikrofon._sus = _dinleyici.oturumuKes;
    YuzerMikrofon.degisim.addListener(_sayfa);
    _goren = YuzerMikrofon.aktif;
  }

  void _sayfa() {
    if (!mounted) return;
    final kayit = YuzerMikrofon.aktif;
    if (kayit == _goren) {
      setState(() {});
      return;
    }
    _goren = kayit;
    _hedef = null;
    _dinleyici.oturumuKes();
    setState(() => _balon = '');
  }

  @override
  void dispose() {
    if (YuzerMikrofon._sus == _dinleyici.oturumuKes) YuzerMikrofon._sus = null;
    YuzerMikrofon.degisim.removeListener(_sayfa);
    _cevapTimer?.cancel();
    _nabiz.dispose();
    _dinleyici.kapat();
    super.dispose();
  }

  void _tasi(DragUpdateDetails d) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    const box = 76.0;
    final left = (YuzerMikrofon.oran.dx * w + d.delta.dx).clamp(8.0, w - box - 8);
    final top = (YuzerMikrofon.oran.dy * h + d.delta.dy).clamp(mq.padding.top + 8, h - box - mq.padding.bottom - 8);
    setState(() {
      YuzerMikrofon.oran = Offset(left / w, top / h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kayit = YuzerMikrofon.aktif;
    if (kayit == null) {
      return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());
    }
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    const box = 76.0;
    final left = (YuzerMikrofon.oran.dx * w).clamp(8.0, w - box - 8);
    final top = (YuzerMikrofon.oran.dy * h).clamp(mq.padding.top + 8, h - box - mq.padding.bottom - 8);
    final sagaYakin = left > w * 0.5;
    final yukarida = top < h * 0.45;

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_balon.isNotEmpty)
              Positioned(
                top: yukarida ? box + 6 : null,
                bottom: yukarida ? null : box + 6,
                right: sagaYakin ? 0 : null,
                left: sagaYakin ? null : 0,
                child: IgnorePointer(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Material(
                      color: Colors.white,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(_balon, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3)),
                      ),
                    ),
                  ),
                ),
              ),
            PointerInterceptor(
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _hedef = YuzerMikrofon.aktif;
                _dinleyici.acKapa();
              },
              onPanUpdate: _tasi,
              child: Semantics(
                button: true,
                label: kayit.ipucu ?? 'Sesli komut',
                child: AnimatedBuilder(
                  animation: _nabiz,
                  builder: (context, _) {
                    final t = _dinliyor ? _nabiz.value : 0.0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_dinliyor)
                          Container(
                            width: 60 + 16 * t,
                            height: 60 + 16 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.28 * (1 - t)),
                            ),
                          ),
                        Material(
                          elevation: 8,
                          color: _dinliyor ? Colors.red.shade600 : const Color(0xFF3949AB),
                          shape: const CircleBorder(),
                          child: const SizedBox(
                            width: 60,
                            height: 60,
                            child: Icon(Icons.mic_rounded, color: Colors.white, size: 30),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class YoneticiSesKutusu extends StatefulWidget {
  final bool aktif;
  final Future<String> Function(String metin) onKomut;
  final String? ipucu;

  const YoneticiSesKutusu({super.key, required this.aktif, required this.onKomut, this.ipucu});

  @override
  State<YoneticiSesKutusu> createState() => _YoneticiSesKutusuState();
}

class _YoneticiSesKutusuState extends State<YoneticiSesKutusu> {
  MicKaydi? _kayit;

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _bagla();
  }

  void _bagla() {
    final kayit = MicKaydi(widget.onKomut, widget.ipucu);
    _kayit = kayit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _kayit != kayit) return;
      YuzerMikrofon.ekle(context, kayit);
    });
  }

  void _kopar() {
    final kayit = _kayit;
    _kayit = null;
    if (kayit != null && kayit.eklendi) YuzerMikrofon.cikar(kayit);
  }

  @override
  void didUpdateWidget(YoneticiSesKutusu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _kayit?.onKomut = widget.onKomut;
    _kayit?.ipucu = widget.ipucu;
    if (widget.aktif == oldWidget.aktif) return;
    if (widget.aktif) {
      _bagla();
    } else {
      _kopar();
    }
  }

  @override
  void dispose() {
    _kopar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
