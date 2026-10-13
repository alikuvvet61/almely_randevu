import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/taksi/taksi_guven.dart';

/// Durak, kendi şoförünün belgesini onaylar. Yolcu plakada Belgeli görür.
class TaksiBelgeOnayEkrani extends StatefulWidget {
  final EsnafModeli esnaf;

  const TaksiBelgeOnayEkrani({super.key, required this.esnaf});

  @override
  State<TaksiBelgeOnayEkrani> createState() => _TaksiBelgeOnayEkraniState();
}

class _TaksiBelgeOnayEkraniState extends State<TaksiBelgeOnayEkrani> {
  final FirestoreServisi _db = FirestoreServisi();
  bool _yukleniyor = true;
  List<_SoforBelge> _liste = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final satirlar = <_SoforBelge>[];
    for (final arac in widget.esnaf.araclar) {
      final tel = (arac['soforTel'] ?? '').toString().trim();
      if (tel.isEmpty) continue;
      Map<String, dynamic> belgeler = {};
      String bulunanTel = tel;
      for (final aday in _db.telefonYazimlari(tel)) {
        if (aday.isEmpty) continue;
        final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(aday).get();
        final gelen = doc.data()?['belgeler'];
        if (gelen is Map && gelen.length >= belgeler.length) {
          belgeler = Map<String, dynamic>.from(gelen);
          bulunanTel = aday;
        }
      }
      satirlar.add(_SoforBelge(
        tel: bulunanTel,
        aracTel: tel,
        plaka: (arac['plaka'] ?? '').toString(),
        ad: (arac['soforAd'] ?? '').toString(),
        belgeler: belgeler,
      ));
    }
    if (!mounted) return;
    setState(() {
      _liste = satirlar;
      _yukleniyor = false;
    });
  }

  Future<void> _karar(_SoforBelge sofor, String tur, bool onay) async {
    await _db.belgeOnayla(sofor.tel, tur, onay);
    if (sofor.aracTel != sofor.tel) await _db.belgeOnayla(sofor.aracTel, tur, onay);
    if (mounted) await _yukle();
  }

  Future<void> _ac(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şoför belgeleri'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
              ? const Center(child: Text('Filoda telefonu yazılı şoför yok.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _liste.length,
                  itemBuilder: (context, i) {
                    final sofor = _liste[i];
                    final belgeli = taksiBelgeli(sofor.belgeler);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sofor.plaka.isEmpty ? sofor.ad : '${sofor.plaka} · ${sofor.ad}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              belgeli
                                  ? 'Yolcu bu plakanın yanında Belgeli görür.'
                                  : 'Ehliyet, ruhsat, sigorta ve taksimetre onaylanınca yolcu Belgeli görür.',
                              style: TextStyle(color: belgeli ? Colors.green.shade800 : Colors.black54, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            for (final tur in taksiZorunluBelgeler) _satir(sofor, tur),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _satir(_SoforBelge sofor, String tur) {
    final belge = sofor.belgeler[tur];
    final map = belge is Map ? Map<String, dynamic>.from(belge) : <String, dynamic>{};
    final durum = (map['status'] ?? '').toString();
    final url = (map['url'] ?? '').toString();
    final ad = taksiBelgeAdlari[tur] ?? tur;
    String yazi = 'Yüklenmedi';
    if (durum == 'Onaylandı') yazi = 'Onaylı';
    if (durum == 'Bekliyor') yazi = 'Onay bekliyor';
    if (durum == 'Reddedildi') yazi = 'Reddedildi';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$ad · $yazi'),
          if (url.isNotEmpty)
            TextButton(onPressed: () => _ac(url), child: const Text('Gör')),
          if (durum == 'Bekliyor' || durum == 'Reddedildi')
            TextButton(onPressed: () => _karar(sofor, tur, true), child: const Text('Onayla')),
          if (durum == 'Bekliyor' || durum == 'Onaylandı')
            TextButton(
              onPressed: () => _karar(sofor, tur, false),
              child: const Text('Reddet', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}

class _SoforBelge {
  final String tel;
  final String aracTel;
  final String plaka;
  final String ad;
  final Map<String, dynamic> belgeler;

  _SoforBelge({
    required this.tel,
    required this.aracTel,
    required this.plaka,
    required this.ad,
    required this.belgeler,
  });
}
