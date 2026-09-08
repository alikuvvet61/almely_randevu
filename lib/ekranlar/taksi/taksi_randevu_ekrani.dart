import 'package:flutter/material.dart';
import '../randevu_ekrani.dart';
import '../../modeller/esnaf_modeli.dart';

/// Wrapper — Taksi için orijinal RandevuEkrani'yi kullanır ve sadece modu taksi olarak işaretler.
class TaksiRandevuEkrani extends StatelessWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const TaksiRandevuEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  Widget build(BuildContext context) {
    return RandevuEkrani(esnaf: esnaf, kullaniciTel: kullaniciTel, modu: RandevuModu.taksi);
  }
}
