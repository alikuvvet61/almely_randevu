import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Geliş tahminini bu kadar aşan araçta iptal bedeli alınmaz.
const Duration taksiIptalGecikmePayi = Duration(minutes: 5);

class TaksiIptalSonucu {
  final double tutar;
  final String sebep;

  const TaksiIptalSonucu(this.tutar, this.sebep);

  bool get bedelli => tutar > 0 && sebep == 'bedel';
}

double taksiTlOku(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return 0;
  final n = double.tryParse(t);
  if (n == null || n < 0) return 0;
  if (n > 9999) return 9999;
  return (n * 100).round() / 100.0;
}

double taksiSayi(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', '.')) ?? 0;
}

double taksiTlSayi(dynamic v) {
  if (v is num) return taksiTlOku(v.toString());
  return taksiTlOku('$v');
}

String taksiTlAlan(double n) => n <= 0 ? '' : taksiTlYazi(n);

String taksiTlYazi(double n) {
  if (n <= 0) return '0';
  if ((n - n.round()).abs() < 0.001) return '${n.round()}';
  return n.toStringAsFixed(2).replaceAll('.', ',');
}

String taksiTlEtiket(double n) => '${taksiTlYazi(n)} TL';

const String taksiIptalSureNotu =
    'Bu ekran, yolcu vazgeçince yolcunun şoföre ödeyeceği tutarı belirler. Şoför çağrıyı kabul edince araç sıradan çıkar. Yolcu ondan sonra vazgeçerse en az taban ücreti öder. Şoför yolcuya doğru gitmezse yolcu ödeme yapmaz. Şoför yolcunun yanına, söylenen süreden 5 dakika geç kalırsa ve yolcu o sırada vazgeçerse de ödeme yapmaz. Yolcu binince ücret taksimetrededir.';

/// Yazılan taban, kilometre ve dakikaya göre değişen cümle.
String taksiIptalTarifeMetni(double taban, double km, double dakika) {
  if (taban <= 0 && km <= 0 && dakika <= 0) {
    return 'Şu an yolcu vazgeçince ödeme yapmaz. Üç tutar da 0. Bir tutar yazınca bu açıklama değişir.';
  }
  final kisa = _ornekTutar(2, 2, taban, km, dakika);
  final uzun = _ornekTutar(6, 10, taban, km, dakika);
  final ornek = 'Örnek: 2 km ve 2 dk ${taksiTlEtiket(kisa)}. 6 km ve 10 dk ${taksiTlEtiket(uzun)}.';
  final parcalar = <String>[
    if (km > 0) 'her kilometre ${taksiTlEtiket(km)}',
    if (dakika > 0) 'her dakika ${taksiTlEtiket(dakika)}',
  ];
  if (taban > 0 && parcalar.isEmpty) {
    return 'Şoför çağrıyı kabul edince araç sıradan çıkar. Yolcu vazgeçerse şoföre ${taksiTlEtiket(taban)} öder. Kısa yolda da uzun yolda da tutar bu rakamda kalır. $ornek';
  }
  if (taban > 0) {
    return 'Şoför çağrıyı kabul edince araç sıradan çıkar. Yolcu vazgeçerse şoföre en az ${taksiTlEtiket(taban)} öder. Uzun yolda ${parcalar.join(', ')} toplanır. Bu toplam tabandan büyükse yolcu o tutarı öder. $ornek';
  }
  return 'Taban 0. Yolcu vazgeçince bedel gidilen yola ve geçen dakikaya göre çıkar: ${parcalar.join(', ')}. $ornek';
}

double _ornekTutar(double km, double dakika, double taban, double kmUcret, double dakikaUcret) {
  final yol = km * kmUcret + dakika * dakikaUcret;
  final tutar = yol > taban ? yol : taban;
  return (tutar * 100).round() / 100.0;
}

String taksiIptalOnayMetni(TaksiIptalSonucu s) {
  switch (s.sebep) {
    case 'ilerlemedi':
      return 'Taksi yola çıktı. Araç yolcuya doğru gitmiyor. İptal bedeli yok. Çağrı kapatılsın mı?';
    case 'gecikti':
      return 'Taksi yola çıktı. Araç, yolcunun yanına söylenen süreden 5 dakika geç kaldı. İptal bedeli yok. Çağrı kapatılsın mı?';
    case 'bedel':
      return 'Şoför çağrıyı kabul etti, araç sıradan çıktı. Vazgeçerseniz şoföre ${taksiTlEtiket(s.tutar)} ödersiniz. Çağrı kapatılsın mı?';
    default:
      return 'Taksi yola çıktı. Bu durağın iptal tarifesi 0 TL. İptal bedeli yok. Çağrı kapatılsın mı?';
  }
}

/// Kabul, aracı sıradan çıkarır. Yolcu ondan sonra vazgeçerse bedel en az tabandır.
/// Şoför yolcuya doğru gitmiyorsa veya tahminden 5 dakika geç kaldıysa tutar 0 kalır.
TaksiIptalSonucu taksiIptalHesapla({
  required Map<String, dynamic> talep,
  required double taban,
  required double kmUcret,
  required double dakikaUcret,
  DateTime? simdi,
}) {
  final now = simdi ?? DateTime.now();
  final kabul = _zaman(talep['kabulZamani']);

  final yolcu = talep['musteriKonum'];
  final arac = talep['soforKonum'];
  double? simdiMetre;
  if (arac is GeoPoint && yolcu is GeoPoint) {
    simdiMetre = Geolocator.distanceBetween(arac.latitude, arac.longitude, yolcu.latitude, yolcu.longitude);
  }
  final kabulMetre = taksiSayi(talep['kabulMesafeMetre']);
  final geldi = (talep['durum'] ?? '').toString() == 'geldim';
  final uzaklasiyor = !geldi && simdiMetre != null && kabulMetre > 0 && simdiMetre > kabulMetre + 80;
  if (uzaklasiyor) return const TaksiIptalSonucu(0, 'ilerlemedi');

  final etaDk = taksiSayi(talep['kabulTahminiDakika']);
  if (kabul != null && etaDk > 0 && now.isAfter(kabul.add(Duration(minutes: etaDk.ceil()) + taksiIptalGecikmePayi))) {
    return const TaksiIptalSonucu(0, 'gecikti');
  }

  if (taban <= 0 && kmUcret <= 0 && dakikaUcret <= 0) {
    return const TaksiIptalSonucu(0, 'tarife_yok');
  }

  var gidilen = taksiSayi(talep['gidilenMetre']);
  if (simdiMetre != null && kabulMetre > simdiMetre) {
    final yaklasma = (kabulMetre - simdiMetre) * 1.3;
    if (yaklasma > gidilen) gidilen = yaklasma;
  }
  final dakika = kabul == null ? 0.0 : now.difference(kabul).inSeconds / 60.0;
  final yol = (gidilen / 1000) * kmUcret + dakika * dakikaUcret;
  final tutar = yol > taban ? yol : taban;
  return TaksiIptalSonucu((tutar * 100).round() / 100.0, 'bedel');
}

DateTime? _zaman(dynamic t) {
  if (t is Timestamp) return t.toDate();
  if (t is DateTime) return t;
  return null;
}
