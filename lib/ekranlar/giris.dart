import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'Admin_Paneli/admin_ekrani.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/versiyon_servisi.dart';
import '../servisler/onesignal_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import 'package:permission_handler/permission_handler.dart';
import 'kullanici_randevu_ekrani.dart';
import 'rehber_ekrani.dart';
import '../main.dart'; // navigatorKey için


import 'taksi/taksi_durak_takip_ekrani.dart';
import 'taksi/taksi_esnaf_paneli.dart';
import 'taksi/taksi_mod_secim_ekrani.dart';
import 'taksi/taksi_talep_dialogu.dart';
import 'esnaf_mod_secim_ekrani.dart';
import 'ana_ekran.dart';
import '../yardimcilar/telefon_girdisi.dart';


class GirisSecimSayfasi extends StatefulWidget {
  const GirisSecimSayfasi({super.key});

  @override
  State<GirisSecimSayfasi> createState() => _GirisSecimSayfasiState();
}

class _GirisSecimSayfasiState extends State<GirisSecimSayfasi> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _adController = TextEditingController();
  bool _loading = false;
  bool _yeniKayit = false;
  String _bekleyenTel = '';
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

  @override
  void dispose() {
    _telController.dispose();
    _adController.dispose();
    super.dispose();
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
      if (data != null && data['action'] == 'taksi_cagri' && data['esnafId'] != null) {
        OneSignalServisi.sonTiklananVeri = null;
        _taksiCagrisinaGit(data['esnafId'].toString());
        return;
      }
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

  Future<void> _taksiCagrisinaGit(String esnafId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('esnaflar').doc(esnafId).get();
      if (!doc.exists || !mounted) return;
      final esnaf = EsnafModeli.fromFirestore(doc);
      final tel = TaksiOturum.telefon;
      final fs = FirestoreServisi();
      final yonetici = tel.isNotEmpty && fs.musteriTelefonAnahtari(tel) == fs.musteriTelefonAnahtari(esnaf.telefon);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => yonetici
              ? TaksiEsnafPaneli(esnaf: esnaf)
              : TaksiDurakTakipEkrani(esnaf: esnaf, soforTel: tel.isEmpty ? null : tel),
        ),
      );
    } catch (e) {
      debugPrint('Taksi çağrısı açılamadı: $e');
    }
  }

  void _girisYap() async {
    String tel = _telController.text.trim();
    // Test aşaması için kısa numara (örn: 113) kısıtlaması geçici olarak esnetildi
    if (!TelefonGirdisi.gecerli(tel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TelefonGirdisi.hata(tel) ?? 'Geçerli bir telefon yazın.')),
      );
      return;
    }
    tel = TelefonGirdisi.rakamlar(tel);
    TaksiOturum.telefon = tel;

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
        // Taksi → 3 mod (müşteri/sürücü/yönetici); diğer kategoriler → müşteri/yönetici
        String kat = esnaf.kategori.trim().toLowerCase();
        if (kat == 'taksi') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => TaksiModSecimEkrani(esnaf: esnaf, girisTel: tel))
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => EsnafModSecimEkrani(esnaf: esnaf, girisTel: tel))
          );
        }
        return;
      }

      final kayit = await _firestoreServisi.kullaniciKaydiBul(tel);
      final ad = (kayit?['adSoyad'] ?? '').toString().trim();
      if (!mounted) return;
      if (ad.isEmpty) {
        setState(() {
          _yeniKayit = true;
          _bekleyenTel = tel;
          _adController.clear();
        });
        return;
      }
      _musteriyeGit(tel);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Giriş Hatası: $e");
    }
  }

  void _musteriyeGit(String tel) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: tel)),
    );
  }

  Future<void> _kaydiTamamla() async {
    final ad = _adController.text.trim();
    if (ad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad yazın.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _firestoreServisi.kullaniciProfiliniGuncelle(_bekleyenTel, {
        'adSoyad': ad,
        'telefon': _bekleyenTel,
        'kayitTarihi': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _musteriyeGit(_bekleyenTel);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt açılamadı: $e')),
        );
      }
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
              height: 210,
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  _logoTiklamaSayisi++;
                  if (_logoTiklamaSayisi >= 5) {
                    _logoTiklamaSayisi = 0;
                    _adminGirisiniAc();
                  }
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dpr = MediaQuery.devicePixelRatioOf(context);
                    final w = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : 340.0;
                    return Image.asset(
                      'assets/AlmEly.png',
                      width: w.clamp(260, 380),
                      height: 210,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      isAntiAlias: true,
                      gaplessPlayback: true,
                      cacheWidth: (400 * dpr).round(),
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.business_center,
                                size: 80, color: Colors.blue),
                          ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Zamanınız bizim için kıymetli.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.blueGrey,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "Hoş Geldiniz",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "İşlemlerinize devam etmek için telefon numaranızla giriş yapın. İlk girişte adınız kaydedilir. SMS gerekmez.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _telController,
              enabled: !_yeniKayit,
              keyboardType: TextInputType.phone,
              inputFormatters: TelefonGirdisi.bicim,
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

            if (_yeniKayit) ...[
              TextField(
                controller: _adController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  helperText: '$_bekleyenTel ilk kez giriyor. Bu ad kişi kaydına yazılır.',
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const CircularProgressIndicator()
            else if (_yeniKayit)
              ElevatedButton(
                onPressed: _kaydiTamamla,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 3,
                ),
                child: const Text('Kaydı tamamla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
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
            if (_yeniKayit && !_loading)
              TextButton(
                onPressed: () => setState(() => _yeniKayit = false),
                child: const Text('Numarayı değiştir'),
              ),
            
            const SizedBox(height: 15),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RehberEkrani())),
              icon: const Icon(Icons.help_outline_rounded, color: Colors.blueGrey),
              label: const Text("Kullanım Rehberi & Yardım", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            ),
            
            const SizedBox(height: 50),
            Text(
              "© 2026 AlmEly Go Hizmet & Randevu",
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
