import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/storage_servisi.dart';
import '../servisler/onesignal_servisi.dart';
import '../widgets/medya_goruntuleyici.dart';

class KazaBildirimEkrani extends StatefulWidget {
  final RandevuModeli randevu;
  const KazaBildirimEkrani({super.key, required this.randevu});

  @override
  State<KazaBildirimEkrani> createState() => _KazaBildirimEkraniState();
}

class _KazaBildirimEkraniState extends State<KazaBildirimEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _storageServisi = StorageServisi();
  final _picker = ImagePicker();
  
  bool _yukleniyor = false;
  bool _konumAliniyor = false;
  String? _canliKonumLink;
  List<String> _hasarGorselleri = [];

  @override
  void initState() {
    super.initState();
    // Varsa eski kaza verisini yükle
    if (widget.randevu.kazaVerisi != null) {
      _hasarGorselleri = List<String>.from(widget.randevu.kazaVerisi!['gorseller'] ?? []);
      _canliKonumLink = widget.randevu.kazaVerisi!['konumLink'];
    }
  }

  Future<void> _konumGonder() async {
    setState(() => _konumAliniyor = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );
      final link = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
      await _firestoreServisi.randevuGuncelle(widget.randevu.id, {
        'kazaVerisi.konumLink': link,
        'kazaVerisi.konumZamani': DateTime.now().toIso8601String(),
        'durum': 'KAZA BİLDİRİLDİ'
      });

      // [YENİ] Aracı otomatik pasife çek
      if (widget.randevu.randevuKanali != null) {
        await _araciPasifeAl(widget.randevu.esnafId, widget.randevu.randevuKanali!);
      }

      // Esnafa KRİTİK bildirim gönder
      await OneSignalServisi.ozelBildirimGonder(
        baslik: "🚨 ACİL: KAZA BİLDİRİMİ!",
        icerik: "${widget.randevu.kullaniciAd} (${widget.randevu.randevuKanali}) konumunda kaza bildirdi! Haritayı açmak için tıklayın.",
        telefon: widget.randevu.esnafTel,
        ekVeri: {'action': 'kaza_detay', 'link': link}
      );

      setState(() {
        _canliKonumLink = link;
        _konumAliniyor = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Canlı konumunuz esnafa başarıyla iletildi."), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _konumAliniyor = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Konum alınamadı: $e")));
    }
  }

  Future<void> _fotoCek() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (file != null) {
      setState(() => _yukleniyor = true);
      final String? url = await _storageServisi.dosyaYukle(widget.randevu.id, File(file.path), true);
      if (url != null) {
        _hasarGorselleri.add(url);
        await _firestoreServisi.randevuGuncelle(widget.randevu.id, {
          'kazaVerisi.gorseller': _hasarGorselleri,
          'durum': 'KAZA BİLDİRİLDİ'
        });

        // [YENİ] Aracı otomatik pasife çek
        if (widget.randevu.randevuKanali != null) {
          await _araciPasifeAl(widget.randevu.esnafId, widget.randevu.randevuKanali!);
        }
      }
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _araciPasifeAl(String esnafId, String aracAd) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('esnaflar').doc(esnafId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['kanallar'] != null) {
          List<dynamic> kanallar = List.from(data['kanallar']);
          bool degisti = false;
          for (var i = 0; i < kanallar.length; i++) {
            var k = kanallar[i];
            if (k is Map && k['ad'] == aracAd) {
              kanallar[i]['aktif'] = false;
              degisti = true;
              break;
            }
          }
          if (degisti) {
            await FirebaseFirestore.instance.collection('esnaflar').doc(esnafId).update({
              'kanallar': kanallar,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Araç pasife alınamadı: $e");
    }
  }

  void _yardimCagir(String no) async {
    final url = Uri.parse("tel:$no");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("ACİL DURUM ASİSTANI", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. ACİL YARDIM REHBERİ (STRES YÖNETİMİ)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade800,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const Text("LÜTFEN SAKİN OLUN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Biz yanınızdayız. Aşağıdaki adımları sırayla izleyin.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _acilButon(Icons.medical_services, "112 AMBULANS", () => _yardimCagir("112")),
                    _acilButon(Icons.local_police, "155 POLİS", () => _yardimCagir("155")),
                    _acilButon(Icons.car_repair, "ÇEKİCİ ÇAĞIR", () => _yardimCagir(widget.randevu.esnafTel)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. KONUM BİLDİRİMİ
                  _bolumBasligi("📍 OLAY YERİ KONUMU"),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        if (_canliKonumLink != null)
                          const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text("Konumunuz esnafa mühürlendi.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))])
                        else
                          const Text("Esnafın size ulaşabilmesi için konumunuzu mühürleyin.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _konumAliniyor ? null : _konumGonder,
                            icon: _konumAliniyor ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
                            label: Text(_canliKonumLink == null ? "KONUMUMU ESNAFA GÖNDER" : "KONUMU GÜNCELLE"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 3. HASAR FOTOĞRAFLARI
                  _bolumBasligi("📸 HASAR FOTOĞRAFLARI"),
                  const Text("Tutanak, ehliyet ve hasarlı bölgeleri çekiniz.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        GestureDetector(
                          onTap: _yukleniyor ? null : _fotoCek,
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.none)),
                            child: _yukleniyor ? const Center(child: CircularProgressIndicator()) : const Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ..._hasarGorselleri.asMap().entries.map((entry) => GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MedyaGoruntuleyici(gorseller: _hasarGorselleri, baslangicIndex: entry.key))),
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), image: DecorationImage(image: NetworkImage(entry.value), fit: BoxFit.cover)),
                          ),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 4. DİJİTAL TUTANAK REHBERİ
                  _bolumBasligi("📖 ADIM ADIM NE YAPMALIYIM?"),
                  _rehberAdimi("1", "Önce kendi güvenliğinizi sağlayın ve dörtlüleri yakın."),
                  _rehberAdimi("2", "Karşı tarafla tartışmaya girmeyin, yaralı varsa 112'yi arayın."),
                  _rehberAdimi("3", "Araçları yerinden oynatmadan olay yerinin geniş açılı fotoğraflarını çekin."),
                  _rehberAdimi("4", "Kaza tespit tutanağını eksiksiz doldurup karşılıklı imzalayın."),
                  _rehberAdimi("5", "Karşı tarafın ehliyet, ruhsat ve sigorta poliçesini fotoğraflayın."),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: const Text("YARDIM PANELİNİ KAPAT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _acilButon(IconData ikon, String metin, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(ikon, color: Colors.red.shade800, size: 28),
          ),
          const SizedBox(height: 8),
          Text(metin, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _bolumBasligi(String baslik) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(baslik, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _rehberAdimi(String no, String metin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 10, backgroundColor: Colors.red.shade100, child: Text(no, style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Text(metin, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }
}
