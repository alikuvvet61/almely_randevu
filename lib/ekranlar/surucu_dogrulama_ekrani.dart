import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import '../widgets/ana_buton.dart';

class SurucuDogrulamaEkrani extends StatefulWidget {
  final EsnafModeli esnaf;

  const SurucuDogrulamaEkrani({super.key, required this.esnaf});

  @override
  State<SurucuDogrulamaEkrani> createState() => _SurucuDogrulamaEkraniState();
}

class _SurucuDogrulamaEkraniState extends State<SurucuDogrulamaEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _picker = ImagePicker();
  
  final Map<String, File?> _yuklenenDosyalar = {
    'ehliyet': null,
    'sigorta': null,
    'plaka_belgesi': null,
    'profil': null,
  };

  bool _yukleniyor = false;

  Future<void> _fotoSec(String tur) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (image != null) {
      setState(() {
        _yuklenenDosyalar[tur] = File(image.path);
      });
    }
  }

  Future<void> _belgeleriGonder() async {
    if (_yuklenenDosyalar.values.any((element) => element == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm belgeleri yükleyin.")),
      );
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      // Not: Normalde burada Firebase Storage'a yükleme yapılıp URL alınmalı.
      // Şimdilik plan gereği URL'leri mockluyoruz veya servis üzerinden ilerliyoruz.
      // FirestoreServisi.surucuBelgeleriniGuncelle metodunu tetikliyoruz.
      
      Map<String, String> urls = {
        'ehliyet': 'mock_url_ehliyet',
        'sigorta': 'mock_url_sigorta',
        'plaka_belgesi': 'mock_url_plaka',
        'profil': 'mock_url_profil',
      };

      await _firestoreServisi.surucuBelgeleriniGuncelle(widget.esnaf.id, urls);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Başarılı"),
            content: const Text("Belgeleriniz incelemeye alındı. Admin onayından sonra bildirim alacaksınız."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("TAMAM"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Widget _dosyaKarti(String baslik, String tur, IconData ikon) {
    bool yuklendi = _yuklenenDosyalar[tur] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: yuklendi ? Colors.green : Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(ikon, color: yuklendi ? Colors.green : Colors.indigo),
        title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(yuklendi ? "Dosya Hazır" : "Fotoğraf çekmek için tıklayın"),
        trailing: yuklendi 
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.camera_alt_outlined),
        onTap: () => _fotoSec(tur),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sürücü Doğrulama")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dünya Standartlarında Güvenlik",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 10),
            const Text(
              "Lütfen aşağıdaki belgeleri güncel ve okunaklı şekilde sisteme yükleyin. Bu işlem hem sizin hem yolcularımızın güvenliği içindir.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _dosyaKarti("Ehliyet (Ön Yüz)", "ehliyet", Icons.badge_outlined),
            _dosyaKarti("Trafik Sigortası", "sigorta", Icons.description_outlined),
            _dosyaKarti("Plaka Ruhsatı", "plaka_belgesi", Icons.directions_car_outlined),
            _dosyaKarti("Profil Fotoğrafı (Yüzünüz Net Görünmeli)", "profil", Icons.face_outlined),
            const SizedBox(height: 40),
            if (_yukleniyor)
              const Center(child: CircularProgressIndicator())
            else
              AnaButon(metin: "BELGELERİ ONAYA GÖNDER", onPressed: _belgeleriGonder),
          ],
        ),
      ),
    );
  }
}
