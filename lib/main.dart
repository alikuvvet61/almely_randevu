import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(AlmElyApp());

class AlmElyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlmEly Randevu Portalı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: GirisSecimSayfasi(),
    );
  }
}

// --- GLOBAL VERİLER ---
String mevcutIl = "Trabzon";
// Kaydedilen tüm esnaflar bu listede tutulacak
List<Map<String, String>> globalEsnafListesi = [];

final Map<String, List<String>> ilceVeritabani = {
  'Trabzon': ['Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Çaykara', 'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Of', 'Ortahisar', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir', 'Yomra'],
  'İstanbul': ['Arnavutköy', 'Beşiktaş', 'Kadıköy', 'Üsküdar', 'Fatih'],
  'Ankara': ['Çankaya', 'Keçiören', 'Mamak', 'Yenimahalle'],
};

// --- 1. GİRİŞ SEÇİM EKRANI ---
class GirisSecimSayfasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/AlmEly.png', width: 220,
                errorBuilder: (c, e, s) => const Icon(Icons.business_center, size: 80, color: Colors.blue)),
            const SizedBox(height: 40),
            _anaButon(context, "Kullanıcı Girişi", Colors.blue, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => KullaniciGirisSayfasi()));
            }),
            const SizedBox(height: 15),
            _anaButon(context, "Yönetici Girişi", Colors.white, Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => AdminGirisSayfasi()));
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

// --- 2. KULLANICI GİRİŞİ VE ANA SAYFA ---
class KullaniciGirisSayfasi extends StatefulWidget {
  @override _KullaniciGirisSayfasiState createState() => _KullaniciGirisSayfasiState();
}

class _KullaniciGirisSayfasiState extends State<KullaniciGirisSayfasi> {
  final _tel = TextEditingController();
  final _sifre = TextEditingController();

  void _girisYap() {
    if ((_tel.text.trim() == '5064000963' || _tel.text.trim() == '05064000963') && _sifre.text == '1234') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => AnaSayfa()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı Giriş! Şifre: 1234'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kullanıcı Girişi')),
    body: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
      TextField(controller: _tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon (5064000963)', border: OutlineInputBorder())),
      const SizedBox(height: 15),
      TextField(controller: _sifre, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder())),
      const SizedBox(height: 25),
      ElevatedButton(onPressed: _girisYap, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)), child: const Text("Giriş Yap")),
    ])),
  );
}

class AnaSayfa extends StatelessWidget {
  final List<Map<String, dynamic>> kategoriler = [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.amber},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.redAccent},
    {'ad': 'Düğün Salonu', 'ikon': Icons.celebration, 'renk': Colors.purple},
  ];

  void _ilceListesiAc(BuildContext context, String katAd) {
    List<String> ilceler = ilceVeritabani[mevcutIl] ?? ['Merkez'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 15),
          Text("$mevcutIl - $katAd Bölgeleri", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(child: ListView.builder(itemCount: ilceler.length, itemBuilder: (c, i) => ListTile(
            leading: const Icon(Icons.location_on, color: Colors.blue),
            title: Text(ilceler[i]),
            onTap: () => Navigator.pop(context),
          ))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AlmEly - $mevcutIl"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: kategoriler.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => _ilceListesiAc(context, kategoriler[i]['ad']),
          child: Card(
            color: kategoriler[i]['renk'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(kategoriler[i]['ikon'], size: 50, color: Colors.white),
              const SizedBox(height: 10),
              Text(kategoriler[i]['ad'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
        ),
      ),
    );
  }
}

// --- 3. YÖNETİCİ PANELİ (GÜNCELLENMİŞ) ---
class AdminPanelSayfasi extends StatefulWidget {
  @override _AdminPanelSayfasiState createState() => _AdminPanelSayfasiState();
}

class _AdminPanelSayfasiState extends State<AdminPanelSayfasi> {
  final _adController = TextEditingController();
  final _telController = TextEditingController();
  final _ilController = TextEditingController();
  final _ilceController = TextEditingController();
  final _adresController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  String _gpsDurum = "Konumu Getir";

  Future<void> _konumZorla(StateSetter setModalState) async {
    setModalState(() => _gpsDurum = "Konum Hassaslaştırılıyor...");
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);

      setModalState(() => _gpsDurum = "Bina Detayları Sorgulanıyor...");

      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'AlmEly_Super_App'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        setModalState(() {
          _ilController.text = address['province'] ?? address['city'] ?? "";
          _ilceController.text = address['district'] ?? address['town'] ?? address['village'] ?? "";

          String bina = address['building'] ?? address['amenity'] ?? "";
          String mahalle = address['suburb'] ?? address['neighbourhood'] ?? "";
          String yol = address['road'] ?? "";
          String binaNo = address['house_number'] ?? "";

          List<String> adresSatiri = [];
          if (bina.isNotEmpty) adresSatiri.add("[$bina]");
          if (mahalle.isNotEmpty) adresSatiri.add("$mahalle Mah.");
          if (yol.isNotEmpty) adresSatiri.add("$yol Sk.");
          if (binaNo.isNotEmpty) adresSatiri.add("No:$binaNo");

          _adresController.text = adresSatiri.join(" ");
          _gpsDurum = "Tam Adres Getirildi ✅";
        });
      }
    } catch (e) {
      setModalState(() => _gpsDurum = "Hata! Tekrar deneyin.");
    }
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
            TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store))),
            const SizedBox(height: 10),
            TextField(controller: _telController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _ilController, decoration: const InputDecoration(labelText: "İl", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _ilceController, decoration: const InputDecoration(labelText: "İlçe", border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _adresController, maxLines: 2, decoration: const InputDecoration(labelText: "Adres", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            ElevatedButton.icon(onPressed: () => _konumZorla(setModalState), icon: const Icon(Icons.gps_fixed), label: Text(_gpsDurum), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, minimumSize: const Size(double.infinity, 50))),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    globalEsnafListesi.add({
                      'ad': _adController.text,
                      'tel': _telController.text,
                      'ilce': _ilceController.text,
                      'adres': _adresController.text,
                    });
                  });
                  _adController.clear(); _telController.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Esnaf Kaydedildi!"), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
                child: const Text("Esnafı Kaydet")
            ),
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
      body: CustomScrollView( // DAHA İYİ KAYDIRMA İÇİN YAPIYI DEĞİŞTİRDİK
        slivers: [
          SliverToBoxAdapter(
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _adminKutu(Icons.add_business, 'Esnaf Ekle', Colors.blue, _esnafEkleFormu),
                _adminKutu(Icons.people, 'Kullanıcılar', Colors.green, () {}),
                _adminKutu(Icons.history, 'Randevular', Colors.orange, () {}),
                _adminKutu(Icons.settings, 'Ayarlar', Colors.grey, () {}),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: Text("📊 Kayıtlı Esnaflar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey))),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final esnaf = globalEsnafListesi[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.store, color: Colors.white)),
                    title: Text(
                        esnaf['ad'] ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 16) // İSİM RENKLENDİ
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(esnaf['tel'] ?? "", style: const TextStyle(fontWeight: FontWeight.w500)), // TEL EKLENDİ
                        ]),
                        Text("${esnaf['ilce']} - ${esnaf['adres']}", style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () {
                        // İlerde buraya arama fonksiyonu ekleyeceğiz
                      },
                    ),
                  ),
                );
              },
              childCount: globalEsnafListesi.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminKutu(IconData i, String b, Color r, VoidCallback t) => Card(
    elevation: 4,
    child: InkWell(onTap: t, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, size: 40, color: r),
      const SizedBox(height: 8),
      Text(b, style: const TextStyle(fontWeight: FontWeight.bold))
    ])),
  );
}

// --- 4. ADMİN GİRİŞ SAYFASI ---
class AdminGirisSayfasi extends StatelessWidget {
  final _ad = TextEditingController();
  final _sif = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Admin Girişi")),
    body: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
      TextField(controller: _ad, decoration: const InputDecoration(labelText: "Kullanıcı Adı (AlmEly)", border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _sif, obscureText: true, decoration: const InputDecoration(labelText: "Şifre (686596)", border: OutlineInputBorder())),
      const SizedBox(height: 25),
      ElevatedButton(onPressed: () {
        if (_ad.text == 'AlmEly' && _sif.text == '686596') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => AdminPanelSayfasi()));
        }
      }, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("Giriş Yap")),
    ])),
  );
}