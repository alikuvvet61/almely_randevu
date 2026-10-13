import 'package:cloud_firestore/cloud_firestore.dart';

class BeklemeListesiModeli {
  final String id;
  final String esnafId;
  final String esnafAdi;
  final DateTime tarih;
  final String saat;
  final int sureDk;
  final String? randevuKanali;
  final String? calisanPersonel;
  final String kullaniciAd;
  final String kullaniciTel;
  final String? hizmetAdi;
  final String durum; // bekliyor | bildirildi | alindi | iptal
  final DateTime? olusturmaTarihi;
  final DateTime? bildirimTarihi;

  BeklemeListesiModeli({
    required this.id,
    required this.esnafId,
    required this.esnafAdi,
    required this.tarih,
    required this.saat,
    this.sureDk = 30,
    this.randevuKanali,
    this.calisanPersonel,
    required this.kullaniciAd,
    required this.kullaniciTel,
    this.hizmetAdi,
    this.durum = 'bekliyor',
    this.olusturmaTarihi,
    this.bildirimTarihi,
  });

  factory BeklemeListesiModeli.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BeklemeListesiModeli.fromMap(data, doc.id);
  }

  factory BeklemeListesiModeli.fromMap(Map<String, dynamic> data, String id) {
    return BeklemeListesiModeli(
      id: id,
      esnafId: data['esnafId'] ?? '',
      esnafAdi: data['esnafAdi'] ?? '',
      tarih: (data['tarih'] as Timestamp).toDate(),
      saat: data['saat'] ?? '',
      sureDk: data['sureDk'] ?? 30,
      randevuKanali: data['randevuKanali'],
      calisanPersonel: data['calisanPersonel'],
      kullaniciAd: data['kullaniciAd'] ?? '',
      kullaniciTel: data['kullaniciTel'] ?? '',
      hizmetAdi: data['hizmetAdi'],
      durum: data['durum'] ?? 'bekliyor',
      olusturmaTarihi: data['olusturmaTarihi'] != null
          ? (data['olusturmaTarihi'] as Timestamp).toDate()
          : null,
      bildirimTarihi: data['bildirimTarihi'] != null
          ? (data['bildirimTarihi'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'esnafId': esnafId,
      'esnafAdi': esnafAdi,
      'tarih': Timestamp.fromDate(DateTime(tarih.year, tarih.month, tarih.day)),
      'saat': saat,
      'sureDk': sureDk,
      'randevuKanali': randevuKanali,
      'calisanPersonel': calisanPersonel,
      'kullaniciAd': kullaniciAd,
      'kullaniciTel': kullaniciTel,
      'hizmetAdi': hizmetAdi,
      'durum': durum,
      'olusturmaTarihi': olusturmaTarihi != null
          ? Timestamp.fromDate(olusturmaTarihi!)
          : FieldValue.serverTimestamp(),
      'bildirimTarihi': bildirimTarihi != null ? Timestamp.fromDate(bildirimTarihi!) : null,
    };
  }

  BeklemeListesiModeli copyWith({
    String? kullaniciTel,
    String? durum,
  }) {
    return BeklemeListesiModeli(
      id: id,
      esnafId: esnafId,
      esnafAdi: esnafAdi,
      tarih: tarih,
      saat: saat,
      sureDk: sureDk,
      randevuKanali: randevuKanali,
      calisanPersonel: calisanPersonel,
      kullaniciAd: kullaniciAd,
      kullaniciTel: kullaniciTel ?? this.kullaniciTel,
      hizmetAdi: hizmetAdi,
      durum: durum ?? this.durum,
      olusturmaTarihi: olusturmaTarihi,
      bildirimTarihi: bildirimTarihi,
    );
  }
}
