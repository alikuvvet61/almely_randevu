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
  DateTime? _baslangicTarihi;
  DateTime? _bitisTarihi;
  
  String? _seciliAcilisSaat;
  String? _seciliKapanisSaat;
  int _slotAraligi = 30;
  bool _setupVarsayilanlariYuklendi = false;

  bool _ogleArasiVar = false;
  String _ogleBaslangic = "12:00";
  String _ogleBitis = "13:00";
  String? _aktifKanal;

  late Stream<EsnafModeli> _esnafStream;
  Stream<DocumentSnapshot>? _ajandaStream;

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
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);
    
    if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      _aktifKanal = widget.esnaf.kanallar!.first.toString();
    } else {
      _aktifKanal = "Uygulama";
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

    _ajandaStreamGuncelle();
  }

  void _ajandaStreamGuncelle() {
    setState(() {
      _ajandaStream = _firestoreServisi.gunlukAjandaSnapStream(widget.esnaf.id, _seciliTarih, _aktifKanal);
    });
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

  void _ajandaOlustur(EsnafModeli esnaf) async {
    if (_baslangicTarihi == null || _bitisTarihi == null || _seciliAcilisSaat == null || _seciliKapanisSaat == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun")));
      return;
    }

    if (_aktifKanal == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir kanal seçin")));
      return;
    }

    // Çakışma kontrolü
    List<String> cakisanBilgiler = [];
    List<DateTime> olusturulacakTarihler = [];

    int gunSayisi = _bitisTarihi!.difference(_baslangicTarihi!).inDays;
    String kanal = _aktifKanal!.trim();
    
    for (int i = 0; i <= gunSayisi; i++) {
      DateTime gun = _baslangicTarihi!.add(Duration(days: i));
      String gunAdi = DateFormat('EEEE', 'tr_TR').format(gun);
      
      if (_calismaGunleri[gunAdi] == true) {
        String tStr = DateFormat('yyyy-MM-dd').format(gun);
        String docId = kanal.isNotEmpty ? "${tStr}_$kanal" : tStr;
        
        if ((esnaf.aktifGunler ?? []).contains(docId)) {
          cakisanBilgiler.add(DateFormat('dd/MM').format(gun));
        } else {
          olusturulacakTarihler.add(gun);
        }
      }
    }

    if (cakisanBilgiler.isNotEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Ajanda Zaten Mevcut"),
            content: Text("Şu tarihler için ajanda zaten oluşturulmuş: ${cakisanBilgiler.join(", ")}"),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam"))],
          ),
        );
      }
      return;
    }

    if (olusturulacakTarihler.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uygun gün bulunamadı")));
      return;
    }
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      await _firestoreServisi.ajandaOlustur(
        esnafId: widget.esnaf.id,
        tarihler: olusturulacakTarihler,
        kanal: kanal,
        acilis: _seciliAcilisSaat!,
        kapanis: _seciliKapanisSaat!,
        ogleBaslangic: _ogleArasiVar ? _ogleBaslangic : null,
        ogleBitis: _ogleArasiVar ? _ogleBitis : null,
        slotAraligi: _slotAraligi,
      );
      
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text("Ajanda başarıyla oluşturuldu"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  void _ajandaSilOnay() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Ajanda Sil"),
        content: Text("${DateFormat('dd/MM/yyyy').format(_seciliTarih)} tarihli ajandayı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              // Onaylı randevu kontrolü
              bool onayliVar = await _firestoreServisi.onayliRandevuVarMi(widget.esnaf.id, _seciliTarih, _aktifKanal);
              
              if (!mounted) return;

              if (onayliVar) {
                navigator.pop(); // Onay kutusunu kapat
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Hata"),
                    content: const Text("Bu tarihte onaylanmış randevu bulunduğu için ajandayı silemezsiniz. Lütfen önce randevuları iptal edin veya başka bir güne taşıyın."),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam"))],
                  ),
                );
                return;
              }

              // 1. Onay kutusunu kapat
              navigator.pop();
              
              // 2. İşlem devam ederken yükleme göstergesi aç
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await _firestoreServisi.ajandaSil(widget.esnaf.id, _seciliTarih, _aktifKanal);
                
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text("Ajanda silindi"), backgroundColor: Colors.green)
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _topluAjandaSilFormu() {
    DateTimeRange? secilenAralik;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Toplu Ajanda Sil"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Silmek istediğiniz tarih aralığını seçin. Onaylı randevusu olan günler silinmeyecektir.", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text("Tarih Aralığı Seç"),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: const Locale('tr', 'TR'),
                );
                if (range != null) {
                  secilenAralik = range;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (secilenAralik == null) {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Lütfen tarih aralığı seçin")));
                return;
              }

              navigator.pop(); // Diyaloğu kapat
              
              showDialog(
                context: context, 
                barrierDismissible: false, 
                builder: (c) => const Center(child: CircularProgressIndicator())
              );

              try {
                await _firestoreServisi.topluAjandaSil(
                  esnafId: widget.esnaf.id,
                  baslangic: secilenAralik!.start,
                  bitis: secilenAralik!.end,
                  kanal: _aktifKanal,
                );
                
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text("Seçilen aralıktaki uygun günler silindi"), backgroundColor: Colors.green)
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text("Seçilenleri Sil"),
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
      stream: _esnafStream,
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
                stream: _firestoreServisi.gunlukAjandaSnapStream(guncelEsnaf.id, _seciliTarih, _aktifKanal),
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
                        icon: const Icon(Icons.date_range, color: Colors.red),
                        onPressed: () => _topluAjandaSilFormu(),
                        tooltip: "Tarih Aralığı Sil",
                      ),
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
                  stream: _ajandaStream,
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
            const Text("Kapatma nedeni seçin", style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir neden seçin")));
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
            child: const Text("Kapat"),
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
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
            _seciliTarih = _seciliTarih.subtract(const Duration(days: 1));
            _ajandaStreamGuncelle();
          }),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_seciliTarih), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: _seciliTarih, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('tr', 'TR'));
              if (p != null) {
                _seciliTarih = p;
                _ajandaStreamGuncelle();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
            _seciliTarih = _seciliTarih.add(const Duration(days: 1));
            _ajandaStreamGuncelle();
          }),
        ],
      ),
    );
  }

  Widget _kanalSecici(EsnafModeli esnaf) {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: esnaf.kanallar!.map((k) {
          String kanalAdi = k.toString();
          String? personelAdi;

          if (esnaf.randevularPersonelAdinaAlinsin) {
            final p = esnaf.personeller?.firstWhere(
              (element) => element is Map && element['kanal'] == kanalAdi,
              orElse: () => null,
            );
            if (p != null) personelAdi = p['isim'];
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(personelAdi ?? kanalAdi, 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                  ),
                  if (personelAdi != null) 
                    Text(kanalAdi, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                ],
              ),
              selected: _aktifKanal == kanalAdi,
              onSelected: (s) {
                if (s) {
                  setState(() {
                    _aktifKanal = kanalAdi;
                    _ajandaStreamGuncelle();
                  });
                }
              },
            ),
          );
        }).toList(),
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
          const Text("Bu tarih için ajanda henüz oluşturulmamış", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ajanda Periyodu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      if (_aktifKanal != null) 
                        Builder(
                          builder: (context) {
                            String? personelAdi;
                            if (esnaf.randevularPersonelAdinaAlinsin) {
                              final p = esnaf.personeller?.firstWhere(
                                (element) => element is Map && element['kanal'] == _aktifKanal,
                                orElse: () => null,
                              );
                              if (p != null) personelAdi = p['isim'];
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(personelAdi ?? _aktifKanal!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                            );
                          }
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (d != null) setState(() => _baslangicTarihi = d);
                          },
                          child: Text(_baslangicTarihi == null ? "Başlangıç" : DateFormat('dd/MM/yyyy').format(_baslangicTarihi!)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(context: context, initialDate: _baslangicTarihi ?? DateTime.now(), firstDate: _baslangicTarihi ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                            if (d != null) setState(() => _bitisTarihi = d);
                          },
                          child: Text(_bitisTarihi == null ? "Bitiş" : DateFormat('dd/MM/yyyy').format(_bitisTarihi!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Çalışma Günleri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    children: _calismaGunleri.keys.map((gun) => FilterChip(
                      label: Text(gun, style: const TextStyle(fontSize: 12)),
                      selected: _calismaGunleri[gun]!,
                      onSelected: (v) => setState(() => _calismaGunleri[gun] = v),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text("Mesai Saatleri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Başlangıç", style: TextStyle(fontSize: 12, color: Colors.green)), 
                          subtitle: Text(_seciliAcilisSaat ?? "--:--", style: const TextStyle(fontWeight: FontWeight.bold)), 
                          onTap: () => _saatSec(true)
                        )
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Bitiş", style: TextStyle(fontSize: 12, color: Colors.red)), 
                          subtitle: Text(_seciliKapanisSaat ?? "--:--", style: const TextStyle(fontWeight: FontWeight.bold)), 
                          onTap: () => _saatSec(false)
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("Öğle Arası", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Öğle arası uygula", style: TextStyle(fontSize: 13)),
                    value: _ogleArasiVar,
                    onChanged: (v) => setState(() => _ogleArasiVar = v),
                  ),
                  if (_ogleArasiVar) Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(_ogleBaslangic.split(":")[0]), minute: int.parse(_ogleBaslangic.split(":")[1])));
                            if (t != null) setState(() => _ogleBaslangic = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                          },
                          child: Text("Başlangıç: $_ogleBaslangic"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(_ogleBitis.split(":")[0]), minute: int.parse(_ogleBitis.split(":")[1])));
                            if (t != null) setState(() => _ogleBitis = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                          },
                          child: Text("Bitiş: $_ogleBitis"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: [5, 10, 15, 20, 30, 45, 60, 90, 120].contains(_slotAraligi) ? _slotAraligi : 30,
                    decoration: const InputDecoration(labelText: "Slot Aralığı (Dakika)", border: OutlineInputBorder()),
                    items: [5, 10, 15, 20, 30, 45, 60, 90, 120].map((e) => DropdownMenuItem(value: e, child: Text("$e dakika"))).toList(),
                    onChanged: (v) => setState(() => _slotAraligi = v!),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () => _ajandaOlustur(esnaf),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text("Ajandayı Oluştur", style: TextStyle(fontWeight: FontWeight.bold)),
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

    bool periyodik = false;
    String tekrarTipi = 'Haftalık'; // 'Günlük' veya 'Haftalık'
    int tekrarSayisi = 4; // Kaç gün veya kaç hafta

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("$saat Randevu Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: adController, decoration: const InputDecoration(labelText: "Müşteri Ad Soyad")),
                TextField(controller: telController, decoration: const InputDecoration(labelText: "Telefon Numarası"), keyboardType: TextInputType.phone),
                const SizedBox(height: 15),
                CheckboxListTile(
                  title: const Text("Tekrarlayan Randevu", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Belirli aralıklarla otomatik ekle", style: TextStyle(fontSize: 11)),
                  value: periyodik,
                  onChanged: (v) => setModalState(() => periyodik = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (periyodik) ...[
                  DropdownButtonFormField<String>(
                    initialValue: tekrarTipi,
                    decoration: const InputDecoration(labelText: "Tekrar Aralığı", isDense: true),
                    items: ['Günlük', 'Haftalık'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setModalState(() => tekrarTipi = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: [2, 3, 4, 5, 6, 7, 14, 21, 28, 30].contains(tekrarSayisi) ? tekrarSayisi : 4,
                    decoration: InputDecoration(labelText: tekrarTipi == 'Günlük' ? "Kaç Gün Boyunca?" : "Kaç Hafta Boyunca?", isDense: true),
                    items: (tekrarTipi == 'Günlük' 
                      ? [2, 3, 4, 5, 6, 7, 14, 30] 
                      : [2, 3, 4, 5, 6, 8, 10, 12]
                    ).map((e) => DropdownMenuItem(value: e, child: Text("$e ${tekrarTipi == 'Günlük' ? 'Gün' : 'Hafta'}"))).toList(),
                    onChanged: (v) => setModalState(() => tekrarSayisi = v!),
                  ),
                ],
                const SizedBox(height: 15),
                const Text("Hizmet Seçin (Birden fazla seçilebilir)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

                // 1. Ana Randevu Çakışma Kontrolü
                bool cakisiyor = await _firestoreServisi.randevuCakisiyorMu(
                  esnafId: widget.esnaf.id,
                  tarih: _seciliTarih,
                  saat: saat,
                  sure: toplamSure,
                  kanal: _aktifKanal,
                );

                if (cakisiyor) {
                  messenger.showSnackBar(const SnackBar(content: Text("Bu saatte başka bir randevu ile çakışma var!"), backgroundColor: Colors.red));
                  return;
                }

                showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

                final String seriId = periyodik ? "SERI_${DateTime.now().millisecondsSinceEpoch}" : '';
                final yeniRandevu = RandevuModeli(
                  id: '',
                  esnafId: widget.esnaf.id,
                  esnafAdi: widget.esnaf.isletmeAdi,
                  esnafTel: widget.esnaf.telefon,
                  kullaniciAd: adController.text,
                  kullaniciTel: telController.text,
                  tarih: _seciliTarih,
                  saat: saat,
                  sure: toplamSure,
                  hizmetAdi: birlesikHizmet,
                  durum: 'Onaylandı',
                  randevuKanali: _aktifKanal,
                  seriId: seriId,
                );

                try {
                  await _firestoreServisi.randevuEkle(yeniRandevu);

                  int basariliSayisi = 1;
                  List<String> cakisanTarihler = [];

                  // Periyodik Tekrar Mantığı
                  if (periyodik) {
                    for (int i = 1; i < tekrarSayisi; i++) {
                      int eklenecekGun = tekrarTipi == 'Günlük' ? i : i * 7;
                      DateTime gelecekTarih = _seciliTarih.add(Duration(days: eklenecekGun));
                      
                      bool pCakisiyor = await _firestoreServisi.randevuCakisiyorMu(
                        esnafId: widget.esnaf.id,
                        tarih: gelecekTarih,
                        saat: saat,
                        sure: toplamSure,
                        kanal: _aktifKanal,
                      );

                      if (!pCakisiyor) {
                        final tekrarRandevu = yeniRandevu.copyWith(tarih: gelecekTarih);
                        await _firestoreServisi.randevuEkle(tekrarRandevu);
                        basariliSayisi++;
                      } else {
                        cakisanTarihler.add(DateFormat('dd/MM').format(gelecekTarih));
                      }
                    }
                  }

                  if (navigator.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // Loader'ı kapat
                    navigator.pop(); // Formu kapat
                    
                    String mesaj = "Randevu eklendi.";
                    if (periyodik) {
                      mesaj = "$basariliSayisi adet randevu oluşturuldu.";
                      if (cakisanTarihler.isNotEmpty) {
                        mesaj += "\nÇakışma nedeniyle atlananlar: ${cakisanTarihler.join(', ')}";
                      }
                    }
                    
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("İşlem Başarılı"),
                        content: Text(mesaj),
                        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Tamam"))],
                      ),
                    );
                  }
                } catch (e) {
                  if (navigator.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    messenger.showSnackBar(SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("Kaydet"),
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
        
        if (slotlar.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Hatalı saat ayarları. Lütfen mesai saatlerini kontrol edin.", textAlign: TextAlign.center)));

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

              // Öğle arası kontrolü
              bool ogleArasiMi = false;
              if (ajanda['ogleBaslangic'] != null && ajanda['ogleBitis'] != null) {
                int sDk = _saatiDakikayaCevir(saat);
                int oBasDk = _saatiDakikayaCevir(ajanda['ogleBaslangic']);
                int oBitDk = _saatiDakikayaCevir(ajanda['ogleBitis']);
                
                if (sDk >= oBasDk && sDk < oBitDk) {
                  // Sadece öğle arasının başlangıç saatinde göster
                  if (saat == ajanda['ogleBaslangic']) {
                    ogleArasiMi = true;
                    kapaliMi = true;
                    neden = "Öğle Arası";
                  } else {
                    // Diğer öğle arası slotlarını tamamen gizle
                    return const SizedBox.shrink();
                  }
                }
              }

              return Opacity(
                opacity: kapaliMi ? 0.6 : 1.0,
                child: Card(
                  elevation: 0,
                  color: ogleArasiMi ? Colors.blue.shade50 : (kapaliMi ? Colors.grey.shade50 : Colors.white),
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), 
                    side: BorderSide(color: ogleArasiMi ? Colors.blue.shade100 : (kapaliMi ? Colors.grey.shade200 : Colors.grey.shade200))
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    child: Row(
                      children: [
                        _saatGostergesi(
                          ogleArasiMi ? ajanda['ogleBaslangic'] : saat, 
                          ogleArasiMi ? ajanda['ogleBitis'] : bitisSaati, 
                          ogleArasiMi ? true : esnaf.slotAralikliGoster, 
                          ogleArasiMi ? Colors.blue : (kapaliMi ? Colors.grey : Colors.black87)
                        ),
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
                                    Text(ogleArasiMi ? "Öğle Arası" : (kapaliMi ? "Randevuya Kapalı" : "Boş Slot"), 
                                      style: TextStyle(
                                        color: ogleArasiMi ? Colors.blue : (kapaliMi ? Colors.grey : Colors.black54), 
                                        fontSize: 16, 
                                        fontWeight: ogleArasiMi ? FontWeight.bold : FontWeight.normal,
                                        fontStyle: (kapaliMi && !ogleArasiMi) ? FontStyle.italic : FontStyle.normal
                                      )),
                                    if (kapaliMi && neden.isNotEmpty && !ogleArasiMi)
                                      Text("Neden: $neden", style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!ogleArasiMi) IconButton(
                          icon: Icon(kapaliMi ? Icons.lock : Icons.lock_open, color: kapaliMi ? Colors.red.shade400 : Colors.green.shade400, size: 22),
                          onPressed: () => _slotKapatAcFormu(saat, kapaliMi),
                          tooltip: kapaliMi ? "Saati Aç" : "Saati Kapat",
                        ),
                        if (ogleArasiMi) const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.restaurant, color: Colors.blue, size: 22),
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
                      Column(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 28),
                          const SizedBox(height: 4),
                          const Text("ONAYLI", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10))
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
      _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, saat, false);
      return;
    }

    String? seciliNeden;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$saat Saati Kapat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kapatma nedeni seçin", style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir neden seçin")));
                return;
              }
              final navigator = Navigator.of(ctx);
              await _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, _aktifKanal, saat, true, neden: seciliNeden);
              if (navigator.mounted) navigator.pop();
            },
            child: const Text("Kapat"),
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
            if (r.seriId != null && r.seriId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                  child: const Text("Periyodik Randevu Serisi", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ),
            const Divider(height: 40),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _aksiyonButonu(ikon: Icons.phone, renk: Colors.blue, etiket: "Ara", onTap: () => launchUrl(Uri.parse("tel:${r.kullaniciTel}"))),
                _aksiyonButonu(ikon: Icons.message, renk: Colors.green, etiket: "WhatsApp", onTap: () {
                  String mesaj = "Merhaba ${r.kullaniciAd}, ${widget.esnaf.isletmeAdi} işletmesindeki ${DateFormat('dd/MM').format(r.tarih)} saat ${r.saat} randevunuz hakkında...";
                  launchUrl(Uri.parse("https://wa.me/${r.kullaniciTel}?text=${Uri.encodeComponent(mesaj)}"), mode: LaunchMode.externalApplication);
                }),
                _aksiyonButonu(ikon: Icons.cancel, renk: Colors.red, etiket: "İptal Et", onTap: () { Navigator.pop(context); _randevuIptalOnay(r); }),
                if (r.seriId != null && r.seriId!.isNotEmpty)
                  _aksiyonButonu(ikon: Icons.delete_forever, renk: Colors.black, etiket: "Seriyi Sil", onTap: () { Navigator.pop(context); _seriSilOnay(r.seriId!); }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _seriSilOnay(String seriId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Tüm Seriyi Sil"),
        content: const Text("Bu randevu serisine ait gelecekteki tüm randevular silinecektir. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogContext);
              await _firestoreServisi.randevuSerisiniSil(seriId);
              if (nav.mounted) nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Randevu serisi silindi")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text("Tümünü Sil"),
          ),
        ],
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
        content: const Text("Randevuyu iptal etmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogContext);
              await _firestoreServisi.randevuIptalEt(r.id, "Esnaf tarafından iptal edildi");
              if (nav.mounted) nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Randevu iptal edildi")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("İptal Et"),
          ),
        ],
      ),
    );
  }
}
