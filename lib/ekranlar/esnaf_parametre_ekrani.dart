import 'package:flutter/material.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';

class EsnafParametreEkrani extends StatefulWidget {
  final String esnafId;
  const EsnafParametreEkrani({super.key, required this.esnafId});

  @override
  State<EsnafParametreEkrani> createState() => _EsnafParametreEkraniState();
}

class _EsnafParametreEkraniState extends State<EsnafParametreEkrani> {
  final _firestoreServisi = FirestoreServisi();
  bool _yukleniyor = true;
  EsnafModeli? _esnaf;

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  Future<void> _verileriGetir() async {
    _firestoreServisi.esnafGetir(widget.esnafId).first.then((esnaf) {
      if (mounted) {
        setState(() {
          _esnaf = esnaf;
          _yukleniyor = false;
        });
      }
    });
  }

  Future<void> _guncelle(Map<String, dynamic> veriler) async {
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnafId, veriler);
      _verileriGetir();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ayarlar güncellendi"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor || _esnaf == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("İşletme Parametreleri")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _parametreKart(
            baslik: "Randevu Onay Modu",
            altBaslik: "Yeni gelen randevular otomatik mi onaylansın yoksa siz mi onaylayacaksınız?",
            icerik: DropdownButtonFormField<String>(
              initialValue: _esnaf!.randevuOnayModu.isEmpty ? 'Manuel' : _esnaf!.randevuOnayModu,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: const [
                DropdownMenuItem(value: 'Manuel', child: Text("Manuel (Ben onaylayacağım)")),
                DropdownMenuItem(value: 'Otomatik', child: Text("Otomatik (Anında onaylansın)")),
              ],
              onChanged: (v) {
                if (v != null) {
                  _guncelle({'randevuOnayModu': v});
                }
              },
            ),
          ),
          const SizedBox(height: 15),
          _parametreKart(
            baslik: "Aynı Gün Randevu Engelleme",
            altBaslik: "Bir müşteri aynı gün içerisinde sadece 1 randevu alabilsin mi?",
            icerik: SwitchListTile(
              title: const Text("Aktif Et", style: TextStyle(fontSize: 14)),
              value: _esnaf!.ayniGunRandevuEngelle,
              onChanged: (v) => _guncelle({'ayniGunRandevuEngelle': v}),
            ),
          ),
          const SizedBox(height: 15),
          _parametreKart(
            baslik: "Slot Görünüm Modu",
            altBaslik: "Randevu saatleri '10:00' yerine '10:00 - 11:00' şeklinde mi görünsün? (Örn: Halı Sahalar için)",
            icerik: SwitchListTile(
              title: const Text("Aralıklı Göster", style: TextStyle(fontSize: 14)),
              value: _esnaf!.slotAralikliGoster,
              onChanged: (v) => _guncelle({'slotAralikliGoster': v}),
            ),
          ),
          const SizedBox(height: 15),
          _parametreKart(
            baslik: "Personel Odaklı Randevu Sistemi",
            altBaslik: "Müşteri kanal/saha yerine personeli seçsin. Randevu personelin bağlı olduğu kanala/sahaya alınır. Bu seçenek açıldığında personel seçimi zorunlu olur.",
            icerik: SwitchListTile(
              title: const Text("Personel Adına Alınsın", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              value: _esnaf!.randevularPersonelAdinaAlinsin,
              onChanged: (v) async {
                // Yerel durumu hemen güncelle ki UI tepki versin
                setState(() {
                  _esnaf = _esnaf!.copyWith(
                    randevularPersonelAdinaAlinsin: v,
                    personelSecimiZorunlu: v,
                  );
                });
                // Firestore'u güncelle
                await _guncelle({
                  'randevularPersonelAdinaAlinsin': v,
                  'personelSecimiZorunlu': v,
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _parametreKart({required String baslik, required String altBaslik, required Widget icerik}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 8),
            Text(altBaslik, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            icerik,
          ],
        ),
      ),
    );
  }
}
