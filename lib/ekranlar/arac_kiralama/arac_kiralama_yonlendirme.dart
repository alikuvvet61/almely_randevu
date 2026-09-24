import 'package:flutter/material.dart';

import '../../modeller/esnaf_modeli.dart';
import '../musteri_ekrani.dart';
import '../randevu_ekrani.dart';
import 'arac_kiralama_musteri_ekrani.dart';
import 'arac_kiralama_randevu_ekrani.dart';

/// Araç Kiralama kategori yönlendirmesi (taksi/taksi_yonlendirme ile aynı desen).
class AracKiralamaYonlendirme {
  static Widget detayEkrani({
    required EsnafModeli esnaf,
    String? kullaniciTel,
  }) {
    if (esnaf.kategori == 'Araç Kiralama') {
      return AracKiralamaMusteriEkrani(
        esnaf: esnaf,
        kullaniciTel: kullaniciTel,
      );
    }

    return MusteriEkrani(
      esnaf: esnaf,
      kullaniciTel: kullaniciTel,
    );
  }

  static Widget randevuEkrani({
    required EsnafModeli esnaf,
    String? kullaniciTel,
  }) {
    if (esnaf.kategori == 'Araç Kiralama') {
      return AracKiralamaRandevuEkrani(
        esnaf: esnaf,
        kullaniciTel: kullaniciTel,
      );
    }

    return RandevuEkrani(
      esnaf: esnaf,
      kullaniciTel: kullaniciTel,
    );
  }
}
