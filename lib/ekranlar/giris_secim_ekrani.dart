import 'package:flutter/material.dart';
import 'kullanici_giris_ekrani.dart';
import 'esnaf_giris_ekrani.dart';
import 'admin_giris_ekrani.dart';
import '../servisler/versiyon_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import 'package:permission_handler/permission_handler.dart';
import '../servisler/onesignal_servisi.dart';
import 'kullanici_randevu_ekrani.dart';

class GirisSecimSayfasi extends StatefulWidget {
  const GirisSecimSayfasi({super.key});

  @override
  State<GirisSecimSayfasi> createState() => _GirisSecimSayfasiState();
}

class _GirisSecimSayfasiState extends State<GirisSecimSayfasi> {
  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında süreçleri başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersiyonServisi.versiyonKontrol(context);
      _bildirimIzniIste();
      _garantiliDeepLinkKontrol();
    });
  }

  Future<void> _bildirimIzniIste() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    // Paralel başlatma
    BildirimServisi.initialize();
    OneSignalServisi.initialize(context: context);
  }

  void _garantiliDeepLinkKontrol() {
    // KRİTİK: Uygulama tamamen çizilene kadar 2.5 saniye bekle (Navigasyon takılmasını önler)
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      
      final data = OneSignalServisi.sonTiklananVeri;
      if (data != null && data['action'] == 'uzatma_ekrani' && data['tel'] != null) {
        String tel = data['tel'].toString();
        OneSignalServisi.sonTiklananVeri = null; // Tüketilen veriyi temizle

        debugPrint("FİNAL DEEP LINK: Uzatma ekranına yönlendiriliyor... Tel: $tel");
        
        // Sarsılmaz Navigasyon: NavigatorState üzerinden doğrudan push yapıyoruz
        Navigator.of(context).push(
          MaterialPageRoute(builder: (c) => KullaniciRandevuEkrani(telefon: tel))
        );
      }
    });
  }

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
