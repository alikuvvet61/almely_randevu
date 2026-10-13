import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../yardimcilar/hizmet_paketi.dart';

class HizmetPaketSecici extends StatelessWidget {
  final EsnafModeli esnaf;
  final List<Map<String, dynamic>> seciliHizmetler;
  final bool tekrarlayan;
  final String telefon;
  final ValueNotifier<PaketSecimi?> secim;
  final FirestoreServisi firestore;
  final double tekUcret;
  final bool tekUcretGoster;

  const HizmetPaketSecici({
    super.key,
    required this.esnaf,
    required this.seciliHizmetler,
    required this.tekrarlayan,
    required this.telefon,
    required this.secim,
    required this.firestore,
    this.tekUcret = 0,
    this.tekUcretGoster = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!HizmetPaketi.uygunMu(esnaf.kategori) || seciliHizmetler.length != 1) {
      return const SizedBox.shrink();
    }
    if (HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(seciliHizmetler.first))) {
      return const SizedBox.shrink();
    }
    if (tekrarlayan) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Tekrarlayan seride paket kullanılmaz. Her gelişi ayrı randevu olarak yazın, hak o zaman düşer.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
        ),
      );
    }

    final hizmet = Map<String, dynamic>.from(seciliHizmetler.first);
    final tanimlar = HizmetPaketi.aktifTanimlar(hizmet);
    final hizmetAdi = (hizmet['isim'] ?? '').toString();
    final birim = HizmetPaketi.hakBirimi(esnaf.kategori);
    final tekBaslik = HizmetPaketi.diyetisyenMi(esnaf.kategori) ? 'Tek kontrol' : 'Tek $birim';
    final ucretYazi = tekUcretGoster
        ? (tekUcret > 0 ? '${tekUcret.toStringAsFixed(0)} TL. ' : 'Ücretsiz. ')
        : '';

    return StreamBuilder<List<MusteriPaketKaydi>>(
      stream: firestore.musteriPaketleri(telefon),
      builder: (context, snapshot) {
        final haklar = (snapshot.data ?? [])
            .where((k) => k.esnafId == esnaf.id && k.hizmetAdi == hizmetAdi && k.kullanilabilir)
            .toList();
        if (tanimlar.isEmpty && haklar.isEmpty) return const SizedBox.shrink();

        return ValueListenableBuilder<PaketSecimi?>(
          valueListenable: secim,
          builder: (context, secili, _) {
            final gecerli = secili != null && secili.hizmetAdi == hizmetAdi;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paket', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$tekBaslik fiyatı yalnızca o satırdadır. Paket seçilirse karttaki tek ücret uygulanmaz; tahsilat işletmede yapılır.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  _secenek(
                    secili: !gecerli,
                    baslik: tekBaslik,
                    alt: '${ucretYazi}Bu gelişin ücreti. Paketten hak düşmez.',
                    onTap: () => secim.value = null,
                  ),
                  for (final hak in haklar)
                    _secenek(
                      secili: gecerli && secili.tur == 'hak' && secili.kayitId == hak.id,
                      baslik: 'Paketten kullan · ${hak.paketAdi}',
                      alt: '${hak.durumYazisi} · ${DateFormat('dd.MM.yyyy').format(hak.bitis)} tarihine kadar',
                      onTap: () => secim.value = PaketSecimi(
                        tur: 'hak',
                        hizmetAdi: hizmetAdi,
                        ad: hak.paketAdi,
                        kayitId: hak.id,
                      ),
                    ),
                  for (final tanim in tanimlar)
                    _secenek(
                      secili: gecerli && secili.tur == 'al' && secili.tanimId == tanim.id,
                      baslik: tanim.ad,
                      alt: '${tanim.gecerlilikGun} günde ${tanim.seans} $birim'
                          '${tanim.ucret > 0 ? ' ${tanim.ucret.toStringAsFixed(0)} TL' : ''}',
                      onTap: () => secim.value = PaketSecimi(
                        tur: 'al',
                        hizmetAdi: hizmetAdi,
                        ad: tanim.ad,
                        tanimId: tanim.id,
                        seans: tanim.seans,
                        gecerlilikGun: tanim.gecerlilikGun,
                        ucret: tanim.ucret,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _secenek({
    required bool secili,
    required String baslik,
    required String alt,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: secili ? Colors.white : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: secili ? Colors.indigo : Colors.transparent, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(alt, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
