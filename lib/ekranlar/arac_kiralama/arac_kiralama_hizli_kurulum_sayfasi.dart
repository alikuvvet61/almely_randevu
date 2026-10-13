import 'package:flutter/material.dart';

import 'package:almely_randevu/ekranlar/hizli_kurulum_kabugu.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/yardimcilar/plaka_girdisi.dart';

/// Araç kiralama paneli kurulum köprüsü. Plaka `kiralikAraclar` kaydına yazılır.
class AracKiralamaKurulumKopru {
  AracKiralamaKurulumKopru({
    required this.esnafOku,
    required this.esnafYaz,
    required this.is724Oku,
    required this.is724Yaz,
    required this.acilisOku,
    required this.kapanisOku,
    required this.acilisYaz,
    required this.kapanisYaz,
    required this.nobetBasOku,
    required this.nobetBitOku,
    required this.nobetBasYaz,
    required this.nobetBitYaz,
    required this.gunler,
    required this.gunDegisti,
    required this.araclar,
    required this.plakaEkle,
    required this.plakaSil,
    required this.hizmetler,
    required this.sureYaz,
    required this.kaydet,
  });

  final EsnafModeli Function() esnafOku;
  final void Function(EsnafModeli) esnafYaz;
  final bool Function() is724Oku;
  final void Function(bool) is724Yaz;
  final String Function() acilisOku;
  final String Function() kapanisOku;
  final void Function(String) acilisYaz;
  final void Function(String) kapanisYaz;
  final String Function() nobetBasOku;
  final String Function() nobetBitOku;
  final void Function(String) nobetBasYaz;
  final void Function(String) nobetBitYaz;
  final Map<String, bool> gunler;
  final VoidCallback gunDegisti;
  final List<Map<String, dynamic>> araclar;
  final String? Function(String plaka) plakaEkle;
  final void Function(int) plakaSil;
  final List<Map<String, dynamic>> hizmetler;
  final void Function({required bool saatlik, required bool acik, required int dakika}) sureYaz;
  final Future<void> Function() kaydet;
}

class AracKiralamaHizliKurulumSayfasi extends StatefulWidget {
  final AracKiralamaKurulumKopru kopru;
  const AracKiralamaHizliKurulumSayfasi({super.key, required this.kopru});

  @override
  State<AracKiralamaHizliKurulumSayfasi> createState() => _AracKiralamaHizliKurulumSayfasiState();
}

class _AracKiralamaHizliKurulumSayfasiState extends State<AracKiralamaHizliKurulumSayfasi> {
  int _adim = 0;
  bool _kaydediliyor = false;
  final _plaka = TextEditingController();

  AracKiralamaKurulumKopru get k => widget.kopru;

  List<String> get _basliklar => [
        'Başlangıç',
        'Randevu alınsın mı',
        '7/24',
        if (!k.is724Oku()) 'Açılış ve kapanış',
        if (k.is724Oku()) 'Başlangıç ve bitiş',
        'Çalışma günleri',
        'Plaka',
        'Saatlik',
        'Günlük',
        'Kim onaylasın',
        'Kayıt',
      ];

  @override
  void dispose() {
    _plaka.dispose();
    super.dispose();
  }

  bool get _son => _adim >= _basliklar.length - 1;

  bool _saatTamam(String saat) => saat != 'Seçilmedi' && saat.contains(':');

  int? _sure(bool saatlik) {
    for (final h in k.hizmetler) {
      final ad = (h['isim'] ?? '').toString().toLowerCase();
      final uygun = saatlik ? ad.contains('saatlik') : (ad.contains('günlük') || ad.contains('gunluk'));
      if (uygun) return int.tryParse('${h['sure']}');
    }
    return null;
  }

  bool _saatlikGecerli(int dakika) => dakika >= 120 && dakika <= 480;

  bool _gunlukGecerli(int dakika) => dakika >= 1440 && dakika % 1440 == 0;

  String? _engel() {
    switch (_basliklar[_adim]) {
      case 'Açılış ve kapanış':
        if (!_saatTamam(k.acilisOku()) || !_saatTamam(k.kapanisOku())) {
          return 'Açılış ve kapanış saatini seçin. İleri ondan sonra açılır.';
        }
        return null;
      case 'Çalışma günleri':
        if (!k.gunler.values.any((acik) => acik)) return 'En az bir gün işaretleyin.';
        return null;
      case 'Plaka':
        if (k.araclar.isEmpty) return 'En az bir plaka ekleyin.';
        return null;
      case 'Saatlik':
        final dakika = _sure(true);
        if (dakika != null && !_saatlikGecerli(dakika)) {
          return 'Saatlik kiralama 2 ile 8 saat arasında olmalıdır.';
        }
        return null;
      case 'Günlük':
        final saatlik = _sure(true);
        final gunluk = _sure(false);
        if (saatlik == null && gunluk == null) return 'Saatlik veya günlük en az biri açık olmalıdır.';
        if (gunluk != null && !_gunlukGecerli(gunluk)) {
          return 'Günlük kiralama 24 saatin katı olmalıdır.';
        }
        return null;
      default:
        return null;
    }
  }

  String _mavi(String baslik) {
    switch (baslik) {
      case 'Başlangıç':
        return 'Hızlı Kurulum menüsüne hoş geldiniz. Yapacağınız tercihleri daha sonra değiştirebileceğinizi unutmayın.';
      case 'Randevu alınsın mı':
        return 'Evet derseniz müşteri kiralama talebi bırakabilir. Hayır derseniz randevu alımı durur. Bunu sonra değiştirebilirsiniz.';
      case '7/24':
        return 'Evet derseniz işletme her gün her saat açık olur. Açılış ve kapanış 00:00 yazılır. Hayır derseniz açılış 08:00, kapanış 20:00 olur; sonraki adımda saati değiştirirsiniz.';
      case 'Açılış ve kapanış':
        return 'Bunlar mesai başlangıç ve bitiş saatlerinizdir. Listeden seçilir. Dokunulan saat aynen yazılır.';
      case 'Başlangıç ve bitiş':
        return '7/24 açıkken açılış ve kapanış 00:00 kalır. Burada başlangıç ve bitiş aralığını seçin.';
      case 'Çalışma günleri':
        return 'İşaretli günlerde kiralama alınır. Kapalı günü boş bırakın. 7/24 açıksa günlerin hepsi açıktır.';
      case 'Plaka':
        return 'Plakayı yazıp ekleyin. Marka ve diğer bilgiler sonra filo kartından tamamlanır. En az bir plaka gerekir.';
      case 'Saatlik':
        return 'Evet derseniz saatlik kiralama 2 ile 8 saat arasında olur. Hayır derseniz saatlik satır listeden kalkar.';
      case 'Günlük':
        return 'Evet derseniz süre tam gün olur, 24 saatin katıdır. Hayır derseniz günlük satır listeden kalkar. Saatlik veya günlük en az biri açık kalmalıdır.';
      case 'Kim onaylasın':
        return 'Ben onaylayacağım derseniz yeni talep sizden onay bekler. Otomatik onaylansın derseniz kayıt hemen onaylanır.';
      case 'Kayıt':
        return 'Aşağıda yaptığınız bütün tercihler durur. Bitir bunları kaydeder.';
      default:
        return '';
    }
  }

  bool _maviSoruda(String baslik) {
    return baslik == 'Randevu alınsın mı' ||
        baslik == '7/24' ||
        baslik == 'Saatlik' ||
        baslik == 'Günlük' ||
        baslik == 'Kim onaylasın';
  }

  String _sureYazi(bool saatlik) {
    final dakika = _sure(saatlik);
    if (dakika == null) return 'kapalı';
    if (saatlik && dakika % 60 == 0) return '${dakika ~/ 60} saat';
    if (!saatlik && dakika % 1440 == 0) return '${dakika ~/ 1440} gün';
    return '$dakika dk';
  }

  String _secim(String baslik) {
    final e = k.esnafOku();
    switch (baslik) {
      case 'Randevu alınsın mı':
        return e.randevuAlinmasin
            ? 'Seçiminiz: Hayır. Müşteri kiralama talebi bırakamaz.'
            : 'Seçiminiz: Evet. Müşteri kiralama talebi bırakabilir.';
      case '7/24':
        return k.is724Oku()
            ? 'Seçiminiz: Evet. Açılış ve kapanış 00:00 olur. Günlerin hepsi açılır.'
            : 'Seçiminiz: Hayır. Açılış 08:00, kapanış 20:00 olur. Saati sonraki adımda değiştirirsiniz.';
      case 'Açılış ve kapanış':
        return 'Seçiminiz: mesai ${k.acilisOku()} ile ${k.kapanisOku()} arası.';
      case 'Başlangıç ve bitiş':
        return 'Seçiminiz: ${k.nobetBasOku()} – ${k.nobetBitOku()}.';
      case 'Çalışma günleri':
        final acik = k.gunler.entries.where((g) => g.value).map((g) => g.key).toList();
        if (acik.isEmpty) return 'Henüz gün seçilmedi. En az bir gün işaretleyin.';
        return 'Seçiminiz: ${acik.join(', ')}.';
      case 'Plaka':
        if (k.araclar.isEmpty) return 'Henüz plaka yok. Bir plaka yazıp ekleyin.';
        final plakalar = k.araclar.map((a) => (a['plaka'] ?? a['ad'] ?? '').toString()).where((p) => p.isNotEmpty).join(', ');
        return 'Seçiminiz: $plakalar.';
      case 'Saatlik':
        return 'Seçiminiz: saatlik ${_sureYazi(true)}.';
      case 'Günlük':
        return 'Seçiminiz: günlük ${_sureYazi(false)}.';
      case 'Kim onaylasın':
        return (e.randevuOnayModu == 'Otomatik')
            ? 'Seçiminiz: Otomatik onaylansın. Kayıt hemen onaylanır.'
            : 'Seçiminiz: Ben onaylayacağım. Yeni talep sizden onay bekler.';
      default:
        return '';
    }
  }

  void _esnaf(EsnafModeli e) {
    k.esnafYaz(e);
    setState(() {});
  }

  void _sureKaydet(bool saatlik, bool acik, int dakika) {
    k.sureYaz(saatlik: saatlik, acik: acik, dakika: dakika);
    setState(() {});
  }

  Future<void> _ileri() async {
    if (_engel() != null) return;
    if (_son) {
      setState(() => _kaydediliyor = true);
      final kaydet = k.kaydet;
      if (!mounted) return;
      Navigator.pop(context);
      await kaydet();
      return;
    }
    setState(() => _adim++);
  }

  @override
  Widget build(BuildContext context) {
    final baslik = _basliklar[_adim];
    return HizliKurulumKabugu(
      adim: _adim,
      toplam: _basliklar.length,
      baslik: baslik,
      baslikGoster: baslik != 'Başlangıç',
      maviUst: _maviSoruda(baslik) ? null : _mavi(baslik),
      icerik: _icerik(baslik),
      secim: _secim(baslik),
      engel: _engel(),
      kaydediliyor: _kaydediliyor,
      son: _son,
      geri: _adim == 0 ? null : () => setState(() => _adim--),
      ileri: _ileri,
    );
  }

  Widget _icerik(String baslik) {
    switch (baslik) {
      case 'Başlangıç':
      case 'Kayıt':
        return baslik == 'Kayıt' ? _ozet() : const SizedBox.shrink();
      case 'Randevu alınsın mı':
        final e = k.esnafOku();
        return hizliEvetHayir(
          'İşletmeye kiralama alınsın mı?',
          _mavi(baslik),
          !e.randevuAlinmasin,
          (v) => _esnaf(e.copyWith(randevuAlinmasin: !v)),
        );
      case '7/24':
        return hizliEvetHayir(
          'İşletme 7/24 çalışsın mı?',
          _mavi(baslik),
          k.is724Oku(),
          (v) {
            k.is724Yaz(v);
            setState(() {});
          },
        );
      case 'Açılış ve kapanış':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            hizliSaatKutu(context, 'Açılış', k.acilisOku(), (v) {
              k.acilisYaz(v);
              setState(() {});
            }),
            hizliSaatKutu(context, 'Kapanış', k.kapanisOku(), (v) {
              k.kapanisYaz(v);
              setState(() {});
            }),
          ],
        );
      case 'Başlangıç ve bitiş':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            hizliSaatKutu(context, 'Başlangıç', k.nobetBasOku(), (v) {
              k.nobetBasYaz(v);
              setState(() {});
            }),
            hizliSaatKutu(context, 'Bitiş', k.nobetBitOku(), (v) {
              k.nobetBitYaz(v);
              setState(() {});
            }),
          ],
        );
      case 'Çalışma günleri':
        return hizliGunler(k.gunler, () {
          k.gunDegisti();
          setState(() {});
        });
      case 'Plaka':
        return _plakalar();
      case 'Saatlik':
        return _sureAdimi(saatlik: true);
      case 'Günlük':
        return _sureAdimi(saatlik: false);
      case 'Kim onaylasın':
        final e = k.esnafOku();
        final onay = e.randevuOnayModu == 'Otomatik' ? 'Otomatik' : 'Manuel';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Talebi kim onaylasın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            hizliMaviKutu(_mavi(baslik)),
            hizliRadyo('Ben onaylayacağım', '', onay == 'Manuel', () => _esnaf(e.copyWith(randevuOnayModu: 'Manuel'))),
            hizliRadyo('Otomatik onaylansın', '', onay == 'Otomatik', () => _esnaf(e.copyWith(randevuOnayModu: 'Otomatik'))),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _plakalar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _plaka,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: PlakaGirdisi.bicim,
          decoration: const InputDecoration(
            labelText: 'Plaka',
            hintText: PlakaGirdisi.ornek,
            border: OutlineInputBorder(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              final hata = k.plakaEkle(_plaka.text);
              if (hata != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
                return;
              }
              _plaka.clear();
              setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Plaka Ekle'),
          ),
        ),
        for (var i = 0; i < k.araclar.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text((k.araclar[i]['plaka'] ?? k.araclar[i]['ad'] ?? '').toString()),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                k.plakaSil(i);
                setState(() {});
              },
            ),
          ),
      ],
    );
  }

  Widget _sureAdimi({required bool saatlik}) {
    final mevcut = _sure(saatlik);
    final acik = mevcut != null;
    final secenekler = saatlik
        ? [for (var saat = 2; saat <= 8; saat++) saat * 60]
        : [for (var gun = 1; gun <= 7; gun++) gun * 1440];
    if (mevcut != null && !secenekler.contains(mevcut)) secenekler.add(mevcut);
    final goster = acik ? mevcut : (saatlik ? 120 : 1440);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hizliEvetHayir(
          saatlik ? 'Saatlik kiralama olsun mu?' : 'Günlük kiralama olsun mu?',
          _mavi(saatlik ? 'Saatlik' : 'Günlük'),
          acik,
          (v) => _sureKaydet(saatlik, v, goster),
        ),
        if (acik) ...[
          const SizedBox(height: 12),
          DropdownButton<int>(
            value: secenekler.contains(goster) ? goster : secenekler.first,
            isExpanded: true,
            items: secenekler
                .map((dakika) => DropdownMenuItem(value: dakika, child: Text(_etiket(saatlik, dakika))))
                .toList(),
            onChanged: (v) {
              if (v != null) _sureKaydet(saatlik, true, v);
            },
          ),
        ],
      ],
    );
  }

  String _etiket(bool saatlik, int dakika) {
    if (saatlik && dakika % 60 == 0 && dakika >= 120 && dakika <= 480) return '${dakika ~/ 60} saat';
    if (!saatlik && dakika % 1440 == 0) return '${dakika ~/ 1440} gün';
    return '$dakika dk';
  }

  Widget _ozet() {
    final e = k.esnafOku();
    final gunler = k.gunler.entries.where((g) => g.value).map((g) => g.key).join(', ');
    final plakalar = k.araclar.map((a) => (a['plaka'] ?? a['ad'] ?? '').toString()).where((p) => p.isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hizliOzetSatiri('Kiralama: ${e.randevuAlinmasin ? 'kapalı' : 'açık'}'),
        hizliOzetSatiri('7/24: ${k.is724Oku() ? 'evet' : 'hayır'}'),
        if (k.is724Oku())
          hizliOzetSatiri('Başlangıç ve bitiş: ${k.nobetBasOku()} – ${k.nobetBitOku()}')
        else
          hizliOzetSatiri('Açılış ve kapanış: ${k.acilisOku()} – ${k.kapanisOku()}'),
        hizliOzetSatiri('Günler: ${gunler.isEmpty ? 'yok' : gunler}'),
        hizliOzetSatiri('Plakalar: ${plakalar.isEmpty ? 'yok' : plakalar}'),
        hizliOzetSatiri('Saatlik: ${_sureYazi(true)}'),
        hizliOzetSatiri('Günlük: ${_sureYazi(false)}'),
        hizliOzetSatiri('Onay: ${e.randevuOnayModu == 'Otomatik' ? 'otomatik' : 'ben onaylayacağım'}'),
      ],
    );
  }
}
