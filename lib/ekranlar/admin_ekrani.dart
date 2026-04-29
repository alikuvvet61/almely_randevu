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
  final _kategoriAdController = TextEditingController();
  final _iptalNedeniController = TextEditingController();

  String _secilenKategori = ''; 
  String _gpsDurum = "Konumu Getir";
  
  String? _duzenlenenKategoriId;

  @override
  void dispose() {
    _adController.dispose();
    _telController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _adresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _kategoriAdController.dispose();
    _iptalNedeniController.dispose();
    super.dispose();
  }

  void _iptalNedenleriYonetimi() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            child: Column(
              children: [
                Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const TabBar(
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.orange,
                  tabs: [
                    Tab(text: "Kullanıcı İptal"),
                    Tab(text: "Esnaf İptal"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _iptalNedeniListeBolumu("kullanici"),
                      _iptalNedeniListeBolumu("esnaf"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iptalNedeniListeBolumu(String tip) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _iptalNedeniController,
            decoration: InputDecoration(
              labelText: tip == "kullanici" ? "Müşteri İptal Nedeni Ekle" : "Esnaf İptal Nedeni Ekle", 
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.orange),
                onPressed: () async {
                  if (_iptalNedeniController.text.isNotEmpty) {
                    await _firestoreServisi.iptalNedeniEkle(tip, _iptalNedeniController.text);
                    if (!mounted) return;
                    _iptalNedeniController.clear();
                  }
                },
              ),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _firestoreServisi.iptalNedenleriniGetir(tip),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final nedenler = snapshot.data!;
                return ListView.builder(
                  itemCount: nedenler.length,
                  itemBuilder: (context, index) {
                    final neden = nedenler[index];
                    return ListTile(
                      title: Text(neden),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _iptalNedeniDuzenleDialog(tip, neden),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _firestoreServisi.iptalNedeniSil(tip, neden);
                            },
                          ),
                        ],
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

  void _iptalNedeniDuzenleDialog(String tip, String eskiNeden) {
    final controller = TextEditingController(text: eskiNeden);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nedeni Düzenle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestoreServisi.iptalNedeniGuncelle(tip, eskiNeden, controller.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _kategoriYonetimiFormu() {
    _duzenlenenKategoriId = null;
    _kategoriAdController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                  child: Column(
                    children: [
                      Text(_duzenlenenKategoriId == null ? "Kategori Yönetimi" : "Kategoriyi Düzenle", 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _kategoriAdController,
                        decoration: const InputDecoration(labelText: "Kategori Adı (Örn: Berber)", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          if (_duzenlenenKategoriId != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() {
                                    _duzenlenenKategoriId = null;
                                    _kategoriAdController.clear();
                                  });
                                },
                                child: const Text("Vazgeç"),
                              ),
                            ),
                          if (_duzenlenenKategoriId != null) const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_kategoriAdController.text.isNotEmpty) {
                                  if (_duzenlenenKategoriId == null) {
                                    await _firestoreServisi.kategoriEkle(_kategoriAdController.text);
                                  } else {
                                    await _firestoreServisi.kategoriGuncelle(_duzenlenenKategoriId!, _kategoriAdController.text);
                                  }
                                  if (!context.mounted) return;
                                  setModalState(() {
                                    _kategoriAdController.clear();
                                    _duzenlenenKategoriId = null;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: Text(_duzenlenenKategoriId == null ? "Ekle" : "Güncelle"),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      const Text("Mevcut Kategoriler", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firestoreServisi.kategorileriGetir(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final kats = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: kats.length,
                            itemBuilder: (context, index) {
                              final kat = kats[index];
                              return ListTile(
                                title: Text(kat['ad']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                      onPressed: () {
                                        setModalState(() {
                                          _duzenlenenKategoriId = kat['id'];
                                          _kategoriAdController.text = kat['ad'];
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _confirmKategoriDelete(kat['id'], kat['ad']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmKategoriDelete(String id, String ad) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kategoriyi Sil"),
        content: Text("'$ad' kategorisini silmek istediğinize emin misiniz? Bu işlem bu kategorideki esnafların görünümünü etkileyebilir."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(onPressed: () async {
            await _firestoreServisi.kategoriSil(id);
            if (!context.mounted) return;
            Navigator.pop(context);
          }, child: const Text("Sil", style: TextStyle(color: Colors.red))),
        ],
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

                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firestoreServisi.kategorileriGetir(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final kats = snapshot.data!;
                          if (kats.isEmpty) return const Text("Lütfen önce kategori tanımlayın.");

                          if (_secilenKategori.isEmpty || !kats.any((k) => k['ad'] == _secilenKategori)) {
                            _secilenKategori = kats[0]['ad'];
                          }

                          return InputDecorator(
                            decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                initialValue: kats.any((k) => k['ad'] == _secilenKategori) ? _secilenKategori : kats[0]['ad'],
                                isExpanded: true,
                                items: kats.map((e) => DropdownMenuItem(value: e['ad'] as String, child: Text(e['ad'] as String))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => _secilenKategori = v);
                                  }
                                },
                              ),
                            ),
                          );
                        }
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
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextField(controller: _latController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Enlem (Lat)", isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _lonController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Boylam (Lon)", isDense: true, border: OutlineInputBorder()))),
                      ]),
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

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(esnaf == null ? "Esnaf Kaydedildi!" : "Esnaf Güncellendi!"),
                                    backgroundColor: Colors.green
                                )
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
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

  void _ajandalariSifirla() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tüm Ajandaları Sıfırla"),
        content: const Text("Tüm esnafların oluşturulmuş ajandaları silinecektir. Bu işlem geri alınamaz. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              await _firestoreServisi.tumAjandalariTemizle();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm ajandalar sıfırlandı.")));
            },
            child: const Text("Evet, Sıfırla", style: TextStyle(color: Colors.red)),
          ),
        ],
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _adminButonUst(Icons.category, 'Kategoriler', Colors.green, () => _kategoriYonetimiFormu()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.add_business, 'Esnaf Ekle', Colors.blue, () => _esnafFormu()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.block, 'Randevu İptal\nNedenleri', Colors.orange, () => _iptalNedenleriYonetimi()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.calendar_month, 'Ajandaları\nSıfırla', Colors.red, () => _ajandalariSifirla()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.people, 'Üyeler', Colors.purple, () {}),
                ],
              ),
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

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreServisi.kategorileriGetir(),
                  builder: (context, katSnapshot) {
                    if (!katSnapshot.hasData) return const CircularProgressIndicator();
                    final kats = katSnapshot.data!.map((e) => e['ad'] as String).toList();
                    
                    if (kats.isEmpty) {
                      return const Center(child: Text("Lütfen önce kategori ekleyin."));
                    }

                    return ListView.builder(
                      itemCount: kats.length,
                      itemBuilder: (context, index) {
                        final kat = kats[index];
                        final kategoriEsnaflari = tumEsnaflar.where((e) => e.kategori == kat).toList();
                        
                        return ExpansionTile(
                          leading: Icon(_kategoriIkonuGetir(kat), color: Colors.blue),
                          title: Text("$kat (${kategoriEsnaflari.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                          children: kategoriEsnaflari.isEmpty 
                            ? [const Padding(padding: EdgeInsets.all(10), child: Text("Bu kategoride kayıtlı esnaf yok.", style: TextStyle(fontSize: 12, color: Colors.grey)))]
                            : kategoriEsnaflari.map((esnaf) => Card(
                            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                            child: ListTile(
                              title: Text(esnaf.isletmeAdi, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              subtitle: Text("Tel: ${esnaf.telefon}\nAdres: ${esnaf.adres}"),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _esnafFormu(esnaf: esnaf)),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _confirmDelete(esnaf)),
                              ]),
                            ),
                          )).toList(),
                        );
                      },
                    );
                  }
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
            onPressed: () async {
              await _firestoreServisi.esnafSil(esnaf.id);
              if (!context.mounted) return;
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(80, 60),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(b, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
