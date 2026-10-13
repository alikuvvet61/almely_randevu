import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';

/// Randevu öncesi/sonrası hatırlatma şablonları ve yer tutucu doldurma.
class HatirlatmaSablonlari {
  static const String varsayilanOnceBaslik = 'Randevu Hatırlatması';
  static const String varsayilanOnceIcerik =
      'Merhaba {musteri}, {isletme} randevunuz {tarih} saat {saat}. Hizmet: {hizmet}. Sizi bekliyoruz!';

  static const String varsayilanSonraBaslik = 'Teşekkürler';
  static const String varsayilanSonraIcerik =
      'Merhaba {musteri}, {isletme} randevunuz için teşekkür ederiz. Görüşleriniz bizim için değerli.';

  static const List<int> onceDakikaSecenekleri = [15, 30, 60, 120, 180, 1440];
  static const List<int> sonraDakikaSecenekleri = [15, 30, 60, 120, 180];

  static String dakikaEtiketi(int dk) {
    if (dk >= 1440) return '${dk ~/ 1440} gün';
    if (dk >= 60) {
      final sa = dk ~/ 60;
      final kalan = dk % 60;
      return kalan == 0 ? '$sa saat' : '$sa sa $kalan dk';
    }
    return '$dk dk';
  }

  static String doldur(
    String sablon, {
    required String musteri,
    required String isletme,
    required String tarih,
    required String saat,
    required String hizmet,
    String personel = '',
    String neden = '',
  }) {
    final nedenYazi = neden.trim().isEmpty ? 'belirtilmedi' : neden.trim();
    return sablon
        .replaceAll('{musteri}', musteri)
        .replaceAll('{isletme}', isletme)
        .replaceAll('{tarih}', tarih)
        .replaceAll('{saat}', saat)
        .replaceAll('{hizmet}', hizmet)
        .replaceAll('{personel}', personel.isEmpty ? '-' : personel)
        .replaceAll('{neden}', nedenYazi);
  }

  static String randevudanDoldur(String sablon, RandevuModeli r, {String? isletmeAdi, String? neden}) {
    return doldur(
      sablon,
      musteri: r.kullaniciAd,
      isletme: isletmeAdi ?? r.esnafAdi,
      tarih: DateFormat('dd.MM.yyyy').format(r.tarih),
      saat: r.saat,
      hizmet: r.hizmetAdi,
      personel: r.calisanPersonel ?? '',
      neden: neden ?? r.iptalNedeni ?? '',
    );
  }

  static String onceBaslik(EsnafModeli e) =>
      (e.hatirlatmaOnceBaslik?.trim().isNotEmpty == true)
          ? e.hatirlatmaOnceBaslik!.trim()
          : varsayilanOnceBaslik;

  static String onceIcerik(EsnafModeli e) =>
      (e.hatirlatmaOnceSablon?.trim().isNotEmpty == true)
          ? e.hatirlatmaOnceSablon!.trim()
          : varsayilanOnceIcerik;

  static String sonraBaslik(EsnafModeli e) =>
      (e.hatirlatmaSonraBaslik?.trim().isNotEmpty == true)
          ? e.hatirlatmaSonraBaslik!.trim()
          : varsayilanSonraBaslik;

  static String sonraIcerik(EsnafModeli e) =>
      (e.hatirlatmaSonraSablon?.trim().isNotEmpty == true)
          ? e.hatirlatmaSonraSablon!.trim()
          : varsayilanSonraIcerik;

  static const String varsayilanOnayBaslik = 'Randevunuz onaylandı';
  static const String varsayilanOnayIcerik =
      'Merhaba {musteri}, {isletme} randevunuz onaylandı. {tarih} saat {saat}. Hizmet: {hizmet}.';

  static const String varsayilanRedBaslik = 'Randevunuz reddedildi';
  static const String varsayilanRedIcerik =
      'Merhaba {musteri}, {isletme} randevunuz reddedildi. {tarih} saat {saat}. Neden: {neden}.';

  static String onayBaslik(EsnafModeli e) =>
      (e.onayBaslik?.trim().isNotEmpty == true) ? e.onayBaslik!.trim() : varsayilanOnayBaslik;

  static String onayIcerik(EsnafModeli e) =>
      (e.onaySablon?.trim().isNotEmpty == true) ? e.onaySablon!.trim() : varsayilanOnayIcerik;

  static String redBaslik(EsnafModeli e) =>
      (e.redBaslik?.trim().isNotEmpty == true) ? e.redBaslik!.trim() : varsayilanRedBaslik;

  static String redIcerik(EsnafModeli e) =>
      (e.redSablon?.trim().isNotEmpty == true) ? e.redSablon!.trim() : varsayilanRedIcerik;

  static bool ortakEsnafMi(String? kategori) => kategori != 'Taksi' && kategori != 'Araç Kiralama';

  static String whatsappUrl(String telefon, String metin) {
    String temiz = telefon.replaceAll(RegExp(r'[^0-9]'), '');
    if (temiz.startsWith('0')) temiz = temiz.substring(1);
    if (temiz.length == 10) temiz = '90$temiz';
    return 'https://wa.me/$temiz?text=${Uri.encodeComponent(metin)}';
  }
}
