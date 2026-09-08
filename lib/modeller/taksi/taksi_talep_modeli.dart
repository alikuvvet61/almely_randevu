import 'package:cloud_firestore/cloud_firestore.dart';

class TaksiTalepModeli {
  final String id;
  final String esnafId;
  final String kullaniciAd;
  final String kullaniciTel;
  final String nereden;
  final String nereye;
  final GeoPoint? konum;
  final String durum;
  final DateTime olusturulmaTarihi;

  const TaksiTalepModeli({
    required this.id,
    required this.esnafId,
    required this.kullaniciAd,
    required this.kullaniciTel,
    required this.nereden,
    required this.nereye,
    this.konum,
    this.durum = 'Bekliyor',
    required this.olusturulmaTarihi,
  });

  factory TaksiTalepModeli.fromMap(Map<String, dynamic> data, String id) {
    return TaksiTalepModeli(
      id: id,
      esnafId: data['esnafId'] ?? '',
      kullaniciAd: data['kullaniciAd'] ?? '',
      kullaniciTel: data['kullaniciTel'] ?? '',
      nereden: data['nereden'] ?? '',
      nereye: data['nereye'] ?? '',
      konum: data['konum'] is GeoPoint ? data['konum'] as GeoPoint : null,
      durum: data['durum'] ?? 'Bekliyor',
      olusturulmaTarihi: data['olusturulmaTarihi'] is Timestamp
          ? (data['olusturulmaTarihi'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'esnafId': esnafId,
      'kullaniciAd': kullaniciAd,
      'kullaniciTel': kullaniciTel,
      'nereden': nereden,
      'nereye': nereye,
      'konum': konum,
      'durum': durum,
      'olusturulmaTarihi': Timestamp.fromDate(olusturulmaTarihi),
    };
  }
}
