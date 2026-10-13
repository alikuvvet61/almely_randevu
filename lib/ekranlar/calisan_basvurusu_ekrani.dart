import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/taksi/taksi_guven.dart';
import '../yardimcilar/calisan_gorevleri.dart';
import '../yardimcilar/plaka_girdisi.dart';
import 'calisan_basvuru_listesi_ekrani.dart';

class CalisanBasvurusuEkrani extends StatefulWidget {
  final String telefon;
  final String adSoyad;

  const CalisanBasvurusuEkrani({super.key, required this.telefon, required this.adSoyad});

  @override
  State<CalisanBasvurusuEkrani> createState() => _CalisanBasvurusuEkraniState();
}

class _CalisanBasvurusuEkraniState extends State<CalisanBasvurusuEkrani> {
  final _firestore = FirestoreServisi();
  final _plaka = TextEditingController();
  String _kategori = '';
  String _gorev = '';
  EsnafModeli? _isletme;
  bool _gonderiliyor = false;
  Map<String, dynamic>? _mevcut;
  EsnafModeli? _kendi;
  final Map<String, dynamic> _belgeDosyasi = {};
  final _picker = ImagePicker();

  static const List<(String, String, IconData)> _belgeSatirlari = [
    ('ehliyet', 'Kimlik / Ehliyet', Icons.badge_outlined),
    ('ruhsat', 'Ruhsat Bilgileri (Tescil)', Icons.directions_car_filled_outlined),
    ('sigorta', 'Zorunlu Trafik Sigortası', Icons.description_outlined),
    ('taksimetre_belge', 'Taksimetre Kalibrasyon Belgesi', Icons.settings_input_component_outlined),
  ];

  bool get _kendiDurak =>
      _kendi != null &&
      _kendi!.kategori == 'Taksi' &&
      _firestore.musteriTelefonAnahtari(_kendi!.telefon) == _firestore.musteriTelefonAnahtari(widget.telefon);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final kayit = await _firestore.kullaniciKaydiBul(widget.telefon);
    final basvuru = await _firestore.calisanBasvurusuGetir(widget.telefon);
    final kendi = await _firestore.telefonIleEsnafGetir(widget.telefon);
    if (!mounted) return;
    setState(() {
      _mevcut = basvuru;
      _kendi = kendi;
      if (_kendiDurak) {
        _kategori = 'Taksi';
        _gorev = CalisanGorevleri.taksiSoforu;
        _isletme = _kendi;
      }
      final plaka = (kayit?['plaka'] ?? '').toString();
      if (plaka.isNotEmpty && _plaka.text.isEmpty) _plaka.text = PlakaGirdisi.yaz(plaka).trimRight();
    });
  }

  @override
  void dispose() {
    _plaka.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final isletme = _isletme;
    if (isletme == null) return;
    setState(() => _gonderiliyor = true);
    final belgeler = <String, String>{};
    if (_belgeZorunlu) {
      final tel = _firestore.musteriTelefonAnahtari(widget.telefon);
      for (final satir in _belgeSatirlari) {
        final tur = satir.$1;
        final veri = _belgeDosyasi[tur];
        if (veri == null) {
          if (mounted) {
            setState(() => _gonderiliyor = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ehliyet, ruhsat, sigorta ve taksimetre fotoğrafı gerekli.')),
            );
          }
          return;
        }
        final url = await _firestore.dosyaYukle(
          veri,
          'calisan_basvuru/$tel/${tur}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (url == null || url.isEmpty) {
          if (mounted) {
            setState(() => _gonderiliyor = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${satir.$2} yüklenemedi.')),
            );
          }
          return;
        }
        belgeler[tur] = url;
      }
    }
    final hata = await _firestore.calisanBasvurusuGonder(
      telefon: widget.telefon,
      adSoyad: widget.adSoyad,
      kategori: _kategori,
      gorev: _gorev,
      esnafId: isletme.id,
      isletmeAdi: isletme.isletmeAdi,
      plaka: _plaka.text,
      belgeler: belgeler,
    );
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (hata != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    await _yukle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_kendiDurak ? 'Aracınız filonuza eklendi.' : 'Başvuru işletmeye gitti.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durum = _mevcut?['durum']?.toString() ?? '';
    final bekliyor = durum == 'Bekliyor';
    final kabul = durum == 'Kabul';
    final iptalBekliyor = durum == 'İptal bekliyor';
    final gorevler = CalisanGorevleri.gorevler(_kategori);
    final plaka = CalisanGorevleri.plakaGerekli(_gorev);
    final belgelerTamam = !_belgeZorunlu || taksiZorunluBelgeler.every((tur) => _belgeDosyasi[tur] != null);
    final hazir = !_gonderiliyor && _gorev.isNotEmpty && _isletme != null && (!plaka || _plaka.text.trim().isNotEmpty) && belgelerTamam;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışan başvurusu'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_mevcut != null && !bekliyor && !kabul && !iptalBekliyor) ...[
            CalisanBasvuruDurumKarti(basvuru: _mevcut!),
            const Text('Yeniden başvurabilirsiniz.'),
            const SizedBox(height: 16),
          ],
          if (bekliyor)
            _durumKutusu()
          else if (kabul || iptalBekliyor)
            CalisanBasvuruDurumKarti(basvuru: _mevcut!)
          else ...[
            Text(
              _kendiDurak
                  ? 'Kendi durağınızda şoförseniz plakanızı yazın. Filoya ekle deyince araç filonuza yazılır.'
                  : 'Kategori, görev ve işletme seçin. Başvuru o işletmeye gider. Kabul edilince bu telefonla o işletmede çalışırsınız.',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            if (_kendiDurak) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Durak', border: OutlineInputBorder()),
                child: Text(_kendi!.isletmeAdi),
              ),
              const SizedBox(height: 12),
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Göreviniz', border: OutlineInputBorder()),
                child: Text(CalisanGorevleri.taksiSoforu),
              ),
            ],
            if (!_kendiDurak)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestore.kategorileriGetir(),
              builder: (context, snapshot) {
                final adlar = <String>[
                  for (final e in snapshot.data ?? [])
                    if ((e['ad'] ?? '').toString().isNotEmpty) (e['ad'] ?? '').toString(),
                ];
                return DropdownButtonFormField<String>(
                  key: ValueKey('kat-$_kategori'),
                  initialValue: _kategori.isEmpty ? null : _kategori,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                  hint: const Text('Seçiniz'),
                  items: adlar.map((ad) => DropdownMenuItem(value: ad, child: Text(ad))).toList(),
                  onChanged: (v) => setState(() {
                    _kategori = (v ?? '').trim();
                    _gorev = '';
                    _isletme = null;
                  }),
                );
              },
            ),
            if (!_kendiDurak && _kategori.isNotEmpty && gorevler.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Bu kategori için görev henüz yok.'),
              ),
            if (!_kendiDurak && gorevler.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('gorev-$_kategori-$_gorev'),
                initialValue: _gorev.isEmpty ? null : _gorev,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Göreviniz', border: OutlineInputBorder()),
                hint: const Text('Seçiniz'),
                items: gorevler.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() {
                  _gorev = (v ?? '').trim();
                  _isletme = null;
                }),
              ),
            ],
            if (!_kendiDurak && _gorev.isNotEmpty) ...[
              const SizedBox(height: 12),
              StreamBuilder<List<EsnafModeli>>(
                stream: _firestore.kategoriyeGoreGetir(_kategori),
                builder: (context, snapshot) {
                  final liste = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    key: ValueKey('isl-$_gorev-${_isletme?.id}'),
                    initialValue: _isletme?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'İşletme', border: OutlineInputBorder()),
                    hint: const Text('Seçiniz'),
                    items: liste
                        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.isletmeAdi)))
                        .toList(),
                    onChanged: (v) {
                      EsnafModeli? sec;
                      for (final e in liste) {
                        if (e.id == v) sec = e;
                      }
                      setState(() => _isletme = sec);
                    },
                  );
                },
              ),
            ],
            if (plaka) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _plaka,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: PlakaGirdisi.bicim,
                decoration: const InputDecoration(
                  labelText: 'Plaka',
                  hintText: PlakaGirdisi.ornek,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_belgeZorunlu) ...[
              const SizedBox(height: 16),
              const Text(
                'Bu dört fotoğraf olmadan başvuru gitmez.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final satir in _belgeSatirlari) _belgeKarti(satir.$1, satir.$2, satir.$3),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: hazir ? _gonder : null,
              child: Text(_gonderiliyor ? 'Gönderiliyor' : (_kendiDurak ? 'Filoya ekle' : 'Başvur')),
            ),
          ],
        ],
      ),
    );
  }

  bool get _belgeZorunlu => CalisanGorevleri.plakaGerekli(_gorev) && !_kendiDurak;

  Future<void> _fotoSec(String tur) async {
    final kaynak = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (kaynak == null) return;
    final image = await _picker.pickImage(source: kaynak, imageQuality: 50);
    if (image == null || !mounted) return;
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _belgeDosyasi[tur] = bytes);
    } else {
      setState(() => _belgeDosyasi[tur] = File(image.path));
    }
  }

  Widget _belgeKarti(String tur, String baslik, IconData ikon) {
    final hazir = _belgeDosyasi[tur] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(ikon, color: hazir ? Colors.green : Colors.indigo),
        title: Text(baslik),
        subtitle: Text(hazir ? 'Fotoğraf hazır' : 'Kamera veya galeriden ekleyin'),
        trailing: Icon(hazir ? Icons.check_circle : Icons.add_a_photo_outlined, color: hazir ? Colors.green : null),
        onTap: _gonderiliyor ? null : () => _fotoSec(tur),
      ),
    );
  }

  Widget _durumKutusu() {
    final ad = (_mevcut?['isletmeAdi'] ?? '').toString();
    final gorev = (_mevcut?['gorev'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text('$ad işletmesine $gorev başvurusu gitti. Kabul edilince bu telefonla o işletmede çalışırsınız.'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _gonderiliyor ? null : _sil,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Başvuruyu sil'),
        ),
      ],
    );
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başvuruyu sil'),
        content: const Text('Bekleyen çalışan başvurunuz iptal edilecek. İşletme bunu İptal/Ret bölümünde görür.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _gonderiliyor = true);
    final hata = await _firestore.calisanBasvurusuSil(widget.telefon);
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (hata != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    setState(() {
      _mevcut = {...?_mevcut, 'durum': 'İptal'};
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başvuru iptal edildi.')));
  }
}
