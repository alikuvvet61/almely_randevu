import 'package:cloud_firestore/cloud_firestore.dart';

class RandevuModeli {
  final String id;
  final String esnafId;
  final String esnafAdi;
  final String esnafTel;
  final String kullaniciAd;
  final String kullaniciTel;
  final DateTime tarih;
  final String saat;
  final int sure; // Randevunun süresi (dakika)
  final String hizmetAdi; // Seçilen hizmet
  final String durum; // 'Beklemede', 'Onaylandı', 'Reddedildi', 'İptal Edildi'
  final String? randevuKanali; // Örn: Koltuk 1, Oda 2
  final String? calisanPersonel; // Örn: Ahmet Yılmaz
  final String? iptalNedeni;
  final bool puanlandi;

  RandevuModeli({
    required this.id,
    required this.esnafId,
    required this.esnafAdi,
    required this.esnafTel,
    required this.kullaniciAd,
    required this.kullaniciTel,
    required this.tarih,
    required this.saat,
    required this.sure,
    required this.hizmetAdi,
    this.durum = 'Beklemede',
    this.randevuKanali,
    this.calisanPersonel,
    this.iptalNedeni,
    this.puanlandi = false,
  });

  factory RandevuModeli.fromFirestore(DocumentSnapshot doc) {
    return RandevuModeli.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory RandevuModeli.fromMap(Map<String, dynamic> data, String id) {
    return RandevuModeli(
      id: id,
      esnafId: data['esnafId'] ?? '',
      esnafAdi: data['esnafAdi'] ?? '',
      esnafTel: data['esnafTel'] ?? '',
      kullaniciAd: data['kullaniciAd'] ?? '',
      kullaniciTel: data['kullaniciTel'] ?? '',
      tarih: (data['tarih'] as Timestamp).toDate(),
      saat: data['saat'] ?? '',
      sure: data['sure'] ?? 30,
      hizmetAdi: data['hizmetAdi'] ?? '',
      durum: data['durum'] ?? 'Beklemede',
      randevuKanali: data['randevu_kanali'],
      calisanPersonel: data['calisan_personel'],
      iptalNedeni: data['iptalNedeni'],
      puanlandi: data['puanlandi'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'esnafId': esnafId,
      'esnafAdi': esnafAdi,
      'esnafTel': esnafTel,
      'kullaniciAd': kullaniciAd,
      'kullaniciTel': kullaniciTel,
      'tarih': Timestamp.fromDate(tarih),
      'saat': saat,
      'sure': sure,
      'hizmetAdi': hizmetAdi,
      'durum': durum,
      'randevu_kanali': randevuKanali,
      'calisan_personel': calisanPersonel,
      'iptalNedeni': iptalNedeni,
      'puanlandi': puanlandi,
    };
  }
}
