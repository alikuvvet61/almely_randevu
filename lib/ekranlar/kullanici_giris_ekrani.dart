import 'package:flutter/material.dart';
import 'ana_ekran.dart';
import '../servisler/bildirim_servisi.dart';

class KullaniciGirisSayfasi extends StatefulWidget {
  const KullaniciGirisSayfasi({super.key});

  @override
  State<KullaniciGirisSayfasi> createState() => _KullaniciGirisSayfasiState();
}

class _KullaniciGirisSayfasiState extends State<KullaniciGirisSayfasi> {
  final TextEditingController _telController = TextEditingController();
  bool _loading = false;

  void _girisYap() {
    String tel = _telController.text.trim();
    if (tel.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen geçerli bir telefon numarası girin."))
      );
      return;
    }

    setState(() => _loading = true);
    
    // Bildirimleri dinlemeye başla ve ana ekrana geç
    BildirimServisi.bildirimDinle(tel);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: tel))
      );
    });
  }

  @override
  void dispose() {
    _telController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kullanıcı Girişi')),
    body: Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_pin_circle, size: 80, color: Colors.blue),
          const SizedBox(height: 30),
          const Text(
            "Hoş Geldiniz",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Randevu almak için telefon numaranızla giriş yapın.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          TextField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefon Numaranız', 
                  hintText: '05xx xxx xx xx',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))))),
          const SizedBox(height: 25),
          _loading 
            ? const CircularProgressIndicator()
            : ElevatedButton(
              onPressed: _girisYap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: const Text("Giriş Yap", style: TextStyle(fontSize: 18)),
            ),
        ],
      ),
    ),
  );
}
