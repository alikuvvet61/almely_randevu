import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/konum_servisi.dart';
import 'esnaf_ajanda_ekrani.dart';
import 'esnaf_randevu_onay_ekrani.dart';

class EsnafPanelEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  const EsnafPanelEkrani({super.key, required this.esnaf});

  @override
  State<EsnafPanelEkrani> createState() => _EsnafPanelEkraniState();
}

class _EsnafPanelEkraniState extends State<EsnafPanelEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _konumServisi = KonumServisi();

  late TextEditingController _adController;
  late TextEditingController _telController;
  late TextEditingController _ilController;
  late TextEditingController _ilceController;
  late TextEditingController _adresController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  String acilisSaat = "09:00";
  String kapanisSaat = "18:00";
  late int slotAraligi;
  List<Map<String, dynamic>> hizmetler = [];
  List<String> kanallar = [];
  List<String> personeller = [];

  bool _degisiklikVar = false;
  
  Map<String, bool> _calismaGunleri = {
    "Pazartesi": true,
    "Salı": true,
    "Çarşamba": true,
    "Perşembe": true,
    "Cuma": true,
    "Cumartesi": true,
    "Pazar": true,
  };

  final List<TextEditingController> _hizmetSureControllerList = [];
  String _gpsDurum = "Konumu Güncelle";

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.esnaf.isletmeAdi);
    _telController = TextEditingController(text: widget.esnaf.telefon);
    _ilController = TextEditingController(text: widget.esnaf.il);
    _ilceController = TextEditingController(text: widget.esnaf.ilce);
    _adresController = TextEditingController(text: widget.esnaf.adres);
    _latController = TextEditingController(text: widget.esnaf.konum.latitude.toString());
    _lonController = TextEditingController(text: widget.esnaf.konum.longitude.toString());

    hizmetler = List<Map<String, dynamic>>.from(widget.esnaf.hizmetler ?? []);
    kanallar = List<String>.from(widget.esnaf.kanallar ?? []);
    personeller = List<String>.from(widget.esnaf.personeller ?? []);

    for (var h in hizmetler) {
      _hizmetSureControllerList.add(TextEditingController(text: h["sure"].toString()));
    }

    slotAraligi = widget.esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

    String? acStr = widget.esnaf.calismaSaatleri?['acilis'];
    String? kapStr = widget.esnaf.calismaSaatleri?['kapanis'];
    if (acStr != null) acilisSaat = acStr;
    if (kapStr != null) kapanisSaat = kapStr;

    if (widget.esnaf.calismaSaatleri?['gunler'] != null) {
      Map<String, dynamic> gelenGunler = widget.esnaf.calismaSaatleri!['gunler'];
      gelenGunler.forEach((key, value) {
        if (_calismaGunleri.containsKey(key)) {
          _calismaGunleri[key] = value as bool;
        }
      });
    }
  }

  int _ebob(int a, int b) => b == 0 ? a : _ebob(b, a % b);

  int _idealSlotHesapla() {
    if (hizmetler.isEmpty) return 30;
    List<int> sureler = hizmetler.map((h) => int.tryParse(h['sure'].toString()) ?? 30).toList();
    int sonuc = sureler[0];
    for (int i = 1; i < sureler.length; i++) {
      sonuc = _ebob(sonuc, sureler[i]);
    }
    if (sonuc < 5) return 5;
    if (sonuc > 60) return 60;
    return sonuc;
  }

  String _getKanalAciklama() {
    switch (widget.esnaf.kategori) {
      case 'Kuaför': return "Uzman, Koltuk, Oda vb. yazılacak";
      case 'Taksi': return "durak, plaka, araçlar vb. yazılacak";
      case 'Halı Saha': return "Açık Saha, Kapalı Saha vb. yazılacak";
      case 'Oto Yıkama': return "Bölüm, Birim vb. yazılacak";
      case 'Restoran': return "Masa1, bölüm vb. yazılacak";
      case 'Düğün Salonu': return "Salon1, Salon2 vb. yazılacak";
      default: return "Birim, Bölüm, Masa vb. yazılacak";
    }
  }

  String _getHizmetAciklama() {
    switch (widget.esnaf.kategori) {
      case 'Kuaför': return "Saç, Sakal, Yıkama, Boya vb. yazılacak";
      case 'Taksi': return "Ulaşım, Özel, Kiralama vb. yazılacak";
      case 'Halı Saha': return "Maç, turnuva, Kiralama vb. yazılacak";
      case 'Oto Yıkama': return "İç, Dış, Cila vb. yazılacak";
      case 'Restoran': return "kahvaltı, yemek vb. yazılacak";
      case 'Düğün Salonu': return "Düğün, kına, nişan vb. yazılacak";
      default: return "Hizmet Türü";
    }
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
    for (var c in _hizmetSureControllerList) { c.dispose(); }
    super.dispose();
  }

  void _hizmetEkleFormu() {
    final isimController = TextEditingController();
    final sureController = TextEditingController(text: "30");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Hizmet Ekle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: isimController, decoration: InputDecoration(labelText: "Hizmet Adı", hintText: _getHizmetAciklama())),
            TextField(controller: sureController, decoration: const InputDecoration(labelText: "Süre (Dakika)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (isimController.text.isNotEmpty) {
                setState(() {
                  hizmetler.add({"isim": isimController.text, "sure": int.tryParse(sureController.text) ?? 30, "fiyat": ""});
                  _hizmetSureControllerList.add(TextEditingController(text: sureController.text));
                  _degisiklikVar = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _hizmetDuzenleFormu(int index) {
    final isimController = TextEditingController(text: hizmetler[index]["isim"]);
    final sureController = TextEditingController(text: hizmetler[index]["sure"].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hizmeti Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: isimController, decoration: const InputDecoration(labelText: "Hizmet Adı")),
            TextField(controller: sureController, decoration: const InputDecoration(labelText: "Süre (Dakika)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (isimController.text.isNotEmpty) {
                setState(() {
                  hizmetler[index]["isim"] = isimController.text;
                  hizmetler[index]["sure"] = int.tryParse(sureController.text) ?? 30;
                  _hizmetSureControllerList[index].text = sureController.text;
                  _degisiklikVar = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _hizmetSilOnay(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hizmeti Sil"),
        content: Text("'${hizmetler[index]["isim"]}' hizmetini silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () {
              setState(() {
                hizmetler.removeAt(index);
                _hizmetSureControllerList[index].dispose();
                _hizmetSureControllerList.removeAt(index);
                _degisiklikVar = true;
              });
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _listeElemaniEkle(String baslik, List<String> liste, String hint) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$baslik Ekle"),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() { liste.add(controller.text); _degisiklikVar = true; });
                Navigator.pop(context);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _listeElemaniDuzenle(String baslik, List<String> liste, int index) {
    final controller = TextEditingController(text: liste[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$baslik Düzenle"),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: "$baslik adını girin")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() { liste[index] = controller.text; _degisiklikVar = true; });
                Navigator.pop(context);
              }
            },
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _listeElemaniSilOnay(String baslik, List<String> liste, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$baslik Sil"),
        content: Text("'${liste[index]}' öğesini silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () { setState(() { liste.removeAt(index); _degisiklikVar = true; }); Navigator.pop(context); },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_degisiklikVar,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? cikisOnay = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Kaydedilmemiş Değişiklikler"),
            content: const Text("Yaptığınız değişiklikler kaydedilmedi. Çıkmak istediğinize emin misiniz?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Çık", style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (cikisOnay == true && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(_adController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          centerTitle: true,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsnafAjandaEkrani(esnaf: widget.esnaf))),
              icon: const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
              label: const Text("Ajanda", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: _esnafDuzenleFormu)
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RANDEVU YÖNETİMİ BÖLÜMÜ
              StreamBuilder<List<RandevuModeli>>(
                stream: _firestoreServisi.esnafTumRandevulariGetir(widget.esnaf.id),
                builder: (context, snapshot) {
                  final hepsi = snapshot.data ?? [];
                  final bekleyenler = hepsi.where((r) => r.durum == 'Onay bekliyor').toList();
                  
                  return Column(
                    children: [
                      if (bekleyenler.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id))
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notification_important, color: Colors.orange),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Text(
                                      "${bekleyenler.length} Randevu Onay Bekliyor",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // TÜM RANDEVULARI GÖR BUTONU/KARTI
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id))
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.history, color: Colors.blue),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    "Randevu Yönetimi & Geçmişi",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              ),

              _bolumKart(
                baslik: "Mesai Saatleri",
                icerik: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _ayarSatiri("Açılış Saati", acilisSaat, () => _saatSec(true)),
                    const Divider(height: 1),
                    _ayarSatiri("Kapanış Saati", kapanisSaat, () => _saatSec(false)),
                  ]),
                ),
              ),

              _bolumKart(
                baslik: "Randevu Kanalları",
                bilgiAciklama: _getKanalAciklama(),
                icerik: _listeWidget(kanallar, "Yeni Kanal Ekle", "Kanal", _getKanalAciklama()),
              ),
              _bolumKart(
                baslik: "Personeller",
                icerik: _listeWidget(personeller, "Yeni Personel Ekle", "Personel", "Personel adını girin"),
              ),
              _bolumKart(
                baslik: "Hizmetler ve Süreleri",
                bilgiAciklama: _getHizmetAciklama(),
                icerik: Column(
                  children: [
                    ...List.generate(hizmetler.length, (index) => _hizmetKarti(index)),
                    const SizedBox(height: 5),
                    TextButton.icon(
                      onPressed: _hizmetEkleFormu,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                      label: const Text("Yeni Hizmet Ekle", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _ayarlariKaydet(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                child: const Text("Ayarları Kaydet", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bolumKart({required String baslik, String? bilgiAciklama, required Widget icerik}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade50)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Text(baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
              if (bilgiAciklama != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: bilgiAciklama,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  ),
                ),
            ],
          ),
          children: [Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: icerik)],
        ),
      ),
    );
  }

  Widget _listeWidget(List<String> liste, String butonMetni, String elemanBaslik, String hint) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ...liste.asMap().entries.map((entry) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13))),
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18), onPressed: () => _listeElemaniDuzenle(elemanBaslik, liste, entry.key)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _listeElemaniSilOnay(elemanBaslik, liste, entry.key)),
                    ],
                  ),
                ),
                if (entry.key < liste.length - 1) const Divider(height: 1),
              ],
            );
          }),
          TextButton.icon(
            onPressed: () => _listeElemaniEkle(elemanBaslik, liste, hint),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(butonMetni, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _ayarSatiri(String baslik, String deger, VoidCallback onTap) => ListTile(
    title: Text(baslik, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    trailing: Text(deger, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
    onTap: onTap,
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
  );

  Widget _hizmetKarti(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(hizmetler[index]["isim"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _hizmetSureControllerList[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(labelText: "Dk", border: InputBorder.none, isDense: true, labelStyle: TextStyle(fontSize: 11)),
              onChanged: (v) {
                hizmetler[index]["sure"] = int.tryParse(v) ?? 30;
                setState(() { _degisiklikVar = true; });
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18), onPressed: () => _hizmetDuzenleFormu(index)),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => _hizmetSilOnay(index)),
        ],
      ),
    );
  }

  Future<void> _ayarlariKaydet({bool sessiz = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_degisiklikVar) {
      if (!sessiz) messenger.showSnackBar(const SnackBar(content: Text("Kayıt yapılacak Değişiklik Bulunamadı"), backgroundColor: Colors.orange));
      return;
    }
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnaf.id, {
        'calismaSaatleri': {'acilis': acilisSaat, 'kapanis': kapanisSaat, 'slotAraligi': slotAraligi, 'gunler': _calismaGunleri},
        'hizmetler': hizmetler,
        'kanallar': kanallar,
        'personeller': personeller,
      });
      setState(() => _degisiklikVar = false);
      if (!mounted) return;
      if (!sessiz) messenger.showSnackBar(const SnackBar(content: Text("Ayarlar başarıyla kaydedildi!"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  void _esnafDuzenleFormu() {
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
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 15),
                      const Text("İşletme Bilgilerini Düzenle", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 15),
                      TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı", isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      TextField(controller: _telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: TextField(controller: _ilController, decoration: const InputDecoration(labelText: "İl", isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _ilceController, decoration: const InputDecoration(labelText: "İlçe", isDense: true, border: OutlineInputBorder()))),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: _adresController, maxLines: 2, decoration: const InputDecoration(labelText: "Adres Bilgisi", isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () => _konumGuncelle(setModalState),
                        icon: const Icon(Icons.gps_fixed, size: 18),
                        label: Text(_gpsDurum, style: const TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, minimumSize: const Size(double.infinity, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () async { await _bilgileriKaydet(); },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text("Bilgileri Kaydet"),
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

  Future<void> _bilgileriKaydet() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnaf.id, {
        'isletmeAdi': _adController.text,
        'telefon': _telController.text,
        'il': _ilController.text,
        'ilce': _ilceController.text,
        'adres': _adresController.text,
        'konum': GeoPoint(double.tryParse(_latController.text) ?? 0.0, double.tryParse(_lonController.text) ?? 0.0),
      });
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text("İşletme bilgileri güncellendi!"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _konumGuncelle(StateSetter setModalState) async {
    setModalState(() => _gpsDurum = "Konum alınıyor...");
    final sonuc = await _konumServisi.konumuVeAdresiGetir();
    if (sonuc != null && !sonuc.containsKey('hata')) {
      double lat = double.tryParse(sonuc['enlem']!) ?? 0.0;
      double lon = double.tryParse(sonuc['boylam']!) ?? 0.0;
      String? profesyonelAdres = await profesyonelAdresGetir(lat, lon);
      setModalState(() {
        _latController.text = sonuc['enlem']!;
        _lonController.text = sonuc['boylam']!;
        _ilController.text = sonuc['il']!;
        _ilceController.text = sonuc['ilce']!;
        _adresController.text = profesyonelAdres ?? sonuc['tamAdres']!;
        _gpsDurum = "Konum Tamam ✅";
      });
    } else { setModalState(() => _gpsDurum = "Hata oluştu."); }
  }

  Future<String?> profesyonelAdresGetir(double lat, double lon) async {
    try {
      String? googleAdres = await _konumServisi.googleAdresGetir(lat, lon);
      if (googleAdres != null && googleAdres.isNotEmpty) return googleAdres;
      final nominatimUrl = 'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1&accept-language=tr';
      final response = await http.get(Uri.parse(nominatimUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonMap = convert.jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonMap.containsKey('address')) {
          final address = jsonMap['address'] as Map<String, dynamic>;
          String mahalle = address['suburb']?.toString() ?? address['village']?.toString() ?? '';
          String cadde = address['road']?.toString() ?? '';
          String no = address['house_number']?.toString() ?? '';
          String postaKodu = address['postcode']?.toString() ?? '';
          String ilce = address['city']?.toString() ?? address['town']?.toString() ?? '';
          String il = address['state']?.toString() ?? '';
          String ulke = address['country']?.toString() ?? '';
          return [mahalle, cadde, no.isNotEmpty ? "No:$no" : null, [postaKodu, ilce, il].where((e) => e.isNotEmpty).join(' '), ulke].where((e) => e != null && e.isNotEmpty).join(', ');
        }
      }
    } catch (e) { debugPrint("Adres hatası: $e"); }
    return null;
  }

  Future<void> _saatSec(bool isAcilis) async {
    String current = isAcilis ? acilisSaat : kapanisSaat;
    TimeOfDay initial = (current == "24:00") ? const TimeOfDay(hour: 0, minute: 0) : TimeOfDay(hour: int.parse(current.split(":")[0]), minute: int.parse(current.split(":")[1]));
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: initial, builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked != null) {
      String formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        if (isAcilis) acilisSaat = formatted;
        else (picked.hour == 0 && picked.minute == 0) ? _showMidnightDialog() : kapanisSaat = formatted;
        _degisiklikVar = true;
      });
    }
  }

  void _showMidnightDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Kapanış Saati"),
      content: const Text("00:00 mı yoksa 24:00 mü?"),
      actions: [
        TextButton(onPressed: () { setState(() { kapanisSaat = "00:00"; _degisiklikVar = true; }); Navigator.pop(context); }, child: const Text("00:00")),
        TextButton(onPressed: () { setState(() { kapanisSaat = "24:00"; _degisiklikVar = true; }); Navigator.pop(context); }, child: const Text("24:00")),
      ],
    ));
  }
}
