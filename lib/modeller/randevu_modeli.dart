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
  final int sure; 
  final String hizmetAdi; 
  final String durum; 
  final String? randevuKanali; 
  final String? calisanPersonel; 
  final String? iptalNedeni;
  final String? seriId; 
  final bool puanlandi;
  final DateTime? olusturulmaTarihi;
  final DateTime? guncellemeTarihi;
  final DateTime? reddedilmeTarihi;
  final bool akilliTakipAktif;
  final DateTime? bildirimZamani;
  final int uzatmaSuresi; 
  final String? gecikmeBildirimId; 
  final String? uzatmaBildirimId; 

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
    this.seriId,
    this.puanlandi = false,
    this.olusturulmaTarihi,
    this.guncellemeTarihi,
    this.reddedilmeTarihi,
    this.akilliTakipAktif = false,
    this.bildirimZamani,
    this.uzatmaSuresi = 0,
    this.gecikmeBildirimId,
    this.uzatmaBildirimId,
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
      seriId: data['seriId'],
      puanlandi: data['puanlandi'] ?? false,
      olusturulmaTarihi: data['olusturulmaTarihi'] != null 
          ? (data['olusturulmaTarihi'] as Timestamp).toDate() 
          : null,
      guncellemeTarihi: data['guncellemeTarihi'] != null
          ? (data['guncellemeTarihi'] as Timestamp).toDate()
          : null,
      reddedilmeTarihi: data['reddedilmeTarihi'] != null
          ? (data['reddedilmeTarihi'] as Timestamp).toDate()
          : null,
      akilliTakipAktif: data['akilliTakipAktif'] ?? false,
      bildirimZamani: data['bildirimZamani'] != null 
          ? (data['bildirimZamani'] as Timestamp).toDate() 
          : null,
      uzatmaSuresi: data['uzatmaSuresi'] ?? 0,
      gecikmeBildirimId: data['gecikmeBildirimId'],
      uzatmaBildirimId: data['uzatmaBildirimId'],
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
      'seriId': seriId,
      'puanlandi': puanlandi,
      'olusturulmaTarihi': olusturulmaTarihi != null 
          ? Timestamp.fromDate(olusturulmaTarihi!) 
          : FieldValue.serverTimestamp(),
      'akilliTakipAktif': akilliTakipAktif,
      'bildirimZamani': bildirimZamani != null 
          ? Timestamp.fromDate(bildirimZamani!) 
          : null,
      'guncellemeTarihi': guncellemeTarihi != null ? Timestamp.fromDate(guncellemeTarihi!) : null,
      'reddedilmeTarihi': reddedilmeTarihi != null ? Timestamp.fromDate(reddedilmeTarihi!) : null,
      'uzatmaSuresi': uzatmaSuresi,
      'gecikmeBildirimId': gecikmeBildirimId,
      'uzatmaBildirimId': uzatmaBildirimId,
    };
  }

  RandevuModeli copyWith({
    String? id,
    String? esnafId,
    String? esnafAdi,
    String? esnafTel,
    String? kullaniciAd,
    String? kullaniciTel,
    DateTime? tarih,
    String? saat,
    int? sure,
    String? hizmetAdi,
    String? durum,
    String? randevuKanali,
    String? calisanPersonel,
    String? iptalNedeni,
    String? seriId,
    bool? puanlandi,
    DateTime? olusturulmaTarihi,
    DateTime? guncellemeTarihi,
    DateTime? reddedilmeTarihi,
    bool? akilliTakipAktif,
    DateTime? bildirimZamani,
    int? uzatmaSuresi,
    String? gecikmeBildirimId,
    String? uzatmaBildirimId,
  }) {
    return RandevuModeli(
      id: id ?? this.id,
      esnafId: esnafId ?? this.esnafId,
      esnafAdi: esnafAdi ?? this.esnafAdi,
      esnafTel: esnafTel ?? this.esnafTel,
      kullaniciAd: kullaniciAd ?? this.kullaniciAd,
      kullaniciTel: kullaniciTel ?? this.kullaniciTel,
      tarih: tarih ?? this.tarih,
      saat: saat ?? this.saat,
      sure: sure ?? this.sure,
      hizmetAdi: hizmetAdi ?? this.hizmetAdi,
      durum: durum ?? this.durum,
      randevuKanali: randevuKanali ?? this.randevuKanali,
      calisanPersonel: calisanPersonel ?? this.calisanPersonel,
      iptalNedeni: iptalNedeni ?? this.iptalNedeni,
      seriId: seriId ?? this.seriId,
      puanlandi: puanlandi ?? this.puanlandi,
      olusturulmaTarihi: olusturulmaTarihi ?? this.olusturulmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      reddedilmeTarihi: reddedilmeTarihi ?? this.reddedilmeTarihi,
      akilliTakipAktif: akilliTakipAktif ?? this.akilliTakipAktif,
      bildirimZamani: bildirimZamani ?? this.bildirimZamani,
      uzatmaSuresi: uzatmaSuresi ?? this.uzatmaSuresi,
      gecikmeBildirimId: gecikmeBildirimId ?? this.gecikmeBildirimId,
      uzatmaBildirimId: uzatmaBildirimId ?? this.uzatmaBildirimId,
    );
  }
}
