import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/konum_servisi.dart';

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

  // Ajanda Oluşturma Değişkenleri
  DateTimeRange? _ajandaTarihAraligi;
  bool _haftaSonuDahil = true;

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

    slotAraligi = widget.esnaf.calismaSaatleri?['slotAraligi'] ?? 30;
    hizmetler = List<Map<String, dynamic>>.from(widget.esnaf.hizmetler ?? []);

    for (var h in hizmetler) {
      _hizmetSureControllerList.add(TextEditingController(text: h["sure"].toString()));
    }

    String? acStr = widget.esnaf.calismaSaatleri?['acilis'];
    String? kapStr = widget.esnaf.calismaSaatleri?['kapanis'];
    if (acStr != null) acilisSaat = acStr;
    if (kapStr != null) kapanisSaat = kapStr;
  }

  // --- EBOB HESAPLAMA (Akıllı Slot Mantığı) ---
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

  // --- AJANDA TARİH ARALIĞI SEÇİMİ ---
  Future<void> _tarihAraligiSec() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: _ajandaTarihAraligi,
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.blue)), child: child!),
    );
    if (picked != null) setState(() => _ajandaTarihAraligi = picked);
  }

  // --- AJANDA OLUŞTURMA İŞLEMİ ---
  Future<void> _ajandaOlustur() async {
    if (_ajandaTarihAraligi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen önce bir tarih aralığı seçin!"), backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _ayarlariKaydet(sessiz: true);
      
      if (!mounted) return;
      Navigator.pop(context); // Yükleme ikonunu kapat
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Ajanda Hazır!"),
          content: Text("${_ajandaTarihAraligi!.start.day}/${_ajandaTarihAraligi!.start.month} - ${_ajandaTarihAraligi!.end.day}/${_ajandaTarihAraligi!.end.month} tarihleri arası, $slotAraligi dakikalık slotlarla randevuya hazır hale getirildi."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam"))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
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
    for (var c in _hizmetSureControllerList) {
      c.dispose();
    }
    super.dispose();
  }

  void _hizmetEkleFormu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreServisi.hizmetTanimlariniGetir(widget.esnaf.kategori),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tanimliHizmetler = snapshot.data!;
          if (tanimliHizmetler.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Yönetici henüz bu kategori için hizmet tanımlamamış.")));

          return ListView.builder(
            itemCount: tanimliHizmetler.length,
            itemBuilder: (context, index) {
              final h = tanimliHizmetler[index];
              return ListTile(
                title: Text(h['ad']),
                leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                onTap: () {
                  setState(() {
                    hizmetler.add({"isim": h['ad'], "sure": 30, "fiyat": ""});
                    _hizmetSureControllerList.add(TextEditingController(text: "30"));
                  });
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _hizmetSil(int index) {
    setState(() {
      hizmetler.removeAt(index);
      _hizmetSureControllerList[index].dispose();
      _hizmetSureControllerList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_adController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _esnafDuzenleFormu)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bolumBasligi("Mesai Saatleri ve Aralık"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: Column(children: [
                _ayarSatiri("Açılış Saati", acilisSaat, () => _saatSec(true)),
                const Divider(height: 1),
                _ayarSatiri("Kapanış Saati", kapanisSaat, () => _saatSec(false)),
              ]),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Randevu Slot Aralığı", style: TextStyle(color: Colors.black87, fontSize: 14)),
                TextButton(
                  onPressed: () {
                    setState(() => slotAraligi = _idealSlotHesapla());
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hizmetlerinize göre en ideal aralık $slotAraligi dk olarak hesaplandı.")));
                  }, 
                  child: const Text("Otomatik Hesapla")
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: [5, 10, 15, 20, 30, 45, 60].contains(slotAraligi) ? slotAraligi : 15,
                  isExpanded: true,
                  items: [5, 10, 15, 20, 30, 45, 60].map((int value) => DropdownMenuItem<int>(value: value, child: Text("$value Dakika"))).toList(),
                  onChanged: (val) => setState(() => slotAraligi = val!),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _bolumBasligi("Ajanda Planlama"),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
              child: Column(children: [
                ListTile(
                  title: const Text("Tarih Aralığı Seç", style: TextStyle(fontSize: 14)),
                  subtitle: Text(_ajandaTarihAraligi == null ? "Henüz seçilmedi" : "${_ajandaTarihAraligi!.start.day}/${_ajandaTarihAraligi!.start.month} - ${_ajandaTarihAraligi!.end.day}/${_ajandaTarihAraligi!.end.month}"),
                  trailing: const Icon(Icons.calendar_month, color: Colors.blue),
                  onTap: _tarihAraligiSec,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text("Hafta Sonları Dahil", style: TextStyle(fontSize: 14)),
                  value: _haftaSonuDahil,
                  onChanged: (v) => setState(() => _haftaSonuDahil = v),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _ajandaOlustur,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text("Ajandayı Oluştur / Güncelle"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )
              ]),
            ),
            const SizedBox(height: 30),
            _bolumBasligi("Hizmetler ve Süreleri"),
            ...List.generate(hizmetler.length, (index) => _hizmetKarti(index)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _hizmetEkleFormu,
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              label: const Text("Yeni Hizmet Ekle", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _ayarlariKaydet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
              ),
              child: const Text("Ayarları Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _ayarSatiri(String baslik, String deger, VoidCallback onTap) => ListTile(
    title: Text(baslik, style: const TextStyle(fontSize: 15, color: Colors.black87)),
    trailing: Text(deger, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey)),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15),
  );

  Widget _hizmetKarti(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(hizmetler[index]["isim"], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
          const SizedBox(width: 15),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _hizmetSureControllerList[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: "Dk", border: InputBorder.none, isDense: true, labelStyle: TextStyle(fontSize: 12, color: Colors.blue)),
              onChanged: (v) => hizmetler[index]["sure"] = int.tryParse(v) ?? 30,
            ),
          ),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => _hizmetSil(index)),
        ],
      ),
    );
  }

  Widget _bolumBasligi(String baslik) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(baslik, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue)));

  Future<void> _ayarlariKaydet({bool sessiz = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnaf.id, {
        'calismaSaatleri': {'acilis': acilisSaat, 'kapanis': kapanisSaat, 'slotAraligi': slotAraligi},
        'hizmetler': hizmetler,
      });
      if (!mounted) return;
      if (!sessiz) {
        messenger.showSnackBar(const SnackBar(content: Text("Ayarlar başarıyla kaydedildi!"), backgroundColor: Colors.green));
      }
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
                      const Text("İşletme Bilgilerini Düzenle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 20),
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
                        onPressed: () => _konumGuncelle(setModalState),
                        icon: const Icon(Icons.gps_fixed),
                        label: Text(_gpsDurum),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, minimumSize: const Size(double.infinity, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _bilgileriKaydet();
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      setModalState(() {
        _latController.text = sonuc['enlem']!;
        _lonController.text = sonuc['boylam']!;
        _ilController.text = sonuc['il']!;
        _ilceController.text = sonuc['ilce']!;
        _adresController.text = sonuc['tamAdres']!;
        _gpsDurum = "Konum Tamam ✅";
      });
    } else {
      setModalState(() => _gpsDurum = "Hata oluştu.");
    }
  }

  Future<void> _saatSec(bool isAcilis) async {
    String current = isAcilis ? acilisSaat : kapanisSaat;
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);

    if (current == "24:00") {
      initial = const TimeOfDay(hour: 0, minute: 0);
    } else {
      final parts = current.split(":");
      initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (picked != null) {
      String formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      
      setState(() {
        if (isAcilis) {
          acilisSaat = formatted;
        } else {
          if (picked.hour == 0 && picked.minute == 0) {
            _showMidnightDialog();
          } else {
            kapanisSaat = formatted;
          }
        }
      });
    }
  }

  void _showMidnightDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kapanış Saati"),
        content: const Text("Bu saati 00:00 (Günün Başlangıcı) mı yoksa 24:00 (Günün Sonu) olarak mı kaydetmek istersiniz?"),
        actions: [
          TextButton(onPressed: () {
            setState(() => kapanisSaat = "00:00");
            Navigator.pop(context);
          }, child: const Text("00:00")),
          TextButton(onPressed: () {
            setState(() => kapanisSaat = "24:00");
            Navigator.pop(context);
          }, child: const Text("24:00", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}