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
  final List<dynamic>? aktifGunler; 
  final List<dynamic>? araclar; // Taksi durağı araçları
  final String randevuOnayModu; // 'Otomatik' veya 'Manuel'
  final bool ayniGunRandevuEngelle; // Aynı gün birden fazla randevu engelleme
  final bool slotAralikliGoster; // Randevu saatlerini aralık (10:00-11:00) şeklinde göster
  final bool personelSecimiZorunlu; // Randevu alırken personel seçimi zorunlu mu?
  final bool randevularPersonelAdinaAlinsin; // Personel seçildiğinde personelin kanalı kullanılsın

  final double puan; // Ortalama Puan
  final int yorumSayisi; // Toplam Yorum Sayısı

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
    this.araclar,
    this.randevuOnayModu = 'Manuel',
    this.ayniGunRandevuEngelle = false,
    this.slotAralikliGoster = false,
    this.personelSecimiZorunlu = false,
    this.randevularPersonelAdinaAlinsin = false,
    this.puan = 0.0,
    this.yorumSayisi = 0,
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
      aktifGunler: data['aktifGunler'] ?? [],
      araclar: data['araclar'] ?? [],
      randevuOnayModu: data['randevuOnayModu'] ?? 'Manuel',
      ayniGunRandevuEngelle: data['ayniGunRandevuEngelle'] ?? false,
      slotAralikliGoster: data['slotAralikliGoster'] ?? false,
      personelSecimiZorunlu: data['personelSecimiZorunlu'] ?? false,
      randevularPersonelAdinaAlinsin: data['randevularPersonelAdinaAlinsin'] ?? false,
      puan: (data['puan'] ?? 0.0).toDouble(),
      yorumSayisi: data['yorumSayisi'] ?? 0,
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
      'araclar': araclar,
      'randevuOnayModu': randevuOnayModu,
      'ayniGunRandevuEngelle': ayniGunRandevuEngelle,
      'slotAralikliGoster': slotAralikliGoster,
      'personelSecimiZorunlu': personelSecimiZorunlu,
      'randevularPersonelAdinaAlinsin': randevularPersonelAdinaAlinsin,
      'puan': puan,
      'yorumSayisi': yorumSayisi,
    };
  }

  EsnafModeli copyWith({
    String? id,
    String? isletmeAdi,
    String? kategori,
    String? telefon,
    String? email,
    String? il,
    String? ilce,
    String? adres,
    GeoPoint? konum,
    Timestamp? kayitTarihi,
    Map<String, dynamic>? calismaSaatleri,
    List<dynamic>? hizmetler,
    List<dynamic>? kanallar,
    List<dynamic>? personeller,
    List<dynamic>? aktifGunler,
    List<dynamic>? araclar,
    String? randevuOnayModu,
    bool? ayniGunRandevuEngelle,
    bool? slotAralikliGoster,
    bool? personelSecimiZorunlu,
    bool? randevularPersonelAdinaAlinsin,
    double? puan,
    int? yorumSayisi,
  }) {
    return EsnafModeli(
      id: id ?? this.id,
      isletmeAdi: isletmeAdi ?? this.isletmeAdi,
      kategori: kategori ?? this.kategori,
      telefon: telefon ?? this.telefon,
      email: email ?? this.email,
      il: il ?? this.il,
      ilce: ilce ?? this.ilce,
      adres: adres ?? this.adres,
      konum: konum ?? this.konum,
      kayitTarihi: kayitTarihi ?? this.kayitTarihi,
      calismaSaatleri: calismaSaatleri ?? this.calismaSaatleri,
      hizmetler: hizmetler ?? this.hizmetler,
      kanallar: kanallar ?? this.kanallar,
      personeller: personeller ?? this.personeller,
      aktifGunler: aktifGunler ?? this.aktifGunler,
      araclar: araclar ?? this.araclar,
      randevuOnayModu: randevuOnayModu ?? this.randevuOnayModu,
      ayniGunRandevuEngelle: ayniGunRandevuEngelle ?? this.ayniGunRandevuEngelle,
      slotAralikliGoster: slotAralikliGoster ?? this.slotAralikliGoster,
      personelSecimiZorunlu: personelSecimiZorunlu ?? this.personelSecimiZorunlu,
      randevularPersonelAdinaAlinsin: randevularPersonelAdinaAlinsin ?? this.randevularPersonelAdinaAlinsin,
      puan: puan ?? this.puan,
      yorumSayisi: yorumSayisi ?? this.yorumSayisi,
    );
  }
}
