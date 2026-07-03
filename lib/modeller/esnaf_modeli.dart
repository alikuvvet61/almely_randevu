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
  final List<Map<String, dynamic>> araclar; // Taksi durağı araçları
  final int? nobetSirasi; // Nöbet sıralaması
  final String? nobetBaslangic; // Nöbet başlangıç saati
  final String? nobetBitis; // Nöbet bitiş saati
  final String? whatsapp; // WhatsApp hattı
  final String? telefonRandevu; // Randevu için telefon hattı
  final String randevuOnayModu; // 'Otomatik' veya 'Manuel'
  final bool ayniGunRandevuEngelle; // Aynı gün birden fazla randevu engelleme
  final bool slotAralikliGoster; // Randevu saatlerini aralık (10:00-11:00) şeklinde göster
  final bool personelSecimiZorunlu; // Randevu alırken personel seçimi zorunlu mu?
  final bool randevularPersonelAdinaAlinsin; // Personel seçildiğinde personelin kanalı kullanılsın
  final bool aracOdakliSistem; // Taksi için araç odaklı sistem (randevular plakaya alınır)
  final bool istirahatliAraclariGizle; // İstirahatte olan araçlar listede gizlensin mi?
  final bool randevuAlinmasin; // İşletmeye randevu alınmasın mı?
  final double konumDogrulamaMesafesi; // Taksi sıraya giriş için konum doğrulama mesafesi (metre)
  final int bakimTemizlikSuresi; // Araç kiralama sonrası bakım ve temizlik süresi (dakika)
  final bool bakimSurecindeRandevuAlinsin; // Bakım süresindeki araca randevu alınabilsin mi?
  final bool akilliTakipModu; // Kiralama bitimine yakın bildirim ve otomatik uzatma sistemi
  final int akilliTakipSuresi; // Kiralama bitimine kaç dakika kala bildirim gitsin?
  final double saatlikUzatmaUcreti; // Akıllı takip modunda 2 saatlik uzatma için saatlik ücret
  final bool ajandayiKendimAyarlayacagim; // Randevu ajandasını manuel mi yönetecek? (Manuel vs Canlı Yapı)
  final int maksimumRandevuGunu; // Müşterinin kaç gün ileriye randevu alabileceği
  final int minimumRandevuSuresi; // Randevu alırken seçilebilecek minimum süre (dakika)

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
    this.araclar = const [],
    this.nobetSirasi,
    this.nobetBaslangic,
    this.nobetBitis,
    this.whatsapp,
    this.telefonRandevu,
    this.randevuOnayModu = 'Manuel',
    this.ayniGunRandevuEngelle = false,
    this.slotAralikliGoster = false,
    this.personelSecimiZorunlu = false,
    this.randevularPersonelAdinaAlinsin = false,
    this.aracOdakliSistem = false,
    this.istirahatliAraclariGizle = true,
    this.randevuAlinmasin = false,
    this.konumDogrulamaMesafesi = 10.0,
    this.bakimTemizlikSuresi = 0,
    this.bakimSurecindeRandevuAlinsin = false,
    this.akilliTakipModu = false,
    this.akilliTakipSuresi = 120,
    this.saatlikUzatmaUcreti = 0.0,
    this.minimumRandevuSuresi = 60, // Varsayılan 1 saat (60 dk)
    this.ajandayiKendimAyarlayacagim = true, // Varsayılan olarak mevcut esnaflar için manuel kalsın
    this.maksimumRandevuGunu = 30, // Varsayılan 30 gün
    this.puan = 0.0,
    this.yorumSayisi = 0,
  });

  factory EsnafModeli.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EsnafModeli.fromMap(data, doc.id);
  }

  factory EsnafModeli.fromMap(Map<String, dynamic> data, String id) {
    return EsnafModeli(
      id: id,
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
      araclar: List<Map<String, dynamic>>.from(data['araclar'] ?? []).map((item) {
        final mapItem = Map<String, dynamic>.from(item);
        mapItem.putIfAbsent('nobetSirasi', () => null);
        return mapItem;
      }).toList(),
      nobetSirasi: data['nobetSirasi'],
      nobetBaslangic: data['nobetBaslangic'],
      nobetBitis: data['nobetBitis'],
      whatsapp: data['whatsapp'],
      telefonRandevu: data['telefonRandevu'],
      randevuOnayModu: data['randevuOnayModu'] ?? 'Manuel',
      ayniGunRandevuEngelle: data['ayniGunRandevuEngelle'] ?? false,
      slotAralikliGoster: data['slotAralikliGoster'] ?? false,
      personelSecimiZorunlu: data['personelSecimiZorunlu'] ?? false,
      randevularPersonelAdinaAlinsin: data['randevularPersonelAdinaAlinsin'] ?? false,
      aracOdakliSistem: data['aracOdakliSistem'] ?? false,
      istirahatliAraclariGizle: data['istirahatliAraclariGizle'] ?? true,
      randevuAlinmasin: data['randevuAlinmasin'] ?? false,
      konumDogrulamaMesafesi: (data['konumDogrulamaMesafesi'] ?? 10.0).toDouble(),
      bakimTemizlikSuresi: data['bakimTemizlikSuresi'] ?? 0,
      bakimSurecindeRandevuAlinsin: data['bakimSurecindeRandevuAlinsin'] ?? false,
      akilliTakipModu: data['akilliTakipModu'] ?? false,
      akilliTakipSuresi: data['akilliTakipSuresi'] ?? 120,
      saatlikUzatmaUcreti: (data['saatlikUzatmaUcreti'] ?? 0.0).toDouble(),
      minimumRandevuSuresi: data['minimumRandevuSuresi'] ?? 60,
      ajandayiKendimAyarlayacagim: data['ajandayiKendimAyarlayacagim'] ?? true,
      maksimumRandevuGunu: data['maksimumRandevuGunu'] ?? 30,
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
      'nobetSirasi': nobetSirasi,
      'nobetBaslangic': nobetBaslangic,
      'nobetBitis': nobetBitis,
      'whatsapp': whatsapp,
      'telefonRandevu': telefonRandevu,
      'randevuOnayModu': randevuOnayModu,
      'ayniGunRandevuEngelle': ayniGunRandevuEngelle,
      'slotAralikliGoster': slotAralikliGoster,
      'personelSecimiZorunlu': personelSecimiZorunlu,
      'randevularPersonelAdinaAlinsin': randevularPersonelAdinaAlinsin,
      'aracOdakliSistem': aracOdakliSistem,
      'istirahatliAraclariGizle': istirahatliAraclariGizle,
      'randevuAlinmasin': randevuAlinmasin,
      'konumDogrulamaMesafesi': konumDogrulamaMesafesi,
      'bakimTemizlikSuresi': bakimTemizlikSuresi,
      'bakimSurecindeRandevuAlinsin': bakimSurecindeRandevuAlinsin,
      'akilliTakipModu': akilliTakipModu,
      'akilliTakipSuresi': akilliTakipSuresi,
      'saatlikUzatmaUcreti': saatlikUzatmaUcreti,
      'minimumRandevuSuresi': minimumRandevuSuresi,
      'ajandayiKendimAyarlayacagim': ajandayiKendimAyarlayacagim,
      'maksimumRandevuGunu': maksimumRandevuGunu,
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
    List<Map<String, dynamic>>? araclar,
    int? nobetSirasi,
    String? nobetBaslangic,
    String? nobetBitis,
    String? whatsapp,
    String? telefonRandevu,
    String? randevuOnayModu,
    bool? ayniGunRandevuEngelle,
    bool? slotAralikliGoster,
    bool? personelSecimiZorunlu,
    bool? randevularPersonelAdinaAlinsin,
    bool? aracOdakliSistem,
    bool? istirahatliAraclariGizle,
    bool? randevuAlinmasin,
    double? konumDogrulamaMesafesi,
    int? bakimTemizlikSuresi,
    bool? bakimSurecindeRandevuAlinsin,
    bool? akilliTakipModu,
    int? akilliTakipSuresi,
    double? saatlikUzatmaUcreti,
    int? minimumRandevuSuresi,
    bool? ajandayiKendimAyarlayacagim,
    int? maksimumRandevuGunu,
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
      nobetSirasi: nobetSirasi ?? this.nobetSirasi,
      nobetBaslangic: nobetBaslangic ?? this.nobetBaslangic,
      nobetBitis: nobetBitis ?? this.nobetBitis,
      whatsapp: whatsapp ?? this.whatsapp,
      telefonRandevu: telefonRandevu ?? this.telefonRandevu,
      randevuOnayModu: randevuOnayModu ?? this.randevuOnayModu,
      ayniGunRandevuEngelle: ayniGunRandevuEngelle ?? this.ayniGunRandevuEngelle,
      slotAralikliGoster: slotAralikliGoster ?? this.slotAralikliGoster,
      personelSecimiZorunlu: personelSecimiZorunlu ?? this.personelSecimiZorunlu,
      randevularPersonelAdinaAlinsin: randevularPersonelAdinaAlinsin ?? this.randevularPersonelAdinaAlinsin,
      aracOdakliSistem: aracOdakliSistem ?? this.aracOdakliSistem,
      istirahatliAraclariGizle: istirahatliAraclariGizle ?? this.istirahatliAraclariGizle,
      randevuAlinmasin: randevuAlinmasin ?? this.randevuAlinmasin,
      konumDogrulamaMesafesi: konumDogrulamaMesafesi ?? this.konumDogrulamaMesafesi,
      bakimTemizlikSuresi: bakimTemizlikSuresi ?? this.bakimTemizlikSuresi,
      bakimSurecindeRandevuAlinsin: bakimSurecindeRandevuAlinsin ?? this.bakimSurecindeRandevuAlinsin,
      akilliTakipModu: akilliTakipModu ?? this.akilliTakipModu,
      akilliTakipSuresi: akilliTakipSuresi ?? this.akilliTakipSuresi,
      saatlikUzatmaUcreti: saatlikUzatmaUcreti ?? this.saatlikUzatmaUcreti,
      minimumRandevuSuresi: minimumRandevuSuresi ?? this.minimumRandevuSuresi,
      ajandayiKendimAyarlayacagim: ajandayiKendimAyarlayacagim ?? this.ajandayiKendimAyarlayacagim,
      maksimumRandevuGunu: maksimumRandevuGunu ?? this.maksimumRandevuGunu,
      puan: puan ?? this.puan,
      yorumSayisi: yorumSayisi ?? this.yorumSayisi,
    );
  }
}
