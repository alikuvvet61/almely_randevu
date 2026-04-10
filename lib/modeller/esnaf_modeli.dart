import 'package:cloud_firestore/cloud_firestore.dart';

class EsnafModeli {
  final String id;
  final String isletmeAdi;
  final String kategori;
  final String telefon;
  final String email; // Esnafın panele girişi için
  final String il;
  final String ilce;
  final String adres;
  final GeoPoint konum;
  final Timestamp? kayitTarihi;

  // --- YENİ EKLENEN RANDEVU ALANLARI ---
  final Map<String, dynamic>? calismaSaatleri; // Örn: {"acilis": "09:00", "kapanis": "19:00", "aralik": 30}
  final List<dynamic>? hizmetler; // Örn: [{"isim": "Saç Kesimi", "fiyat": 200, "sure": 30}]

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
      // Yeni alanlar
      calismaSaatleri: data['calismaSaatleri'],
      hizmetler: data['hizmetler'] ?? [],
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
      // Yeni alanlar
      'calismaSaatleri': calismaSaatleri,
      'hizmetler': hizmetler,
    };
  }
}