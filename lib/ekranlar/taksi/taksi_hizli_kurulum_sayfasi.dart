import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:almely_randevu/ekranlar/hizli_kurulum_kabugu.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/taksi/taksi_iptal_bedeli.dart';

/// Taksi paneli kurulum köprüsü. Filo `araclar` listesine yazılır.
class TaksiKurulumKopru {
  TaksiKurulumKopru({
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
    required this.aracEkle,
    required this.aracNobetYaz,
    required this.aracSil,
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
  final String? Function({required String plaka, required String ad, required String tel, int? nobet}) aracEkle;
  final String? Function(int index, int nobet) aracNobetYaz;
  final void Function(int) aracSil;
  final Future<void> Function() kaydet;
}

class TaksiHizliKurulumSayfasi extends StatefulWidget {
  final TaksiKurulumKopru kopru;
  const TaksiHizliKurulumSayfasi({super.key, required this.kopru});

  @override
  State<TaksiHizliKurulumSayfasi> createState() => _TaksiHizliKurulumSayfasiState();
}

class _TaksiHizliKurulumSayfasiState extends State<TaksiHizliKurulumSayfasi> {
  int _adim = 0;
  bool _kaydediliyor = false;
  String? _seciliTel;
  int? _seciliNobet;
  late final TextEditingController _iptalTaban;
  late final TextEditingController _iptalKm;
  late final TextEditingController _iptalDakika;

  TaksiKurulumKopru get k => widget.kopru;

  @override
  void initState() {
    super.initState();
    final e = widget.kopru.esnafOku();
    _iptalTaban = TextEditingController(text: taksiTlAlan(e.taksiIptalTabanUcret));
    _iptalKm = TextEditingController(text: taksiTlAlan(e.taksiIptalKmUcret));
    _iptalDakika = TextEditingController(text: taksiTlAlan(e.taksiIptalDakikaUcret));
  }

  @override
  void dispose() {
    _iptalTaban.dispose();
    _iptalKm.dispose();
    _iptalDakika.dispose();
    super.dispose();
  }

  List<String> get _basliklar => [
        'Başlangıç',
        'Randevu alınsın mı',
        if (!k.esnafOku().randevuAlinmasin) 'Araç odaklı',
        '7/24',
        'Açılış ve kapanış',
        if (k.is724Oku()) 'Nöbet saatleri',
        'Çalışma günleri',
        'Şoför',
        'Anlık çağrı',
        'Yeni rezervasyon',
        'Onay ve red',
        'Hatırlatma',
        'İstirahatli araçlar',
        'Konum mesafesi',
        'Kim onaylasın',
        'Navigasyon',
        'İptal bedeli',
        'Kayıt',
      ];

  bool get _son => _adim >= _basliklar.length - 1;

  bool _saatTamam(String saat) => saat != 'Seçilmedi' && saat.contains(':');

  String? _engel() {
    switch (_basliklar[_adim]) {
      case 'Açılış ve kapanış':
        if (!_saatTamam(k.acilisOku()) || !_saatTamam(k.kapanisOku())) {
          return 'Açılış ve kapanış saatini seçin. İleri ondan sonra açılır.';
        }
        return null;
      case 'Çalışma günleri':
        if (!k.gunler.values.any((acik) => acik)) return 'En az bir gün işaretleyin. İleri ondan sonra açılır.';
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
        return 'Evet derseniz müşteri randevu alabilir. Hayır derseniz randevu alımı durur ve müşteri Hemen Randevu Al düğmesini görmez. Bunu sonra değiştirebilirsiniz.';
      case 'Araç odaklı':
        return 'Plaka derseniz yolcu plaka seçer ve randevu o araca yazılır. Durak derseniz plaka seçilmez, randevu durak adına alınır; aracı durak ayırır.';
      case '7/24':
        return 'Evet derseniz durak her gün her saat açık kalır. Gündüz mesai saati ayrıca durur. Hayır derseniz yalnızca açılış ve kapanış geçerlidir.';
      case 'Açılış ve kapanış':
        return 'Bunlar gündüz mesaisinde çalışacak araçların saatidir. Listeden seçilir. Dokunulan saat aynen yazılır.';
      case 'Nöbet saatleri':
        return '7/24 açıkken nöbet aralığı burada seçilir. Listeden seçilir. Dokunulan saat aynen yazılır.';
      case 'Çalışma günleri':
        return 'İşaretli günlerde durak çalışır. Kapalı günü boş bırakın.';
      case 'Şoför':
        return 'Listede yalnızca bu durağa başvurup kabul edilen şoförler durur. Başka durağın şoförü gelmez. Aynı kişi bir kez yazar. Şoför yoksa İleri ile devam edilir. Şoför seçilmeden Şoför Ekle kapalı kalır. Şoförü sonra da ekleyebilirsiniz.';
      case 'Anlık çağrı':
        return 'Evet derseniz yolcu “Taksi İstiyorum” deyince durak telefonuna ve varsa sıradaki şoföre “Yeni taksi çağrısı” bildirimi gider. Uygulama kapalı olsa da bu bildirim gelir. Kabul ve red penceresi, taksi paneli açılınca bekleyen talep için çıkar. Reddederseniz yolcuya “şu an araç çıkarılamadı” gider. Hayır derseniz bu bildirim gitmez.';
      case 'Yeni rezervasyon':
        return 'Evet derseniz ileri saatli rezervasyon düşünce durak telefonuna haber gider. Hayır derseniz bu haber gitmez.';
      case 'Onay ve red':
        return 'Evet derseniz rezervasyonu onaylayınca, reddedince veya iptal edince yolcuya bildirim gider. Hayır derseniz bu bildirimler gitmez.';
      case 'Hatırlatma':
        return 'Yalnızca onaylanmış taksi rezervasyonunda, alış saatinden seçilen dakika önce yolcuya “Taksi rezervasyonunuz yaklaşıyor” bildirimi gider. Kapalı derseniz hatırlatma kurulmaz.';
      case 'İstirahatli araçlar':
        return 'Evet derseniz istirahatteki araçları müşteriler “Bugün Çalışan Araçlarımız” listesinde göremez. Hayır derseniz müşteriler o listede de görür.';
      case 'Konum mesafesi':
        return 'Şoför bu mesafeden uzaktaysa sıraya giremez. Aralık 5 ile 500 metre arasındadır.';
      case 'Kim onaylasın':
        return 'Ben onaylayacağım derseniz yeni randevu sizden onay bekler. Otomatik onaylansın derseniz kayıt hemen onaylanır.';
      case 'Navigasyon':
        return 'Yolcu taksi istedikten sonra, çağrıyı kabul eden şoföre sorulup sorulmayacağını seçer. Hayır derseniz o şoföre “Navigasyon başlasın mı?” diye sorulur. Evet derseniz sorulmaz, Google Haritalar alış noktasına kendiliğinden açılır.';
      case 'İptal bedeli':
        return 'Bu adım, yolcu vazgeçince şoföre ödeyeceği tutarı belirler. Kırmızı not kuralı yazar. Yeşil açıklama yazdığınız tutara göre değişir.';
      case 'Kayıt':
        return 'Aşağıda yaptığınız bütün tercihler durur. Bitir bunları kaydeder.';
      default:
        return '';
    }
  }

  bool _maviSoruda(String baslik) {
    return baslik == 'Randevu alınsın mı' ||
        baslik == 'Araç odaklı' ||
        baslik == '7/24' ||
        baslik == 'Anlık çağrı' ||
        baslik == 'Yeni rezervasyon' ||
        baslik == 'Onay ve red' ||
        baslik == 'Hatırlatma' ||
        baslik == 'İstirahatli araçlar' ||
        baslik == 'Konum mesafesi' ||
        baslik == 'Kim onaylasın' ||
        baslik == 'Navigasyon' ||
        baslik == 'İptal bedeli';
  }

  String _secim(String baslik) {
    final e = k.esnafOku();
    switch (baslik) {
      case 'Randevu alınsın mı':
        return e.randevuAlinmasin
            ? 'Seçiminiz: Hayır. Müşteri bu duraktan randevu alamaz.'
            : 'Seçiminiz: Evet. Müşteri bu duraktan randevu alabilir.';
      case 'Araç odaklı':
        return e.aracOdakliSistem
            ? 'Seçiminiz: Plaka. Yolcu plaka seçer. Randevu o araca yazılır.'
            : 'Seçiminiz: Durak. Plaka seçilmez. Randevu durak adına alınır; aracı durak ayırır.';
      case '7/24':
        return k.is724Oku()
            ? 'Seçiminiz: Evet. Durak her saat açık. Nöbet saatini bir sonraki adımda seçersiniz.'
            : 'Seçiminiz: Hayır. Yalnızca açılış ve kapanış geçerlidir.';
      case 'Açılış ve kapanış':
        return 'Seçiminiz: gündüz mesaisinde çalışacak araçlar ${k.acilisOku()} ile ${k.kapanisOku()} arasında çalışır.';
      case 'Nöbet saatleri':
        return 'Seçiminiz: nöbet ${k.nobetBasOku()}–${k.nobetBitOku()}.';
      case 'Çalışma günleri':
        final acik = k.gunler.entries.where((g) => g.value).map((g) => g.key).toList();
        if (acik.isEmpty) return 'Henüz gün seçilmedi. En az bir gün işaretleyin.';
        return 'Seçiminiz: ${acik.join(', ')}.';
      case 'Şoför':
        if (k.araclar.isEmpty) return 'Henüz şoför yok. Şoför olmadan da devam edebilirsiniz.';
        final satir = k.araclar.map((a) {
          final plaka = (a['plaka'] ?? '').toString();
          final ad = (a['soforAd'] ?? '').toString();
          final sira = a['nobetSirasi'];
          final siraYazi = sira == null ? '' : ' · № $sira';
          return '$plaka ($ad$siraYazi)';
        }).join(', ');
        return 'Seçiminiz: $satir.';
      case 'Anlık çağrı':
        return e.taksiCagriBildirim
            ? 'Seçiminiz: Evet. Uygulama kapalı olsa da durak telefonuna ve varsa sıradaki şoföre bildirim gider. Kabul ve red, taksi paneli açılınca yapılır.'
            : 'Seçiminiz: Hayır. Anlık çağrı bildirimi gitmez.';
      case 'Yeni rezervasyon':
        return e.taksiRezervasyonEsnafBildirim
            ? 'Seçiminiz: Evet. Yeni rezervasyon durak telefonuna gider.'
            : 'Seçiminiz: Hayır. Yeni rezervasyon durağa bildirilmez.';
      case 'Onay ve red':
        return e.taksiRezervasyonMusteriBildirim
            ? 'Seçiminiz: Evet. Onay, red ve iptal yolcuya gider.'
            : 'Seçiminiz: Hayır. Onay, red ve iptal yolcuya gitmez.';
      case 'Hatırlatma':
        return e.taksiRezervasyonHatirlatmaDk <= 0
            ? 'Seçiminiz: Kapalı. Hatırlatma kurulmaz.'
            : 'Seçiminiz: ${e.taksiRezervasyonHatirlatmaDk} dakika önce. Onaylanmış taksi rezervasyonunda yolcuya “Taksi rezervasyonunuz yaklaşıyor” bildirimi gider.';
      case 'İstirahatli araçlar':
        return e.istirahatliAraclariGizle
            ? 'Seçiminiz: Evet. İstirahatteki araçları müşteriler Bugün Çalışan Araçlarımız listesinde göremez.'
            : 'Seçiminiz: Hayır. İstirahatteki araçları müşteriler de görür.';
      case 'Konum mesafesi':
        return 'Seçiminiz: ${_mesafe(e).round()} m. Şoför sıraya girmek için durağa bu kadar yakın olmalıdır.';
      case 'Kim onaylasın':
        return (e.randevuOnayModu == 'Otomatik')
            ? 'Seçiminiz: Otomatik onaylansın. Kayıt hemen onaylanır.'
            : 'Seçiminiz: Ben onaylayacağım. Yeni randevu sizden onay bekler.';
      case 'Navigasyon':
        return e.taksiNavigasyonOtomatik
            ? 'Seçiminiz: Evet. Yolcu taksi istedikten sonra, kabul eden şoföre sorulmaz. Google Haritalar alış noktasına kendiliğinden açılır.'
            : 'Seçiminiz: Hayır. Yolcu taksi istedikten sonra, çağrıyı kabul eden şoföre “Navigasyon başlasın mı?” diye sorulur.';
      case 'İptal bedeli':
        return taksiIptalTarifeMetni(e.taksiIptalTabanUcret, e.taksiIptalKmUcret, e.taksiIptalDakikaUcret);
      default:
        return '';
    }
  }

  void _esnaf(EsnafModeli e) {
    k.esnafYaz(e);
    setState(() {
      if (_adim >= _basliklar.length) _adim = _basliklar.length - 1;
    });
  }

  int _hatirlatmaDk(EsnafModeli e) {
    final dk = e.taksiRezervasyonHatirlatmaDk;
    return dk < 0 ? 0 : dk;
  }

  double _mesafe(EsnafModeli e) {
    final ham = e.konumDogrulamaMesafesi.clamp(5, 500).toDouble();
    return (ham / 5).round() * 5.0;
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
        final randevu = k.esnafOku();
        return hizliEvetHayir(
          'Durağa randevu alınsın mı?',
          _mavi(baslik),
          !randevu.randevuAlinmasin,
          (v) => _esnaf(randevu.copyWith(randevuAlinmasin: !v)),
        );
      case 'Araç odaklı':
        final arac = k.esnafOku();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alınan randevular nereye alınsın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            hizliMaviKutu(_mavi(baslik)),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Plaka'),
                  selected: arac.aracOdakliSistem,
                  onSelected: (_) => _esnaf(arac.copyWith(aracOdakliSistem: true)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Durak'),
                  selected: !arac.aracOdakliSistem,
                  onSelected: (_) => _esnaf(arac.copyWith(aracOdakliSistem: false)),
                ),
              ],
            ),
          ],
        );
      case '7/24':
        return hizliEvetHayir(
          'Durak 7/24 çalışsın mı?',
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
      case 'Nöbet saatleri':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            hizliSaatKutu(context, 'Nöbet başlangıç', k.nobetBasOku(), (v) {
              k.nobetBasYaz(v);
              setState(() {});
            }),
            hizliSaatKutu(context, 'Nöbet bitiş', k.nobetBitOku(), (v) {
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
      case 'Şoför':
        return _sofor();
      case 'Anlık çağrı':
        final cagri = k.esnafOku();
        return hizliEvetHayir(
          'Anlık çağrı bildirimi gitsin mi?',
          _mavi(baslik),
          cagri.taksiCagriBildirim,
          (v) => _esnaf(cagri.copyWith(taksiCagriBildirim: v)),
        );
      case 'Yeni rezervasyon':
        final rezervasyon = k.esnafOku();
        return hizliEvetHayir(
          'Yeni rezervasyon durağa bildirilsin mi?',
          _mavi(baslik),
          rezervasyon.taksiRezervasyonEsnafBildirim,
          (v) => _esnaf(rezervasyon.copyWith(taksiRezervasyonEsnafBildirim: v)),
        );
      case 'Onay ve red':
        final yolcu = k.esnafOku();
        return hizliEvetHayir(
          'Onay ve red yolcuya bildirilsin mi?',
          _mavi(baslik),
          yolcu.taksiRezervasyonMusteriBildirim,
          (v) => _esnaf(yolcu.copyWith(taksiRezervasyonMusteriBildirim: v)),
        );
      case 'Hatırlatma':
        return _hatirlatma();
      case 'İstirahatli araçlar':
        final gizle = k.esnafOku();
        return hizliEvetHayir(
          'İstirahatteki araçlar gizlensin mi?',
          _mavi(baslik),
          gizle.istirahatliAraclariGizle,
          (v) => _esnaf(gizle.copyWith(istirahatliAraclariGizle: v)),
        );
      case 'Konum mesafesi':
        return _konum();
      case 'Kim onaylasın':
        final e = k.esnafOku();
        final onay = e.randevuOnayModu == 'Otomatik' ? 'Otomatik' : 'Manuel';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Randevuyu kim onaylasın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            hizliMaviKutu(_mavi(baslik)),
            hizliRadyo('Ben onaylayacağım', '', onay == 'Manuel', () => _esnaf(e.copyWith(randevuOnayModu: 'Manuel'))),
            hizliRadyo('Otomatik onaylansın', '', onay == 'Otomatik', () => _esnaf(e.copyWith(randevuOnayModu: 'Otomatik'))),
          ],
        );
      case 'Navigasyon':
        final navi = k.esnafOku();
        return hizliEvetHayir(
          'Kabul edilince navigasyon kendiliğinden açılsın mı?',
          _mavi(baslik),
          navi.taksiNavigasyonOtomatik,
          (v) => _esnaf(navi.copyWith(taksiNavigasyonOtomatik: v)),
        );
      case 'İptal bedeli':
        return _iptalBedeli();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sofor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreServisi().calisanBasvurulariTumunuDinle(k.esnafOku().id),
          builder: (context, snapshot) {
            final fs = FirestoreServisi();
            final kayitlilar = fs.durakKabulSoforleri(snapshot.data ?? []);
            final kullanicilar = kayitlilar.where((u) => !_soforEkli(u)).toList();
            if (kullanicilar.isEmpty) {
              final mesaj = kayitlilar.isEmpty
                  ? 'Bu durağa kabul edilmiş şoför yok. Şoför, İşletmede çalışıyorum ile bu durağa başvurur. Kabul edince burada bir kez görünür.'
                  : 'Bu durağın kabul edilmiş şoförleri eklendi.';
              return Text(mesaj);
            }
            final secili = kullanicilar.any((u) => u['anahtar']?.toString() == _seciliTel) ? _seciliTel : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(secili),
                  initialValue: secili,
                  decoration: const InputDecoration(labelText: 'Bu durağın şoförlerinden seç'),
                  hint: const Text('Şoför seçiniz'),
                  items: kullanicilar
                      .map((u) => DropdownMenuItem(
                            value: u['anahtar'].toString(),
                            child: Text('${u['adSoyad']} (${u['plaka']})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _seciliTel = v),
                ),
                const SizedBox(height: 12),
                _nobetSecici(
                  secili: _seciliNobet,
                  haric: null,
                  genis: true,
                  onSec: (v) => setState(() => _seciliNobet = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _seciliTel == null ? null : () => _soforEkle(),
                    icon: const Icon(Icons.add),
                    label: const Text('Şoför Ekle'),
                  ),
                ),
              ],
            );
          },
        ),
        for (var i = 0; i < k.araclar.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text((k.araclar[i]['plaka'] ?? '').toString()),
            subtitle: Text(_aracAlt(k.araclar[i])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _nobetSecici(
                  secili: _nobetSayi(k.araclar[i]['nobetSirasi']),
                  haric: i,
                  onSec: (v) {
                    final hata = k.aracNobetYaz(i, v);
                    if (hata != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
                      return;
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    k.aracSil(i);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _nobetSecici({required int? secili, required int? haric, required ValueChanged<int> onSec, bool genis = false}) {
    final dolu = <int>{};
    for (var i = 0; i < k.araclar.length; i++) {
      if (i == haric) continue;
      final n = _nobetSayi(k.araclar[i]['nobetSirasi']);
      if (n != null) dolu.add(n);
    }
    final secenekler = <int>[
      for (var n = 1; n <= 30; n++)
        if (!dolu.contains(n) || n == secili) n,
    ];
    if (secili != null && !secenekler.contains(secili)) {
      secenekler.add(secili);
      secenekler.sort();
    }
    return DropdownButton<int>(
      isExpanded: genis,
      value: secili != null && secenekler.contains(secili) ? secili : null,
      hint: const Text('Nöbet sırası'),
      items: secenekler.map((n) => DropdownMenuItem(value: n, child: Text('№ $n'))).toList(),
      onChanged: (v) {
        if (v != null) onSec(v);
      },
    );
  }

  int? _nobetSayi(dynamic ham) {
    if (ham is int) return ham;
    if (ham is num) return ham.toInt();
    return int.tryParse('$ham');
  }

  bool _soforEkli(Map<String, dynamic> kullanici) {
    final fs = FirestoreServisi();
    final tel = fs.musteriTelefonAnahtari((kullanici['anahtar'] ?? kullanici['tel'] ?? '').toString());
    final plaka = _plakaAnahtar((kullanici['plaka'] ?? '').toString());
    return k.araclar.any((a) {
      final aracTel = fs.musteriTelefonAnahtari((a['soforTel'] ?? '').toString());
      final aracPlaka = _plakaAnahtar((a['plaka'] ?? '').toString());
      if (plaka.isNotEmpty && aracPlaka == plaka) return true;
      if (tel.isNotEmpty && aracTel == tel) return true;
      return false;
    });
  }

  String _plakaAnahtar(String ham) => ham.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _aracAlt(Map<String, dynamic> arac) => (arac['soforAd'] ?? '').toString();

  Future<void> _soforEkle() async {
    if (_seciliTel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şoför seçin.')));
      return;
    }
    if (_seciliNobet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nöbet sırası seçin.')));
      return;
    }
    final basvurular = await FirestoreServisi().calisanBasvurulariTumunuDinle(k.esnafOku().id).first;
    final kullanicilar = FirestoreServisi().durakKabulSoforleri(basvurular);
    final secili = kullanicilar.where((u) => u['anahtar']?.toString() == _seciliTel);
    if (secili.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şoför seçin.')));
      return;
    }
    final u = secili.first;
    final hata = k.aracEkle(
      plaka: (u['plaka'] ?? '').toString(),
      ad: (u['adSoyad'] ?? u['ad'] ?? '').toString(),
      tel: (u['tel'] ?? '').toString(),
      nobet: _seciliNobet,
    );
    if (!mounted) return;
    if (hata != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    setState(() {
      _seciliTel = null;
      _seciliNobet = null;
    });
  }

  Widget _hatirlatma() {
    final e = k.esnafOku();
    final mevcut = _hatirlatmaDk(e);
    final secenekler = [0, 15, 30, 60];
    if (!secenekler.contains(mevcut)) secenekler.add(mevcut);
    secenekler.sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alış saatinden kaç dakika önce hatırlatılsın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        hizliMaviKutu(_mavi('Hatırlatma')),
        DropdownButton<int>(
          value: mevcut,
          isExpanded: true,
          items: secenekler
              .map((dk) => DropdownMenuItem(
                    value: dk,
                    child: Text(dk == 0 ? 'Kapalı' : '$dk dakika önce'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            _esnaf(e.copyWith(taksiRezervasyonHatirlatmaDk: v));
          },
        ),
      ],
    );
  }

  Widget _konum() {
    final e = k.esnafOku();
    final deger = _mesafe(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Şoför sıraya girmek için durağa en fazla kaç metre uzakta olsun?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        hizliMaviKutu(_mavi('Konum mesafesi')),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: deger,
                min: 5,
                max: 500,
                divisions: 99,
                label: '${deger.round()} m',
                onChanged: (v) => _esnaf(e.copyWith(konumDogrulamaMesafesi: v)),
              ),
            ),
            Text('${deger.round()} m', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _iptalSoru(TextEditingController c, String soru, [String yardim = '']) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(soru, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            labelText: 'TL',
            helperText: yardim.isEmpty ? null : yardim,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _iptalYaz(),
        ),
      ],
    );
  }

  void _iptalYaz() {
    final e = k.esnafOku();
    _esnaf(e.copyWith(
      taksiIptalTabanUcret: taksiTlOku(_iptalTaban.text),
      taksiIptalKmUcret: taksiTlOku(_iptalKm.text),
      taksiIptalDakikaUcret: taksiTlOku(_iptalDakika.text),
    ));
  }

  Widget _iptalBedeli() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hizliMaviKutu(_mavi('İptal bedeli')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: const Text(
            taksiIptalSureNotu,
            style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w600, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        _iptalSoru(_iptalTaban, 'Vazgeçince taban ücreti kaç TL?'),
        const SizedBox(height: 8),
        _iptalSoru(_iptalKm, 'Şoförün gittiği her kilometre başına kaç TL?'),
        const SizedBox(height: 8),
        _iptalSoru(
          _iptalDakika,
          'Şoförün çağrıyı kabul ettiği andan yolcunun vazgeçtiği ana kadar geçen her dakika için kaç TL?',
          'Süre, şoförün çağrıyı kabul ettiği andan yolcunun vazgeçtiği ana kadardır.',
        ),
      ],
    );
  }

  Widget _ozet() {
    final e = k.esnafOku();
    final gunler = k.gunler.entries.where((g) => g.value).map((g) => g.key).join(', ');
    final araclar = k.araclar.map((a) {
      final plaka = (a['plaka'] ?? '').toString();
      final ad = (a['soforAd'] ?? '').toString();
      return '$plaka ($ad)';
    }).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hizliOzetSatiri('Randevu: ${e.randevuAlinmasin ? 'kapalı' : 'açık'}'),
        if (!e.randevuAlinmasin) hizliOzetSatiri('Alınan randevular: ${e.aracOdakliSistem ? 'Plaka' : 'Durak'}'),
        hizliOzetSatiri('7/24: ${k.is724Oku() ? 'evet' : 'hayır'}'),
        hizliOzetSatiri('Gündüz mesai araçları: ${k.acilisOku()} – ${k.kapanisOku()}'),
        if (k.is724Oku()) hizliOzetSatiri('Nöbet: ${k.nobetBasOku()} – ${k.nobetBitOku()}'),
        hizliOzetSatiri('Günler: ${gunler.isEmpty ? 'yok' : gunler}'),
        hizliOzetSatiri('Araçlar: ${araclar.isEmpty ? 'yok' : araclar}'),
        hizliOzetSatiri('Anlık çağrı: ${e.taksiCagriBildirim ? 'açık' : 'kapalı'}'),
        hizliOzetSatiri('Yeni rezervasyon: ${e.taksiRezervasyonEsnafBildirim ? 'durağa gider' : 'kapalı'}'),
        hizliOzetSatiri('Onay ve red: ${e.taksiRezervasyonMusteriBildirim ? 'yolcuya gider' : 'kapalı'}'),
        hizliOzetSatiri('Hatırlatma: ${e.taksiRezervasyonHatirlatmaDk <= 0 ? 'kapalı' : '${e.taksiRezervasyonHatirlatmaDk} dakika önce'}'),
        hizliOzetSatiri('İstirahatli araçlar: ${e.istirahatliAraclariGizle ? 'müşteri görmez' : 'müşteri görür'}'),
        hizliOzetSatiri('Konum mesafesi: ${_mesafe(e).round()} m'),
        hizliOzetSatiri('Onay: ${e.randevuOnayModu == 'Otomatik' ? 'otomatik' : 'ben onaylayacağım'}'),
        hizliOzetSatiri('Navigasyon: ${e.taksiNavigasyonOtomatik ? 'kabulde kendiliğinden açılır' : 'kabulde sorulur'}'),
        hizliOzetSatiri('İptal bedeli: taban ${taksiTlEtiket(e.taksiIptalTabanUcret)}, km ${taksiTlEtiket(e.taksiIptalKmUcret)}, dk ${taksiTlEtiket(e.taksiIptalDakikaUcret)}'),
      ],
    );
  }
}
