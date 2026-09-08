import 'package:flutter/material.dart';

import '../../modeller/esnaf_modeli.dart';
import '../esnaf_detay_ekrani.dart';

/// Taksi için detay ekranı giriş noktası.
/// Yarın tam taksi uygulaması açıldığında burada tek başına detay ekranı
/// mantığı soyutlanabilir; bugün ise mevcut ekranı güvenli şekilde korur.
class TaksiEsnafDetayEkrani extends StatelessWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const TaksiEsnafDetayEkrani({
    super.key,
    required this.esnaf,
    this.kullaniciTel,
  });

  @override
  Widget build(BuildContext context) {
    return EsnafDetayEkrani(
      esnaf: esnaf,
      kullaniciTel: kullaniciTel,
    );
  }
}
