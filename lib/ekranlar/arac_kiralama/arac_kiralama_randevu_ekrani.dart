import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/widgets/ana_buton.dart';

class AracKiralamaRandevuEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const AracKiralamaRandevuEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<AracKiralamaRandevuEkrani> createState() => _AracKiralamaRandevuEkraniState();
}

class _AracKiralamaRandevuEkraniState extends State<AracKiralamaRandevuEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _adController = TextEditingController();
  final _telController = TextEditingController();

  final ValueNotifier<DateTime?> _seciliTarihNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _seciliBitisTarihiNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _seciliKanalNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _islemYapiliyorNotifier = ValueNotifier(false);

  StreamSubscription? _randevularSub;

  @override
  void initState() {
    super.initState();
    if (widget.kullaniciTel != null) _telController.text = widget.kullaniciTel!;
    
    _seciliTarihNotifier.value = DateTime.now();
    _seciliBitisTarihiNotifier.value = DateTime.now().add(const Duration(days: 1));

    _seciliTarihNotifier.addListener(_updateRandevular);
    _updateRandevular();
  }

  void _updateRandevular() {
    final t = _seciliTarihNotifier.value;
    if (t == null) return;
    _randevularSub?.cancel();
    _randevularSub = _firestoreServisi.randevulariGetir(widget.esnaf.id, t).listen((event) {
      // Randevu kontrolü eklenecekse burada işlenebilir
    });
  }

  @override
  void dispose() {
    _randevularSub?.cancel();
    _adController.dispose();
    _telController.dispose();
    super.dispose();
  }

  int _getToplamSure() {
    if (_seciliTarihNotifier.value == null || _seciliBitisTarihiNotifier.value == null) return 0;
    final start = DateTime(_seciliTarihNotifier.value!.year, _seciliTarihNotifier.value!.month, _seciliTarihNotifier.value!.day, 10, 0);
    final end = DateTime(_seciliBitisTarihiNotifier.value!.year, _seciliBitisTarihiNotifier.value!.month, _seciliBitisTarihiNotifier.value!.day, 10, 0);
    return end.difference(start).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Araç Kiralama")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _zamanSecici(),
            const SizedBox(height: 20),
            _aracSecici(),
            const SizedBox(height: 20),
            _iletisimForm(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _bottomBar(),
    );
  }

  Widget _zamanSecici() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          ListTile(
            title: const Text("Alış Tarihi"), 
            trailing: Text(DateFormat('dd.MM.yyyy').format(_seciliTarihNotifier.value!)), 
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _seciliTarihNotifier.value!, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _seciliTarihNotifier.value = d);
            }
          ),
          ListTile(
            title: const Text("İade Tarihi"), 
            trailing: Text(DateFormat('dd.MM.yyyy').format(_seciliBitisTarihiNotifier.value!)), 
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _seciliBitisTarihiNotifier.value!, firstDate: _seciliTarihNotifier.value!, lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _seciliBitisTarihiNotifier.value = d);
            }
          ),
        ]),
      ),
    );
  }

  Widget _aracSecici() {
    final kanallar = widget.esnaf.kanallar ?? [];
    return Wrap(spacing: 10, children: kanallar.map((k) {
      String ad = k is Map ? k['ad'] : k.toString();
      bool secili = _seciliKanalNotifier.value == ad;
      return ChoiceChip(label: Text(ad), selected: secili, onSelected: (v) => setState(() => _seciliKanalNotifier.value = v ? ad : null));
    }).toList());
  }

  Widget _iletisimForm() {
    return Column(children: [
      TextField(controller: _adController, decoration: const InputDecoration(labelText: "Ad Soyad")),
      TextField(controller: _telController, decoration: const InputDecoration(labelText: "Telefon")),
    ]);
  }

  Widget _bottomBar() {
    return Container(padding: const EdgeInsets.all(20), child: AnaButon(metin: "KİRALAMAYI TAMAMLA", onPressed: _seciliKanalNotifier.value != null ? _kaydet : null));
  }

  Future<void> _kaydet() async {
    _islemYapiliyorNotifier.value = true;
    final r = RandevuModeli(
      id: '', esnafId: widget.esnaf.id, esnafAdi: widget.esnaf.isletmeAdi, esnafTel: widget.esnaf.telefon,
      kullaniciAd: _adController.text, kullaniciTel: _telController.text,
      tarih: _seciliTarihNotifier.value!, saat: "10:00", sure: _getToplamSure(),
      hizmetAdi: "Araç Kiralama", randevuKanali: _seciliKanalNotifier.value,
      durum: 'Onay bekliyor',
    );
    await _firestoreServisi.randevuEkle(r);
    _islemYapiliyorNotifier.value = false;
    if (mounted) Navigator.pop(context);
  }
}
