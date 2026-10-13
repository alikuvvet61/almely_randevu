import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import '../../modeller/esnaf_modeli.dart';
import '../../servisler/firestore_servisi.dart';
import '../../servisler/konum_servisi.dart';
import '../../servisler/taksi/taksi_guven.dart';
import '../../yardimcilar/kategori_gorseli.dart';
import '../../yardimcilar/telefon_girdisi.dart';
import '../../widgets/isletme_basvuru_alanlari.dart';

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
  final _aracTuruController = TextEditingController();
  final _aracSinifiController = TextEditingController();

  String _secilenKategori = '';
  String _gpsDurum = "Konumu Getir";

  String? _duzenlenenKategoriId;
  String? _duzenlenenKategoriAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _isletmeBildirimi());
  }

  Future<void> _isletmeBildirimi() async {
    final bekleyen = await _firestoreServisi.esnafBasvurulariDinle().first;
    final vergiler = await _firestoreServisi.vergiGuncellemeleriDinle().first;
    if (!mounted || (bekleyen.isEmpty && vergiler.isEmpty)) return;
    final parcilar = <String>[
      if (bekleyen.isNotEmpty) '${bekleyen.length} işletme başvurusu',
      if (vergiler.isNotEmpty) '${vergiler.length} vergi güncellemesi',
    ];
    final incele = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşletme bildirimi var'),
        content: Text('${parcilar.join(' ve ')} onay bekliyor. Vergi numarasını ve levhayı inceleyin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Sonra')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İncele')),
        ],
      ),
    );
    if (incele == true && mounted) _isletmeBasvurulariPanel();
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
    _kategoriAdController.dispose();
    _iptalNedeniController.dispose();
    _aracTuruController.dispose();
    _aracSinifiController.dispose();
    super.dispose();
  }

  void _aracTuruYonetimi() {
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
                  labelColor: Colors.blueGrey,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blueGrey,
                  tabs: [
                    Tab(text: "Araç Türleri"),
                    Tab(text: "Araç Sınıfları"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _aracTuruListeBolumu(),
                      _aracSinifiListeBolumu(),
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

  Widget _aracTuruListeBolumu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _aracTuruController,
            decoration: InputDecoration(
              labelText: "Yeni Araç Türü Ekle (SUV, Sedan vb.)",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueGrey),
                onPressed: () async {
                  if (_aracTuruController.text.isNotEmpty) {
                    await _firestoreServisi.aracTuruEkle(_aracTuruController.text.trim());
                    _aracTuruController.clear();
                  }
                },
              ),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _firestoreServisi.aracTurleriniGetir(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final turler = snapshot.data!;
                return ListView.builder(
                  itemCount: turler.length,
                  itemBuilder: (context, index) {
                    final tur = turler[index];
                    return ListTile(
                      title: Text(tur),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _aracTuruDuzenleDialog(tur),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _firestoreServisi.aracTuruSil(tur);
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

  Widget _aracSinifiListeBolumu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _aracSinifiController,
            decoration: InputDecoration(
              labelText: "Yeni Araç Sınıfı Ekle (Ekonomik, Lüks vb.)",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueGrey),
                onPressed: () async {
                  if (_aracSinifiController.text.isNotEmpty) {
                    await _firestoreServisi.aracSinifiEkle(_aracSinifiController.text.trim());
                    _aracSinifiController.clear();
                  }
                },
              ),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _firestoreServisi.aracSiniflariniGetir(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final siniflar = snapshot.data!;
                return ListView.builder(
                  itemCount: siniflar.length,
                  itemBuilder: (context, index) {
                    final sinif = siniflar[index];
                    return ListTile(
                      title: Text(sinif),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _aracSinifiDuzenleDialog(sinif),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await _firestoreServisi.aracSinifiSil(sinif);
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

  void _aracTuruDuzenleDialog(String eskiTur) {
    final controller = TextEditingController(text: eskiTur);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Araç Türünü Düzenle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestoreServisi.aracTuruGuncelle(eskiTur, controller.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _aracSinifiDuzenleDialog(String eskiSinif) {
    final controller = TextEditingController(text: eskiSinif);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sınıf Adını Düzenle"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestoreServisi.aracSinifiGuncelle(eskiSinif, controller.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
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
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(labelText: "Kategori Adı (Örn: Berber)", border: OutlineInputBorder()),
                      ),
                      if (_kategoriAdController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              KategoriGorseli.ikon(_kategoriAdController.text),
                              color: KategoriGorseli.renk(_kategoriAdController.text),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'İkon ada göre seçildi. Ekle deyince kaydolur.',
                                style: TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                                  final ikonKod = KategoriGorseli.ikon(_kategoriAdController.text).codePoint;
                                  final renkKod = KategoriGorseli.renk(_kategoriAdController.text).toARGB32();
                                  if (_duzenlenenKategoriId == null) {
                                    await _firestoreServisi.kategoriEkle(_kategoriAdController.text, ikon: ikonKod, renk: renkKod);
                                  } else {
                                    await _firestoreServisi.kategoriGuncelle(
                                        _duzenlenenKategoriId!,
                                        _kategoriAdController.text,
                                        eskiAd: _duzenlenenKategoriAd,
                                        ikon: ikonKod,
                                        renk: renkKod,
                                    );
                                  }
                                  if (!context.mounted) return;
                                  setModalState(() {
                                    _kategoriAdController.clear();
                                    _duzenlenenKategoriId = null;
                                    _duzenlenenKategoriAd = null;
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
                                leading: _buildKategoriIkonWidget(
                                    kat['ad'],
                                    ikonKod: kat['ikon'] as int?,
                                    color: _kategoriRengiGetir(kat['ad'], renkKod: kat['renk'] as int?)
                                ),
                                title: Text(kat['ad']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                      onPressed: () {
                                        setModalState(() {
                                          _duzenlenenKategoriId = kat['id'];
                                          _duzenlenenKategoriAd = kat['ad'];
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
          _gpsDurum = "Konum Tamam ?";
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
                      TextField(controller: _telController, keyboardType: TextInputType.phone, inputFormatters: TelefonGirdisi.bicim, decoration: const InputDecoration(labelText: "Telefon", hintText: "05xx xxx xx xx", isDense: true, border: OutlineInputBorder())),
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
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: () async {
                          final telefonMesaji = TelefonGirdisi.hata(_telController.text);
                          if (telefonMesaji != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(telefonMesaji)));
                            return;
                          }
                          EsnafModeli guncelEsnaf = EsnafModeli(
                            id: esnaf?.id ?? '',
                            isletmeAdi: _adController.text,
                            kategori: _secilenKategori,
                            telefon: TelefonGirdisi.rakamlar(_telController.text),
                            email: 'esnaf_test@mail.com',
                            il: _ilController.text,
                            ilce: _ilceController.text,
                            adres: _adresController.text,
                            konum: GeoPoint(
                              double.tryParse(_latController.text) ?? 0.0,
                              double.tryParse(_lonController.text) ?? 0.0,
                            ),
                            yapayZekaAktif: esnaf?.yapayZekaAktif ?? false,
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
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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

  void _belgeOnaylariPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Bekleyen Belge Onayları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreServisi.tumKullanicilariGetir(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final bekleyenler = <Map<String, dynamic>>[];
                  for (var user in snapshot.data!) {
                    final belgeler = user['belgeler'] as Map<String, dynamic>?;
                    if (belgeler == null) continue;
                    final durakta = belgeler.entries.any((e) =>
                        !taksiZorunluBelgeler.contains(e.key) &&
                        e.value is Map &&
                        e.value['status'] == 'Bekliyor');
                    if (durakta) bekleyenler.add(user);
                  }

                  if (bekleyenler.isEmpty) return const Center(child: Text("Onay bekleyen belge bulunamadı."));

                  return ListView.builder(
                    itemCount: bekleyenler.length,
                    itemBuilder: (context, index) {
                      final user = bekleyenler[index];
                      final belgeler = user['belgeler'] as Map<String, dynamic>;
                      final pendingList = belgeler.entries.where((e) =>
                          !taksiZorunluBelgeler.contains(e.key) &&
                          e.value is Map &&
                          e.value['status'] == 'Bekliyor').toList();

                      return ExpansionTile(
                        title: Text("${user['adSoyad'] ?? user['ad'] ?? 'İsimsiz'} (${user['tel']})"),
                        subtitle: Text("${pendingList.length} belge onay bekliyor"),
                        children: pendingList.map((belge) {
                          String tur = belge.key;
                          String url = belge.value['url'];
                          return ListTile(
                            leading: const Icon(Icons.description, color: Colors.orange),
                            title: Text(_belgeTurMetni(tur)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, color: Colors.blue),
                                  onPressed: () => _belgeGoruntule(url, _belgeTurMetni(tur)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: () => _firestoreServisi.belgeOnayla(user['tel'], tur, true),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => _firestoreServisi.belgeOnayla(user['tel'], tur, false),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _belgeTurMetni(String tur) {
    switch (tur) {
      case 'selfie': return "Canlı Yüz Doğrulama";
      case 'ehliyet': return "Kimlik / Ehliyet";
      case 'sofor_karti': return "Ticari Araç Kullanma Belgesi";
      case 'adli_sicil': return "Adli Sicil Kaydı";
      case 'psikoteknik': return "Psikoteknik Raporu";
      case 'ruhsat': return "Ruhsat Bilgileri";
      case 'sigorta': return "Trafik Sigortası";
      case 'arac_foto': return "Araç Görselleri";
      case 'arac_on': return "Araç Ön Görünüm";
      case 'arac_arka': return "Araç Arka Görünüm";
      case 'arac_sag': return "Araç Sağ Yan";
      case 'arac_sol': return "Araç Sol Yan";
      case 'saglik_raporu': return "Sağlık Raporu";
      case 'alkol_testi': return "Alkol/Madde Testi";
      case 'muayene_raporu': return "Muayene Raporu";
      case 'belediye_ruhsat': return "Belediye Ruhsatı";
      case 'ferdi_kaza': return "Ferdi Kaza Sigortası";
      case 'taksimetre_belge': return "Taksimetre Belgesi";
      case 'vergi_levhasi': return "Vergi Levhasi";
      case 'ikametgah': return "İkametgah";
      default: return tur;
    }
  }

  void _belgeGoruntule(String url, String baslik) {
    showDialog(
      context: context,
      builder: (ctx) {
        final Widget gorsel;
        if (url.startsWith('http')) {
          gorsel = Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100),
          );
        } else if (kIsWeb) {
          gorsel = const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.computer, color: Colors.blue, size: 50),
              SizedBox(height: 10),
              Text("Web tarayıcıda yerel dosya önizleme kısıtlıdır. Lütfen mobil cihazdan kontrol edin.", textAlign: TextAlign.center),
            ],
          );
        } else if (File(url).existsSync()) {
          gorsel = Image.file(File(url), fit: BoxFit.contain);
        } else {
          gorsel = const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 50),
              SizedBox(height: 10),
              Text("Görsel yerel cihazda bulunamadı.", textAlign: TextAlign.center),
            ],
          );
        }
        final bosluk = MediaQuery.sizeOf(ctx).height - 240;
        final yukseklik = bosluk.clamp(220.0, 560.0);
        return AlertDialog(
          title: Text(baslik),
          content: SizedBox(
            width: double.maxFinite,
            height: yukseklik,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: gorsel,
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat"))],
        );
      },
    );
  }

  void _isletmeBasvurulariPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DefaultTabController(
        length: 3,
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('İşletme başvuruları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ),
              const TabBar(
                labelColor: Colors.indigo,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.indigo,
                tabs: [
                  Tab(text: 'Bekleyen'),
                  Tab(text: 'Onaylanan'),
                  Tab(text: 'İptal/Red'),
                ],
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreServisi.esnafBasvurulariTumunuDinle(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final liste = snapshot.data!;
                    List<Map<String, dynamic>> sec(String durum) =>
                        liste.where((b) => b['durum']?.toString() == durum).toList();
                    return TabBarView(
                      children: [
                        Column(
                          children: [
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _firestoreServisi.vergiGuncellemeleriDinle(),
                              builder: (context, vergiSnap) {
                                final vergiler = vergiSnap.data ?? const <Map<String, dynamic>>[];
                                if (vergiler.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Vergi güncellemesi', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    ...vergiler.map(_vergiGuncellemeSatiri),
                                    const Divider(),
                                  ],
                                );
                              },
                            ),
                            Expanded(child: _basvuruListesi(sheetContext, sec('Bekliyor'), 'Onay bekleyen başvuru yok.', aksiyon: true)),
                          ],
                        ),
                        _basvuruListesi(sheetContext, sec('Onaylandı'), 'Onaylanan başvuru yok.'),
                        _basvuruListesi(
                          sheetContext,
                          liste.where((b) => b['durum']?.toString() == 'Reddedildi' || b['durum']?.toString() == 'İptal').toList(),
                          'İptal veya red yok.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basvuruListesi(BuildContext sheetContext, List<Map<String, dynamic>> liste, String bos, {bool aksiyon = false}) {
    if (liste.isEmpty) return Center(child: Text(bos));
    return ListView.builder(
      itemCount: liste.length,
      itemBuilder: (context, index) {
        final b = liste[index];
        final adresSatir = [
          b['ilce'],
          b['il'],
          b['adres'],
        ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' · ');
        final vergiNo = (b['vergiNo'] ?? '').toString().trim();
        final tur = (b['isletmeTuru'] ?? '').toString().trim();
        final not = (b['redNotu'] ?? '').toString().trim();
        return ListTile(
          onTap: () => _basvuruEvrak(b),
          title: Text((b['isletmeAdi'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${b['adSoyad'] ?? ''} · ${b['telefon'] ?? ''}\n${b['kategori'] ?? ''}${tur.isEmpty ? '' : ' · ${isletmeTuruYazisi(tur)}'} · VKN: ${vergiNo.isEmpty ? 'yok' : vergiNo}${adresSatir.isEmpty ? '' : '\n$adresSatir'}${not.isEmpty ? '' : '\nNot: $not'}\nAyrıntı ve levha için dokunun',
          ),
          isThreeLine: true,
          trailing: aksiyon
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Onayla',
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        final mesaj = await _firestoreServisi.esnafBasvurusuOnayla((b['id'] ?? '').toString());
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                          content: Text(mesaj ?? 'İşletme kaydı açıldı. Aynı telefonla girişte yönetici kapısı çıkar.'),
                          backgroundColor: mesaj == null ? Colors.green : Colors.orange,
                        ));
                      },
                    ),
                    IconButton(
                      tooltip: 'Reddet',
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _basvuruReddet(sheetContext, (b['id'] ?? '').toString(), (b['isletmeAdi'] ?? '').toString()),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _vergiGuncellemeSatiri(Map<String, dynamic> esnaf) {
    final g = esnaf['vergiGuncelleme'];
    final yeniTur = g is Map ? (g['isletmeTuru'] ?? '').toString() : '';
    final yeniNo = g is Map ? (g['vergiNo'] ?? '').toString() : '';
    final yeniUrl = g is Map ? (g['vergiLevhaUrl'] ?? '').toString() : '';
    final eskiTur = (esnaf['isletmeTuru'] ?? '').toString();
    final eskiNo = (esnaf['vergiNo'] ?? '').toString();
    final eskiUrl = (esnaf['vergiLevhaUrl'] ?? '').toString();
    final ad = (esnaf['isletmeAdi'] ?? 'İşletme').toString();
    String etiket(String tur) => tur == 'Şirket' ? 'VKN' : 'T.C.';
    return ListTile(
      onTap: () => _vergiKarsilastir(ad, eskiTur, eskiNo, eskiUrl, yeniTur, yeniNo, yeniUrl),
      title: Text(ad, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Kayıtlı ${etiket(eskiTur)}: ${eskiNo.isEmpty ? 'yok' : eskiNo}\nYeni ${etiket(yeniTur)}: ${yeniNo.isEmpty ? 'yok' : yeniNo}'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Onayla',
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () async {
              final mesaj = await _firestoreServisi.vergiGuncellemesiniOnayla((esnaf['id'] ?? '').toString());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(mesaj ?? 'Vergi bilgisi güncellendi.'),
                backgroundColor: mesaj == null ? Colors.green : Colors.orange,
              ));
            },
          ),
          IconButton(
            tooltip: 'Reddet',
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _vergiReddet((esnaf['id'] ?? '').toString(), ad),
          ),
        ],
      ),
    );
  }

  void _vergiKarsilastir(String ad, String eskiTur, String eskiNo, String eskiUrl, String yeniTur, String yeniNo, String yeniUrl) {
    String satir(String baslik, String tur, String no) {
      final alan = tur == 'Şirket' ? 'Vergi Kimlik No (VKN)' : 'T.C. Kimlik No';
      return '$baslik: ${tur.isEmpty ? 'tür yok' : isletmeTuruYazisi(tur)} · $alan: ${no.isEmpty ? 'yok' : no}';
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ad),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(satir('Kayıtlı', eskiTur, eskiNo)),
            const SizedBox(height: 8),
            Text(satir('Yeni', yeniTur, yeniNo)),
            if (eskiUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _belgeGoruntule(eskiUrl, 'Kayıtlı vergi levhası');
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Kayıtlı levhayı aç'),
              ),
            if (yeniUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _belgeGoruntule(yeniUrl, 'Yeni vergi levhası');
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Yeni levhayı aç'),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  void _vergiReddet(String esnafId, String ad) {
    final notController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$ad vergi güncellemesi reddedilsin mi?'),
        content: TextField(
          controller: notController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Not (opsiyonel)',
            hintText: 'Kayıtlı levha değişmez',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () async {
              await _firestoreServisi.vergiGuncellemesiniReddet(esnafId, notController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _basvuruEvrak(Map<String, dynamic> b) {
    String al(String anahtar) => (b[anahtar] ?? '').toString().trim();
    final adres = [al('adres'), al('ilce'), al('il')].where((e) => e.isNotEmpty).join(', ');
    final olanak = b['olanaklar'] is List ? (b['olanaklar'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).join(', ') : '';
    final satirlar = <String>[
      if (al('isletmeTuru').isNotEmpty) 'Tür: ${isletmeTuruYazisi(al('isletmeTuru'))}',
      'Yetkili: ${al('adSoyad').isEmpty ? 'yok' : al('adSoyad')}',
      'Telefon: ${al('telefon')}',
      'E-posta: ${al('email').isEmpty ? 'yok' : al('email')}',
      'Vergi Kimlik No (VKN): ${al('vergiNo').isEmpty ? 'yok' : al('vergiNo')}',
      if (adres.isNotEmpty) adres,
      'Mesai: ${al('acilis').isEmpty ? '—' : al('acilis')} – ${al('kapanis').isEmpty ? '—' : al('kapanis')}',
      'Kapalı gün: ${al('kapaliGun').isEmpty ? 'yok' : al('kapaliGun')}',
      if (al('sabitTel').isNotEmpty) 'Sabit: ${al('sabitTel')}',
      if (al('web').isNotEmpty) 'Web: ${al('web')}',
      if (al('instagram').isNotEmpty) 'Instagram: ${al('instagram')}',
      if (al('mersisNo').isNotEmpty) 'MERSİS: ${al('mersisNo')}',
      if (al('ticaretSicilNo').isNotEmpty) 'Ticaret sicil: ${al('ticaretSicilNo')}',
      if (olanak.isNotEmpty) 'Olanak: $olanak',
      if (al('tanitim').isNotEmpty) al('tanitim'),
    ];
    final url = al('vergiLevhaUrl');
    final logo = al('logoUrl');
    final no = al('vergiNo');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text((b['isletmeAdi'] ?? 'Başvuru').toString()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...satirlar.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(s),
                  )),
              const SizedBox(height: 8),
              if (url.isEmpty)
                const Text('Vergi levhası yok. Reddedip yeniden isteyebilirsiniz.')
              else
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _belgeGoruntule(url, 'Vergi levhası · ${no.isEmpty ? 'numara yok' : no}');
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Vergi levhasını aç'),
                ),
              if (logo.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _belgeGoruntule(logo, 'Logo');
                  },
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Logoyu aç'),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  void _basvuruReddet(BuildContext sheetContext, String id, String ad) {
    final notController = TextEditingController();
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('$ad reddedilsin mi?'),
        content: TextField(
          controller: notController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Not (opsiyonel)',
            hintText: 'Kişi başvuruyu yenileyebilir',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () async {
              await _firestoreServisi.esnafBasvurusuReddet(id, notController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _ajandalariSifirla() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tüm Ajanda Defterlerini Sıfırla"),
        content: const Text("Tüm esnafların oluşturulmuş ajanda defteri kayıtları silinecektir. Bu işlem geri alınamaz. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              await _firestoreServisi.tumAjandalariTemizle();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tüm ajanda defteri kayıtları sıfırlandı.")));
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
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firestoreServisi.esnafBasvurulariDinle(),
                    builder: (context, snap) {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firestoreServisi.vergiGuncellemeleriDinle(),
                        builder: (context, vergiSnap) {
                          final n = (snap.data?.length ?? 0) + (vergiSnap.data?.length ?? 0);
                          return _adminButonUst(
                            Icons.store_mall_directory_outlined,
                            n > 0 ? 'İşletme\nBaşvurusu ($n)' : 'İşletme\nBaşvurusu',
                            Colors.indigo,
                            () => _isletmeBasvurulariPanel(),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.block, 'Randevu İptal\nNedenleri', Colors.orange, () => _iptalNedenleriYonetimi()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.directions_car, 'Araç Tür/Sınıf\nTanımı', Colors.blueGrey, () => _aracTuruYonetimi()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.calendar_month, 'Defterleri\nSıfırla', Colors.red, () => _ajandalariSifirla()),
                  const SizedBox(width: 8),
                  _adminButonUst(Icons.verified_user, 'Belge\nOnayları', Colors.teal, () => _belgeOnaylariPanel()),
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
                      if (!katSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final kats = katSnapshot.data!;

                      if (kats.isEmpty) {
                        return const Center(child: Text("Lütfen önce kategori ekleyin."));
                      }

                      return CustomScrollView(
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final katVerisi = kats[index];
                                final katAd = katVerisi['ad'];
                                final kategoriEsnaflari = tumEsnaflar.where((e) => e.kategori == katAd).toList();

                                return ExpansionTile(
                                  leading: _buildKategoriIkonWidget(
                                      katAd,
                                      ikonKod: katVerisi['ikon'] as int?,
                                      color: _kategoriRengiGetir(katAd, renkKod: katVerisi['renk'] as int?)
                                  ),
                                  title: Text("$katAd (${kategoriEsnaflari.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  children: kategoriEsnaflari.isEmpty
                                      ? [const Padding(padding: EdgeInsets.all(10), child: Text("Bu kategoride kayıtlı esnaf yok.", style: TextStyle(fontSize: 12, color: Colors.grey)))]
                                      : kategoriEsnaflari.map((esnaf) => Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                    elevation: 0.5,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          title: Text(esnaf.isletmeAdi, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                          subtitle: Text("Tel: ${esnaf.telefon}\nAdres: ${esnaf.adres}"),
                                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _esnafFormu(esnaf: esnaf)),
                                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _confirmDelete(esnaf)),
                                          ]),
                                        ),
                                        SwitchListTile(
                                          title: const Text('Yapay zeka'),
                                          subtitle: const Text('Bu işletme kullansın'),
                                          value: esnaf.yapayZekaAktif,
                                          onChanged: (v) => _firestoreServisi.esnafGuncelle(esnaf.id, {'yapayZekaAktif': v}),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                );
                              },
                              childCount: kats.length,
                            ),
                          ),
                        ],
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

  Color _kategoriRengiGetir(String ad, {int? renkKod}) {
    if (renkKod != null) return Color(renkKod);
    return KategoriGorseli.renk(ad);
  }

  IconData _kategoriIkonuGetir(String kat) => KategoriGorseli.ikon(kat);

  Widget _buildKategoriIkonWidget(String ad, {int? ikonKod, double size = 24, Color? color}) {
    if (ikonKod != null) {
      return Text(
        String.fromCharCode(ikonKod),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: size,
          color: color,
          inherit: false,
        ),
      );
    }
    return Icon(_kategoriIkonuGetir(ad), size: size, color: color);
  }

  Widget _adminButonUst(IconData i, String b, Color r, VoidCallback t) => ElevatedButton(
    onPressed: t,
    style: ElevatedButton.styleFrom(
      backgroundColor: r,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
