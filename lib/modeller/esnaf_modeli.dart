import 'package:cloud_firestore/cloud_firestore.dart';

class EsnafModeli {
  final String id;
  final String isletmeAdi;
  final String kategori;
  final String telefon;
  final String il;
  final String ilce;
  final String adres;
  final GeoPoint konum;
  final Timestamp? kayitTarihi;

  EsnafModeli({
    required this.id,
    required this.isletmeAdi,
    required this.kategori,
    required this.telefon,
    required this.il,
    required this.ilce,
    required this.adres,
    required this.konum,
    this.kayitTarihi,
  });

  // Firestore verisini modele dönüştürür
  factory EsnafModeli.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EsnafModeli(
      id: doc.id,
      isletmeAdi: data['isletmeAdi'] ?? '',
      kategori: data['kategori'] ?? '',
      telefon: data['telefon'] ?? '',
      il: data['il'] ?? '',
      ilce: data['ilce'] ?? '',
      adres: data['adres'] ?? '',
      konum: data['konum'] ?? const GeoPoint(0, 0),
      kayitTarihi: data['kayitTarihi'] as Timestamp?,
    );
  }

  // Modeli Firestore'a gönderilecek Map yapısına dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'isletmeAdi': isletmeAdi,
      'kategori': kategori,
      'telefon': telefon,
      'il': il,
      'ilce': ilce,
      'adres': adres,
      'konum': konum,
      'kayitTarihi': kayitTarihi ?? FieldValue.serverTimestamp(),
    };
  }
}
