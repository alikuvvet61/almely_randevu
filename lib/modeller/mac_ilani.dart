class MacKatilim {
  final String tel;
  final String telYazi;
  final String ad;

  const MacKatilim({required this.tel, required this.telYazi, required this.ad});

  factory MacKatilim.fromMap(Map<String, dynamic> data) {
    return MacKatilim(
      tel: (data['tel'] ?? '').toString(),
      telYazi: (data['telYazi'] ?? '').toString(),
      ad: (data['ad'] ?? '').toString().trim().isEmpty ? 'İsimsiz' : (data['ad'] ?? '').toString().trim(),
    );
  }
}

class MacIlani {
  final String id;
  final String tur;
  final String durum;
  final String esnafId;
  final String isletmeAdi;
  final String saha;
  final String tarih;
  final String saat;
  final String acanTel;
  final String acanAd;
  final int kacKisi;
  final List<MacKatilim> katilanlar;
  final String takimAdi;
  final int oyuncuSayisi;
  final String rakipTakimAdi;
  final String rakipTel;
  final String rakipTelYazi;
  final String rakipAd;
  final String cagiranTel;
  final String cagiranTelYazi;
  final String cagiranAd;
  final String cagiranTakim;
  final String notu;

  const MacIlani({
    required this.id,
    required this.tur,
    required this.durum,
    required this.esnafId,
    required this.isletmeAdi,
    required this.saha,
    required this.tarih,
    required this.saat,
    required this.acanTel,
    required this.acanAd,
    required this.kacKisi,
    required this.katilanlar,
    required this.takimAdi,
    required this.oyuncuSayisi,
    required this.rakipTakimAdi,
    required this.rakipTel,
    required this.rakipTelYazi,
    required this.rakipAd,
    required this.cagiranTel,
    required this.cagiranTelYazi,
    required this.cagiranAd,
    required this.cagiranTakim,
    required this.notu,
  });

  bool get eksik => tur == 'eksik';
  bool get takim => tur == 'takim';
  bool get benOyuncu => tur == 'oyuncu';
  bool get benRakip => tur == 'rakip';
  bool get kaleciyim => tur == 'kaleci';
  bool get kaleciAriyor => tur == 'kaleci_ara';
  bool get katilma => eksik || kaleciAriyor;
  bool get hazir => benOyuncu || benRakip || kaleciyim;
  bool get acik => durum == 'Açık';
  bool get doldu => durum == 'Doldu';
  bool get eslesti => durum == 'Eşleşti';
  bool get cagrildi => durum == 'Çağrıldı';

  String get baslik {
    if (eksik) return 'Oyuncu arıyorum';
    if (benOyuncu) return 'Takım arıyorum';
    if (kaleciyim) return 'Kaleciyim';
    if (kaleciAriyor) return 'Kaleci arıyorum';
    if (benRakip) return 'Rakibiz';
    if (takim) return 'Rakip arıyoruz';
    return 'İstek';
  }

  DateTime get an {
    final parca = DateTime.tryParse('$tarih $saat');
    if (parca != null) return parca;
    return DateTime.tryParse(tarih) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get saatiGecti => an.isBefore(DateTime.now());

  bool dahil(String anahtar) {
    if (anahtar.isEmpty) return false;
    if (acanTel == anahtar || rakipTel == anahtar || cagiranTel == anahtar) return true;
    return katilanlar.any((k) => k.tel == anahtar);
  }

  factory MacIlani.fromMap(String id, Map<String, dynamic> data) {
    final ham = data['katilanlar'];
    final katilanlar = <MacKatilim>[];
    if (ham is List) {
      for (final e in ham) {
        if (e is Map) katilanlar.add(MacKatilim.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    return MacIlani(
      id: id,
      tur: (data['tur'] ?? '').toString(),
      durum: (data['durum'] ?? '').toString(),
      esnafId: (data['esnafId'] ?? '').toString(),
      isletmeAdi: (data['isletmeAdi'] ?? '').toString(),
      saha: (data['saha'] ?? '').toString(),
      tarih: (data['tarih'] ?? '').toString(),
      saat: (data['saat'] ?? '').toString(),
      acanTel: (data['acanTel'] ?? '').toString(),
      acanAd: (data['acanAd'] ?? '').toString().trim().isEmpty ? 'İsimsiz' : (data['acanAd'] ?? '').toString().trim(),
      kacKisi: (data['kacKisi'] as num?)?.toInt() ?? 0,
      katilanlar: katilanlar,
      takimAdi: (data['takimAdi'] ?? '').toString(),
      oyuncuSayisi: (data['oyuncuSayisi'] as num?)?.toInt() ?? 0,
      rakipTakimAdi: (data['rakipTakimAdi'] ?? '').toString(),
      rakipTel: (data['rakipTel'] ?? '').toString(),
      rakipTelYazi: (data['rakipTelYazi'] ?? '').toString(),
      rakipAd: (data['rakipAd'] ?? '').toString(),
      cagiranTel: (data['cagiranTel'] ?? '').toString(),
      cagiranTelYazi: (data['cagiranTelYazi'] ?? '').toString(),
      cagiranAd: (data['cagiranAd'] ?? '').toString(),
      cagiranTakim: (data['cagiranTakim'] ?? '').toString(),
      notu: (data['not'] ?? '').toString(),
    );
  }
}
