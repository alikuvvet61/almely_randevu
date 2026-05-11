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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("İşletme Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_esnaf!.kategori != 'Taksi') ...[
            _parametreKart(
              baslik: "Randevu Onay Modu",
              altBaslik: "Yeni gelen randevular otomatik mi onaylansın yoksa siz mi onaylayacaksınız?",
              icon: Icons.approval_rounded,
              icerik: DropdownButtonFormField<String>(
                key: ValueKey(_esnaf!.randevuOnayModu),
                initialValue: _esnaf!.randevuOnayModu.isEmpty ? 'Manuel' : _esnaf!.randevuOnayModu,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Manuel', child: Text("Manuel (Ben onaylayacağım)", style: TextStyle(fontSize: 16))),
                  DropdownMenuItem(value: 'Otomatik', child: Text("Otomatik (Anında onaylansın)", style: TextStyle(fontSize: 16))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _guncelle({'randevuOnayModu': v});
                  }
                },
              ),
            ),
            _parametreKart(
              baslik: "Aynı Gün Randevu",
              altBaslik: "Bir müşteri aynı gün içerisinde sadece 1 randevu alabilsin mi?",
              icon: Icons.event_busy_rounded,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Engelleme Aktif", style: TextStyle(fontSize: 16)),
                value: _esnaf!.ayniGunRandevuEngelle,
                onChanged: (v) => _guncelle({'ayniGunRandevuEngelle': v}),
              ),
            ),
            _parametreKart(
              baslik: "Slot Görünüm Modu",
              altBaslik: "Randevu saatleri '10:00' yerine '10:00 - 11:00' şeklinde mi görünsün? (Örn: Halı Sahalar için)",
              icon: Icons.timer_outlined,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Aralıklı Göster", style: TextStyle(fontSize: 16)),
                value: _esnaf!.slotAralikliGoster,
                onChanged: (v) => _guncelle({'slotAralikliGoster': v}),
              ),
            ),
          ],
          if (_esnaf!.kategori == 'Taksi') ...[
            _parametreKart(
              baslik: "Araç Odaklı Sistem",
              altBaslik: "Randevular doğrudan araç (plaka) adına alınsın.",
              icon: Icons.local_taxi_rounded,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Aktif Et", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                value: _esnaf!.aracOdakliSistem,
                onChanged: (v) async {
                  setState(() {
                    _esnaf = _esnaf!.copyWith(aracOdakliSistem: v);
                  });
                  await _guncelle({'aracOdakliSistem': v});
                },
              ),
            ),
            _parametreKart(
              baslik: "İstirahetli Araçları Gizle",
              altBaslik: "Durumu 'İstirahatte' olan araçlar 'Bugün Çalışan Araçlarımız' listesinde görünmesin.",
              icon: Icons.visibility_off_rounded,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Listede Gizle", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                value: _esnaf!.istirahatliAraclariGizle,
                onChanged: (v) async {
                  setState(() {
                    _esnaf = _esnaf!.copyWith(istirahatliAraclariGizle: v);
                  });
                  await _guncelle({'istirahatliAraclariGizle': v});
                },
              ),
            ),
            _parametreKart(
              baslik: "Konum Doğrulama Mesafesi",
              altBaslik: "Şoförlerin sıraya girebilmesi için durak merkezine maksimum ne kadar uzaklıkta (metre) olması gerektiğini belirleyin.",
              icon: Icons.location_searching_rounded,
              icerik: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _esnaf!.konumDogrulamaMesafesi,
                          min: 5,
                          max: 500,
                          divisions: 99,
                          label: "${_esnaf!.konumDogrulamaMesafesi.round()} m",
                          onChanged: (v) {
                            setState(() {
                              _esnaf = _esnaf!.copyWith(konumDogrulamaMesafesi: v);
                            });
                          },
                          onChangeEnd: (v) => _guncelle({'konumDogrulamaMesafesi': v}),
                        ),
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_esnaf!.konumDogrulamaMesafesi.round()}m",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const Text("Sınır: 5m - 500m", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
          if (_esnaf!.kategori != 'Taksi')
            _parametreKart(
              baslik: "Personel Odaklı Sistem",
              altBaslik: "Müşteri kanal/saha yerine personeli seçsin. Personel seçimi zorunlu hale gelir.",
              icon: Icons.people_alt_rounded,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Aktif Et", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                value: _esnaf!.randevularPersonelAdinaAlinsin,
                onChanged: (v) async {
                  setState(() {
                    _esnaf = _esnaf!.copyWith(
                      randevularPersonelAdinaAlinsin: v,
                      personelSecimiZorunlu: v,
                    );
                  });
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

  Widget _parametreKart({required String baslik, required String altBaslik, required IconData icon, required Widget icerik}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    baslik, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              altBaslik, 
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)
            ),
            const SizedBox(height: 18),
            icerik,
          ],
        ),
      ),
    );
  }
}
