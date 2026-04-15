import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../widgets/ana_buton.dart';

class RandevuEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;
  const RandevuEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<RandevuEkrani> createState() => _RandevuEkraniState();
}

class _RandevuEkraniState extends State<RandevuEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _adController = TextEditingController();
  final _telController = TextEditingController();

  final List<Map<String, dynamic>> _seciliHizmetler = [];
  String? _seciliKanal;
  DateTime _seciliTarih = DateTime.now();
  String? _seciliSaat;
  bool _saatKendimSececegim = false;

  @override
  void initState() {
    super.initState();
    if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      _seciliKanal = widget.esnaf.kanallar!.first.toString();
    }
    
    List<DateTime> aktifler = _getAktifTarihler();
    if (aktifler.isNotEmpty) {
      _seciliTarih = aktifler.first;
    }

    if (widget.kullaniciTel != null) {
      _telController.text = widget.kullaniciTel!;
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _telController.dispose();
    super.dispose();
  }

  int get _toplamSure {
    int toplam = 0;
    for (var h in _seciliHizmetler) {
      toplam += int.tryParse(h['sure'].toString()) ?? 0;
    }
    return toplam;
  }

  String get _birlesikHizmetAdi {
    return _seciliHizmetler.map((h) => h['isim']).join(' + ');
  }

  List<DateTime> _getAktifTarihler() {
    final aktifler = widget.esnaf.aktifGunler ?? [];
    List<DateTime> tarihler = [];
    final bugun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    for (var item in aktifler) {
      final parcalar = item.toString().split('_');
      if (parcalar.isNotEmpty) {
        // Kanal filtresini daha sağlam hale getirdik
        if (_seciliKanal != null) {
          if (parcalar.length <= 1 || parcalar[1] != _seciliKanal) continue;
        } else {
          if (parcalar.length > 1) continue;
        }
        
        try {
          DateTime t = DateFormat('yyyy-MM-dd').parse(parcalar[0]);
          if (t.isAtSameMomentAs(bugun) || t.isAfter(bugun)) {
            if (!tarihler.any((d) => d.isAtSameMomentAs(t))) {
              tarihler.add(t);
            }
          }
        } catch (e) { debugPrint("Tarih parse hatası: $e"); }
      }
    }
    tarihler.sort();
    return tarihler;
  }

  bool _isGunAktif(DateTime tarih) {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    // Firestore'daki kanal bazlı anahtar formatına uyduruldu
    String anahtar = _seciliKanal != null ? "${tarihStr}_$_seciliKanal" : tarihStr;
    return (widget.esnaf.aktifGunler ?? []).contains(anahtar);
  }

  int _saatiDakikayaCevir(String saat) {
    final parcalar = saat.split(':');
    return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
  }

  List<String> _slotlariUret() {
    List<String> slotlar = [];
    final calisma = widget.esnaf.calismaSaatleri;
    if (calisma == null) return [];

    String acilis = calisma['acilis'] ?? "09:00";
    String kapanis = calisma['kapanis'] ?? "18:00";
    // slotDakika veya slotAraligi her ikisine de bakıyoruz
    int slotAraligi = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;

    try {
      DateTime current = DateFormat("HH:mm").parse(acilis);
      DateTime end = DateFormat("HH:mm").parse(kapanis == "24:00" ? "23:59" : kapanis);

      while (current.isBefore(end)) {
        slotlar.add(DateFormat("HH:mm").format(current));
        current = current.add(Duration(minutes: slotAraligi));
      }
    } catch (e) { debugPrint("Slot üretme hatası: $e"); }
    return slotlar;
  }

  bool _saatMusaitMi(String slot, List<RandevuModeli> randevular, int hizmetSuresi) {
    int sBaslangic = _saatiDakikayaCevir(slot);
    int sBitis = sBaslangic + hizmetSuresi;

    if (_seciliTarih.day == DateTime.now().day &&
        _seciliTarih.month == DateTime.now().month &&
        _seciliTarih.year == DateTime.now().year) {
      int simdiDakika = DateTime.now().hour * 60 + DateTime.now().minute;
      if (sBaslangic <= simdiDakika) return false;
    }

    for (var r in randevular) {
      if (_seciliKanal != null && r.randevu_kanali != _seciliKanal) continue;
      int rBaslangic = _saatiDakikayaCevir(r.saat);
      int rBitis = rBaslangic + r.sure;
      if (sBaslangic < rBitis && rBaslangic < sBitis) return false;
    }
    return true;
  }

  Future<void> _randevuKaydet() async {
    if (_adController.text.isEmpty || _telController.text.isEmpty || _seciliHizmetler.isEmpty || _seciliSaat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun.")));
      return;
    }

    final yeniRandevu = RandevuModeli(
      id: '',
      esnafId: widget.esnaf.id,
      esnafAdi: widget.esnaf.isletmeAdi,
      kullaniciAd: _adController.text,
      kullaniciTel: _telController.text,
      tarih: _seciliTarih,
      saat: _seciliSaat!,
      sure: _toplamSure,
      hizmetAdi: _birlesikHizmetAdi,
      randevu_kanali: _seciliKanal,
      durum: 'Onay bekliyor',
    );

    try {
      await _firestoreServisi.randevuEkle(yeniRandevu);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: const Text("Randevunuz başarıyla oluşturuldu. Esnaf onayından sonra tarafınıza bilgi verilecektir.", textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            }, child: const Text("TAMAM"))
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  Future<void> _takvimAc() async {
    final DateTime? secilen = await showDatePicker(
      context: context,
      initialDate: _seciliTarih,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
    );
    if (secilen != null) {
      setState(() {
        _seciliTarih = secilen;
        _seciliSaat = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Randevu Al")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hizmet Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: (widget.esnaf.hizmetler ?? []).map((h) {
                bool secili = _seciliHizmetler.contains(h);
                return FilterChip(
                  label: Text("${h['isim']} (${h['sure']} dk)"),
                  selected: secili,
                  onSelected: (val) => setState(() {
                    if (val) {
                      _seciliHizmetler.add(h);
                    } else {
                      _seciliHizmetler.remove(h);
                    }
                    _seciliSaat = null;
                  }),
                );
              }).toList(),
            ),
            
            if (_seciliHizmetler.isNotEmpty) ...[
              const SizedBox(height: 15),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Randevu saatini kendim seçmek istiyorum", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                value: _saatKendimSececegim,
                onChanged: (val) => setState(() { _saatKendimSececegim = val ?? false; _seciliSaat = null; }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],

            const Divider(height: 40),
            
            if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.length > 1) ...[
              const Text("Kanal / Salon Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _seciliKanal,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: widget.esnaf.kanallar!.map((k) => DropdownMenuItem(value: k.toString(), child: Text(k.toString()))).toList(),
                onChanged: (val) => setState(() { 
                  _seciliKanal = val; 
                  _seciliSaat = null;
                  // Kanal değişince tarih listesini de güncellememiz gerekebilir
                }),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tarih Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _takvimAc,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text("Tüm Tarihler", style: TextStyle(fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 10),
            _tarihSecici(),
            
            const Divider(height: 40),
            
            if (_seciliHizmetler.isNotEmpty) ...[
              const Text("Randevu Saati", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              if (!_isGunAktif(_seciliTarih))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("Bu tarih için ajanda henüz açılmamış.", style: TextStyle(color: Colors.red))),
                )
              else
                _saatSecimiBolumu(),
            ],

            const SizedBox(height: 30),
            const Text("İletişim Bilgileriniz", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(controller: _adController, decoration: const InputDecoration(labelText: "Ad Soyad", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _telController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon Numarası", border: OutlineInputBorder())),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)]),
        child: AnaButon(
          metin: "RANDEVUYU TAMAMLA",
          onPressed: (_seciliSaat != null && _seciliHizmetler.isNotEmpty) ? () => _randevuKaydet() : null,
        ),
      ),
    );
  }

  Widget _tarihSecici() {
    List<DateTime> aktifTarihler = _getAktifTarihler();
    if (aktifTarihler.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("Bu kanal için müsait tarih bulunamadı.", textAlign: TextAlign.center, style: TextStyle(color: Colors.orange, fontSize: 12)),
      ));
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: aktifTarihler.length,
        itemBuilder: (context, index) {
          DateTime gun = aktifTarihler[index];
          bool secili = gun.day == _seciliTarih.day && gun.month == _seciliTarih.month && gun.year == _seciliTarih.year;

          return InkWell(
            onTap: () => setState(() { _seciliTarih = gun; _seciliSaat = null; }),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: secili ? Colors.blue : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: secili ? Colors.blue : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EE', 'tr_TR').format(gun), style: TextStyle(color: secili ? Colors.white : Colors.blueGrey, fontSize: 12)),
                  Text(gun.day.toString(), style: TextStyle(color: secili ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _saatSecimiBolumu() {
    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.randevulariGetir(widget.esnaf.id, _seciliTarih),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final randevular = snapshot.data ?? [];
        final slotlar = _slotlariUret();

        String? ilkMusait;
        for (var s in slotlar) {
          if (_saatMusaitMi(s, randevular, _toplamSure)) {
            ilkMusait = s;
            break;
          }
        }

        if (!_saatKendimSececegim) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_seciliSaat != ilkMusait) setState(() => _seciliSaat = ilkMusait);
          });
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text("Hizmetlerinize göre en uygun saat: ${ilkMusait ?? 'Müsait saat kalmadı'} olarak belirlendi.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 10, runSpacing: 10,
          children: slotlar.map((s) {
            bool musait = _saatMusaitMi(s, randevular, _toplamSure);
            bool secili = _seciliSaat == s;
            return InkWell(
              onTap: musait ? () => setState(() => _seciliSaat = s) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: secili ? Colors.amber : (musait ? Colors.white : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: secili ? Colors.amber : (musait ? Colors.blue : Colors.grey.shade300)),
                ),
                child: Text(s, style: TextStyle(color: secili ? Colors.white : (musait ? Colors.blue : Colors.grey), fontWeight: FontWeight.bold, decoration: musait ? null : TextDecoration.lineThrough)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
