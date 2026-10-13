import 'package:flutter/material.dart';

import 'package:almely_randevu/yardimcilar/mesai_saati_sec.dart';

/// Taksi ve araç kiralama kurulum ekranlarının ortak çerçevesi.
class HizliKurulumKabugu extends StatelessWidget {
  const HizliKurulumKabugu({
    super.key,
    required this.adim,
    required this.toplam,
    required this.baslik,
    required this.icerik,
    required this.ileri,
    this.maviUst,
    this.secim = '',
    this.engel,
    this.kaydediliyor = false,
    this.son = false,
    this.geri,
    this.baslikGoster = true,
  });

  final int adim;
  final int toplam;
  final String baslik;
  final String? maviUst;
  final Widget icerik;
  final String secim;
  final String? engel;
  final bool kaydediliyor;
  final bool son;
  final bool baslikGoster;
  final VoidCallback? geri;
  final VoidCallback? ileri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hızlı Kurulum · ${adim + 1}/$toplam')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (adim + 1) / toplam),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (baslikGoster) ...[
                    Text(baslik, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ],
                  if (maviUst != null) ...[
                    hizliMaviKutu(maviUst!),
                    const SizedBox(height: 16),
                  ],
                  icerik,
                ],
              ),
            ),
          ),
          if (engel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(engel!, style: const TextStyle(color: Colors.red)),
            ),
          if (secim.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(secim, style: TextStyle(height: 1.35, color: Colors.green.shade900)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (geri != null)
                  OutlinedButton(
                    onPressed: kaydediliyor ? null : geri,
                    child: const Text('Geri'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: engel != null || kaydediliyor ? null : ileri,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: Text(kaydediliyor ? 'Kaydediliyor' : (son ? 'Bitir' : 'İleri')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget hizliMaviKutu(String metin) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(metin, style: TextStyle(height: 1.35, color: Colors.blue.shade900)),
  );
}

Widget hizliEvetHayir(String soru, String mavi, bool evet, ValueChanged<bool> yaz) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(soru, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 10),
      hizliMaviKutu(mavi),
      const SizedBox(height: 12),
      Row(
        children: [
          ChoiceChip(
            label: const Text('Evet'),
            selected: evet,
            onSelected: (_) => yaz(true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Hayır'),
            selected: !evet,
            onSelected: (_) => yaz(false),
          ),
        ],
      ),
    ],
  );
}

Widget hizliRadyo(String baslik, String alt, bool secili, VoidCallback yaz) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      secili ? Icons.radio_button_checked : Icons.radio_button_off,
      color: secili ? Colors.indigo : Colors.grey,
    ),
    title: Text(baslik),
    subtitle: alt.isEmpty ? null : Text(alt),
    onTap: yaz,
  );
}

Widget hizliSaatKutu(BuildContext context, String etiket, String deger, ValueChanged<String> yaz) {
  return InkWell(
    onTap: () async {
      final t = await mesaiSaatiSec(context, baslik: etiket, secili: deger.contains(':') ? deger : '09:00');
      if (t != null) yaz(t);
    },
    child: Column(
      children: [
        Text(etiket, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          deger,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: deger == 'Seçilmedi' ? Colors.red : Colors.blue,
          ),
        ),
      ],
    ),
  );
}

Widget hizliGunler(Map<String, bool> gunler, VoidCallback degisti) {
  return Column(
    children: [
      for (final gun in gunler.keys)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(gun),
          value: gunler[gun] ?? false,
          onChanged: (v) {
            gunler[gun] = v ?? false;
            degisti();
          },
        ),
    ],
  );
}

Widget hizliOzetSatiri(String satir) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(satir, style: const TextStyle(height: 1.35)),
  );
}

Widget hizliKurulumDugmesi(VoidCallback ac) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: ac,
        icon: const Icon(Icons.flash_on),
        label: const Text('Hızlı Kurulum'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
  );
}
