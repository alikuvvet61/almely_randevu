import 'package:cloud_firestore/cloud_firestore.dart';

class EsnafModeli {
  final String id;
  final String isletmeAdi;
  final String kategori;
  final String telefon;
  final String email;
  final String il;
  final String ilce;
  final String adres;
  final GeoPoint konum;
  final Timestamp? kayitTarihi;

  final Map<String, dynamic>? calismaSaatleri;
  final List<dynamic>? hizmetler;
  final List<dynamic>? kanallar;
  final List<dynamic>? personeller;
  final List<dynamic>? aktifGunler; // Sadece "Oluştur" denilen günler buraya eklenir

  EsnafModeli({
    required this.id,
    required this.isletmeAdi,
    required this.kategori,
    required this.telefon,
    required this.email,
    required this.il,
    required this.ilce,
    required this.adres,
    required this.konum,
    this.kayitTarihi,
    this.calismaSaatleri,
    this.hizmetler,
    this.kanallar,
    this.personeller,
    this.aktifGunler,
  });

  factory EsnafModeli.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EsnafModeli(
      id: doc.id,
      isletmeAdi: data['isletmeAdi'] ?? '',
      kategori: data['kategori'] ?? '',
      telefon: data['telefon'] ?? '',
      email: data['email'] ?? '',
      il: data['il'] ?? '',
      ilce: data['ilce'] ?? '',
      adres: data['adres'] ?? '',
      konum: data['konum'] ?? const GeoPoint(0, 0),
      kayitTarihi: data['kayitTarihi'] as Timestamp?,
      calismaSaatleri: data['calismaSaatleri'],
      hizmetler: data['hizmetler'] ?? [],
      kanallar: data['kanallar'] ?? [],
      personeller: data['personeller'] ?? [],
      // Sadece aktifGunler varsa alıyoruz, kapaliGunler fallback'ini sildik.
      aktifGunler: data['aktifGunler'] ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isletmeAdi': isletmeAdi,
      'kategori': kategori,
      'telefon': telefon,
      'email': email,
      'il': il,
      'ilce': ilce,
      'adres': adres,
      'konum': konum,
      'kayitTarihi': kayitTarihi ?? FieldValue.serverTimestamp(),
      'calismaSaatleri': calismaSaatleri,
      'hizmetler': hizmetler,
      'kanallar': kanallar,
      'personeller': personeller,
      'aktifGunler': aktifGunler,
    };
  }
}
