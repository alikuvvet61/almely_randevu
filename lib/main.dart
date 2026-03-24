import 'package:flutter/material.dart';

void main() => runApp(AlmElyApp());

class AlmElyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlmEly Randevu Portalı',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GirisSecimSayfasi(),
    );
  }
}

// --- 1. LOGOLU VE SLOGANLI GİRİŞ SEÇİM EKRANI ---
class GirisSecimSayfasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO: Assets klasöründeki AlmEly.png dosyasını kullanır
              Image.asset(
                'assets/AlmEly.png',
                width: 300,
                height: 300,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.business, size: 100, color: Colors.blue),
              ),

              // SLOGAN
              Text(
                "Türkiye'nin Tek Nokta",
                style: TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              Text(
                "Randevu Portalı",
                style: TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.w300),
              ),

              SizedBox(height: 50),

              // KULLANICI GİRİŞ BUTONU
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(280, 55),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KullaniciGirisSayfasi())),
                child: Text('Kullanıcı Girişi', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),

              SizedBox(height: 15),

              // YÖNETİCİ GİRİŞ BUTONU
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(280, 55),
                  side: BorderSide(color: Colors.grey, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminGirisSayfasi())),
                child: Text('Yönetici Girişi', style: TextStyle(color: Colors.grey[800], fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. KULLANICI GİRİŞ & KAYIT ---
class KullaniciGirisSayfasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kullanıcı Girişi')),
      body: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'E-posta veya Kullanıcı Adı', border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa())),
              child: Text('Giriş Yap'),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KayitSayfasi())),
              child: Text('Hesabınız yok mu? Hemen Kayıt Olun'),
            )
          ],
        ),
      ),
    );
  }
}

class KayitSayfasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Yeni Kullanıcı Oluştur')),
      body: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(decoration: InputDecoration(labelText: 'E-posta', border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              onPressed: () => Navigator.pop(context),
              child: Text('Kaydı Tamamla'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. YÖNETİCİ GİRİŞ SİSTEMİ (AlmEly / 686596) ---
class AdminGirisSayfasi extends StatefulWidget {
  @override
  _AdminGirisSayfasiState createState() => _AdminGirisSayfasiState();
}

class _AdminGirisSayfasiState extends State<AdminGirisSayfasi> {
  final adController = TextEditingController();
  final sifreController = TextEditingController();

  void kontrolEt() {
    if (adController.text == 'AlmEly' && sifreController.text == '686596') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminPanelSayfasi()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hatalı Yönetici Bilgisi!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Yönetici Girişi'), backgroundColor: Colors.black87),
      body: Padding(
        padding: EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(controller: adController, decoration: InputDecoration(labelText: 'Yönetici Kullanıcı Adı', border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(controller: sifreController, decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 25),
            ElevatedButton(
              onPressed: kontrolEt,
              child: Text('Sisteme Gir', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, minimumSize: Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. YÖNETİCİ PANELİ ---
class AdminPanelSayfasi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AlmEly Kontrol Paneli'),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GirisSecimSayfasi())))],
      ),
      body: GridView.count(
        padding: EdgeInsets.all(20),
        crossAxisCount: 2,
        children: [
          _adminButon(Icons.add_business, 'Esnaf Ekle'),
          _adminButon(Icons.people, 'Kullanıcılar'),
          _adminButon(Icons.calendar_month, 'Randevular'),
          _adminButon(Icons.bar_chart, 'İstatistikler'),
        ],
      ),
    );
  }

  Widget _adminButon(IconData ikon, String baslik) {
    return Card(
      child: InkWell(
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(ikon, size: 40, color: Colors.blue), SizedBox(height: 10), Text(baslik)],
        ),
      ),
    );
  }
}

// --- 5. ANA UYGULAMA EKRANI (KULLANICILAR İÇİN) ---
class AnaSayfa extends StatelessWidget {
  final List<Map<String, dynamic>> kategoriler = [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.yellow[700]},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.redAccent},
    {'ad': 'Düğün Salonu', 'ikon': Icons.celebration, 'renk': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AlmEly Randevu'),
        actions: [IconButton(icon: Icon(Icons.exit_to_app), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GirisSecimSayfasi())))],
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: kategoriler.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(color: kategoriler[index]['renk'], borderRadius: BorderRadius.circular(15)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(kategoriler[index]['ikon'], size: 50, color: Colors.white),
                SizedBox(height: 10),
                Text(kategoriler[index]['ad'], style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}