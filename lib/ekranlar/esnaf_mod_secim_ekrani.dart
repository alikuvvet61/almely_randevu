import 'package:flutter/material.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../widgets/ortak_profil_sayfasi.dart';
import '../widgets/profil_dairesi.dart';
import '../widgets/sallanan_profil_ikonu.dart';
import 'ana_ekran.dart';
import 'esnaf_paneli.dart';
import 'arac_kiralama/arac_kiralama_esnaf_paneli.dart';

/// Taksi dışı esnaf girişinde: Müşteri veya Yönetici seçimi.
class EsnafModSecimEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String girisTel;

  const EsnafModSecimEkrani({super.key, required this.esnaf, required this.girisTel});

  @override
  State<EsnafModSecimEkrani> createState() => _EsnafModSecimEkraniState();
}

class _EsnafModSecimEkraniState extends State<EsnafModSecimEkrani> {
  Map<String, dynamic>? _kayit;

  bool get _aracKiralama {
    final kat = widget.esnaf.kategori.trim().toLowerCase();
    return kat == 'araç kiralama' || kat == 'arac kiralama';
  }

  @override
  void initState() {
    super.initState();
    _kisiyiYukle();
  }

  Future<void> _kisiyiYukle() async {
    final kayit = await FirestoreServisi().kullaniciKaydiBul(widget.girisTel);
    if (!mounted) return;
    setState(() => _kayit = kayit);
  }

  String get _ad => (_kayit?['adSoyad'] ?? _kayit?['ad'] ?? '').toString().trim();

  String get _foto => (_kayit?['fotoUrl'] ?? '').toString().trim();

  void _profilAc() {
    ortakProfilAc(
      context: context,
      telefon: widget.girisTel,
      isletmeDuzenle: (e) {
        final Widget sayfa = _aracKiralama
            ? AracKiralamaEsnafPaneli(esnaf: e, isletmeFormunuAc: true)
            : EsnafPaneli(esnaf: e, isletmeFormunuAc: true);
        Navigator.push(context, MaterialPageRoute(builder: (c) => sayfa));
      },
      profilKapandi: () {
        if (mounted) _kisiyiYukle();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final esnaf = widget.esnaf;
    final soforTel = (esnaf.telefon != widget.girisTel) ? widget.girisTel : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Giriş Modu Seçin"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          SallananProfilIkonu(
            salla: false,
            tooltip: 'Profilim',
            ikon: ProfilDairesi(fotoUrl: _foto, boyut: 32),
            onPressed: _profilAc,
          ),
          const SizedBox(width: 48),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfilDairesi(fotoUrl: _foto, boyut: 84, onTap: _profilAc),
              if (_ad.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _ad,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                "Sistem sizi tanıdı!",
                style: TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                "${esnaf.isletmeAdi} bünyesinde kayıtlısınız.",
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _modKarti(
                context,
                baslik: "Müşteri",
                aciklama: "Hizmet ve randevulardan faydalanın",
                ikon: Icons.person_search_rounded,
                renk: Colors.blue,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: widget.girisTel)),
                  );
                },
              ),
              const SizedBox(height: 20),
              _modKarti(
                context,
                baslik: "Yönetici",
                aciklama: "İşletmenizi yönetin",
                ikon: Icons.admin_panel_settings_rounded,
                renk: Colors.indigo,
                onTap: () {
                  if (_aracKiralama) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (c) => AracKiralamaEsnafPaneli(esnaf: esnaf, soforTel: soforTel),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (c) => EsnafPaneli(esnaf: esnaf, soforTel: soforTel),
                      ),
                    );
                  }
                },
              ),
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
            ),
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
