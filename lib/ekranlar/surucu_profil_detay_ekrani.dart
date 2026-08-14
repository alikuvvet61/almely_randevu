import 'package:flutter/material.dart';
import '../modeller/esnaf_modeli.dart';

class SurucuProfilDetayEkrani extends StatelessWidget {
  final EsnafModeli esnaf;
  final Map<String, dynamic> arac;

  const SurucuProfilDetayEkrani({super.key, required this.esnaf, required this.arac});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Sürücü Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Yardım", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ÜST PROFİL BÖLÜMÜ
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              width: double.infinity,
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.indigo.shade100, width: 2),
                        ),
                        child: const Icon(Icons.person, size: 60, color: Colors.indigo),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    arac['soforAd'] ?? "İsimsiz Sürücü",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      const Text("4.95", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 10),
                      const Text("|", style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text("AKTİF / ÇEVRİMİÇİ", style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // DURUM ÇUBUĞU
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              color: Colors.blue.shade700,
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "DURUM: %85 TAMAMLANDI - 1 Belge Güncelleme Bekliyor",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // BÖLÜMLER
            _bolumBaslik("1. KİMLİK & GÜVENLİK (Uber Standardı)"),
            _listeElemani("Canlı Yüz Doğrulama (Selfie)", "Onaylandı", true),
            _listeElemani("Kimlik / Ehliyet", "Onaylandı", true),

            _bolumBaslik("2. YEREL MEVZUAT & LİSANSLAR (BiTaksi & Singapur)"),
            _listeElemani("TUDES / PDVL Şoför Kartı", "Onaylandı", true),
            _listeElemani("Adli Sicil Kaydı (QR)", "Süresi Doldu / Yenile", false, uyari: true),
            _listeElemani("Psikoteknik Raporu", "Onaylandı", true),

            _bolumBaslik("3. ARAÇ VE HİZMET SINIFI"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Plaka: ${arac['plaka'] ?? ''} (Sarı Taksi / BiTaksi)", style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text("Hizmet: Comfort / VIP (Uber XL)", style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            _listeElemani("Ruhsat & Trafik Sigortası", "Onaylandı", true),
            _listeElemani("Araç Görselleri (4 Açı)", "Onaylandı", true),

            _bolumBaslik("4. FİNANS VE HAK EDİŞ"),
            _finansElemani("Banka", "TR12 0006 2000 ... 4567", "Güncelle"),
            _finansElemani("Bağlı Filo", esnaf.isletmeAdi, "Detay"),

            const SizedBox(height: 40),
            
            // GÜNCELLEME BUTONU
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("TÜM BİLGİLERİ GÜNCELLE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _bolumBaslik(String metin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        metin,
        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }

  Widget _listeElemani(String baslik, String durum, bool onayli, {bool uyari = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: uyari ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            onayli ? Icons.check_circle : (uyari ? Icons.error : Icons.pending),
            color: onayli ? Colors.green : (uyari ? Colors.red : Colors.orange),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            durum,
            style: TextStyle(
              color: onayli ? Colors.green : (uyari ? Colors.red : Colors.orange),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _finansElemani(String baslik, String deger, String aksiyon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(deger, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Row(
              children: [
                Text(aksiyon, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right, size: 18, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
