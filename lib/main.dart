import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'ekranlar/ana_ekran.dart';
import 'ekranlar/admin_ekrani.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8",
          appId: "1:1013564598824:web:ae03d69dd700b7df86a31d",
          messagingSenderId: "1013564598824",
          projectId: "almely-randevu",
          storageBucket: "almely-randevu.firebasestorage.app",
          authDomain: "almely-randevu.firebaseapp.com",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase başlatma hatası: $e");
  }
  runApp(const AlmElyApp());
}

class AlmElyApp extends StatelessWidget {
  const AlmElyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlmEly Randevu Portalı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GirisSecimSayfasi(),
    );
  }
}

class GirisSecimSayfasi extends StatelessWidget {
  const GirisSecimSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
            _anaButon(context, "Kullanıcı Girişi", Colors.blue, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const KullaniciGirisSayfasi()));
            }),
            const SizedBox(height: 15),
            _anaButon(context, "Yönetici Girişi", Colors.white, Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminGirisSayfasi()));
            }, kenarlik: true),
          ],
        ),
      ),
    );
  }

  Widget _anaButon(BuildContext context, String m, Color r, Color y, VoidCallback t, {bool kenarlik = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(280, 60),
        backgroundColor: r,
        side: kenarlik ? const BorderSide(color: Colors.blue, width: 2) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: t,
      child: Text(m, style: TextStyle(color: y, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

class KullaniciGirisSayfasi extends StatelessWidget {
  const KullaniciGirisSayfasi({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kullanıcı Girişi')),
        body: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(children: [
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Telefon (Hızlı Giriş)', border: OutlineInputBorder())),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (c) => const AnaEkran())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
              child: const Text("Giriş Yap"),
            ),
          ]),
        ),
      );
}

class AdminGirisSayfasi extends StatelessWidget {
  const AdminGirisSayfasi({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Admin Girişi")),
        body: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(children: [
            const TextField(
                decoration: InputDecoration(
                    labelText: "Hızlı Giriş Aktif", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (c) => const AdminEkrani())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("Giriş Yap"),
            ),
          ]),
        ),
      );
}
