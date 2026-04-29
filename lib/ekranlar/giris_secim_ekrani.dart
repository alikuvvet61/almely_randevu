import 'package:flutter/material.dart';
import 'kullanici_giris_ekrani.dart';
import 'esnaf_giris_ekrani.dart';
import 'admin_giris_ekrani.dart';

class GirisSecimSayfasi extends StatelessWidget {
  const GirisSecimSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/AlmEly.png',
                width: 220,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.business_center, size: 80, color: Colors.blue),
              ),
              const SizedBox(height: 40),
              _anaButon(context, "Müşteri Girişi", Colors.blue, Colors.white, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const KullaniciGirisSayfasi()));
              }),
              const SizedBox(height: 15),
              _anaButon(context, "Esnaf Paneli", Colors.indigo, Colors.white, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const EsnafGirisEkrani()));
              }),
              const SizedBox(height: 15),
              _anaButon(context, "Yönetici Girişi", Colors.white, Colors.blue, () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminGirisSayfasi()));
              }, kenar: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _anaButon(BuildContext context, String m, Color r, Color y, VoidCallback t, {bool kenar = false}) {
    IconData icon = Icons.person;
    if (m.contains("Esnaf")) icon = Icons.business;
    if (m.contains("Yönetici")) icon = Icons.admin_panel_settings;
    
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(280, 60),
        backgroundColor: r,
        side: kenar ? const BorderSide(color: Colors.blue, width: 2) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: t,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: y, size: 24),
          const SizedBox(width: 10),
          Text(m, style: TextStyle(color: y, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
