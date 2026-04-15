import 'package:flutter/material.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import 'esnaf_paneli.dart'; // Panelin olduğu dosya yolu

class EsnafGirisEkrani extends StatefulWidget {
  const EsnafGirisEkrani({super.key});

  @override
  State<EsnafGirisEkrani> createState() => _EsnafGirisEkraniState();
}

class _EsnafGirisEkraniState extends State<EsnafGirisEkrani> {
  final _telController = TextEditingController();
  bool _loading = false;
  final _firestoreServisi = FirestoreServisi();

  void _girisYap(String? telInput) async {
    String tel = telInput ?? _telController.text.trim();
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen telefon numaranızı girin.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Firebase'den bu numaraya sahip esnafı çekiyoruz
      final esnaf = await _firestoreServisi.telefonIleEsnafGetir(tel);

      if (!mounted) return;
      setState(() => _loading = false);

      if (esnaf != null) {
        // BAŞARILI: Esnaf bulundu, panele gönder
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => EsnafPanelEkrani(esnaf: esnaf)),
        );
      } else {
        // HATA: Numara veritabanında yok
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bu numara ile kayıtlı bir dükkan bulunamadı!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Giriş hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AlmEly Esnaf Girişi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 80, color: Colors.indigo),
            const SizedBox(height: 30),
            TextField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefon Numaranız",
                hintText: "05xx xxx xx xx",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.indigo,
              ),
              onPressed: () => _girisYap(null),
              child: const Text("Giriş Yap", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const Text("Hızlı Giriş (Geliştirme Modu)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<List<EsnafModeli>>(
              stream: _firestoreServisi.esnaflariGetir(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final esnaflar = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: esnaflar.length,
                  itemBuilder: (context, index) {
                    final e = esnaflar[index];
                    return Card(
                      child: ListTile(
                        title: Text(e.isletmeAdi),
                        subtitle: Text(e.telefon),
                        leading: const Icon(Icons.business, color: Colors.indigo),
                        onTap: () => _girisYap(e.telefon),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}