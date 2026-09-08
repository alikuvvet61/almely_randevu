import 'package:flutter/material.dart';
import '../../servisler/bildirim_servisi.dart';

class TaksiBildirimServisi {
  static Future<void> sendTalepKabulBildirim(String kullaniciTel, String isletmeAdi, {BuildContext? context}) async {
    if (kullaniciTel.trim().isEmpty) return;
    await BildirimServisi.bildirimGonder(
      baslik: 'Taksi Talebiniz Kabul Edildi',
      icerik: '$isletmeAdi tarafından talebiniz kabul edildi. Lütfen hazır olun.',
      kullaniciTel: kullaniciTel,
      context: context,
    );
  }

  static Future<void> sendTalepReddetBildirim(String kullaniciTel, String isletmeAdi, {BuildContext? context}) async {
    if (kullaniciTel.trim().isEmpty) return;
    await BildirimServisi.bildirimGonder(
      baslik: 'Taksi Talebiniz Reddedildi',
      icerik: '$isletmeAdi tarafından talebiniz maalesef reddedildi.',
      kullaniciTel: kullaniciTel,
      context: context,
    );
  }
}
