import 'package:cloud_firestore/cloud_firestore.dart';

class YoneticiSesKomutu {
  final String mesaj;
  final String? acilis;
  final String? kapanis;
  final bool? randevuAlinmasin;
  final bool taksiIstiyorum;
  final bool anlasildi;

  const YoneticiSesKomutu({
    required this.mesaj,
    this.acilis,
    this.kapanis,
    this.randevuAlinmasin,
    this.taksiIstiyorum = false,
    this.anlasildi = true,
  });
}

YoneticiSesKomutu yoneticiSesKomutuCoz(String ham) {
  final metin = ham.toLowerCase().trim();
  if (metin.isEmpty) {
    return const YoneticiSesKomutu(mesaj: 'Bir şey duyulmadı.', anlasildi: false);
  }
  if (metin.contains('taksi istiyorum') ||
      metin.contains('taksi ister') ||
      metin.contains('taksi çağır') ||
      metin.contains('taksi cagir') ||
      metin.contains('taksi lazım') ||
      metin.contains('taksi lazim')) {
    return const YoneticiSesKomutu(
      mesaj: 'Çağrı penceresi açıldı. Onaylamadan gitmez.',
      taksiIstiyorum: true,
    );
  }
  if (metin.contains('randevu') && (metin.contains('durdur') || metin.contains('kapat'))) {
    return const YoneticiSesKomutu(
      mesaj: 'Randevu alımı durdu. Müşteri randevu düğmesini görmez.',
      randevuAlinmasin: true,
    );
  }
  if (metin.contains('randevu') && (metin.contains('aç') || metin.contains('ac') || metin.contains('devam') || metin.contains('başlat') || metin.contains('baslat'))) {
    return const YoneticiSesKomutu(
      mesaj: 'Randevu alımı açıldı.',
      randevuAlinmasin: false,
    );
  }
  final saat = _saatBul(metin);
  final acilis = metin.contains('açılış') || metin.contains('acilis') || metin.contains('başlangıç') || metin.contains('baslangic');
  final kapanis = metin.contains('kapanış') || metin.contains('kapanis') || metin.contains('bitiş') || metin.contains('bitis');
  if (saat != null && acilis && !kapanis) {
    return YoneticiSesKomutu(mesaj: 'Açılış saati $saat oldu.', acilis: saat);
  }
  if (saat != null && kapanis && !acilis) {
    return YoneticiSesKomutu(mesaj: 'Kapanış saati $saat oldu.', kapanis: saat);
  }
  if (saat != null && metin.contains('mesai') && acilis) {
    return YoneticiSesKomutu(mesaj: 'Açılış saati $saat oldu.', acilis: saat);
  }
  return const YoneticiSesKomutu(
    mesaj: 'Bunu uygulamadım. Açılış saati, kapanış saati, randevu alımını durdur veya taksi istiyorum diyebilirsiniz.',
    anlasildi: false,
  );
}

String? _saatBul(String metin) {
  final rakam = RegExp(r'(?:^|\s)(\d{1,2})(?:[:.](\d{2}))?(?:\s|$)').firstMatch(metin);
  if (rakam != null) {
    return _saatYaz(int.tryParse(rakam.group(1)!), int.tryParse(rakam.group(2) ?? ''));
  }
  const sozcuk = {
    'bir': 1,
    'iki': 2,
    'üç': 3,
    'uc': 3,
    'dört': 4,
    'dort': 4,
    'beş': 5,
    'bes': 5,
    'altı': 6,
    'alti': 6,
    'yedi': 7,
    'sekiz': 8,
    'dokuz': 9,
    'on': 10,
    'on bir': 11,
    'on iki': 12,
    'on üç': 13,
    'on uc': 13,
    'on dört': 14,
    'on dort': 14,
    'on beş': 15,
    'on bes': 15,
    'on altı': 16,
    'on alti': 16,
    'on yedi': 17,
    'on sekiz': 18,
    'on dokuz': 19,
    'yirmi': 20,
    'yirmi bir': 21,
    'yirmi iki': 22,
    'yirmi üç': 23,
    'yirmi uc': 23,
  };
  String? bulunan;
  var enUzun = 0;
  final bucuk = RegExp(r'(?:^|\s)buçuk(?:\s|$)').hasMatch(metin) || RegExp(r'(?:^|\s)bucuk(?:\s|$)').hasMatch(metin);
  for (final e in sozcuk.entries) {
    final varMi = RegExp('(?:^|\\s)${RegExp.escape(e.key)}(?:\\s|\$)').hasMatch(metin);
    if (varMi && e.key.length > enUzun) {
      enUzun = e.key.length;
      bulunan = _saatYaz(e.value, bucuk ? 30 : 0);
    }
  }
  return bulunan;
}

Future<void> yoneticiSesKomutunuYaz(String esnafId, YoneticiSesKomutu komut) async {
  final veri = <String, dynamic>{};
  if (komut.acilis != null) veri['calismaSaatleri.acilis'] = komut.acilis;
  if (komut.kapanis != null) veri['calismaSaatleri.kapanis'] = komut.kapanis;
  if (komut.randevuAlinmasin != null) {
    veri['randevuAlinmasin'] = komut.randevuAlinmasin;
    if (komut.randevuAlinmasin == true) veri['randevuSadeceYonetici'] = false;
  }
  if (veri.isEmpty) return;
  await FirebaseFirestore.instance.collection('esnaflar').doc(esnafId).update(veri);
}

String? _saatYaz(int? saat, int? dakika) {
  if (saat == null || saat < 0 || saat > 23) return null;
  final dk = dakika ?? 0;
  if (dk < 0 || dk > 59) return null;
  final s = saat.toString().padLeft(2, '0');
  final d = dk.toString().padLeft(2, '0');
  return '$s:$d';
}
