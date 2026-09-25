import 'package:flutter/material.dart';
import '../ekranlar/ekran_rehber_detay_ekrani.dart';
import 'ekran_rehber_katmani.dart';

/// AppBar actions için — global üst sağ ? ile aynı ikon/stil.
/// Not: [EkranRehberKatmani] zaten her ekranda sağ üstte gösterir; çift ikon olmaması için
/// AppBar'a yalnızca global katman yoksa ekleyin.
class EkranRehberAppBarAksiyonu extends StatelessWidget {
  final String? sinifAdi;

  const EkranRehberAppBarAksiyonu({super.key, this.sinifAdi});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Kullanım Rehberi',
      icon: const Icon(Icons.help_outline, size: 26),
      onPressed: () => EkranRehberDetayEkrani.ac(
        context,
        sinifAdi: sinifAdi ?? AktifEkranTakibi.sinifAdi.value,
      ),
    );
  }
}
