import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/esnaf_modeli.dart';

class EsnafAjandaEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  const EsnafAjandaEkrani({super.key, required this.esnaf});

  @override
  State<EsnafAjandaEkrani> createState() => _EsnafAjandaEkraniState();
}

class _EsnafAjandaEkraniState extends State<EsnafAjandaEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  DateTime _seciliTarih = DateTime.now();
  DateTimeRange? _seciliAralik;
  String? _seciliAcilisSaat;
  String? _seciliKapanisSaat;
  bool _ogleArasiVar = false;
  String _ogleBaslangic = "12:00";
  String _ogleBitis = "13:00";
  int _slotAraligi = 30;
  String? _aktifKanal;

  final Map<String, bool> _calismaGunleri = {
    "Pazartesi": true,
    "Salı": true,
    "Çarşamba": true,
    "Perşembe": true,
    "Cuma": true,
    "Cumartesi": true,
    "Pazar": true,
  };

  @override
  void initState() {
    super.initState();
    if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      _aktifKanal = widget.esnaf.kanallar!.first;
    }
  }

  int _idealSlotHesapla(EsnafModeli esnaf) {
    if (esnaf.hizmetler == null || esnaf.hizmetler!.isEmpty) return 30;
    List<int> sureler = esnaf.hizmetler!.map((h) => int.tryParse(h['sure'].toString()) ?? 30).toList();
    int minSure = sureler.reduce((a, b) => a < b ? a : b);
    return [5, 10, 15, 20, 30, 45, 60].firstWhere((s) => s >= minSure, orElse: () => 30);
  }

  Future<void> _saatSec(bool acilis) async {
    final TimeOfDay initial = acilis 
        ? (_seciliAcilisSaat != null ? TimeOfDay.fromDateTime(DateFormat("HH:mm").parse(_seciliAcilisSaat!)) : const TimeOfDay(hour: 9, minute: 0))
        : (_seciliKapanisSaat != null ? TimeOfDay.fromDateTime(DateFormat("HH:mm").parse(_seciliKapanisSaat!)) : const TimeOfDay(hour: 19, minute: 0));

    final t = await showTimePicker(
      context: context, 
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (t != null) {
      setState(() {
        final s = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        if (acilis) {
          _seciliAcilisSaat = s;
        } else {
          _seciliKapanisSaat = s;
        }
      });
    }
  }

  Future<void> _ogleSaatSec(bool baslangic) async {
    final t = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay(hour: int.parse((baslangic ? _ogleBaslangic : _ogleBitis).split(":")[0]), minute: int.parse((baslangic ? _ogleBaslangic : _ogleBitis).split(":")[1])),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (t != null) {
      setState(() {
        final s = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        if (baslangic) {
          _ogleBaslangic = s;
        } else {
          _ogleBitis = s;
        }
      });
    }
  }

  void _topluAjandaOlustur(String? kanal) async {
    if (_seciliAralik == null || _seciliAcilisSaat == null || _seciliKapanisSaat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tarih aralığı ve ajanda saatlerini seçin")));
      return;
    }
    
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    DateTime start = _seciliAralik!.start;
    DateTime end = _seciliAralik!.end;
    
    try {
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        DateTime gun = start.add(Duration(days: i));
        String gunAdi = DateFormat('EEEE', 'tr_TR').format(gun);
        if (_calismaGunleri[gunAdi] == true) {
          await _firestoreServisi.ajandaOlustur(
            esnafId: widget.esnaf.id,
            tarih: gun,
            acilis: _seciliAcilisSaat!,
            kapanis: _seciliKapanisSaat!,
            slotDakika: _slotAraligi,
            ogleBaslangic: _ogleArasiVar ? _ogleBaslangic : null,
            ogleBitis: _ogleArasiVar ? _ogleBitis : null,
            kanal: kanal
          );
        }
      }
    } finally {
      if (mounted) {
        navigator.pop();
      }
    }
    
    if (mounted) {
      messenger.showSnackBar(const SnackBar(content: Text("Ajanda başarıyla oluşturuldu")));
      setState(() {});
    }
  }

  bool _ajandaAcikMi(EsnafModeli esnaf, DateTime tarih, String? kanal) {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String anahtar = kanal != null ? "${tarihStr}_$kanal" : tarihStr;
    return esnaf.aktifGunler?.contains(anahtar) ?? false;
  }

  List<String> _slotlariUret(EsnafModeli esnaf) {
    final calisma = esnaf.calismaSaatleri;
    if (calisma == null) return [];

    String acilis = calisma['acilis'] ?? "09:00";
    String kapanis = calisma['kapanis'] ?? "18:00";
    int slotAraligi = calisma['slotDakika'] ?? 30;

    List<String> list = [];
    try {
      DateTime bas = DateFormat("HH:mm").parse(acilis);
      DateTime bit = DateFormat("HH:mm").parse(kapanis);
      
      while (bas.isBefore(bit)) {
        list.add(DateFormat("HH:mm").format(bas));
        bas = bas.add(Duration(minutes: slotAraligi));
      }
    } catch (e) { debugPrint("Slot üretme hatası: $e"); }
    return list;
  }

  void _randevuAlModal(EsnafModeli esnaf, String saat, String? aktifKanal) {
    final adController = TextEditingController();
    final telController = TextEditingController();
    String? secilenHizmet;
    int? hizmetSuresi;
    String? secilenPersonel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (stfContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(stfContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$saat Slotuna Randevu", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              if (aktifKanal != null) Text("Kanal: $aktifKanal", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: adController, decoration: const InputDecoration(labelText: "Müşteri Adı", isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon", isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Hizmet", isDense: true, border: OutlineInputBorder()),
                items: (esnaf.hizmetler ?? []).map<DropdownMenuItem<String>>((h) => DropdownMenuItem(value: h['isim'], child: Text("${h['isim']} (${h['sure']} dk)"))).toList(),
                onChanged: (val) {
                  final h = esnaf.hizmetler!.firstWhere((x) => x['isim'] == val);
                  setModalState(() { secilenHizmet = val; hizmetSuresi = h['sure']; });
                },
              ),
              const SizedBox(height: 10),
              if (esnaf.personeller != null && esnaf.personeller!.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Personel", isDense: true, border: OutlineInputBorder()),
                  items: esnaf.personeller!.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p.toString(), child: Text(p.toString()))).toList(),
                  onChanged: (val) => setModalState(() => secilenPersonel = val),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (adController.text.isEmpty || telController.text.isEmpty || secilenHizmet == null) {
                    ScaffoldMessenger.of(stfContext).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun")));
                    return;
                  }
                  
                  final messenger = ScaffoldMessenger.of(stfContext);
                  final navigator = Navigator.of(stfContext);

                  final yeniRandevu = RandevuModeli(
                    id: "",
                    esnafId: esnaf.id,
                    esnafAdi: esnaf.isletmeAdi,
                    kullaniciAd: adController.text,
                    kullaniciTel: telController.text,
                    hizmetAdi: secilenHizmet!,
                    tarih: _seciliTarih,
                    saat: saat,
                    sure: hizmetSuresi ?? 30,
                    durum: "Onaylandı",
                    calisan_personel: secilenPersonel,
                    randevu_kanali: aktifKanal
                  );
                  await _firestoreServisi.randevuEkle(yeniRandevu);
                  
                  if (!stfContext.mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text("Randevu kaydedildi")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                child: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EsnafModeli>(
      stream: _firestoreServisi.esnafGetir(widget.esnaf.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text("Hata: ${snapshot.error}")));
        if (snapshot.connectionState == ConnectionState.waiting) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        
        final esnaf = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text("${esnaf.isletmeAdi} Ajandası", style: const TextStyle(fontSize: 18)),
            actions: [
              IconButton(icon: const Icon(Icons.settings), onPressed: () {
                // Ayarlar modalı veya sayfası açılabilir
              })
            ],
          ),
          body: Column(
            children: [
              _tarihSecici(true),
              if (esnaf.kanallar != null && esnaf.kanallar!.isNotEmpty)
                Container(
                  height: 50,
                  color: Colors.white,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: esnaf.kanallar!.map((k) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: ChoiceChip(
                        label: Text(k.toString()),
                        selected: _aktifKanal == k.toString(),
                        onSelected: (s) {
                          setState(() {
                            _aktifKanal = k.toString();
                          });
                        },
                      ),
                    )).toList(),
                  ),
                ),
              Expanded(child: _slotListesi(esnaf, _aktifKanal)),
            ],
          ),
        );
      }
    );
  }

  Widget _gunSecimSatiri(String gun) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Checkbox(value: _calismaGunleri[gun], onChanged: (v) => setState(() => _calismaGunleri[gun] = v!)),
      Text(gun, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _tarihSecici(bool acik) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _seciliTarih = _seciliTarih.subtract(const Duration(days: 1)))),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
            label: Text(
              DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_seciliTarih), 
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.bold, 
                color: Colors.black87
              )
            ),
            onPressed: () async {
              final picker = await showDatePicker(
                context: context, 
                initialDate: _seciliTarih, 
                firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                lastDate: DateTime.now().add(const Duration(days: 365)), 
                locale: const Locale('tr', 'TR'),
              );
              if (picker != null && mounted) setState(() => _seciliTarih = picker);
            },
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _seciliTarih = _seciliTarih.add(const Duration(days: 1)))),
        ],
      ),
    );
  }

  Widget _slotListesi(EsnafModeli esnaf, String? kanal) {
    bool acik = _ajandaAcikMi(esnaf, _seciliTarih, kanal);
    if (!acik) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text("Ajanda Ayarları", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue))),
                  const SizedBox(height: 15),
                  const Text("Ajanda Saatlerini Seç", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _saatSec(true),
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(_seciliAcilisSaat == null ? "Başlangıç Saati" : "Başlangıç: $_seciliAcilisSaat"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _saatSec(false),
                          icon: const Icon(Icons.access_time_filled, size: 16),
                          label: Text(_seciliKapanisSaat == null ? "Bitiş Saati" : "Bitiş: $_seciliKapanisSaat"),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text("Tarih Aralığı Seç", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: Icon(Icons.date_range, size: 18, color: _seciliAralik != null ? Colors.white : Colors.blue),
                    label: Text(
                      _seciliAralik == null ? "Başlangıç ve Bitiş Tarihi Seç" : "${DateFormat('dd/MM/yyyy').format(_seciliAralik!.start)} - ${DateFormat('dd/MM/yyyy').format(_seciliAralik!.end)}",
                      style: TextStyle(color: _seciliAralik != null ? Colors.white : Colors.black87, fontSize: 13),
                    ),
                    onPressed: () async {
                      final a = await showDateRangePicker(
                        context: context, 
                        firstDate: DateTime.now().subtract(const Duration(days: 1)), 
                        lastDate: DateTime.now().add(const Duration(days: 365)), 
                        initialDateRange: _seciliAralik, 
                        locale: const Locale('tr', 'TR'),
                      );
                      if (a != null) setState(() => _seciliAralik = a);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48), 
                      backgroundColor: _seciliAralik != null ? Colors.amber : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: _seciliAralik != null ? Colors.amber : Colors.blue.shade100),
                    ),
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Öğle Arası", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Switch(value: _ogleArasiVar, onChanged: (v) => setState(() => _ogleArasiVar = v), activeThumbColor: Colors.amber),
                    ],
                  ),
                  if (_ogleArasiVar)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _ogleSaatSec(true),
                              icon: const Icon(Icons.fastfood_outlined, size: 16),
                              label: Text("Başlangıç: $_ogleBaslangic"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _ogleSaatSec(false),
                              icon: const Icon(Icons.done_all, size: 16),
                              label: Text("Bitiş: $_ogleBitis"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 30),
                  const Text("Çalışma Günleri", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _calismaGunleri.keys.take(4).map((gun) => _gunSecimSatiri(gun)).toList(),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _calismaGunleri.keys.skip(4).map((gun) => _gunSecimSatiri(gun)).toList(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Slot Aralığı", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      TextButton.icon(onPressed: () => setState(() => _slotAraligi = _idealSlotHesapla(esnaf)), icon: const Icon(Icons.calculate_outlined, size: 14), label: const Text("Hesapla", style: TextStyle(fontSize: 11))),
                    ],
                  ),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [5, 10, 15, 20, 30, 45, 60].contains(_slotAraligi) ? _slotAraligi : 15,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, color: Colors.black),
                        items: [5, 10, 15, 20, 30, 45, 60].map((int value) => DropdownMenuItem<int>(value: value, child: Text("$value Dakika"))).toList(),
                        onChanged: (val) => setState(() => _slotAraligi = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: (_seciliAralik == null || _seciliAcilisSaat == null || _seciliKapanisSaat == null) ? null : () => _topluAjandaOlustur(kanal),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text("AJANDAYI OLUŞTUR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.randevulariGetir(esnaf.id, _seciliTarih),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final tumRandevular = snapshot.data ?? [];
        final slotlar = _slotlariUret(esnaf);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: slotlar.length,
          itemBuilder: (context, index) {
            final saat = slotlar[index];
            final randevu = tumRandevular.where((r) => r.saat == saat && (kanal == null || r.randevu_kanali == kanal)).toList();
            
            bool dolu = randevu.isNotEmpty;
            return Card(
              color: dolu ? Colors.orange.shade50 : Colors.white,
              child: ListTile(
                leading: Text(saat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                title: Text(dolu ? randevu.first.kullaniciAd : "Boş Slot"),
                subtitle: Text(dolu ? "${randevu.first.hizmetAdi} (${randevu.first.kullaniciTel})" : "Randevu oluşturmak için tıklayın"),
                trailing: Icon(dolu ? Icons.check_circle : Icons.add_circle_outline, color: dolu ? Colors.green : Colors.grey),
                onTap: () {
                  if (!dolu) {
                    _randevuAlModal(esnaf, saat, kanal);
                  } else {
                    // Randevu detayları veya silme işlemi
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
