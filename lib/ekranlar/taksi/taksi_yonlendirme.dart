import 'package:flutter/material.dart';

import '../../modeller/esnaf_modeli.dart';
import '../musteri_ekrani.dart';
import '../randevu_ekrani.dart';
import 'taksi_musteri_ekrani.dart';
import 'taksi_randevu_ekrani.dart';

class TaksiYonlendirme {
  static Widget detayEkrani({
    required EsnafModeli esnaf,
    String? kullaniciTel,
  }) {
    if (esnaf.kategori == 'Taksi') {
      return TaksiMusteriEkrani(
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
    if (esnaf.kategori == 'Taksi') {
      return TaksiRandevuEkrani(
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
