import 'package:flutter/material.dart';
import '../modeller/esnaf_modeli.dart';
import 'ana_ekran.dart';
import 'esnaf_paneli.dart';
import 'durak_takip_ekrani.dart';

class ModSecimEkrani extends StatelessWidget {
  final EsnafModeli esnaf;
  final String girisTel;

  const ModSecimEkrani({super.key, required this.esnaf, required this.girisTel});

  @override
  Widget build(BuildContext context) {
    bool isManager = esnaf.telefon == girisTel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Giriş Modu Seçin"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Sistem sizi tanıdı!",
                style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                "${esnaf.isletmeAdi} bünyesinde kayıtlısınız.",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // 1. MÜŞTERİ MODU
              _modKarti(
                context,
                baslik: "Müşteri Modu",
                aciklama: "Randevu al, hizmetleri incele",
                ikon: Icons.person_search_rounded,
                renk: Colors.blue,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: girisTel))
                  );
                },
              ),
              const SizedBox(height: 20),

              // 2. ŞOFÖR MODU
              _modKarti(
                context,
                baslik: "Sürücü Modu",
                aciklama: "Canlı durak takibi ve profil yönetimi",
                ikon: Icons.local_taxi_rounded,
                renk: Colors.green,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => DurakTakipEkrani(esnaf: esnaf, soforTel: girisTel))
                  );
                },
              ),
              
              // 3. YÖNETİCİ MODU (Sadece yönetici tel ise)
              if (isManager) ...[
                const SizedBox(height: 20),
                _modKarti(
                  context,
                  baslik: "Yönetici Modu",
                  aciklama: "Durağı yönet, raporları incele",
                  ikon: Icons.admin_panel_settings_rounded,
                  renk: Colors.indigo,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => EsnafPaneli(esnaf: esnaf))
                    );
                  },
                ),
              ],

              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Farklı bir numara ile giriş yap", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modKarti(
    BuildContext context, {
    required String baslik,
    required String aciklama,
    required IconData ikon,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: renk.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: renk.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, color: renk, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: renk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aciklama,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: renk.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
