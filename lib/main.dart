import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
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
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 80, color: Colors.blue),
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

class KullaniciGirisSayfasi extends StatefulWidget {
  const KullaniciGirisSayfasi({super.key});
  @override
  State<KullaniciGirisSayfasi> createState() => _KullaniciGirisSayfasiState();
}

class _KullaniciGirisSayfasiState extends State<KullaniciGirisSayfasi> {
  void _girisYap() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const AnaSayfa()));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kullanıcı Girişi')),
    body: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
      const TextField(decoration: InputDecoration(labelText: 'Telefon (Hızlı Giriş)', border: OutlineInputBorder())),
      const SizedBox(height: 25),
      ElevatedButton(onPressed: _girisYap, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)), child: const Text("Giriş Yap")),
    ])),
  );
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  final List<Map<String, dynamic>> kategoriler = const [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.amber},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.redAccent},
    {'ad': 'Düğün Salonu', 'ikon': Icons.celebration, 'renk': Colors.purple},
  ];

  void _esnafListesiAc(BuildContext context, String katAd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 15),
          Text("$katAd Esnafları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('esnaflar').where('kategori', isEqualTo: katAd).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text("Veri çekilirken hata: ${snapshot.error}"),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, color: Colors.grey, size: 40),
                        SizedBox(height: 10),
                        Text("Henüz esnaf bulunamadı."),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['isletmeAdi'] ?? ""),
                      subtitle: Text("${data['ilce']} - ${data['telefon']}"),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AlmEly - Trabzon"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: kategoriler.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => _esnafListesiAc(context, kategoriler[i]['ad']),
          child: Card(
            color: kategoriler[i]['renk'],
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(kategoriler[i]['ikon'], size: 50, color: Colors.white),
              Text(kategoriler[i]['ad'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}

class AdminPanelSayfasi extends StatefulWidget {
  const AdminPanelSayfasi({super.key});
  @override
  State<AdminPanelSayfasi> createState() => _AdminPanelSayfasiState();
}

class _AdminPanelSayfasiState extends State<AdminPanelSayfasi> {
  final _adController = TextEditingController();
  final _telController = TextEditingController();
  final _ilController = TextEditingController();
  final _ilceController = TextEditingController();
  final _adresController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  String _secilenKategori = 'Kuaför';
  String _gpsDurum = "Konumu Getir";

  void _temizle() {
    _adController.clear();
    _telController.clear();
    _ilController.clear();
    _ilceController.clear();
    _adresController.clear();
    _latController.clear();
    _lonController.clear();
    _gpsDurum = "Konumu Getir";
  }

  @override
  void dispose() {
    _adController.dispose();
    _telController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _adresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _esnafSil(String id) async => await FirebaseFirestore.instance.collection('esnaflar').doc(id).delete();

  Future<void> esnafKaydet() async {
    try {
      await FirebaseFirestore.instance.collection('esnaflar').add({
        'isletmeAdi': _adController.text,
        'kategori': _secilenKategori,
        'telefon': _telController.text,
        'il': _ilController.text,
        'ilce': _ilceController.text,
        'adres': _adresController.text,
        'konum': GeoPoint(double.tryParse(_latController.text) ?? 0.0, double.tryParse(_lonController.text) ?? 0.0),
        'kayitTarihi': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      _temizle();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Esnaf Kaydedildi!"), backgroundColor: Colors.green));

      setState(() {
        _secilenKategori = 'Kuaför';
        _gpsDurum = "Konumu Getir";
      });
    } catch (e) { debugPrint("Kayıt hatası: $e"); }
  }

  Future<void> _konumZorla(StateSetter setModalState) async {
    setModalState(() => _gpsDurum = "İzinler kontrol ediliyor...");
    
    try {
      bool servisAcikMi = await Geolocator.isLocationServiceEnabled();
      if (!servisAcikMi) {
        setModalState(() => _gpsDurum = "Konum servisi kapalı!");
        return;
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) {
          setModalState(() => _gpsDurum = "İzin reddedildi.");
          return;
        }
      }
      
      if (izin == LocationPermission.deniedForever) {
        setModalState(() => _gpsDurum = "Ayarlardan izin verin.");
        return;
      }

      setModalState(() => _gpsDurum = "Uydulara bağlanılıyor...");
      
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(accuracy: LocationAccuracy.best)
            : AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, forceLocationManager: true, intervalDuration: const Duration(seconds: 1)),
      );
      
      if (!mounted) return;
      setModalState(() {
        _latController.text = pos.latitude.toString();
        _lonController.text = pos.longitude.toString();
        _gpsDurum = "Adres alınıyor...";
      });
      await _adresDtaylariniCek(pos.latitude, pos.longitude, setModalState);
    } catch (e) { 
      debugPrint("Konum alma hatası: $e");
      if (mounted) setModalState(() => _gpsDurum = "Hata!"); 
    }
  }

  Future<void> _adresDtaylariniCek(double lat, double lon, StateSetter setModalState) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'AlmElyApp', 'Accept-Language': 'tr'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final addr = data['address'];

        String mekan = data['display_name'].split(',')[0];
        String mahalle = addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'] ?? "";
        String sokak = addr['road'] ?? addr['street'] ?? "";
        String no = addr['house_number'] ?? "";
        String ilce = addr['district'] ?? addr['town'] ?? addr['county'] ?? "";
        String il = addr['province'] ?? addr['city'] ?? "Trabzon";

        List<String> parcalar = [];
        if (mekan.isNotEmpty && !mekan.contains(RegExp(r'[0-9]'))) parcalar.add(mekan);
        if (mahalle.isNotEmpty) parcalar.add("$mahalle Mah.");
        if (sokak.isNotEmpty) parcalar.add("$sokak Sok.");
        if (no.isNotEmpty) parcalar.add("No:$no");
        if (ilce.isNotEmpty) parcalar.add(ilce);
        if (il.isNotEmpty) parcalar.add(il);

        setModalState(() {
          _ilController.text = il;
          _ilceController.text = ilce;
          _adresController.text = parcalar.join(', ');
          _gpsDurum = "Konum Tamam ✅";
        });
      }
    } catch (e) { if (mounted) setModalState(() => _gpsDurum = "Adres Hatası!"); }
  }

  void _esnafEkleFormu() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Yeni Esnaf Kaydı", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: _secilenKategori,
              decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
              items: ['Kuaför', 'Taksi', 'Halı Saha', 'Oto Yıkama', 'Restoran', 'Düğün Salonu']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setModalState(() {
                    _secilenKategori = v;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _telController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _ilController, decoration: const InputDecoration(labelText: "İl", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _ilceController, decoration: const InputDecoration(labelText: "İlçe", border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _adresController, maxLines: 2, decoration: const InputDecoration(labelText: "Adres Bilgisi", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            ElevatedButton.icon(onPressed: () => _konumZorla(setModalState), icon: const Icon(Icons.gps_fixed), label: Text(_gpsDurum), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, minimumSize: const Size(double.infinity, 50))),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => esnafKaydet(), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("Esnafı Kaydet")),
            const SizedBox(height: 20),
          ]),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici Paneli')),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(15), child: Row(children: [
            Expanded(child: _adminButonUst(Icons.add_business, 'Esnaf Ekle', Colors.blue, _esnafEkleFormu)),
            const SizedBox(width: 10),
            Expanded(child: _adminButonUst(Icons.people, 'Üyeler', Colors.green, () {})),
          ])),
          const Divider(thickness: 2),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("KAYITLI ESNAFLAR", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('esnaflar').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text("Veriler yüklenemedi: ${snapshot.error}"),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Henüz esnaf kaydı yok."));
                
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, i) {
                    var doc = snapshot.data!.docs[i]; var data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text(data['kategori']?[0] ?? "E")),
                        title: Text(data['isletmeAdi'] ?? "", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        subtitle: Text("Kat: ${data['kategori']}\nTel: ${data['telefon']}\nAdres: ${data['adres']}"),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _esnafSil(doc.id)),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _adminButonUst(IconData i, String b, Color r, VoidCallback t) => ElevatedButton.icon(
    onPressed: t, icon: Icon(i, color: Colors.white), label: Text(b, style: const TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(backgroundColor: r, padding: const EdgeInsets.symmetric(vertical: 15)),
  );
}

class AdminGirisSayfasi extends StatelessWidget {
  const AdminGirisSayfasi({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Admin Girişi")),
    body: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
      const TextField(decoration: InputDecoration(labelText: "Hızlı Giriş Aktif", border: OutlineInputBorder())),
      const SizedBox(height: 25),
      ElevatedButton(onPressed: () {
        try {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const AdminPanelSayfasi()));
        } catch (e) {
          debugPrint("Yönetici Paneline Geçiş Hatası: $e");
        }
      }, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("Giriş Yap")),
    ])),
  );
}
