import 'package:cloud_firestore/cloud_firestore.dart';

/// Seans hakkı satılan kategoriler. Taksi, kiralama ve tek etkinlikler dışarıda.
class HizmetPaketi {
  static const Set<String> uygunKategoriler = {
    'Kuaför',
    'Berber',
    'Diyetisyen',
    'Fizyoterapi ve Rehabilitasyon',
    'Psikolog',
    'Özel Ders',
    'Pet Kuaför',
    'Veteriner',
    'Oto Yıkama',
  };

  static bool uygunMu(String? kategori) => uygunKategoriler.contains(kategori);

  static bool diyetisyenMi(String? kategori) => kategori == 'Diyetisyen';

  static bool ozelDersMi(String? kategori) => kategori == 'Özel Ders';

  /// Ekranda görünen hak birimi. Kayıttaki alan adı seans kalır.
  static String hakBirimi(String? kategori) => ozelDersMi(kategori) ? 'ders' : 'seans';

  /// Hizmet sürelerinin ortak böleni. Ön görüşme 30, ders 60 ise 30.
  static int idealSlot(List<dynamic>? hizmetler) {
    if (hizmetler == null || hizmetler.isEmpty) return 30;
    final sureler = hizmetler
        .map((h) => h is Map ? int.tryParse('${h['sure']}') ?? 0 : 0)
        .where((s) => s > 0)
        .toList();
    if (sureler.isEmpty) return 30;
    int gcd(int a, int b) {
      while (b != 0) {
        final t = b;
        b = a % b;
        a = t;
      }
      return a;
    }
    var sonuc = sureler.first;
    for (var i = 1; i < sureler.length; i++) {
      sonuc = gcd(sonuc, sureler[i]);
    }
    if (sonuc < 5) return 5;
    if (sonuc > 120) return 120;
    return sonuc;
  }

  /// İlk günden son güne kadar her takvim günü. Ara gün atlanmaz.
  static List<DateTime> ardisikGunler(DateTime baslangic, DateTime bitis) {
    final gunler = <DateTime>[];
    var gun = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final son = DateTime(bitis.year, bitis.month, bitis.day);
    while (!gun.isAfter(son)) {
      gunler.add(gun);
      gun = gun.add(const Duration(days: 1));
    }
    return gunler;
  }

  /// İlk gün randevu günü, sonrakiler 7’şer gün. Geçerlilik dışına çıkanlar yazılmaz.
  static List<DateTime> haftalikPlan(DateTime baslangic, int seans, {int? gecerlilikGun, DateTime? bitis}) {
    final bas = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final adet = seans < 1 ? 1 : seans;
    final son = bitis == null ? null : DateTime(bitis.year, bitis.month, bitis.day);
    final gunler = <DateTime>[];
    for (var i = 0; i < adet; i++) {
      final gun = bas.add(Duration(days: i * 7));
      if (i > 0 && gecerlilikGun != null && gecerlilikGun > 0 && gun.difference(bas).inDays > gecerlilikGun) break;
      if (i > 0 && son != null && gun.isAfter(son)) break;
      gunler.add(gun);
    }
    return gunler;
  }

  static bool diyetSecimiMi(String? kategori, Map<String, dynamic> hizmet) {
    if (diyetisyenMi(kategori)) return true;
    return _sade((hizmet['isim'] ?? '').toString()).contains('diyet');
  }

  static String _sade(String metin) {
    var s = metin.toLowerCase().trim();
    const harfler = {
      'ö': 'o',
      'ü': 'u',
      'ı': 'i',
      'ğ': 'g',
      'ş': 's',
      'ç': 'c',
    };
    harfler.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool randevuOnGorusmeMi(String hizmetAdi) => onGorusmeAdiMi({'isim': hizmetAdi});

  static bool ilkGorusmeMi(Map<String, dynamic> hizmet) {
    if (hizmet.containsKey('ilkGorusme')) return hizmet['ilkGorusme'] == true;
    return onGorusmeAdiMi(hizmet);
  }

  static bool onGorusmeAdiMi(Map<String, dynamic> hizmet) {
    final ad = _sade((hizmet['isim'] ?? '').toString());
    return ad.contains('ongorusme') || ad.contains('ilkgorusme') || ad.contains('ilkmuayene');
  }

  /// Ön görüşme satırını listenin başına alır. Diğer hizmetlerin sırası aynı kalır.
  static List<dynamic> onGorusmeBasa(List<dynamic> liste) {
    final ilk = <dynamic>[];
    final diger = <dynamic>[];
    for (final e in liste) {
      if (e is Map && ilkGorusmeMi(Map<String, dynamic>.from(e))) {
        ilk.add(e);
      } else {
        diger.add(e);
      }
    }
    return [...ilk, ...diger];
  }

  static List<HizmetPaketTanimi> tanimlar(Map<String, dynamic> hizmet) {
    final ham = hizmet['paketler'];
    if (ham is! List) return [];
    return ham
        .whereType<Map>()
        .map((e) => HizmetPaketTanimi.fromMap(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty && p.ad.isNotEmpty && p.seans >= 2)
        .toList();
  }

  static List<HizmetPaketTanimi> aktifTanimlar(Map<String, dynamic> hizmet) {
    return tanimlar(hizmet).where((p) => p.aktif).toList();
  }
}

class HizmetPaketTanimi {
  final String id;
  final String ad;
  final int seans;
  final int gecerlilikGun;
  final double ucret;
  final bool aktif;

  const HizmetPaketTanimi({
    required this.id,
    required this.ad,
    required this.seans,
    required this.gecerlilikGun,
    required this.ucret,
    this.aktif = true,
  });

  factory HizmetPaketTanimi.fromMap(Map<String, dynamic> data) {
    return HizmetPaketTanimi(
      id: (data['id'] ?? '').toString(),
      ad: (data['ad'] ?? '').toString(),
      seans: (data['seans'] as num?)?.toInt() ?? 0,
      gecerlilikGun: (data['gecerlilikGun'] as num?)?.toInt() ?? 90,
      ucret: (data['ucret'] as num?)?.toDouble() ?? 0,
      aktif: data['aktif'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ad': ad,
        'seans': seans,
        'gecerlilikGun': gecerlilikGun,
        'ucret': ucret,
        'aktif': aktif,
      };
}

class MusteriPaketKaydi {
  final String id;
  final String esnafId;
  final String esnafAdi;
  final String kullaniciTel;
  final String hizmetAdi;
  final String paketAdi;
  final int toplamSeans;
  final int kalanSeans;
  final double ucret;
  final DateTime bitis;
  final String durum;

  const MusteriPaketKaydi({
    required this.id,
    required this.esnafId,
    required this.esnafAdi,
    required this.kullaniciTel,
    required this.hizmetAdi,
    required this.paketAdi,
    required this.toplamSeans,
    required this.kalanSeans,
    required this.ucret,
    required this.bitis,
    required this.durum,
  });

  bool get suresiDoldu => bitis.isBefore(DateTime.now());

  bool get tamamenIade => toplamSeans > 0 && kalanSeans >= toplamSeans;

  bool get kullanilabilir => durum == 'aktif' && kalanSeans > 0 && !tamamenIade && !suresiDoldu;

  String get durumYazisi {
    if (durum == 'iptal' || tamamenIade) return 'İptal edildi';
    if (suresiDoldu && kalanSeans > 0) return 'Süresi doldu';
    if (kalanSeans <= 0 || durum == 'bitti') return 'Hak bitti';
    return '$kalanSeans hak kaldı';
  }

  factory MusteriPaketKaydi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MusteriPaketKaydi(
      id: doc.id,
      esnafId: (data['esnafId'] ?? '').toString(),
      esnafAdi: (data['esnafAdi'] ?? '').toString(),
      kullaniciTel: (data['kullaniciTel'] ?? '').toString(),
      hizmetAdi: (data['hizmetAdi'] ?? '').toString(),
      paketAdi: (data['paketAdi'] ?? '').toString(),
      toplamSeans: (data['toplamSeans'] as num?)?.toInt() ?? 0,
      kalanSeans: (data['kalanSeans'] as num?)?.toInt() ?? 0,
      ucret: (data['ucret'] as num?)?.toDouble() ?? 0,
      bitis: data['bitis'] is Timestamp ? (data['bitis'] as Timestamp).toDate() : DateTime.now(),
      durum: (data['durum'] ?? 'aktif').toString(),
    );
  }
}

/// Randevu ekranındaki seçim. `al` yeni paket, `hak` mevcut hak.
class PaketSecimi {
  final String tur;
  final String hizmetAdi;
  final String ad;
  final String? tanimId;
  final String? kayitId;
  final int seans;
  final int gecerlilikGun;
  final double ucret;

  const PaketSecimi({
    required this.tur,
    required this.hizmetAdi,
    required this.ad,
    this.tanimId,
    this.kayitId,
    this.seans = 0,
    this.gecerlilikGun = 0,
    this.ucret = 0,
  });
}
