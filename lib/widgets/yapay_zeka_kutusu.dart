import 'package:flutter/material.dart';

import '../yardimcilar/ekran_rehber_katalogu.dart';
import 'yonetici_ses_kutusu.dart';

class YapayZekaKutusu extends StatefulWidget {
  final bool aktif;
  final String isletmeAdi;
  final String rehberAnahtar;
  final VoidCallback? taksiIstiyorum;
  final VoidCallback? randevuAl;

  const YapayZekaKutusu({
    super.key,
    required this.aktif,
    required this.isletmeAdi,
    required this.rehberAnahtar,
    this.taksiIstiyorum,
    this.randevuAl,
  });

  @override
  State<YapayZekaKutusu> createState() => _YapayZekaKutusuState();
}

class _YapayZekaKutusuState extends State<YapayZekaKutusu> {
  MicKaydi? _kayit;
  bool _calisiyor = false;

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _bagla();
  }

  void _bagla() {
    final kayit = MicKaydi(_calistir, 'Sesli komut');
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
  void didUpdateWidget(YapayZekaKutusu oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  String _sade(String s) {
    return s.toLowerCase().replaceAll('ı', 'i').replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ş', 's').replaceAll('ö', 'o').replaceAll('ç', 'c');
  }

  bool _taksiIstegi(String soru) {
    final t = _sade(soru);
    return t.contains('taksi istiyorum') || t.contains('taksi ister') || t.contains('taksi cagir') || t.contains('taksi lazim');
  }

  bool _randevuIstegi(String soru) {
    final t = _sade(soru);
    return t.contains('randevu al') || t.contains('hemen randevu') || t.contains('arac kirala') || t.contains('araba kirala');
  }

  Future<String> _calistir(String ham) async {
    final soru = ham.trim();
    if (soru.isEmpty || !widget.aktif || _calisiyor) return '';
    _calisiyor = true;
    try {
      if (_taksiIstegi(soru)) {
        if (widget.taksiIstiyorum == null) return 'Bu işletmede taksi çağrısı yok.';
        widget.taksiIstiyorum!();
        return '${widget.isletmeAdi} için çağrı hazır. Alış yerini kontrol edip onaylayın.';
      }
      if (_randevuIstegi(soru)) {
        if (widget.randevuAl == null) return 'Bu ekranda randevu düğmesi yok.';
        widget.randevuAl!();
        return 'Randevu ekranı açıldı.';
      }
      return EkranRehberKatalogu.ara(soru, tercih: widget.rehberAnahtar);
    } finally {
      _calisiyor = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
