import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../modeller/esnaf_modeli.dart';
import '../bildirim_servisi.dart';
import 'taksi_iptal_bedeli.dart';

/// Cevap yoksa bu sürede sıradaki araca geçilir.
const Duration taksiSoruAraligi = Duration(seconds: 25);

class TaksiSoruSonucu {
  final String tur;
  final String? plaka;
  final String? soforTel;
  final String? adres;
  final String? esnafId;
  final String? musteriTel;

  const TaksiSoruSonucu(this.tur, {this.plaka, this.soforTel, this.adres, this.esnafId, this.musteriTel});

  bool get gecti => tur == 'gecti';
  bool get kapandi => tur == 'kapandi';
}

/// Bekleyen çağrıyı sıradaki araca yazar. Süre dolduysa veya araç kalmadıysa kapatır.
/// [zorla] reddetmede 25 saniyeyi beklemeden geçirir.
Future<TaksiSoruSonucu> taksiSiradakiAracaSor(String talepId, {bool zorla = false}) async {
  if (talepId.isEmpty) return const TaksiSoruSonucu('erken');
  final ref = FirebaseFirestore.instance.collection('taksi_talepleri').doc(talepId);
  try {
    final sonuc = await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || (data['durum'] ?? '').toString() != 'bekliyor') {
        return const TaksiSoruSonucu('erken');
      }
      final simdi = DateTime.now();
      final bas = _baslangic(data);
      if (bas != null && simdi.difference(bas) >= const Duration(minutes: 2)) {
        tx.update(ref, {'durum': 'sure_doldu', 'kapanisZamani': FieldValue.serverTimestamp()});
        return TaksiSoruSonucu('kapandi', musteriTel: (data['musteriTel'] ?? data['kullaniciTel'] ?? '').toString());
      }
      final soruAni = _soruAni(data) ?? bas;
      if (!zorla && (soruAni == null || simdi.difference(soruAni) < taksiSoruAraligi)) {
        return const TaksiSoruSonucu('erken');
      }
      final esnafId = (data['esnafId'] ?? '').toString();
      if (esnafId.isEmpty) return const TaksiSoruSonucu('erken');
      final esSnap = await tx.get(FirebaseFirestore.instance.collection('esnaflar').doc(esnafId));
      final araclar = List<dynamic>.from(esSnap.data()?['araclar'] ?? []);
      final sorulan = <String>{
        for (final p in List<dynamic>.from(data['sorulanPlakalar'] ?? [])) p.toString(),
        (data['plaka'] ?? '').toString(),
      }..removeWhere((p) => p.isEmpty);
      final sonraki = _sonrakiArac(araclar, sorulan);
      if (sonraki == null) {
        final durum = zorla ? 'reddedildi' : 'sure_doldu';
        tx.update(ref, {'durum': durum, 'kapanisZamani': FieldValue.serverTimestamp()});
        return TaksiSoruSonucu('kapandi', musteriTel: (data['musteriTel'] ?? data['kullaniciTel'] ?? '').toString());
      }
      final plaka = (sonraki['plaka'] ?? '').toString();
      final sofor = (sonraki['soforTel'] ?? '').toString();
      tx.update(ref, {
        'plaka': plaka,
        'soforTel': sofor,
        'sorulanPlakalar': [...sorulan, plaka],
        'soruZamani': FieldValue.serverTimestamp(),
      });
      return TaksiSoruSonucu(
        'gecti',
        plaka: plaka,
        soforTel: sofor,
        adres: (data['adres'] ?? '').toString(),
        esnafId: esnafId,
      );
    });
    if (sonuc.gecti && (sonuc.esnafId ?? '').isNotEmpty) {
      final es = await FirebaseFirestore.instance.collection('esnaflar').doc(sonuc.esnafId).get();
      if (es.exists && es.data() != null) {
        await BildirimServisi.taksiCagriDustu(
          esnaf: EsnafModeli.fromMap(es.data()!, es.id),
          soforTel: sonuc.soforTel,
          adres: sonuc.adres ?? '',
          talepId: talepId,
        );
      }
    }
    if (sonuc.kapandi && (sonuc.musteriTel ?? '').isNotEmpty) {
      await BildirimServisi.taksiCagriReddedildi(sonuc.musteriTel!);
    }
    return sonuc;
  } catch (e) {
    debugPrint('Sıradaki araca geçilemedi: $e');
    return const TaksiSoruSonucu('erken');
  }
}

/// Yolcu, binmeden vazgeçer. Araç müsait kalır, sıraya kendiliğinden girmez.
/// Dönüş, yazılan iptal bedelidir. Çağrı kapanmazsa null döner.
Future<double?> taksiBinmedenVazgec({
  required String talepId,
  required String esnafId,
}) async {
  if (talepId.isEmpty) return null;
  final ref = FirebaseFirestore.instance.collection('taksi_talepleri').doc(talepId);
  final esRef = FirebaseFirestore.instance.collection('esnaflar').doc(esnafId);
  String plaka = '';
  try {
    final bedel = await FirebaseFirestore.instance.runTransaction<double?>((tx) async {
      final snap = await tx.get(ref);
      final ham = snap.data();
      if (ham == null) return null;
      final durum = (ham['durum'] ?? '').toString();
      if (durum != 'yolda' && durum != 'geldim') return null;
      plaka = (ham['plaka'] ?? '').toString();
      final es = await tx.get(esRef);
      final tarife = es.data() ?? {};
      final sonuc = taksiIptalHesapla(
        talep: ham,
        taban: taksiTlSayi(tarife['taksiIptalTabanUcret']),
        kmUcret: taksiTlSayi(tarife['taksiIptalKmUcret']),
        dakikaUcret: taksiTlSayi(tarife['taksiIptalDakikaUcret']),
      );
      tx.update(ref, {
        'durum': 'yolcu_iptal',
        'iptalBedeli': sonuc.tutar,
        'kapanisZamani': FieldValue.serverTimestamp(),
      });
      return sonuc.tutar;
    });
    if (bedel == null) return null;
    await taksiAraciMusaitYap(esnafId, plaka);
    return bedel;
  } catch (e) {
    debugPrint('Binmeden vazgeçilemedi: $e');
    return null;
  }
}

Future<void> taksiAraciMusaitYap(String esnafId, String plaka) async {
  if (esnafId.isEmpty || plaka.isEmpty) return;
  final es = await FirebaseFirestore.instance.collection('esnaflar').doc(esnafId).get();
  if (!es.exists) return;
  final ham = List<dynamic>.from(es.data()?['araclar'] ?? []);
  final i = ham.indexWhere((a) => a is Map && (a['plaka'] ?? '').toString() == plaka);
  if (i == -1) return;
  ham[i]['durakta'] = false;
  ham[i]['siraZamani'] = 0;
  ham[i]['durum'] = 'Müsait';
  await es.reference.update({'araclar': ham});
}

DateTime? _baslangic(Map<String, dynamic> data) {
  final t = data['olusturulmaTarihi'] ?? data['tarih'];
  if (t is Timestamp) return t.toDate();
  return null;
}

DateTime? _soruAni(Map<String, dynamic> data) {
  final t = data['soruZamani'];
  if (t is Timestamp) return t.toDate();
  return null;
}

Map<String, dynamic>? _sonrakiArac(List<dynamic> ham, Set<String> sorulan) {
  final liste = <Map<String, dynamic>>[];
  for (final a in ham) {
    if (a is! Map) continue;
    final m = Map<String, dynamic>.from(a);
    if (m['durakta'] != true) continue;
    if ((m['durum'] ?? '').toString() == 'İstirahatte') continue;
    final plaka = (m['plaka'] ?? '').toString();
    if (plaka.isEmpty || sorulan.contains(plaka)) continue;
    liste.add(m);
  }
  final gun = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
  liste.sort((a, b) {
    final an = _nobetci(a, gun) ? 0 : 1;
    final bn = _nobetci(b, gun) ? 0 : 1;
    if (an != bn) return an.compareTo(bn);
    final t1 = (a['siraZamani'] ?? 0) as num;
    final t2 = (b['siraZamani'] ?? 0) as num;
    return t1.compareTo(t2);
  });
  if (liste.isEmpty) return null;
  return liste.first;
}

bool _nobetci(Map<String, dynamic> arac, String gun) {
  final bilgi = arac['nobetBilgileri'];
  if (bilgi is Map) {
    final gunluk = bilgi[gun];
    if (gunluk is Map && gunluk['nobetci'] == true) return true;
  }
  return false;
}
