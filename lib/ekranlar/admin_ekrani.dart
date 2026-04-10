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
  final _hizmetTanimController = TextEditingController();

  String _secilenKategori = 'Kuaför';
  String _hizmetKategori = 'Kuaför';
  String _gpsDurum = "Konumu Getir";
  final List<String> kategoriListesi = ['Kuaför', 'Taksi', 'Halı Saha', 'Oto Yıkama', 'Restoran', 'Düğün Salonu'];

  // Düzenleme modu için değişkenler
  String? _duzenlenenHizmetId;

  @override
  void dispose() {
    _adController.dispose();
    _telController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _adresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _hizmetTanimController.dispose();
    super.dispose();
  }

  void _hizmetTanimlamaFormu() {
    _duzenlenenHizmetId = null;
    _hizmetTanimController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_duzenlenenHizmetId == null ? "Hizmet Tanımlama (Admin)" : "Hizmeti Düzenle", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 20),
                if (_duzenlenenHizmetId == null)
                  DropdownButtonFormField<String>(
                    value: _hizmetKategori,
                    decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                    items: kategoriListesi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setModalState(() => _hizmetKategori = v!),
                  ),
                const SizedBox(height: 15),
                TextField(
                  controller: _hizmetTanimController,
                  decoration: const InputDecoration(labelText: "Hizmet Adı (Örn: Saç Kesimi)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_duzenlenenHizmetId != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _duzenlenenHizmetId = null;
                              _hizmetTanimController.clear();
                            });
                          },
                          child: const Text("Vazgeç"),
                        ),
                      ),
                    if (_duzenlenenHizmetId != null) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_hizmetTanimController.text.isNotEmpty) {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            if (_duzenlenenHizmetId == null) {
                              // Yeni Kayıt
                              await _firestoreServisi.hizmetTanimEkle(_hizmetTanimController.text, _hizmetKategori);
                              if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Hizmet Tanımlandı")));
                            } else {
                              // Güncelleme
                              await _firestoreServisi.hizmetTanimGuncelle(_duzenlenenHizmetId!, _hizmetTanimController.text);
                              if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Hizmet Güncellendi")));
                            }
                            
                            setModalState(() {
                              _hizmetTanimController.clear();
                              _duzenlenenHizmetId = null;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: Text(_duzenlenenHizmetId == null ? "Hizmet Kaydet" : "Güncelle"),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40),
                const Text("Tanımlı Hizmetler", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 250,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firestoreServisi.hizmetTanimlariniGetir(_hizmetKategori),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final h = snapshot.data![index];
                          return ListTile(
                            title: Text(h['ad']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () {
                                    setModalState(() {
                                      _duzenlenenHizmetId = h['id'];
                                      _hizmetTanimController.text = h['ad'];
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _firestoreServisi.hizmetTanimSil(h['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
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
    if (!mounted) return;

    if (sonuc != null) {
      if (sonuc.containsKey('hata')) {
        setModalState(() => _gpsDurum = sonuc['hata']!);
      } else {
        setModalState(() {
          _latController.text = sonuc['enlem'] ?? "";
          _lonController.text = sonuc['boylam'] ?? "";
          _ilController.text = sonuc['il'] ?? "";
          _ilceController.text = sonuc['ilce'] ?? "";
          _adresController.text = sonuc['tamAdres'] ?? "";
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
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double maxHeight = MediaQuery.of(context).size.height * 0.85;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 15),
                      Text(esnaf == null ? "Yeni Esnaf Kaydı" : "Esnaf Düzenle",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 15),

                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Kategori",
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _secilenKategori,
                            isExpanded: true,
                            items: kategoriListesi.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => _secilenKategori = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı", isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: _telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextField(controller: _ilController, decoration: const InputDecoration(labelText: "İl", isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _ilceController, decoration: const InputDecoration(labelText: "İlçe", isDense: true, border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 10),
                      TextField(controller: _adresController, maxLines: 2, decoration: const InputDecoration(labelText: "Adres Bilgisi", isDense: true, border: OutlineInputBorder())),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: () => _konumAl(setModalState),
                        icon: const Icon(Icons.gps_fixed),
                        label: Text(_gpsDurum),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          EsnafModeli guncelEsnaf = EsnafModeli(
                            id: esnaf?.id ?? '',
                            isletmeAdi: _adController.text,
                            kategori: _secilenKategori,
                            telefon: _telController.text,
                            email: 'esnaf_test@mail.com',
                            il: _ilController.text,
                            ilce: _ilceController.text,
                            adres: _adresController.text,
                            konum: GeoPoint(
                              double.tryParse(_latController.text) ?? 0.0,
                              double.tryParse(_lonController.text) ?? 0.0,
                            ),
                          );

                          try {
                            if (esnaf == null) {
                              await _firestoreServisi.esnafEkle(guncelEsnaf);
                            } else {
                              await _firestoreServisi.esnafGuncelle(esnaf.id, guncelEsnaf.toMap());
                            }

                            if (!mounted) return;
                            navigator.pop();
                            scaffoldMessenger.showSnackBar(
                                SnackBar(
                                    content: Text(esnaf == null ? "Esnaf Kaydedildi!" : "Esnaf Güncellendi!"),
                                    backgroundColor: Colors.green
                                )
                            );
                          } catch (e) {
                            if (!mounted) return;
                            scaffoldMessenger.showSnackBar(
                                SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(esnaf == null ? "Esnafı Kaydet" : "Değişiklikleri Kaydet"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(child: _adminButonUst(Icons.add_business, 'Esnaf Ekle', Colors.blue, () => _esnafFormu())),
                const SizedBox(width: 10),
                Expanded(child: _adminButonUst(Icons.list_alt, 'Hizmet Tanımla', Colors.orange, () => _hizmetTanimlamaFormu())),
                const SizedBox(width: 10),
                Expanded(child: _adminButonUst(Icons.people, 'Üyeler', Colors.green, () {})),
              ],
            ),
          ),
          const Divider(thickness: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("KAYITLI ESNAFLAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
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
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          title: Text(esnaf.isletmeAdi, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          subtitle: Text("Tel: ${esnaf.telefon}\nAdres: ${esnaf.adres}", style: const TextStyle(fontSize: 12)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _esnafFormu(esnaf: esnaf)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _confirmDelete(esnaf)),
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

  void _confirmDelete(EsnafModeli esnaf) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Esnafı Sil"),
        content: Text("${esnaf.isletmeAdi} kaydını silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(
            onPressed: () {
              _firestoreServisi.esnafSil(esnaf.id);
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
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

  Widget _adminButonUst(IconData i, String b, Color r, VoidCallback t) => ElevatedButton(
    onPressed: t,
    style: ElevatedButton.styleFrom(
      backgroundColor: r,
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(b, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}