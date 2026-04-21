import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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
  int _slotAraligi = 30;
  bool _setupVarsayilanlariYuklendi = false;

  final bool _ogleArasiVar = false;
  final String _ogleBaslangic = "12:00";
  final String _ogleBitis = "13:00";
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
      _aktifKanal = widget.esnaf.kanallar!.first.toString();
    }
    
    _seciliAcilisSaat = widget.esnaf.calismaSaatleri?['acilis'] ?? "09:00";
    _seciliKapanisSaat = widget.esnaf.calismaSaatleri?['kapanis'] ?? "18:00";
    _slotAraligi = _hesaplaIdealSlot(widget.esnaf.hizmetler);
    
    int? mevcutSlot = widget.esnaf.calismaSaatleri?['slotDakika'] ?? widget.esnaf.calismaSaatleri?['slotAraligi'];
    if (mevcutSlot != null) {
      bool uyumlu = true;
      for (var h in widget.esnaf.hizmetler ?? []) {
        int sure = int.tryParse(h['sure'].toString()) ?? 0;
        if (sure > 0 && sure % mevcutSlot != 0) { uyumlu = false; break; }
      }
      if (uyumlu) _slotAraligi = mevcutSlot;
    }
  }

  int _hesaplaIdealSlot(List<dynamic>? hizmetler) {
    if (hizmetler == null || hizmetler.isEmpty) return 30;
    List<int> sureler = hizmetler
        .map((h) => int.tryParse(h['sure'].toString()) ?? 0)
        .where((s) => s > 0)
        .toList();
    if (sureler.isEmpty) return 30;

    int gcd(int a, int b) {
      while (b != 0) {
        var t = b;
        b = a % b;
        a = t;
      }
      return a;
    }

    int sonuc = sureler[0];
    for (int i = 1; i < sureler.length; i++) {
      sonuc = gcd(sonuc, sureler[i]);
    }
    
    if (sonuc < 5) return 5;
    if (sonuc > 60) return 60;
    return sonuc;
  }

  Future<void> _saatSec(bool acilis) async {
    String? mevcut = acilis ? _seciliAcilisSaat : _seciliKapanisSaat;
    TimeOfDay initial;
    
    if (mevcut != null && mevcut != "24:00") {
      try {
        initial = TimeOfDay.fromDateTime(DateFormat("HH:mm").parse(mevcut));
      } catch (e) {
        initial = acilis ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 0, minute: 0);
      }
    } else {
      initial = acilis ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 0, minute: 0);
    }

    final t = await showTimePicker(
      context: context, 
      initialTime: initial, 
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );

    if (t != null) {
      if (!mounted) return;
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

  void _topluAjandaOlustur() async {
    if (_seciliAralik == null || _seciliAcilisSaat == null || _seciliKapanisSaat == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları seçin")));
      return;
    }
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    List<DateTime> tarihler = [];
    for (int i = 0; i <= _seciliAralik!.end.difference(_seciliAralik!.start).inDays; i++) {
      DateTime gun = _seciliAralik!.start.add(Duration(days: i));
      if (_calismaGunleri[DateFormat('EEEE', 'tr_TR').format(gun)] == true) {
        tarihler.add(gun);
      }
    }

    try {
      await _firestoreServisi.ajandaOlustur(
        esnafId: widget.esnaf.id,
        tarihler: tarihler,
        acilis: _seciliAcilisSaat!,
        kapanis: _seciliKapanisSaat!,
        slotDakika: _slotAraligi,
        ogleBaslangic: _ogleArasiVar ? _ogleBaslangic : null,
        ogleBitis: _ogleArasiVar ? _ogleBitis : null,
        kanal: _aktifKanal,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajanda başarıyla oluşturuldu")));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  void _ajandaSilOnay() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Ajandayı Sil"),
        content: Text("${DateFormat('dd/MM/yyyy').format(_seciliTarih)} tarihindeki ajandayı silmek istediğinize emin misiniz? Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(c);
              final messenger = ScaffoldMessenger.of(context);
              await _firestoreServisi.ajandaSil(widget.esnaf.id, _seciliTarih, _aktifKanal);
              if (navigator.mounted) navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Ajanda başarıyla silindi")));
            },
            child: const Text("SİL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<String> _slotlariUret(Map<String, dynamic> data, EsnafModeli esnaf) {
    List<String> list = [];
    try {
      String acilisStr = data['acilis'] ?? esnaf.calismaSaatleri?['acilis'] ?? "09:00";
      String kapanisStr = data['kapanis'] ?? esnaf.calismaSaatleri?['kapanis'] ?? "19:00";
      int slot = data['slotDakika'] ?? data['slotAraligi'] ?? 
                 esnaf.calismaSaatleri?['slotDakika'] ?? 
                 esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

      if (slot <= 0) return [];

      DateTime bas = DateFormat("HH:mm").parse(acilisStr);
      DateTime bit = DateFormat("HH:mm").parse(kapanisStr);
      if (bit.isBefore(bas) || kapanisStr == "00:00" || kapanisStr == "24:00") bit = bit.add(const Duration(days: 1));
      
      DateTime temp = bas;
      while (temp.isBefore(bit)) {
        list.add(DateFormat("HH:mm").format(temp));
        temp = temp.add(Duration(minutes: slot));
      }
    } catch (e) {
      debugPrint("Slot hatası: $e");
    }
    return list;
  }

  int _saatiDakikayaCevir(String saat) {
    final parcalar = saat.split(':');
    return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
  }

  String _dakikayiSaateCevir(int toplamDakika) {
    int saat = (toplamDakika ~/ 60) % 24;
    int dakika = toplamDakika % 60;
    return "${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}";
  }

  bool _isSlotInRange(String slot, RandevuModeli r, Map<String, dynamic> ajanda, EsnafModeli esnaf) {
    int current = _saatiDakikayaCevir(slot);
    int start = _saatiDakikayaCevir(r.saat);
    String acilis = ajanda['acilis'] ?? esnaf.calismaSaatleri?['acilis'] ?? "09:00";
    int acilisDakika = _saatiDakikayaCevir(acilis);
    if (current < acilisDakika) current += 1440;
    if (start < acilisDakika) start += 1440;
    int end = start + r.sure;
    return current >= start && current < end;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EsnafModeli>(
      stream: _firestoreServisi.esnafGetir(widget.esnaf.id),
      builder: (context, esnafSnapshot) {
        final guncelEsnaf = esnafSnapshot.data ?? widget.esnaf;

        if (esnafSnapshot.hasData && !_setupVarsayilanlariYuklendi) {
          _seciliAcilisSaat = guncelEsnaf.calismaSaatleri?['acilis'] ?? _seciliAcilisSaat;
          _seciliKapanisSaat = guncelEsnaf.calismaSaatleri?['kapanis'] ?? _seciliKapanisSaat;
          
          int ideal = _hesaplaIdealSlot(guncelEsnaf.hizmetler);
          int? mevcutSlot = guncelEsnaf.calismaSaatleri?['slotDakika'] ?? guncelEsnaf.calismaSaatleri?['slotAraligi'];
          
          if (mevcutSlot != null) {
            bool uyumlu = true;
            for (var h in guncelEsnaf.hizmetler ?? []) {
              int sure = int.tryParse(h['sure'].toString()) ?? 0;
              if (sure > 0 && sure % mevcutSlot != 0) { uyumlu = false; break; }
            }
            _slotAraligi = uyumlu ? mevcutSlot : ideal;
          } else {
            _slotAraligi = ideal;
          }
          
          _setupVarsayilanlariYuklendi = true;
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text("${guncelEsnaf.isletmeAdi} Ajandası"),
            actions: [
              StreamBuilder<DocumentSnapshot>(
                stream: _firestoreServisi.gunlukAjandaGetir(guncelEsnaf.id, _seciliTarih, _aktifKanal),
                builder: (context, snapshot) {
                  bool exists = snapshot.hasData && snapshot.data!.exists;
                  if (!exists) return const SizedBox.shrink();

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final kapaliSlotlarRaw = data['kapaliSlotlar'] ?? {};
                  final slotlar = _slotlariUret(data, guncelEsnaf);
                  
                  bool tumuKapali = false;
                  if (slotlar.isNotEmpty) {
                    if (kapaliSlotlarRaw is Map) {
                      tumuKapali = slotlar.every((s) => kapaliSlotlarRaw.containsKey(s));
                    } else if (kapaliSlotlarRaw is List) {
                      tumuKapali = slotlar.every((s) => kapaliSlotlarRaw.contains(s));
                    }
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(tumuKapali ? Icons.lock_open : Icons.lock, color: tumuKapali ? Colors.green : Colors.orange),
                        onPressed: () => _tumuKapatAcFormu(data, tumuKapali),
                        tooltip: tumuKapali ? "Tüm Günü Aç" : "Tüm Günü Kapat",
                      ),
                      IconButton(onPressed: _ajandaSilOnay, icon: const Icon(Icons.delete_sweep, color: Colors.red)),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _tarihSecici(),
              if (guncelEsnaf.kanallar != null && guncelEsnaf.kanallar!.isNotEmpty) _kanalSecici(guncelEsnaf),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _firestoreServisi.gunlukAjandaGetir(guncelEsnaf.id, _seciliTarih, _aktifKanal),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    
                    String tarihStr = DateFormat('yyyy-MM-dd').format(_seciliTarih);
                    String anahtar = (_aktifKanal != null && _aktifKanal!.isNotEmpty) ? "${tarihStr}_$_aktifKanal" : tarihStr;
                    bool aktifMi = (guncelEsnaf.aktifGunler ?? []).contains(anahtar);

                    if ((!snapshot.hasData || !snapshot.data!.exists) && !aktifMi) return _ajandaKurulumFormu(guncelEsnaf);
                    
                    Map<String, dynamic> ajandaVerisi;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      ajandaVerisi = snapshot.data!.data() as Map<String, dynamic>;
                    } else {
                      ajandaVerisi = guncelEsnaf.calismaSaatleri ?? {'acilis': '09:00', 'kapanis': '19:00', 'slotDakika': 30};
                    }
                    
                    return _gunlukSlotGorunumu(guncelEsnaf, ajandaVerisi);
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void _tumuKapatAcFormu(Map<String, dynamic> data, bool ac) {
    if (ac) {
      _firestoreServisi.gunuKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, [], false);
      return;
    }

    String? seciliNeden;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tüm Günü Kapat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kapatma nedeni seçiniz:", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            StreamBuilder<List<String>>(
              stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final nedenler = snapshot.data!;
                return DropdownButtonFormField<String>(
                  items: nedenler.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => seciliNeden = v,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (seciliNeden == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen neden seçin")));
                return;
              }
              final navigator = Navigator.of(ctx);
              final slotlar = _slotlariUret(data, widget.esnaf);
              final randevular = await _firestoreServisi.randevulariGetir(widget.esnaf.id, _seciliTarih).first;
              
              List<String> yeniKapatilacaklar = [];
              for (var s in slotlar) {
                bool dolu = randevular.any((r) => (_aktifKanal == null || r.randevuKanali == _aktifKanal) && _isSlotInRange(s, r, data, widget.esnaf));
                if (!dolu) yeniKapatilacaklar.add(s);
              }
              await _firestoreServisi.gunuKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, yeniKapatilacaklar, true, neden: seciliNeden);
              if (navigator.mounted) navigator.pop();
            },
            child: const Text("KAPAT"),
          ),
        ],
      ),
    );
  }

  Widget _tarihSecici() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _seciliTarih = _seciliTarih.subtract(const Duration(days: 1)))),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_seciliTarih), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: _seciliTarih, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('tr', 'TR'));
              if (p != null) setState(() => _seciliTarih = p);
            },
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _seciliTarih = _seciliTarih.add(const Duration(days: 1)))),
        ],
      ),
    );
  }

  Widget _kanalSecici(EsnafModeli esnaf) {
    return Container(
      height: 50, color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: esnaf.kanallar!.map((k) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(k.toString()),
            selected: _aktifKanal == k.toString(),
            onSelected: (s) => setState(() => _aktifKanal = k.toString()),
          ),
        )).toList(),
      ),
    );
  }

  Widget _ajandaKurulumFormu(EsnafModeli esnaf) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.event_busy, size: 60, color: Colors.grey),
          const SizedBox(height: 10),
          const Text("Bu gün için ajanda henüz oluşturulmamış.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("Toplu Ajanda Oluştur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Divider(),
                  ListTile(
                    title: const Text("Tarih Aralığı Seç", style: TextStyle(fontSize: 13)),
                    subtitle: Text(_seciliAralik == null ? "Seçtiğiniz tarihler" : "${DateFormat('dd/MM').format(_seciliAralik!.start)} - ${DateFormat('dd/MM').format(_seciliAralik!.end)}"),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final a = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('tr', 'TR'));
                      if (a != null) {
                        if (!mounted) return;
                        setState(() { _seciliAralik = a; });
                      }
                    },
                  ),
                  Row(
                    children: [
                      Expanded(child: ListTile(title: const Text("Açılış", style: TextStyle(fontSize: 13)), subtitle: Text(_seciliAcilisSaat ?? "--:--"), onTap: () => _saatSec(true))),
                      Expanded(child: ListTile(title: const Text("Kapanış", style: TextStyle(fontSize: 13)), subtitle: Text(_seciliKapanisSaat ?? "--:--"), onTap: () => _saatSec(false))),
                    ],
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_slotAraligi),
                    initialValue: _slotAraligi,
                    decoration: const InputDecoration(labelText: "Slot Aralığı", labelStyle: TextStyle(fontSize: 13)),
                    items: [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240].map((e) => DropdownMenuItem(value: e, child: Text("$e Dakika"))).toList(),
                    onChanged: (v) {
                       setState(() {
                         _slotAraligi = v!;
                       });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _topluAjandaOlustur,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("AJANDAYI ŞİMDİ OLUŞTUR"),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _esnafRandevuEkleFormu(String saat, int slotDakika, List<dynamic> hizmetler) {
    final adController = TextEditingController();
    final telController = TextEditingController();
    List<Map<String, dynamic>> seciliHizmetler = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("$saat Randevusu Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: adController, decoration: const InputDecoration(labelText: "Müşteri Ad Soyad")),
                TextField(controller: telController, decoration: const InputDecoration(labelText: "Telefon Numarası"), keyboardType: TextInputType.phone),
                const SizedBox(height: 15),
                const Text("Hizmet Seçin (Çoklu Seçilebilir)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const Divider(),
                ...hizmetler.map((h) {
                  bool secili = seciliHizmetler.any((x) => x['isim'] == h['isim']);
                  return CheckboxListTile(
                    title: Text("${h['isim']} (${h['sure']} dk)"),
                    value: secili,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          seciliHizmetler.add(Map<String, dynamic>.from(h));
                        } else {
                          seciliHizmetler.removeWhere((x) => x['isim'] == h['isim']);
                        }
                      });
                    },
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                if (adController.text.isEmpty || telController.text.isEmpty || seciliHizmetler.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun")));
                  return;
                }
                
                int toplamSure = 0;
                String birlesikHizmet = seciliHizmetler.map((x) {
                  toplamSure += int.tryParse(x['sure'].toString()) ?? 0;
                  return x['isim'];
                }).join(' + ');

                final yeniRandevu = RandevuModeli(
                  id: '',
                  esnafId: widget.esnaf.id,
                  esnafAdi: widget.esnaf.isletmeAdi,
                  kullaniciAd: adController.text,
                  kullaniciTel: telController.text,
                  tarih: _seciliTarih,
                  saat: saat,
                  sure: toplamSure,
                  hizmetAdi: birlesikHizmet,
                  durum: 'Onaylandı',
                  randevuKanali: _aktifKanal,
                );

                await _firestoreServisi.randevuEkle(yeniRandevu);
                if (navigator.mounted) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text("Randevu başarıyla eklendi"), backgroundColor: Colors.green));
                }
              },
              child: const Text("KAYDET"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gunlukSlotGorunumu(EsnafModeli esnaf, Map<String, dynamic> ajanda) {
    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.randevulariGetir(esnaf.id, _seciliTarih),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final slotlar = _slotlariUret(ajanda, esnaf);
        final randevular = snapshot.data ?? [];
        final kapaliSlotlarRaw = ajanda['kapaliSlotlar'] ?? {};
        
        if (slotlar.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Hatalı saat ayarları. Lütfen ajandayı silip tekrar oluşturun.", textAlign: TextAlign.center)));

        final Set<String> islenmisRandevular = {};
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: slotlar.length,
          itemBuilder: (context, index) {
            final saat = slotlar[index];
            final r = randevular.where((x) => (_aktifKanal == null || x.randevuKanali == _aktifKanal) && _isSlotInRange(saat, x, ajanda, esnaf)).toList();
            
            int slotDakika = ajanda['slotDakika'] ?? ajanda['slotAraligi'] ?? 
                             esnaf.calismaSaatleri?['slotDakika'] ?? 
                             esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

            String bitisSaati;
            if (r.isNotEmpty) {
              int baslangicDakika = _saatiDakikayaCevir(r.first.saat);
              bitisSaati = _dakikayiSaateCevir(baslangicDakika + r.first.sure);
            } else {
              bitisSaati = _dakikayiSaateCevir(_saatiDakikayaCevir(saat) + slotDakika);
            }

            if (r.isEmpty) {
              bool kapaliMi = false;
              String neden = "Esnaf tarafından kapatıldı";
              
              if (kapaliSlotlarRaw is Map) {
                kapaliMi = kapaliSlotlarRaw.containsKey(saat);
                neden = kapaliSlotlarRaw[saat] ?? "Esnaf tarafından kapatıldı";
              } else if (kapaliSlotlarRaw is List) {
                kapaliMi = kapaliSlotlarRaw.contains(saat);
              }

              return Opacity(
                opacity: kapaliMi ? 0.6 : 1.0,
                child: Card(
                  elevation: 0,
                  color: kapaliMi ? Colors.grey.shade50 : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: kapaliMi ? Colors.grey.shade200 : Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    child: Row(
                      children: [
                        _saatGostergesi(saat, bitisSaati, esnaf.slotAralikliGoster, kapaliMi ? Colors.grey : Colors.black87),
                        const SizedBox(width: 15),
                        Expanded(
                          child: IgnorePointer(
                            ignoring: kapaliMi,
                            child: InkWell(
                              onTap: () => _esnafRandevuEkleFormu(saat, slotDakika, esnaf.hizmetler ?? []),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(kapaliMi ? "Randevuya Kapalı" : "Boş Slot", 
                                      style: TextStyle(color: kapaliMi ? Colors.grey : Colors.black54, fontSize: 16, fontStyle: kapaliMi ? FontStyle.italic : FontStyle.normal)),
                                    if (kapaliMi && neden.isNotEmpty)
                                      Text("Neden: $neden", style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(kapaliMi ? Icons.lock : Icons.lock_open, color: kapaliMi ? Colors.red.shade400 : Colors.green.shade400, size: 22),
                          onPressed: () => _slotKapatAcFormu(saat, kapaliMi),
                          tooltip: kapaliMi ? "Saati Randevuya Aç" : "Saati Randevuya Kapat",
                        ),
                        if (!kapaliMi) IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 22),
                          onPressed: () => _esnafRandevuEkleFormu(saat, slotDakika, esnaf.hizmetler ?? []),
                          tooltip: "Randevu Ekle",
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final randevu = r.first;
            if (islenmisRandevular.contains(randevu.id)) return const SizedBox();
            islenmisRandevular.add(randevu.id);

            return Card(
              elevation: 4,
              color: Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade200, width: 1.5)),
              child: InkWell(
                onTap: () => _randevuIslemMenusu(randevu),
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      _saatGostergesi(randevu.saat, bitisSaati, esnaf.slotAralikliGoster, Colors.orange),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(randevu.kullaniciAd, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange.shade900)),
                            const SizedBox(height: 4),
                            Text("${randevu.hizmetAdi} (${randevu.kullaniciTel})", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                      ),
                      const Column(
                        children: [
                          Icon(Icons.verified, color: Colors.green, size: 28),
                          SizedBox(height: 4),
                          Text("ONAYLI", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10))
                        ]
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _slotKapatAcFormu(String saat, bool kapali) {
    if (kapali) {
      _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, saat);
      return;
    }

    String? seciliNeden;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$saat Saatini Kapat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kapatma nedeni seçiniz:", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            StreamBuilder<List<String>>(
              stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final nedenler = snapshot.data!;
                return DropdownButtonFormField<String>(
                  items: nedenler.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => seciliNeden = v,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (seciliNeden == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen neden seçin")));
                return;
              }
              final navigator = Navigator.of(ctx);
              await _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, saat, neden: seciliNeden);
              if (navigator.mounted) navigator.pop();
            },
            child: const Text("KAPAT"),
          ),
        ],
      ),
    );
  }

  Widget _saatGostergesi(String baslangic, String bitis, bool aralikliMi, Color renk) {
    if (!aralikliMi) {
      return SizedBox(
        width: 60,
        child: Text(baslangic, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: renk)),
      );
    }
    return Text(
      "$baslangic - $bitis",
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: renk),
    );
  }

  void _randevuIslemMenusu(RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.kullaniciAd, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("${r.hizmetAdi} - ${r.saat}", style: const TextStyle(color: Colors.grey)),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _aksiyonButonu(ikon: Icons.phone, renk: Colors.blue, etiket: "Ara", onTap: () => launchUrl(Uri.parse("tel:${r.kullaniciTel}"))),
                _aksiyonButonu(ikon: Icons.message, renk: Colors.green, etiket: "WhatsApp", onTap: () {
                  String mesaj = "Merhaba ${r.kullaniciAd}, ${widget.esnaf.isletmeAdi} işletmesindeki ${DateFormat('dd/MM').format(r.tarih)} saat ${r.saat} randevunuz hakkında...";
                  launchUrl(Uri.parse("https://wa.me/${r.kullaniciTel}?text=${Uri.encodeComponent(mesaj)}"), mode: LaunchMode.externalApplication);
                }),
                _aksiyonButonu(ikon: Icons.cancel, renk: Colors.red, etiket: "İptal Et", onTap: () { Navigator.pop(context); _randevuIptalOnay(r); }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _aksiyonButonu({required IconData ikon, required Color renk, required String etiket, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 25, backgroundColor: renk.withValues(alpha: 0.1), child: Icon(ikon, color: renk)),
          const SizedBox(height: 8),
          Text(etiket, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _randevuIptalOnay(RandevuModeli r) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Randevuyu İptal Et"),
        content: const Text("Bu randevuyu iptal etmek istediğinize emin misiniz? Müşteriye bilgi verilmesi önerilir."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogContext);
              await _firestoreServisi.randevuIptalEt(r.id, "Esnaf tarafından iptal edildi.");
              if (nav.mounted) nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Randevu iptal edildi.")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("İptal Et"),
          ),
        ],
      ),
    );
  }
}
