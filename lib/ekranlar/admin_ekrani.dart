import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/konum_servisi.dart';

class AdminEkrani extends StatefulWidget {
  const AdminEkrani({super.key});

  @override
  State<AdminEkrani> createState() => _AdminEkraniState();
}

class _AdminEkraniState extends State<AdminEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _konumServisi = KonumServisi();

  final _adController = TextEditingController();
  final _telController = TextEditingController();
  final _ilController = TextEditingController();
  final _ilceController = TextEditingController();
  final _adresController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  String _secilenKategori = 'Kuaför';
  String _gpsDurum = "Konumu Getir";
  final List<String> kategoriListesi = ['Kuaför', 'Taksi', 'Halı Saha', 'Oto Yıkama', 'Restoran', 'Düğün Salonu'];

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

  void _formuTemizle() {
    _adController.clear();
    _telController.clear();
    _ilController.clear();
    _ilceController.clear();
    _adresController.clear();
    _latController.clear();
    _lonController.clear();
    _secilenKategori = 'Kuaför';
    _gpsDurum = "Konumu Getir";
  }

  Future<void> _konumAl(StateSetter setModalState) async {
    setModalState(() => _gpsDurum = "Konum alınıyor...");

    final sonuc = await _konumServisi.konumuVeAdresiGetir();

    if (!mounted) return; // Context kontrolü için yeterli

    if (sonuc != null) {
      if (sonuc.containsKey('hata')) {
        setModalState(() => _gpsDurum = sonuc['hata']!);
      } else {
        setModalState(() {
          _latController.text = sonuc['enlem'] ?? "";
          _lonController.text = sonuc['boylam'] ?? "";
          _ilController.text = sonuc['il'] ?? "";
          _ilceController.text = sonuc['ilce'] ?? "";

          String gelenAdres = sonuc['tamAdres'] ?? "";

          // EĞER Google hala Gelişim Sk. döndürüyorsa ama biz İran Cd. olduğunu biliyorsak:
          // (Burada kullanıcıya manuel düzenleme şansı da vermiş oluyoruz)
          _adresController.text = gelenAdres;

          _gpsDurum = "Konum Tamam ✅";
        });
      }
    } else {
      setModalState(() => _gpsDurum = "Konum alınamadı.");
    }
  }

  void _esnafFormu({EsnafModeli? esnaf}) {
    if (esnaf != null) {
      _adController.text = esnaf.isletmeAdi;
      _telController.text = esnaf.telefon;
      _ilController.text = esnaf.il;
      _ilceController.text = esnaf.ilce;
      _adresController.text = esnaf.adres;
      _latController.text = esnaf.konum.latitude.toString();
      _lonController.text = esnaf.konum.longitude.toString();
      _secilenKategori = esnaf.kategori;
      _gpsDurum = "Konum Kayıtlı";
    } else {
      _formuTemizle();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(esnaf == null ? "Yeni Esnaf Kaydı" : "Esnaf Düzenle", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _secilenKategori,
                decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                items: kategoriListesi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setModalState(() => _secilenKategori = v);
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
              ElevatedButton.icon(
                onPressed: () => _konumAl(setModalState), 
                icon: const Icon(Icons.gps_fixed), 
                label: Text(_gpsDurum),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  final yeniEsnaf = EsnafModeli(
                    id: esnaf?.id ?? '',
                    isletmeAdi: _adController.text,
                    kategori: _secilenKategori,
                    telefon: _telController.text,
                    il: _ilController.text,
                    ilce: _ilceController.text,
                    adres: _adresController.text,
                    konum: GeoPoint(double.tryParse(_latController.text) ?? 0, double.tryParse(_lonController.text) ?? 0),
                  );

                  if (esnaf == null) {
                    await _firestoreServisi.esnafEkle(yeniEsnaf);
                  } else {
                    await _firestoreServisi.esnafGuncelle(esnaf.id, yeniEsnaf);
                  }
                  
                  if (!context.mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(
                    content: Text(esnaf == null ? "Esnaf Kaydedildi!" : "Esnaf Güncellendi!"),
                    backgroundColor: esnaf == null ? Colors.green : Colors.blue,
                  ));
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: Text(esnaf == null ? "Esnafı Kaydet" : "Değişiklikleri Kaydet"),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici Paneli')),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(15), child: Row(children: [
            Expanded(child: _adminButonUst(Icons.add_business, 'Esnaf Ekle', Colors.blue, () => _esnafFormu())),
            const SizedBox(width: 10),
            Expanded(child: _adminButonUst(Icons.people, 'Üyeler', Colors.green, () {})),
          ])),
          const Divider(thickness: 2),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("KAYITLI ESNAFLAR", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: StreamBuilder<List<EsnafModeli>>(
              stream: _firestoreServisi.esnaflariGetir(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));

                final tumEsnaflar = snapshot.data ?? [];
                if (tumEsnaflar.isEmpty) return const Center(child: Text("Henüz esnaf kaydı yok."));

                return ListView(
                  children: kategoriListesi.map((kat) {
                    final kategoriEsnaflari = tumEsnaflar.where((e) => e.kategori == kat).toList();
                    if (kategoriEsnaflari.isEmpty) return const SizedBox.shrink();

                    return ExpansionTile(
                      leading: Icon(_kategoriIkonuGetir(kat), color: Colors.blue),
                      title: Text("$kat (${kategoriEsnaflari.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                      children: kategoriEsnaflari.map((esnaf) => Card(
                        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        child: ListTile(
                          title: Text(esnaf.isletmeAdi, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.phone, size: 16, color: Colors.green),
                              const SizedBox(width: 5),
                              Text(esnaf.telefon, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ]),
                            Text("Adres: ${esnaf.adres}"),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _esnafFormu(esnaf: esnaf)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _firestoreServisi.esnafSil(esnaf.id)),
                          ]),
                        ),
                      )).toList(),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _kategoriIkonuGetir(String kat) {
    switch (kat) {
      case 'Kuaför': return Icons.content_cut;
      case 'Taksi': return Icons.local_taxi;
      case 'Halı Saha': return Icons.sports_soccer;
      case 'Oto Yıkama': return Icons.local_car_wash;
      case 'Restoran': return Icons.restaurant;
      case 'Düğün Salonu': return Icons.celebration;
      default: return Icons.business;
    }
  }

  Widget _adminButonUst(IconData i, String b, Color r, VoidCallback t) => ElevatedButton.icon(
    onPressed: t, icon: Icon(i, color: Colors.white), label: Text(b, style: const TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(backgroundColor: r, padding: const EdgeInsets.symmetric(vertical: 15)),
  );
}
