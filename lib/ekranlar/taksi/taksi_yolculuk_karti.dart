import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../servisler/bildirim_servisi.dart';
import '../../servisler/firestore_servisi.dart';
import '../../servisler/taksi/taksi_cagri_sirasi.dart';
import '../../servisler/taksi/taksi_iptal_bedeli.dart';
import '../../servisler/taksi/taksi_konum_akisi.dart';

const taksiSurenDurumlar = {'bekliyor', 'yolda', 'geldim', 'bindi'};

/// Yolcunun pinine bu kadar yaklaşınca "geldim" kendiliğinden yazılır.
const double taksiGeldimMetre = 100;

/// Kimse kabul etmezse çağrı bu sürede kapanır.
const Duration taksiCagriBekleme = Duration(minutes: 2);

DateTime? taksiTalepAni(Map<String, dynamic> data) {
  final t = data['olusturulmaTarihi'] ?? data['tarih'];
  if (t is Timestamp) return t.toDate();
  return null;
}

Duration taksiCagriKalani(Map<String, dynamic> data, {DateTime? yerelden}) {
  final ani = taksiTalepAni(data) ?? yerelden ?? DateTime.now();
  final kalan = taksiCagriBekleme - DateTime.now().difference(ani);
  if (kalan.isNegative) return Duration.zero;
  return kalan;
}

/// Durum hâlâ bekliyor ise kapatır. Kabul edilmişse false döner.
Future<bool> taksiBekleyenCagriyiKapat(String talepId, String durum) async {
  if (talepId.isEmpty) return false;
  final ref = FirebaseFirestore.instance.collection('taksi_talepleri').doc(talepId);
  try {
    return await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if ((snap.data()?['durum'] ?? '').toString() != 'bekliyor') return false;
      tx.update(ref, {
        'durum': durum,
        'kapanisZamani': FieldValue.serverTimestamp(),
      });
      return true;
    });
  } catch (e) {
    debugPrint('Çağrı kapanmadı: $e');
    return false;
  }
}

/// Kabul, çağrı hâlâ bekliyor ise yazılır.
Future<bool> taksiCagriyiKabulEt(DocumentReference ref, Map<String, dynamic> alanlar) async {
  try {
    return await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final veri = snap.data();
      final durum = veri is Map ? (veri['durum'] ?? '').toString() : '';
      if (durum != 'bekliyor') return false;
      tx.update(ref, alanlar);
      return true;
    });
  } catch (e) {
    debugPrint('Çağrı kabul edilmedi: $e');
    return false;
  }
}

String taksiDurumBasligi(String durum) {
  switch (durum) {
    case 'bekliyor':
      return 'Onay bekleniyor';
    case 'yolda':
      return 'Taksi yolda';
    case 'geldim':
      return 'Taksiniz geldi';
    case 'bindi':
      return 'Yolculuk başladı';
    case 'indi':
      return 'Yolculuk bitti';
    default:
      return 'Taksi';
  }
}

int taksiDakika(GeoPoint arac, GeoPoint yolcu) {
  final metre = Geolocator.distanceBetween(
    arac.latitude,
    arac.longitude,
    yolcu.latitude,
    yolcu.longitude,
  );
  var dk = ((metre * 1.3) / 500).round();
  if (dk < 1) dk = 1;
  if (dk > 45) dk = 45;
  return dk;
}

/// Şoför veya durak sahibi, kabul edilmiş çağrıyı ilerletir.
class TaksiYolculukKarti extends StatefulWidget {
  final String esnafId;
  final String? soforTel;
  final String? plaka;
  final bool konumGonder;

  const TaksiYolculukKarti({
    super.key,
    required this.esnafId,
    this.soforTel,
    this.plaka,
    this.konumGonder = false,
  });

  @override
  State<TaksiYolculukKarti> createState() => _TaksiYolculukKartiState();
}

class _TaksiYolculukKartiState extends State<TaksiYolculukKarti> {
  final FirestoreServisi _db = FirestoreServisi();
  StreamSubscription? _dinleyici;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _gelen = [];
  final Set<String> _geldi = {};
  bool _islem = false;

  bool _benim(Map<String, dynamic> data) {
    final tel = widget.soforTel;
    final plaka = (widget.plaka ?? '').trim();
    if ((tel == null || tel.isEmpty) && plaka.isEmpty) return true;
    final kayitTel = _db.musteriTelefonAnahtari('${data['soforTel'] ?? ''}');
    final benimTel = _db.musteriTelefonAnahtari(tel ?? '');
    if (benimTel.isNotEmpty && kayitTel == benimTel) return true;
    final kayitPlaka = (data['plaka'] ?? '').toString().trim();
    return plaka.isNotEmpty && kayitPlaka == plaka;
  }

  @override
  void initState() {
    super.initState();
    _dinleyici = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: widget.esnafId)
        .snapshots()
        .listen((snap) {
      final onceki = _aktif.map((d) => d.id).toSet();
      final liste = snap.docs.where((d) {
        final durum = (d.data()['durum'] ?? '').toString();
        return durum == 'yolda' || durum == 'geldim' || durum == 'bindi';
      }).toList();
      if (mounted) {
        for (final id in onceki) {
          if (liste.any((d) => d.id == id)) continue;
          final kalan = snap.docs.where((d) => d.id == id);
          if (kalan.isEmpty) continue;
          final veri = kalan.first.data();
          if ((veri['durum'] ?? '').toString() == 'yolcu_iptal' && _benim(veri)) {
            final bedel = (veri['iptalBedeli'] is num) ? (veri['iptalBedeli'] as num).toDouble() : 0.0;
            final yazi = bedel > 0 ? 'Yolcu vazgeçti. İptal bedeli ${taksiTlEtiket(bedel)}.' : 'Yolcu vazgeçti.';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(yazi)));
          }
        }
        setState(() => _gelen = liste);
      }
    });
    _akisiBagla();
  }

  @override
  void didUpdateWidget(covariant TaksiYolculukKarti oldWidget) {
    super.didUpdateWidget(oldWidget);
    _akisiBagla();
  }

  void _akisiBagla() {
    if (!widget.konumGonder) return;
    TaksiKonumAkisi.baslat(
      esnafId: widget.esnafId,
      soforTel: widget.soforTel,
      plaka: widget.plaka,
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _aktif =>
      _gelen.where((d) => _benim(d.data())).toList();

  Future<void> _ilerlet(QueryDocumentSnapshot<Map<String, dynamic>> doc, String durum) async {
    if (_islem) return;
    if (durum == 'geldim') _geldi.add(doc.id);
    setState(() => _islem = true);
    final data = doc.data();
    final plaka = (data['plaka'] ?? '').toString();
    final tel = (data['musteriTel'] ?? data['kullaniciTel'] ?? '').toString();
    try {
      await doc.reference.update({
        'durum': durum,
        if (durum == 'geldim') 'geldimZamani': FieldValue.serverTimestamp(),
        if (durum == 'bindi') 'bindiZamani': FieldValue.serverTimestamp(),
        if (durum == 'indi') 'indimZamani': FieldValue.serverTimestamp(),
      });
      if (durum == 'geldim' && tel.isNotEmpty) {
        await BildirimServisi.bildirimGonder(
          kullaniciTel: tel,
          baslik: 'Taksiniz geldi',
          icerik: plaka.isEmpty ? 'Aracınız kapıda.' : '$plaka plakalı aracınız kapıda.',
        );
      }
      if (durum == 'bindi' && tel.isNotEmpty) {
        await BildirimServisi.bildirimGonder(
          kullaniciTel: tel,
          baslik: 'Yolculuk başladı',
          icerik: 'İyi yolculuklar. Ücret taksimetrededir.',
        );
      }
      if (durum == 'indi') {
        await _araciBirak(plaka);
        if (tel.isNotEmpty) {
          await BildirimServisi.bildirimGonder(
            kullaniciTel: tel,
            baslik: 'Yolculuk bitti',
            icerik: 'Ücret taksimetrededir. Araç sıradan çıktı.',
          );
        }
      }
    } catch (e) {
      if (durum == 'geldim') _geldi.remove(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yazılamadı: $e')));
      }
    }
    if (mounted) setState(() => _islem = false);
  }

  Future<void> _araciBirak(String plaka) => taksiAraciMusaitYap(widget.esnafId, plaka);

  @override
  void dispose() {
    _dinleyici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_aktif.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final doc in _aktif) _kart(doc),
      ],
    );
  }

  Widget _kart(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final durum = (data['durum'] ?? '').toString();
    final plaka = (data['plaka'] ?? 'Plaka yok').toString();
    final adres = (data['adres'] ?? '').toString();
    final nereye = (data['nereye'] ?? '').toString();
    String dugme = '';
    String sonraki = '';
    if (durum == 'geldim') {
      dugme = 'Yolcu bindi';
      sonraki = 'bindi';
    } else if (durum == 'bindi') {
      dugme = 'Yolculuk bitti';
      sonraki = 'indi';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.yellow.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.yellow.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$plaka · ${taksiDurumBasligi(durum)}', style: const TextStyle(fontWeight: FontWeight.w900)),
          if (data['sahteKonum'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Sahte konum açık. Yolcunun gördüğü nokta bu telefona ait olmayabilir.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
              ),
            ),
          if (adres.isNotEmpty) Text('Alış: $adres'),
          if (nereye.isNotEmpty) Text('Varış: $nereye'),
          const SizedBox(height: 4),
          const Text('Ücret taksimetrededir.', style: TextStyle(fontSize: 12)),
          if (durum == 'yolda')
            Text(
              'Yolcuya ${taksiGeldimMetre.round()} metreden yakın olunca geldi kendiliğinden yazılır.',
              style: const TextStyle(fontSize: 12),
            ),
          if (dugme.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _islem ? null : () => _ilerlet(doc, sonraki),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.yellow),
                child: Text(dugme, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
