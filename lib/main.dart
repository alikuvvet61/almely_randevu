import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'servisler/bildirim_servisi.dart';
import 'ekranlar/esnaf_giris_ekrani.dart';
import 'ekranlar/ana_ekran.dart'; 
import 'ekranlar/admin_ekrani.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Türkçe tarih formatlarını başlat
  await initializeDateFormatting('tr_TR', null);

  // Bildirim servisini başlat
  await BildirimServisi.initialize();

  try {
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
      // Türkçe Dil Desteği
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
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

class KullaniciGirisSayfasi extends StatefulWidget {
  const KullaniciGirisSayfasi({super.key});

  @override
  State<KullaniciGirisSayfasi> createState() => _KullaniciGirisSayfasiState();
}

class _KullaniciGirisSayfasiState extends State<KullaniciGirisSayfasi> {
  final TextEditingController _telController = TextEditingController();

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
      child: Column(children: [
        TextField(
            controller: _telController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Telefon (Hızlı Giriş)', 
                hintText: '05xx xxx xx xx',
                border: OutlineInputBorder())),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: () {
            if (_telController.text.length >= 10) {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: _telController.text))
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Lütfen geçerli bir telefon numarası girin."))
              );
            }
          },
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
            obscureText: true,
            decoration: InputDecoration(
                labelText: "Yönetici Şifresi", border: OutlineInputBorder())),
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