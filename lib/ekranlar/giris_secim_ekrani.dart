import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'admin_ekrani.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/versiyon_servisi.dart';
import '../servisler/onesignal_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kullanici_randevu_ekrani.dart';
import 'rehber_ekrani.dart';
import '../main.dart'; // navigatorKey için


import 'taksi/taksi_mod_secim_ekrani.dart';
import 'ana_ekran.dart';
import 'esnaf_paneli.dart';


class GirisSecimSayfasi extends StatefulWidget {
  const GirisSecimSayfasi({super.key});

  @override
  State<GirisSecimSayfasi> createState() => _GirisSecimSayfasiState();
}

class _GirisSecimSayfasiState extends State<GirisSecimSayfasi> {
  final TextEditingController _telController = TextEditingController();
  bool _loading = false;
  int _logoTiklamaSayisi = 0;
  final _firestoreServisi = FirestoreServisi();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // [HIZLANDIRMA] Logo resmini önbelleğe alalım ki anında görünsün
    precacheImage(const AssetImage('assets/AlmEly.png'), context);
  }

  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında süreçleri başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersiyonServisi.versiyonKontrol(context);
      _bildirimIzniIste();
      _garantiliDeepLinkKontrol();
      _aktifKullaniciyiKontrolEt();
    });
  }

  void _aktifKullaniciyiKontrolEt() async {
    // [YENİ] Web'de ve Mobil'de mühürlü numarayı takip edelim
    // Eğer bir numara OneSignal üzerinden kaydedilmişse, dinleyiciyi ana ekranda da başlatalım
    if (kIsWeb) {
       // Web tarafında mühürlü cihazı takip ediyoruz
    }
  }

  Future<void> _bildirimIzniIste() async {
    if (kIsWeb) return; // Web'de izin isteme (Hata veriyor)
    
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    // scheduleExactAlarm web'de unimplemented hatası veriyor
    try {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      debugPrint("İzin Hatası (Web olabilir): $e");
    }

    // Paralel başlatma
    await BildirimServisi.initialize();
    if (mounted) await OneSignalServisi.initialize();
  }

  void _garantiliDeepLinkKontrol() {
    // [HIZLANDIRMA] Bekleme süresini optimize ediyoruz
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final data = OneSignalServisi.sonTiklananVeri;
      if (data != null && data['action'] == 'uzatma_ekrani' && data['tel'] != null) {
        String tel = data['tel'].toString();
        String? rId = data['randevuId']?.toString();
        OneSignalServisi.sonTiklananVeri = null; // Tüketilen veriyi hemen temizle

        debugPrint("YÖNLENDİRME BAŞLATILIYOR: Hedef Tel: $tel, Randevu ID: $rId");
        
        // --- AKILLI YÖNLENDİRME ---
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (c) => KullaniciRandevuEkrani(telefon: tel, seciliRandevuId: rId))
        );
      }
    });
  }

  void _girisYap() async {
    String tel = _telController.text.trim();
    // Test aşaması için kısa numara (örn: 113) kısıtlaması geçici olarak esnetildi
    if (tel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir telefon numarası girin."))
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Bildirim Kayıtlarını Başlat
      BildirimServisi.bildirimDinle(tel);
      await OneSignalServisi.kullaniciyiKaydet(tel);

      // 2. Rol Sorgula
      final esnaf = await _firestoreServisi.telefonIleEsnafGetir(tel);

      if (!mounted) return;
      setState(() => _loading = false);

      if (esnaf != null) {
        // Taksi → mod seçim (müşteri/şoför/yönetici); diğer kategoriler → EsnafPaneli
        String kat = esnaf.kategori.trim().toLowerCase();
        if (kat == 'taksi') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => TaksiModSecimEkrani(esnaf: esnaf, girisTel: tel))
          );
        } else {
          String? soforTel = (esnaf.telefon != tel) ? tel : null;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => EsnafPaneli(esnaf: esnaf, soforTel: soforTel))
          );
        }
      } else {
        // NORMAL MÜŞTERİ: Doğrudan ana ekrana
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: tel))
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Giriş Hatası: $e");
    }
  }

  void _adminGirisiniAc() {
    final passC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Yönetici Doğrulaması"),
        content: TextField(
          controller: passC,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Yönetici Şifresi"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              if (passC.text == "6161") {
                Navigator.pop(ctx);
                // Ara ekranı atlayıp doğrudan AdminEkrani'na gidiyoruz
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminEkrani()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!")));
              }
            },
            child: const Text("Giriş Yap"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // [DÜZELTME] İçerik artık yukarıda sabit kalır, zıplama yapmaz
          children: [
            const SizedBox(height: 60), // [YENİ] En üstteki boşluk artık kalıcıdır (Resimdeki kırmızı alan)
            
            // Logo (5 Tıklama ile Admin Paneli)
            SizedBox(
              height: 180, // [GERİ ALINDI] Logo boyutu eski orijinal haline getirildi
              child: GestureDetector(
                onTap: () {
                  _logoTiklamaSayisi++;
                  if (_logoTiklamaSayisi >= 5) {
                    _logoTiklamaSayisi = 0;
                    _adminGirisiniAc();
                  }
                },
                child: Image.asset(
                  'assets/AlmEly.png',
                  width: 220,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                  const Center(child: Icon(Icons.business_center, size: 80, color: Colors.blue)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            const Text(
              "Hoş Geldiniz",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "İşlemlerinize devam etmek için telefon numaranızla giriş yapın.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Telefon Numaranız', 
                hintText: '05xx xxx xx xx',
                prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 25),

            if (_loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _girisYap,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                ),
                child: const Text("Giriş Yap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            
            const SizedBox(height: 15),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RehberEkrani())),
              icon: const Icon(Icons.help_outline_rounded, color: Colors.blueGrey),
              label: const Text("Kullanım Rehberi & Yardım", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 50),
            Text(
              "© 2026 AlmEly Randevu Portalı",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
            
            const SizedBox(height: 30),
            const Divider(),
            const Text(
              "Hızlı Giriş (Geliştirme Modu)", 
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)
            ),
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
                      elevation: 0,
                      color: Colors.grey.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(e.isletmeAdi, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(e.telefon),
                        leading: const Icon(Icons.business, color: Colors.blueGrey, size: 20),
                        onTap: () {
                          _telController.text = e.telefon;
                          _girisYap();
                        },
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
