import 'package:cloud_firestore/cloud_firestore.dart';

class RandevuModeli {
  final String id;
  final String esnafId;
  final String esnafAdi;
  final String kullaniciAd;
  final String kullaniciTel;
  final DateTime tarih;
  final String saat;
  final String durum; // 'Beklemede', 'Onaylandı', 'Reddedildi'

  RandevuModeli({
    required this.id,
    required this.esnafId,
    required this.esnafAdi,
    required this.kullaniciAd,
    required this.kullaniciTel,
    required this.tarih,
    required this.saat,
    this.durum = 'Beklemede',
  });

  factory RandevuModeli.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RandevuModeli(
      id: doc.id,
      esnafId: data['esnafId'] ?? '',
      esnafAdi: data['esnafAdi'] ?? '',
      kullaniciAd: data['kullaniciAd'] ?? '',
      kullaniciTel: data['kullaniciTel'] ?? '',
      tarih: (data['tarih'] as Timestamp).toDate(),
      saat: data['saat'] ?? '',
      durum: data['durum'] ?? 'Beklemede',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'esnafId': esnafId,
      'esnafAdi': esnafAdi,
      'kullaniciAd': kullaniciAd,
      'kullaniciTel': kullaniciTel,
      'tarih': Timestamp.fromDate(tarih),
      'saat': saat,
      'durum': durum,
    };
  }
}
