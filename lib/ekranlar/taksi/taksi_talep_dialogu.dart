import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../modeller/esnaf_modeli.dart';
import '../../servisler/bildirim_servisi.dart';
import '../../servisler/firestore_servisi.dart';
import '../../servisler/taksi/taksi_cagri_sesi.dart';
import '../../servisler/taksi/taksi_cagri_sirasi.dart';
import '../../servisler/taksi/taksi_konum_akisi.dart';
import 'taksi_yolculuk_karti.dart';

/// Aynı çağrı için iki ekran birden pencere açmasın.
final Set<String> taksiAcikTalepPencereleri = {};

class TaksiOturum {
  static String telefon = '';
}

void taksiTalepPenceresiAc(
  BuildContext context, {
  required DocumentSnapshot doc,
  required EsnafModeli esnaf,
  String? soforTel,
  required bool isSofor,
}) {
  if (!taksiAcikTalepPencereleri.add(doc.id)) return;
  final ses = TaksiCagriSesi()..baslat();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TaksiTalepDialogu(
      doc: doc,
      esnaf: esnaf,
      soforTel: soforTel,
      isSofor: isSofor,
    ),
  ).whenComplete(() {
    ses.durdur();
    taksiAcikTalepPencereleri.remove(doc.id);
  });
}

class TaksiTalepDialogu extends StatefulWidget {
  final DocumentSnapshot doc;
  final EsnafModeli esnaf;
  final String? soforTel;
  final bool isSofor;

  const TaksiTalepDialogu({
    super.key,
    required this.doc,
    required this.esnaf,
    required this.soforTel,
    required this.isSofor,
  });

  @override
  State<TaksiTalepDialogu> createState() => _TaksiTalepDialoguState();
}

class _TaksiTalepDialoguState extends State<TaksiTalepDialogu> {
  StreamSubscription? _dinle;
  Timer? _zaman;
  Map<String, dynamic> _veri = {};
  var _kapandi = false;

  @override
  void initState() {
    super.initState();
    final ham = widget.doc.data();
    _veri = ham is Map ? Map<String, dynamic>.from(ham) : {};
    _dinle = widget.doc.reference.snapshots().listen(_gelen);
    _zamanKur();
  }

  @override
  void dispose() {
    _zaman?.cancel();
    _dinle?.cancel();
    super.dispose();
  }

  void _gelen(DocumentSnapshot snap) {
    final ham = snap.data();
    if (ham is! Map) return;
    final veri = Map<String, dynamic>.from(ham);
    final durum = (veri['durum'] ?? '').toString();
    if (!mounted) return;
    if (durum.isNotEmpty && durum != 'bekliyor') {
      if (durum == 'iptal' || durum == 'yolcu_iptal') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yolcu vazgeçti.')));
      }
      _kapat();
      return;
    }
    final benim = _ayniTel(veri['soforTel'], widget.soforTel);
    if (widget.isSofor && !benim) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çağrı sıradaki araca geçti.')));
      _kapat();
      return;
    }
    setState(() => _veri = veri);
    _zamanKur();
  }

  void _zamanKur() {
    _zaman?.cancel();
    final toplam = taksiCagriKalani(_veri);
    final soru = _veri['soruZamani'];
    var soruKalan = taksiSoruAraligi;
    if (soru is Timestamp) {
      soruKalan = taksiSoruAraligi - DateTime.now().difference(soru.toDate());
      if (soruKalan.isNegative) soruKalan = Duration.zero;
    }
    final bekle = soruKalan < toplam ? soruKalan : toplam;
    _zaman = Timer(bekle == Duration.zero ? const Duration(seconds: 1) : bekle, () {
      taksiSiradakiAracaSor(widget.doc.id);
    });
  }

  void _kapat() {
    if (_kapandi || !mounted) return;
    _kapandi = true;
    Navigator.of(context).pop();
  }

  bool _ayniTel(Object? a, Object? b) {
    final fs = FirestoreServisi();
    final x = fs.musteriTelefonAnahtari('${a ?? ''}');
    final y = fs.musteriTelefonAnahtari('${b ?? ''}');
    return x.isNotEmpty && x == y;
  }

  Future<void> _reddet() async {
    final sonuc = await taksiSiradakiAracaSor(widget.doc.id, zorla: true);
    if (!mounted) return;
    if (widget.isSofor || sonuc.kapandi) _kapat();
  }

  Future<void> _kabul() async {
    final guncel = await widget.doc.reference.get();
    final talep = guncel.data();
    if (talep is! Map || (talep['durum'] ?? '').toString() != 'bekliyor') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu çağrı kapandı.')));
        _kapat();
      }
      return;
    }
    final veri = Map<String, dynamic>.from(talep);
    GeoPoint? ilkKonum;
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 8));
      ilkKonum = GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {}
    final plaka = veri['plaka'];
    final sofor = widget.soforTel ?? veri['soforTel'] ?? 'Yönetici';
    final yolcuKonum = veri['musteriKonum'];
    double? kabulMetre;
    int? kabulDakika;
    if (ilkKonum != null && yolcuKonum is GeoPoint) {
      kabulMetre = Geolocator.distanceBetween(
        ilkKonum.latitude,
        ilkKonum.longitude,
        yolcuKonum.latitude,
        yolcuKonum.longitude,
      );
      kabulDakika = taksiDakika(ilkKonum, yolcuKonum);
    }
    final kabul = await taksiCagriyiKabulEt(widget.doc.reference, {
      'durum': 'yolda',
      'soforTel': sofor,
      'kabulZamani': FieldValue.serverTimestamp(),
      'gidilenMetre': 0,
      if (ilkKonum != null) 'soforKonum': ilkKonum,
      if (ilkKonum != null) 'kabulKonum': ilkKonum,
      if (kabulMetre != null) 'kabulMesafeMetre': kabulMetre,
      if (kabulDakika != null) 'kabulTahminiDakika': kabulDakika,
    });
    if (!kabul) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu çağrı kapandı.')));
        _kapat();
      }
      return;
    }
    final tel = (veri['musteriTel'] ?? veri['kullaniciTel'] ?? '').toString();
    if (tel.isNotEmpty) {
      BildirimServisi.bildirimGonder(
        kullaniciTel: tel,
        baslik: 'Taksiniz Yolda!',
        icerik: plaka != null ? '$plaka plakalı aracımız yola çıktı, size doğru geliyor.' : 'Aracımız yola çıktı, size doğru geliyor.',
      );
    }
    if (plaka != null) {
      final esDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
      if (esDoc.exists) {
        final gAraclar = List.from(esDoc.data()?['araclar'] ?? []);
        final i = gAraclar.indexWhere((a) => a is Map && a['plaka'] == plaka);
        if (i != -1) {
          gAraclar[i]['durakta'] = false;
          gAraclar[i]['siraZamani'] = 0;
          gAraclar[i]['durum'] = 'Meşgul';
          await esDoc.reference.update({'araclar': gAraclar});
        }
      }
    }
    final konum = veri['musteriKonum'];
    final adres = (veri['adres'] ?? '').toString();
    final otomatik = widget.esnaf.taksiNavigasyonOtomatik;
    if (!mounted) return;
    final ana = Navigator.of(context, rootNavigator: true);
    _kapat();
    if (widget.isSofor) {
      TaksiKonumAkisi.baslat(
        esnafId: widget.esnaf.id,
        soforTel: '$sofor',
        plaka: plaka?.toString(),
      );
    }
    if (otomatik) {
      _navigasyonAc(konum);
    } else {
      _navigasyonSor(ana.context, konum, adres);
    }
  }

  Future<void> _navigasyonAc(dynamic konum) async {
    if (konum is! GeoPoint) return;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${konum.latitude},${konum.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _navigasyonSor(BuildContext ana, dynamic konum, String adres) {
    if (konum is! GeoPoint) return;
    showDialog<void>(
      context: ana,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Navigasyon'),
        content: Text('Müşterinin konumuna navigasyon başlatılsın mı?\n\nAdres: ${adres.isEmpty ? 'Belirtilmedi' : adres}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hayır')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigasyonAc(konum);
            },
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _veri;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_taxi, size: 50, color: Colors.orange),
            const SizedBox(height: 15),
            const Text('Yeni Taksi Talebi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            const Text('25 saniye cevap yoksa sıradaki araca geçer.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            _satir(Icons.person, 'Müşteri', '${data['musteriAd'] ?? 'Müşteri'}'),
            _satir(Icons.phone, 'Telefon', '${data['musteriTel'] ?? 'Bilinmiyor'}'),
            _satir(Icons.location_on, 'Alış', '${data['adres'] ?? 'Konum belirtilmemiş'}'),
            if ((data['nereye'] ?? '').toString().trim().isNotEmpty) _satir(Icons.flag, 'Varış', '${data['nereye']}'),
            if (data['plaka'] != null) _satir(Icons.directions_car, 'Araç', '${data['plaka']}'),
            const SizedBox(height: 8),
            Text('Tahmini geliş: ${data['tahminiSure'] ?? '--'} dk', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _reddet,
                    child: const Text('Reddet', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _kabul,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text('Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _satir(IconData ikon, String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(child: Text('$baslik: $deger', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
