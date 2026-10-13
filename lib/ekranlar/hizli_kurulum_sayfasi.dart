import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/yardimcilar/hatirlatma_sablonlari.dart';
import 'package:almely_randevu/yardimcilar/mesai_saati_sec.dart';
import 'package:almely_randevu/yardimcilar/kategori_kanal_rehberi.dart';

/// Ortak esnaf panelindeki alanları adım adım doldurur.
class HizliKurulumKopru {
  HizliKurulumKopru({
    required this.kategori,
    required this.vitrin,
    required this.onGorusmeUygun,
    required this.acilisOku,
    required this.kapanisOku,
    required this.is724Oku,
    required this.nobetBasOku,
    required this.nobetBitOku,
    required this.acilisYaz,
    required this.kapanisYaz,
    required this.is724Yaz,
    required this.nobetBasYaz,
    required this.nobetBitYaz,
    required this.gunler,
    required this.gunDegisti,
    required this.kanallar,
    required this.kanalEkle,
    required this.kanalSil,
    required this.personeller,
    required this.personelOdakliOku,
    required this.personelOdakliYaz,
    required this.personelEkle,
    required this.personelSil,
    required this.hizmetler,
    required this.onGorusmeAcik,
    required this.onGorusmeYaz,
    required this.hizmetEkle,
    required this.hizmetSil,
    required this.galeri,
    required this.galeriEkle,
    required this.galeriSil,
    required this.tanitimOku,
    required this.tanitimYaz,
    required this.kaydet,
    required this.esnafOku,
    required this.esnafYaz,
  });

  final String kategori;
  final bool vitrin;
  final bool onGorusmeUygun;
  final String Function() acilisOku;
  final String Function() kapanisOku;
  final bool Function() is724Oku;
  final String Function() nobetBasOku;
  final String Function() nobetBitOku;
  final void Function(String) acilisYaz;
  final void Function(String) kapanisYaz;
  final void Function(bool) is724Yaz;
  final void Function(String) nobetBasYaz;
  final void Function(String) nobetBitYaz;
  final Map<String, bool> gunler;
  final VoidCallback gunDegisti;
  final List<String> kanallar;
  final void Function(String ad) kanalEkle;
  final void Function(int i) kanalSil;
  final List<Map<String, dynamic>> personeller;
  final bool Function() personelOdakliOku;
  final void Function(bool) personelOdakliYaz;
  final void Function(String isim, String kanal) personelEkle;
  final void Function(int i) personelSil;
  final List<Map<String, dynamic>> hizmetler;
  final bool Function() onGorusmeAcik;
  final void Function(bool) onGorusmeYaz;
  final void Function({
    required String isim,
    required int sure,
    required double ucret,
    required bool ucretGoster,
  }) hizmetEkle;
  final void Function(int i) hizmetSil;
  final List<String> Function() galeri;
  final Future<void> Function() galeriEkle;
  final void Function(String url) galeriSil;
  final String Function() tanitimOku;
  final void Function(String) tanitimYaz;
  final Future<void> Function() kaydet;
  final EsnafModeli Function() esnafOku;
  final void Function(EsnafModeli) esnafYaz;
}

class HizliKurulumSayfasi extends StatefulWidget {
  final HizliKurulumKopru kopru;
  const HizliKurulumSayfasi({super.key, required this.kopru});

  @override
  State<HizliKurulumSayfasi> createState() => _HizliKurulumSayfasiState();
}

class _HizliKurulumSayfasiState extends State<HizliKurulumSayfasi> {
  int _adim = 0;
  final _kanalAd = TextEditingController();
  final _personelAd = TextEditingController();
  String _personelKanal = '';
  final _hizmetAd = TextEditingController();
  final _hizmetSure = TextEditingController(text: '30');
  final _hizmetUcret = TextEditingController();
  bool _ucretGoster = false;
  final _onGorusmeSure = TextEditingController(text: '30');
  final _onGorusmeUcret = TextEditingController();
  bool _onGorusmeUcretAl = false;
  int _randevuSekli = 1;
  bool _fotoYukleniyor = false;
  bool _kaydediliyor = false;

  HizliKurulumKopru get k => widget.kopru;

  List<String> get _basliklar => [
        'Başlangıç',
        'Randevu alınsın mı',
        '7/24',
        if (!k.is724Oku()) 'Açılış ve kapanış',
        if (k.is724Oku()) 'Mesai başlangıç ve bitiş',
        'Çalışma günleri',
        'Randevu kanalı',
        'Çalışanlar',
        if (k.vitrin) 'Tanıtım',
        'Hizmetler',
        'Öncesi bildirim',
        'Sonrası bildirim',
        'Red bildirimi',
        'Kimler alabilsin',
        if (k.onGorusmeUygun) 'Randevu şekli',
        'Kim onaylasın',
        'Süresi dolan',
        'Aynı gün',
        'Ajanda',
        'İleri gün',
        'Geç iptal',
        'Kara liste',
        'Sadakat',
        'Aralıklı slot',
        if (k.vitrin) 'Vitrin',
        'Kayıt',
      ];

  @override
  void initState() {
    super.initState();
    final e = k.esnafOku();
    if (e.sadeceOnGorusme) {
      _randevuSekli = 2;
    } else if (e.onGorusmeZorunlu) {
      _randevuSekli = 3;
    }
  }

  @override
  void dispose() {
    _kanalAd.dispose();
    _personelAd.dispose();
    _hizmetAd.dispose();
    _hizmetSure.dispose();
    _hizmetUcret.dispose();
    _onGorusmeSure.dispose();
    _onGorusmeUcret.dispose();
    super.dispose();
  }

  bool get _son => _adim >= _basliklar.length - 1;

  String? _engel() {
    switch (_basliklar[_adim]) {
      case 'Açılış ve kapanış':
        final acilis = k.acilisOku();
        final kapanis = k.kapanisOku();
        if (acilis == 'Seçilmedi' || kapanis == 'Seçilmedi' || !acilis.contains(':') || !kapanis.contains(':')) {
          return 'Açılış ve kapanış saatini seçin. İleri ondan sonra açılır.';
        }
        return null;
      case 'Çalışma günleri':
        if (!k.gunler.values.any((v) => v)) return 'En az bir çalışma günü seçin.';
        return null;
      case 'Randevu kanalı':
        if (!k.kanallar.any((e) => e.trim().isNotEmpty)) return 'En az bir kanal yazıp Kanal Ekle deyin.';
        return null;
      case 'Hizmetler':
        final varMi = k.hizmetler.any((h) {
          final ad = (h['isim'] ?? h['ad'] ?? '').toString().trim();
          final sure = int.tryParse('${h['sure'] ?? ''}') ?? 0;
          return ad.isNotEmpty && sure > 0;
        });
        if (!varMi) return 'En az bir hizmet adı ve süresi girip Hizmet Ekle deyin.';
        return null;
      default:
        return null;
    }
  }

  Future<void> _saatSec(String etiket, String simdi, void Function(String) yaz) async {
    final t = await mesaiSaatiSec(context, baslik: etiket, secili: simdi.contains(':') ? simdi : '09:00');
    if (t == null) return;
    yaz(t);
    setState(() {});
  }

  void _kanalEkle() {
    final ad = _kanalAd.text.trim();
    if (ad.isEmpty) return;
    if (k.kanallar.any((e) => e.trim().toLowerCase() == ad.toLowerCase())) return;
    k.kanalEkle(ad);
    _kanalAd.clear();
    setState(() {});
  }

  void _hizmetEkle() {
    final ad = _hizmetAd.text.trim();
    final sure = int.tryParse(_hizmetSure.text.trim()) ?? 0;
    if (ad.isEmpty || sure <= 0) return;
    final ucret = double.tryParse(_hizmetUcret.text.trim().replaceAll(',', '.')) ?? 0;
    k.hizmetEkle(isim: ad, sure: sure, ucret: ucret, ucretGoster: _ucretGoster && ucret > 0);
    _hizmetAd.clear();
    _hizmetUcret.clear();
    _ucretGoster = false;
    setState(() {});
  }

  void _personelEkle() {
    final ad = _personelAd.text.trim();
    if (ad.isEmpty) return;
    k.personelEkle(ad, _personelKanal);
    _personelAd.clear();
    _personelKanal = '';
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
    final engel = _engel();
    final secim = _secilenAciklama(baslik);
    final rehber = KategoriKanalRehberi.bul(k.kategori);
    return Scaffold(
      appBar: AppBar(
        title: Text('Hızlı Kurulum · ${ _adim + 1}/${_basliklar.length}'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_adim + 1) / _basliklar.length),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (baslik != 'Başlangıç') ...[
                    Text(baslik, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ],
                  if (!_maviSoruAltinda(baslik)) ...[
                    _aciklamaKutusu(_aciklamaMetni(baslik, rehber)),
                    const SizedBox(height: 16),
                  ],
                  _icerik(baslik, rehber),
                ],
              ),
            ),
          ),
          if (engel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(engel, style: const TextStyle(color: Colors.red)),
            ),
          if (secim.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(secim, style: TextStyle(height: 1.35, color: Colors.green.shade900)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (_adim > 0)
                  OutlinedButton(
                    onPressed: _kaydediliyor ? null : () => setState(() => _adim--),
                    child: const Text('Geri'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: engel != null || _kaydediliyor ? null : _ileri,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: Text(_kaydediliyor ? 'Kaydediliyor' : (_son ? 'Bitir' : 'İleri')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _secilenAciklama(String baslik) {
    final e = k.esnafOku();
    switch (baslik) {
      case 'Randevu alınsın mı':
        return e.randevuAlinmasin
            ? 'Seçiminiz: Hayır. Müşteri Hemen Randevu Al düğmesini görmez.'
            : 'Seçiminiz: Evet. Müşteri bu işletmeden randevu alabilir.';
      case '7/24':
        return k.is724Oku()
            ? 'Seçiminiz: Evet. İşletme her gün her saat açık kalır. Açılış ve kapanış 00:00 olur.'
            : 'Seçiminiz: Hayır. Bir sonraki adımda açılış ve kapanış saatini seçersiniz.';
      case 'Açılış ve kapanış':
        return 'Seçiminiz: mesai ${k.acilisOku()} ile ${k.kapanisOku()} arası. Müşteri yalnızca bu saatlerde randevu görür.';
      case 'Mesai başlangıç ve bitiş':
        return 'Seçiminiz: nöbet ${k.nobetBasOku()}–${k.nobetBitOku()}. 7/24 açık olduğu için müşteri her saati görebilir.';
      case 'Çalışma günleri':
        final acik = k.gunler.entries.where((g) => g.value).map((g) => g.key).toList();
        if (acik.isEmpty) return 'Henüz gün seçilmedi. En az bir gün işaretleyin.';
        return 'Seçiminiz: ${acik.join(', ')}. Bu günlerde randevu alınır.';
      case 'Randevu kanalı':
        final adlar = k.kanallar.where((a) => a.trim().isNotEmpty).toList();
        if (adlar.isEmpty) return 'Henüz kanal yok. Bir ad yazıp Kanal Ekle deyin.';
        return 'Seçiminiz: ${adlar.join(', ')}. Aynı saatte her kanal ayrı randevu alır.';
      case 'Çalışanlar':
        if (!k.personelOdakliOku()) return 'Seçiminiz: Hayır. Müşteri personel seçmez.';
        final kisiler = k.personeller.map((p) => (p['isim'] ?? '').toString()).where((a) => a.isNotEmpty).toList();
        if (kisiler.isEmpty) return 'Seçiminiz: Evet. Randevu çalışan adına alınır. Personel adını ekleyebilirsiniz.';
        return 'Seçiminiz: Evet. Randevu şu çalışanlar adına alınır: ${kisiler.join(', ')}.';
      case 'Tanıtım':
        final yazi = k.tanitimOku().trim();
        final foto = k.galeri().length;
        if (yazi.isEmpty && foto == 0) return 'Seçiminiz: boş. Tanıtım ve fotoğraf eklemeden İleri diyebilirsiniz.';
        return 'Seçiminiz: ${yazi.isEmpty ? 'tanıtım yazısı yok' : 'kısa tanıtım yazıldı'}, $foto fotoğraf. Müşteri sayfasında görünür.';
      case 'Hizmetler':
        final adlar = k.hizmetler
            .map((h) => (h['isim'] ?? h['ad'] ?? '').toString().trim())
            .where((a) => a.isNotEmpty)
            .toList();
        if (adlar.isEmpty) return 'Henüz hizmet yok. Ad ve süre yazıp Hizmet Ekle deyin.';
        return 'Seçiminiz: ${adlar.join(', ')}. Süre, müşteri geldiğinde harcanacak dakikadır.';
      case 'Öncesi bildirim':
        if (!e.hatirlatmaOnceAktif) return 'Seçiminiz: Hayır. Randevudan önce bildirim gitmez.';
        final dk = HatirlatmaSablonlari.onceDakikaSecenekleri.contains(e.hatirlatmaOnceDk) ? e.hatirlatmaOnceDk : 60;
        return 'Seçiminiz: Evet. Onaylı randevudan ${HatirlatmaSablonlari.dakikaEtiketi(dk)} önce müşteriye bildirim gider.';
      case 'Sonrası bildirim':
        if (!e.hatirlatmaSonraAktif) return 'Seçiminiz: Hayır. Randevu bittikten sonra bildirim gitmez.';
        final dk = HatirlatmaSablonlari.sonraDakikaSecenekleri.contains(e.hatirlatmaSonraDk) ? e.hatirlatmaSonraDk : 30;
        return 'Seçiminiz: Evet. Randevu saatinden ${HatirlatmaSablonlari.dakikaEtiketi(dk)} sonra müşteriye bildirim gider.';
      case 'Red bildirimi':
        return e.redBildirimAktif
            ? 'Seçiminiz: Evet. Randevuyu reddedince müşteriye bildirim gider.'
            : 'Seçiminiz: Hayır. Red bildirimi gitmez.';
      case 'Kimler alabilsin':
        return e.randevuSadeceYonetici
            ? 'Seçiminiz: Sadece Yönetici. Randevuyu siz yazarsınız. Müşteri kendi randevusunu alamaz.'
            : 'Seçiminiz: Müşteri ve Yönetici. Müşteri kendi randevusunu alır, siz de yazabilirsiniz.';
      case 'Randevu şekli':
        if (_randevuSekli == 2) {
          final sure = int.tryParse(_onGorusmeSure.text.trim()) ?? 30;
          final ucret = _onGorusmeUcretAl ? (_onGorusmeUcret.text.trim().isEmpty ? '0' : _onGorusmeUcret.text.trim()) : '0';
          return 'Seçiminiz: yalnızca ön görüşme, $sure dk, ücret $ucret TL. Müşteri başka hizmet seçemez.';
        }
        if (_randevuSekli == 3) {
          final sure = int.tryParse(_onGorusmeSure.text.trim()) ?? 30;
          final ucret = _onGorusmeUcretAl ? (_onGorusmeUcret.text.trim().isEmpty ? '0' : _onGorusmeUcret.text.trim()) : '0';
          return 'Seçiminiz: önce ön görüşme ($sure dk, ücret $ucret TL). Saati gelip onaylanınca diğer hizmetler açılır.';
        }
        return 'Seçiminiz: yalnızca hizmetler. Ön görüşme yoktur. Müşteri doğrudan hizmet alır.';
      case 'Kim onaylasın':
        return e.randevuOnayModu == 'Otomatik'
            ? 'Seçiminiz: Otomatik. Yeni randevu hemen onaylanır.'
            : 'Seçiminiz: Ben onaylayacağım. Yeni randevu sizden onay bekler.';
      case 'Süresi dolan':
        return e.sureDolanOnaylanmasin
            ? 'Seçiminiz: Evet. 10 dakika dolunca bekleyen randevu onaylanamaz. Yine de reddedebilirsiniz.'
            : 'Seçiminiz: Hayır. Süre dolsa da randevuyu onaylayabilirsiniz.';
      case 'Aynı gün':
        return e.ayniGunRandevuEngelle
            ? 'Seçiminiz: Evet. Bir müşteri bu işletmede aynı güne yalnızca 1 randevu alır.'
            : 'Seçiminiz: Hayır. Aynı güne birden fazla randevu engellenmez.';
      case 'Ajanda':
        return e.ajandayiKendimAyarlayacagim
            ? 'Seçiminiz: Evet. Ajanda günlerini siz hazırlarsınız.'
            : 'Seçiminiz: Hayır. Müşteri günleri otomatik açılır.';
      case 'İleri gün':
        return 'Seçiminiz: ${e.maksimumRandevuGunu.clamp(1, 365)} gün. Müşteri bugünden en fazla bu kadar ileriye yazar.';
      case 'Geç iptal':
        final saat = [0, 1, 2, 3, 6, 12, 24].contains(e.iptalSinirSaati) ? e.iptalSinirSaati : 0;
        return saat == 0
            ? 'Seçiminiz: Kapalı. İptal normal iptal sayılır, geç iptal notu düşmez.'
            : 'Seçiminiz: $saat saat. Randevuya bu kadar az kala iptal geç iptal notu olur.';
      case 'Kara liste':
        final esik = [0, 2, 3, 4, 5].contains(e.karaListeEsik) ? e.karaListeEsik : 0;
        return esik == 0
            ? 'Seçiminiz: Kapalı. Not düşülür, yeni randevu kapanmaz.'
            : 'Seçiminiz: $esik. Gelmedi ile geç iptal bu sayıya ulaşınca müşteri bu işletmeden yeni randevu alamaz.';
      case 'Sadakat':
        if (!e.sadakatAktif) return 'Seçiminiz: Hayır. Sadakat indirimi işaretlenmez.';
        return 'Seçiminiz: Evet. Her ${e.sadakatAdet}. onaylı randevuda kasada %${e.sadakatYuzde} indirim notu düşer.';
      case 'Aralıklı slot':
        return e.slotAralikliGoster
            ? 'Seçiminiz: Evet. Saat 10:00-11:00 arası şeklinde görünür.'
            : 'Seçiminiz: Hayır. Yalnızca başlangıç saati görünür, örneğin 10:00.';
      case 'Vitrin':
        final foto = k.galeri().length;
        return foto == 0
            ? 'Seçiminiz: fotoğraf yok. Boş geçebilirsiniz. Müşteri sayfasında vitrin görünmez.'
            : 'Seçiminiz: $foto fotoğraf. Müşteri sayfanıza girince vitrinde görür.';
      default:
        return '';
    }
  }

  bool _maviSoruAltinda(String baslik) {
    const adimlar = {
      'Randevu alınsın mı',
      '7/24',
      'Çalışanlar',
      'Öncesi bildirim',
      'Sonrası bildirim',
      'Red bildirimi',
      'Kimler alabilsin',
      'Randevu şekli',
      'Kim onaylasın',
      'Süresi dolan',
      'Aynı gün',
      'Ajanda',
      'İleri gün',
      'Geç iptal',
      'Kara liste',
      'Sadakat',
      'Aralıklı slot',
    };
    return adimlar.contains(baslik);
  }

  Widget _maviKutu() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _aciklamaKutusu(_aciklamaMetni(_basliklar[_adim], KategoriKanalRehberi.bul(k.kategori))),
    );
  }

  Widget _aciklamaKutusu(String metin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(metin, style: TextStyle(height: 1.35, color: Colors.blue.shade900)),
    );
  }

  String _aciklamaMetni(String baslik, KategoriKanalRehberi rehber) {
    switch (baslik) {
      case 'Başlangıç':
        return 'Hızlı Kurulum menüsüne hoş geldiniz. Yapacağınız tercihleri daha sonra değiştirebileceğinizi unutmayın.';
      case 'Randevu alınsın mı':
        return 'Evet derseniz müşteri randevu alabilir. Hayır derseniz Hemen Randevu Al düğmesi kapanır. Bunu sonra değiştirebilirsiniz.';
      case '7/24':
        return 'Evet derseniz işletme her gün her saat açık olur. Hayır derseniz bir sonraki adımda açılış ve kapanış saatini seçersiniz.';
      case 'Açılış ve kapanış':
        return 'Bunlar mesai başlangıç ve bitiş saatlerinizdir. Müşteri yalnızca bu aralıkta saat görür.';
      case 'Mesai başlangıç ve bitiş':
        return '7/24 açıkken açılış ve kapanış 00:00 kalır. Burada sizin nöbet aralığınızı seçin.';
      case 'Çalışma günleri':
        return 'İşaretli günlerde randevu alınır. Kapalı günü boş bırakın. 7/24 açıksa günlerin hepsi açıktır.';
      case 'Randevu kanalı':
        return 'Kanal adını yazın. ${rehber.kanalBilgi} Aynı saatte ikinci bir kişi alınacaksa her yeri ayrı yazın. Kanal Ekle ile listeye alın.';
      case 'Çalışanlar':
        return 'Evet derseniz randevu çalışan adına alınır; ad ve kanal çıkar. Hayır derseniz müşteri kişi seçmez. Tek başınıza çalışıyorsanız Hayır deyip İleri deyin.';
      case 'Tanıtım':
        return 'Kısa tanıtım müşteri sayfasında adresin altında görünür. Fotoğraf en fazla 6 olur. İkisi de boş geçilebilir.';
      case 'Hizmetler':
        return '${rehber.hizmetBilgi} Süre, randevulu müşteri geldiğinde harcanacak dakikadır. Hizmet Ekle ile listeye alın. Ön görüşme bir sonraki sorudadır.';
      case 'Öncesi bildirim':
        return 'Evet derseniz onaylı randevudan önce müşteriye bildirim gider ve süreyi seçersiniz. Hayır derseniz öncesi kapalı kalır.';
      case 'Sonrası bildirim':
        return 'Evet derseniz randevu bittikten sonra bildirim gider ve süreyi seçersiniz. Hayır derseniz sonrası kapalı kalır.';
      case 'Red bildirimi':
        return 'Evet derseniz randevuyu reddettiğinizde müşteriye red bildirimi gider. Müşterinin kendi iptali bu metni göndermez.';
      case 'Kimler alabilsin':
        return 'Müşteri ve Yönetici: müşteri kendi randevusunu alır, siz de yazabilirsiniz. Sadece Yönetici: randevuyu siz verirsiniz.';
      case 'Randevu şekli':
        return 'Yalnızca hizmetlerde ön görüşme kapalı kalır. Yalnızca ön görüşmede müşteri başka hizmet seçemez. Üçüncü seçenekte önce ön görüşme alınır; saati gelip onaylanınca diğer hizmetler açılır.';
      case 'Kim onaylasın':
        return 'Ben onaylayacağım derseniz yeni randevu sizden onay bekler. Otomatik onaylansın derseniz kayıt hemen onaylanır.';
      case 'Süresi dolan':
        return 'Bekleyen randevuyu 10 dakika içinde onaylamanız gerekir. Evet derseniz süre dolunca onay kapanır; reddetmek açık kalır. Hayır derseniz süre dolsa da onaylayabilirsiniz.';
      case 'Aynı gün':
        return 'Evet derseniz bir müşteri bu işletmede aynı güne yalnızca 1 randevu alır. Hizmet veya kanal değiştirmek ikinci hak açmaz.';
      case 'Ajanda':
        return 'Evet derseniz ajanda günlerini siz hazırlarsınız. Hayır derseniz müşteri günleri otomatik açılır.';
      case 'İleri gün':
        return 'Müşteri ve tekrarlayan seri bugünden en fazla bu kadar gün ileriye yazılır.';
      case 'Geç iptal':
        return 'Müşteri randevusuna bu kadar saat kala iptal ederse geç iptal notu düşer. 0 kapalıdır; iptal normal iptal sayılır.';
      case 'Kara liste':
        return 'Gelmedi ile geç iptal toplanır. Seçilen sayıya ulaşan müşteri bu işletmeden yeni randevu alamaz. 0 kapalıdır.';
      case 'Sadakat':
        return 'Evet derseniz kaçıncı randevu ve yüzde sorulur. İndirim kasada not düşer. Paket hakkı değişmez. Hayır derseniz işaretlenmez.';
      case 'Aralıklı slot':
        return 'Evet derseniz saat 10:00 yerine 10:00-11:00 arası görünür. Hayır derseniz yalnızca başlangıç saati görünür.';
      case 'Vitrin':
        return 'Müşteri sayfanıza girince vitrin fotoğrafı görsün mü? En fazla 6. Boş geçip İleri diyebilirsiniz.';
      case 'Kayıt':
        return 'Aşağıda yaptığınız bütün tercihler durur. Bitir bunları kaydeder. Fotoğraf eklediyseniz o zaten yayınlanmıştır.';
      default:
        return '';
    }
  }

  Widget _icerik(String baslik, KategoriKanalRehberi rehber) {
    switch (baslik) {
      case 'Başlangıç':
        return const SizedBox.shrink();
      case 'Randevu alınsın mı':
        return _randevuAlinsin();
      case '7/24':
        return _yediYirmiDort();
      case 'Açılış ve kapanış':
        return _acilisKapanis();
      case 'Mesai başlangıç ve bitiş':
        return _nobetSaat();
      case 'Çalışma günleri':
        return _gunler();
      case 'Randevu kanalı':
        return _kanallar();
      case 'Çalışanlar':
        return _personeller();
      case 'Tanıtım':
        return _tanitim();
      case 'Hizmetler':
        return _hizmetler();
      case 'Öncesi bildirim':
        return _onceBildirim();
      case 'Sonrası bildirim':
        return _sonraBildirim();
      case 'Red bildirimi':
        return _redBildirim();
      case 'Kimler alabilsin':
        return _kimlerAlabilsin();
      case 'Randevu şekli':
        return _randevuSekliSoru();
      case 'Kim onaylasın':
        return _kimOnaylasin();
      case 'Süresi dolan':
        return _sureDolan();
      case 'Aynı gün':
        return _ayniGun();
      case 'Ajanda':
        return _ajandaSoru();
      case 'İleri gün':
        return _ileriGun();
      case 'Geç iptal':
        return _gecIptal();
      case 'Kara liste':
        return _karaListe();
      case 'Sadakat':
        return _sadakat();
      case 'Aralıklı slot':
        return _aralikliSlot();
      case 'Vitrin':
        return _vitrin();
      case 'Kayıt':
        return _ozet();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _saatKutu(String etiket, String deger, void Function(String) yaz) {
    return InkWell(
      onTap: () => _saatSec(etiket, deger, yaz),
      child: Column(
        children: [
          Text(etiket, style: const TextStyle(color: Colors.grey)),
          Text(deger, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ],
      ),
    );
  }

  Widget _randevuAlinsin() {
    final e = k.esnafOku();
    return _evetHayir(
      'İşletmeye randevu alınsın mı?',
      !e.randevuAlinmasin,
      (v) => _esnaf(e.copyWith(randevuAlinmasin: !v, randevuSadeceYonetici: v ? e.randevuSadeceYonetici : false)),
    );
  }

  Widget _yediYirmiDort() {
    return _evetHayir(
      'İşletmeniz 7/24 mü çalışıyor?',
      k.is724Oku(),
      (v) {
        k.is724Yaz(v);
        setState(() {});
      },
    );
  }

  Widget _acilisKapanis() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _saatKutu('Açılış', k.acilisOku(), k.acilisYaz),
        _saatKutu('Kapanış', k.kapanisOku(), k.kapanisYaz),
      ],
    );
  }

  Widget _nobetSaat() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _saatKutu('Mesai başlangıç', k.nobetBasOku(), k.nobetBasYaz),
        _saatKutu('Mesai bitiş', k.nobetBitOku(), k.nobetBitYaz),
      ],
    );
  }

  Widget _evetHayir(String soru, bool evet, ValueChanged<bool> yaz, {bool mavi = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(soru, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (mavi) _maviKutu(),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Evet'),
              selected: evet,
              onSelected: (_) => yaz(true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Hayır'),
              selected: !evet,
              onSelected: (_) => yaz(false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gunler() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final hepsi = k.gunler.values.every((v) => v);
              k.gunler.updateAll((key, _) => !hepsi);
              k.gunDegisti();
              setState(() {});
            },
            child: Text(k.gunler.values.every((v) => v) ? 'Tümünü kaldır' : 'Tümünü seç'),
          ),
        ),
        ...k.gunler.keys.map((gun) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(gun),
              value: k.gunler[gun] ?? false,
              onChanged: (v) {
                k.gunler[gun] = v ?? false;
                k.gunDegisti();
                setState(() {});
              },
            )),
      ],
    );
  }

  Widget _kanallar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _kanalAd,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Kanal Adı', border: OutlineInputBorder()),
          onSubmitted: (_) => _kanalEkle(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _kanalEkle,
            icon: const Icon(Icons.add),
            label: const Text('Kanal Ekle'),
          ),
        ),
        ...k.kanallar.asMap().entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  k.kanalSil(e.key);
                  setState(() {});
                },
              ),
            )),
      ],
    );
  }

  Widget _personeller() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Randevular çalışanlar adına mı alınsın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        _maviKutu(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Çalışan adına alınsın'),
          value: k.personelOdakliOku(),
          onChanged: (v) {
            k.personelOdakliYaz(v);
            setState(() {});
          },
        ),
        if (k.personelOdakliOku()) ...[
          TextField(
            controller: _personelAd,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Personel adı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('personel-kanal-${k.kanallar.join('|')}-$_personelKanal'),
            initialValue: k.kanallar.contains(_personelKanal) || _personelKanal.isEmpty ? _personelKanal : '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Bağlı olduğu kanal', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tüm kanallar')),
              ...k.kanallar.map((ad) => DropdownMenuItem(value: ad, child: Text(ad))),
            ],
            onChanged: (v) => setState(() => _personelKanal = v ?? ''),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _personelEkle,
              icon: const Icon(Icons.add),
              label: const Text('Personel Ekle'),
            ),
          ),
          ...k.personeller.asMap().entries.map((e) {
            final ad = (e.value['isim'] ?? '').toString();
            final kanal = (e.value['kanal'] ?? '').toString();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ad.isEmpty ? 'İsimsiz' : ad),
              subtitle: Text(kanal.isEmpty ? 'Tüm kanallar' : kanal),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  k.personelSil(e.key);
                  setState(() {});
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _hizmetler() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _hizmetAd,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Hizmet adı', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hizmetSure,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Randevulu müşteri geldiğinde harcanacak süre (dakika)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hizmetUcret,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Ücret (isteğe bağlı)', suffixText: 'TL', border: OutlineInputBorder()),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ücreti müşteri görsün mü'),
          value: _ucretGoster,
          onChanged: (v) => setState(() => _ucretGoster = v ?? false),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _hizmetEkle,
            icon: const Icon(Icons.add),
            label: const Text('Hizmet Ekle'),
          ),
        ),
        ...k.hizmetler.asMap().entries.map((e) {
          final ad = (e.value['isim'] ?? e.value['ad'] ?? '').toString();
          final sure = e.value['sure'] ?? '';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ad.isEmpty ? 'Adsız' : ad),
            subtitle: Text('$sure dk'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                k.hizmetSil(e.key);
                setState(() {});
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _vitrin() => _fotoAlani();

  Widget _fotoAlani() {
    final fotolar = k.galeri();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...fotolar.map((url) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        onTap: () {
                          k.galeriSil(url);
                          setState(() {});
                        },
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
            if (fotolar.length < 6)
              InkWell(
                onTap: _fotoYukleniyor
                    ? null
                    : () async {
                        setState(() => _fotoYukleniyor = true);
                        await k.galeriEkle();
                        if (mounted) setState(() => _fotoYukleniyor = false);
                      },
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _fotoYukleniyor
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo, color: Colors.indigo),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _esnaf(EsnafModeli e) {
    k.esnafYaz(e);
    setState(() {});
  }

  Widget _radyo(String baslik, String alt, bool secili, VoidCallback yaz) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(secili ? Icons.radio_button_checked : Icons.radio_button_off, color: secili ? Colors.indigo : Colors.grey),
      title: Text(baslik),
      subtitle: alt.isEmpty ? null : Text(alt),
      onTap: yaz,
    );
  }

  Widget _secim(String baslik, String aciklama, int deger, List<int> secenekler, String Function(int) etiket, ValueChanged<int> yaz, {bool mavi = false}) {
    final goster = secenekler.contains(deger) ? deger : secenekler.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (mavi) _maviKutu() else ...[
          const SizedBox(height: 4),
          Text(aciklama, style: const TextStyle(color: Colors.black54)),
        ],
        DropdownButton<int>(
          value: goster,
          isExpanded: true,
          items: secenekler.map((v) => DropdownMenuItem(value: v, child: Text(etiket(v)))).toList(),
          onChanged: (v) {
            if (v != null) yaz(v);
          },
        ),
      ],
    );
  }

  Widget _tanitim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: k.tanitimOku(),
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Kısa tanıtım',
            hintText: 'Ne yaptığınızı kısaca yazın',
            border: OutlineInputBorder(),
          ),
          onChanged: k.tanitimYaz,
        ),
        const SizedBox(height: 8),
        _fotoAlani(),
      ],
    );
  }

  Widget _onceBildirim() {
    final e = k.esnafOku();
    final dk = HatirlatmaSablonlari.onceDakikaSecenekleri.contains(e.hatirlatmaOnceDk) ? e.hatirlatmaOnceDk : 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _evetHayir(
          'Randevudan önce müşteriye bildirim gitsin mi?',
          e.hatirlatmaOnceAktif,
          (v) => _esnaf(e.copyWith(hatirlatmaAktif: v || e.hatirlatmaSonraAktif, hatirlatmaOnceAktif: v)),
        ),
        if (e.hatirlatmaOnceAktif)
          _secim(
            'Ne kadar önce?',
            'Onaylı randevunun saatinden bu kadar önce gider.',
            dk,
            HatirlatmaSablonlari.onceDakikaSecenekleri,
            HatirlatmaSablonlari.dakikaEtiketi,
            (v) => _esnaf(e.copyWith(hatirlatmaOnceDk: v)),
          ),
      ],
    );
  }

  Widget _sonraBildirim() {
    final e = k.esnafOku();
    final dk = HatirlatmaSablonlari.sonraDakikaSecenekleri.contains(e.hatirlatmaSonraDk) ? e.hatirlatmaSonraDk : 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _evetHayir(
          'Randevudan sonra müşteriye bildirim gitsin mi?',
          e.hatirlatmaSonraAktif,
          (v) => _esnaf(e.copyWith(hatirlatmaAktif: v || e.hatirlatmaOnceAktif, hatirlatmaSonraAktif: v)),
        ),
        if (e.hatirlatmaSonraAktif)
          _secim(
            'Ne kadar sonra?',
            'Randevu saatinden bu kadar sonra gider.',
            dk,
            HatirlatmaSablonlari.sonraDakikaSecenekleri,
            HatirlatmaSablonlari.dakikaEtiketi,
            (v) => _esnaf(e.copyWith(hatirlatmaSonraDk: v)),
          ),
      ],
    );
  }

  Widget _redBildirim() {
    final e = k.esnafOku();
    return _evetHayir(
      'Randevuyu reddedince müşteriye bildirim gitsin mi?',
      e.redBildirimAktif,
      (v) => _esnaf(e.copyWith(redBildirimAktif: v)),
    );
  }

  Widget _kimlerAlabilsin() {
    final e = k.esnafOku();
    final yonetici = e.randevuSadeceYonetici;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Randevuyu kimler alabilsin?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        _maviKutu(),
        _radyo('Müşteri ve Yönetici', 'Müşteri kendi randevusunu alır. Siz de yazabilirsiniz.', !yonetici, () => _esnaf(e.copyWith(randevuAlinmasin: false, randevuSadeceYonetici: false))),
        _radyo('Sadece Yönetici', 'Randevuları sadece yönetici versin işaretlenir.', yonetici, () => _esnaf(e.copyWith(randevuAlinmasin: false, randevuSadeceYonetici: true))),
      ],
    );
  }

  Widget _randevuSekliSoru() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Randevular nasıl alınsın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        _maviKutu(),
        _radyo('Yalnızca hizmetler', 'Ön görüşme yoktur. Müşteri doğrudan hizmet alır.', _randevuSekli == 1, () => _randevuSekliYaz(1)),
        _radyo('Yalnızca ön görüşme', 'Başka hizmet seçemez.', _randevuSekli == 2, () => _randevuSekliYaz(2)),
        _radyo('Ön görüşme, ardından diğer hizmetler', 'Önce ön görüşme alınır. Saati gelip onaylanınca diğer hizmetler açılır.', _randevuSekli == 3, () => _randevuSekliYaz(3)),
        if (_randevuSekli == 2 || _randevuSekli == 3) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _onGorusmeSure,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Ön görüşme süresi (dakika)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _onGorusmeSatiriniYaz(),
          ),
          const SizedBox(height: 8),
          _evetHayir(
            'Ön görüşme ücreti kişiden alınsın mı?',
            _onGorusmeUcretAl,
            (v) {
              setState(() => _onGorusmeUcretAl = v);
              _onGorusmeSatiriniYaz();
            },
            mavi: false,
          ),
          if (_onGorusmeUcretAl)
            TextField(
              controller: _onGorusmeUcret,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ücret ne kadar?', suffixText: 'TL', border: OutlineInputBorder()),
              onChanged: (_) => _onGorusmeSatiriniYaz(),
            ),
        ],
      ],
    );
  }

  void _randevuSekliYaz(int sekil) {
    setState(() => _randevuSekli = sekil);
    final e = k.esnafOku();
    if (sekil == 1) {
      if (k.onGorusmeAcik()) k.onGorusmeYaz(false);
      _esnaf(e.copyWith(sadeceOnGorusme: false, onGorusmeZorunlu: false));
      return;
    }
    if (!k.onGorusmeAcik()) k.onGorusmeYaz(true);
    _onGorusmeSatiriniYaz();
    _esnaf(k.esnafOku().copyWith(
      sadeceOnGorusme: sekil == 2,
      onGorusmeZorunlu: sekil == 3,
    ));
  }

  void _onGorusmeSatiriniYaz() {
    final sure = int.tryParse(_onGorusmeSure.text.trim()) ?? 30;
    final ucret = _onGorusmeUcretAl ? (double.tryParse(_onGorusmeUcret.text.trim().replaceAll(',', '.')) ?? 0) : 0.0;
    final i = k.hizmetler.indexWhere((h) {
      if (h['ilkGorusme'] == true) return true;
      final ad = (h['isim'] ?? h['ad'] ?? '').toString().toLowerCase();
      return ad.contains('ön görüşme') || ad.contains('on gorusme') || ad.contains('ilk görüşme');
    });
    if (i < 0) return;
    k.hizmetler[i]['sure'] = sure <= 0 ? 30 : sure;
    k.hizmetler[i]['ucret'] = ucret;
    k.hizmetler[i]['ucretGoster'] = _onGorusmeUcretAl && ucret > 0;
    k.hizmetler[i]['ilkGorusme'] = true;
    final e = k.esnafOku();
    _esnaf(e.copyWith(
      sadeceOnGorusme: _randevuSekli == 2,
      onGorusmeZorunlu: _randevuSekli == 3,
    ));
  }

  Widget _kimOnaylasin() {
    final e = k.esnafOku();
    final onay = e.randevuOnayModu == 'Otomatik' ? 'Otomatik' : 'Manuel';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Randevuyu kim onaylasın?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        _maviKutu(),
        _radyo('Ben onaylayacağım', '', onay == 'Manuel', () => _esnaf(e.copyWith(randevuOnayModu: 'Manuel'))),
        _radyo('Otomatik onaylansın', '', onay == 'Otomatik', () => _esnaf(e.copyWith(randevuOnayModu: 'Otomatik'))),
      ],
    );
  }

  Widget _sureDolan() {
    final e = k.esnafOku();
    return _evetHayir(
      '10 dakikası dolan randevu onaylanmasın mı?',
      e.sureDolanOnaylanmasin,
      (v) => _esnaf(e.copyWith(sureDolanOnaylanmasin: v)),
    );
  }

  Widget _ayniGun() {
    final e = k.esnafOku();
    return _evetHayir(
      'Müşteri aynı gün içerisinde sadece 1 randevu alabilsin mi?',
      e.ayniGunRandevuEngelle,
      (v) => _esnaf(e.copyWith(ayniGunRandevuEngelle: v)),
    );
  }

  Widget _ajandaSoru() {
    final e = k.esnafOku();
    return _evetHayir(
      'Ajandayı siz mi hazırlayacaksınız?',
      e.ajandayiKendimAyarlayacagim,
      (v) => _esnaf(e.copyWith(ajandayiKendimAyarlayacagim: v)),
    );
  }

  Widget _ileriGun() {
    final e = k.esnafOku();
    final gun = e.maksimumRandevuGunu.clamp(1, 365);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Maksimum ileri kaç gün randevu oluşturulsun?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        _maviKutu(),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: gun.toDouble(),
                min: 1,
                max: 365,
                divisions: 364,
                label: '$gun gün',
                onChanged: (v) => _esnaf(e.copyWith(maksimumRandevuGunu: v.toInt())),
              ),
            ),
            Text('$gun gün', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _gecIptal() {
    final e = k.esnafOku();
    return _secim(
      'Geç iptal kaç saat kala tutulsun?',
      'Bu saatten az kala iptal geç iptal notu olur.',
      [0, 1, 2, 3, 6, 12, 24].contains(e.iptalSinirSaati) ? e.iptalSinirSaati : 0,
      const [0, 1, 2, 3, 6, 12, 24],
      (v) => v == 0 ? 'Kapalı' : '$v saat',
      (v) => _esnaf(e.copyWith(iptalSinirSaati: v)),
      mavi: true,
    );
  }

  Widget _karaListe() {
    final e = k.esnafOku();
    return _secim(
      'Kaç kez sonra kara listeye alınsın?',
      'Gelmedi ve geç iptal toplanır. Sayıya ulaşan müşteri bu işletmeden yeni randevu alamaz.',
      [0, 2, 3, 4, 5].contains(e.karaListeEsik) ? e.karaListeEsik : 0,
      const [0, 2, 3, 4, 5],
      (v) => v == 0 ? 'Kapalı' : '$v kez',
      (v) => _esnaf(e.copyWith(karaListeEsik: v)),
      mavi: true,
    );
  }

  Widget _sadakat() {
    final e = k.esnafOku();
    final adetler = [2, 3, 4, 5, 6, 8, 10];
    final yuzdeler = [5, 10, 15, 20, 25, 50];
    final adet = adetler.contains(e.sadakatAdet) ? e.sadakatAdet : 5;
    final yuzde = yuzdeler.contains(e.sadakatYuzde) ? e.sadakatYuzde : 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _evetHayir(
          'Sadakat indirimi yapılsın mı?',
          e.sadakatAktif,
          (v) => _esnaf(e.copyWith(sadakatAktif: v)),
        ),
        if (e.sadakatAktif) ...[
          _secim('Kaçıncı randevu?', 'İndirim notunun düşeceği onaylı randevu sırası.', adet, adetler, (v) => '$v. randevu', (v) => _esnaf(e.copyWith(sadakatAdet: v))),
          _secim('Yüzde', 'Kasada düşecek indirim yüzdesi.', yuzde, yuzdeler, (v) => '%$v', (v) => _esnaf(e.copyWith(sadakatYuzde: v))),
        ],
      ],
    );
  }

  Widget _aralikliSlot() {
    final e = k.esnafOku();
    return _evetHayir(
      'Randevular aralıklı slot şeklinde görülsün mü?',
      e.slotAralikliGoster,
      (v) => _esnaf(e.copyWith(slotAralikliGoster: v)),
    );
  }

  Widget _ozetSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 2),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }

  String _hizmetOzeti(Map<String, dynamic> h) {
    final ad = (h['isim'] ?? h['ad'] ?? '').toString().trim();
    if (ad.isEmpty) return '';
    final sure = h['sure'] ?? '';
    final ucretHam = h['ucret'];
    final ucret = ucretHam is num ? ucretHam.toDouble() : double.tryParse('$ucretHam'.replaceAll(',', '.')) ?? 0;
    final goster = h['ucretGoster'] == true;
    final ucretYazi = ucret <= 0 ? '' : ' · ${ucret == ucret.roundToDouble() ? ucret.toInt() : ucret} TL${goster ? '' : ' (müşteri görmez)'}';
    return '$ad · $sure dk$ucretYazi';
  }

  String _randevuSekliOzeti(EsnafModeli e) {
    Map<String, dynamic>? onGorusme;
    for (final h in k.hizmetler) {
      final ad = (h['isim'] ?? h['ad'] ?? '').toString().toLowerCase();
      if (h['ilkGorusme'] == true || ad.contains('ön görüşme') || ad.contains('on gorusme') || ad.contains('ilk görüşme')) {
        onGorusme = h;
        break;
      }
    }
    final sure = onGorusme?['sure'] ?? (_onGorusmeSure.text.trim().isEmpty ? '30' : _onGorusmeSure.text.trim());
    final ucretHam = onGorusme?['ucret'];
    final ucret = ucretHam is num ? ucretHam.toDouble() : double.tryParse('${ucretHam ?? _onGorusmeUcret.text}'.replaceAll(',', '.')) ?? 0;
    final ucretYazi = ucret <= 0 ? 'ücret yok' : '${ucret == ucret.roundToDouble() ? ucret.toInt() : ucret} TL';
    if (e.sadeceOnGorusme || _randevuSekli == 2) {
      return 'Yalnızca ön görüşme · $sure dk · $ucretYazi. Müşteri başka hizmet seçemez.';
    }
    if (e.onGorusmeZorunlu || _randevuSekli == 3) {
      return 'Önce ön görüşme · $sure dk · $ucretYazi. Saati gelip onaylanınca diğer hizmetler açılır.';
    }
    return 'Yalnızca hizmetler. Ön görüşme yoktur.';
  }

  Widget _ozet() {
    final e = k.esnafOku();
    final gun = k.gunler.entries.where((g) => g.value).map((g) => g.key).join(', ');
    final hizmetler = k.hizmetler.map(_hizmetOzeti).where((s) => s.isNotEmpty).toList();
    final onceDk = HatirlatmaSablonlari.onceDakikaSecenekleri.contains(e.hatirlatmaOnceDk) ? e.hatirlatmaOnceDk : 60;
    final sonraDk = HatirlatmaSablonlari.sonraDakikaSecenekleri.contains(e.hatirlatmaSonraDk) ? e.hatirlatmaSonraDk : 30;
    final saat = [0, 1, 2, 3, 6, 12, 24].contains(e.iptalSinirSaati) ? e.iptalSinirSaati : 0;
    final esik = [0, 2, 3, 4, 5].contains(e.karaListeEsik) ? e.karaListeEsik : 0;
    final kanalYazi = k.kanallar.where((a) => a.trim().isNotEmpty).join(', ');
    final kisiler = k.personeller.map((p) {
      final ad = (p['isim'] ?? '').toString().trim();
      final kanal = (p['kanal'] ?? '').toString().trim();
      if (ad.isEmpty) return '';
      return kanal.isEmpty ? ad : '$ad ($kanal)';
    }).where((s) => s.isNotEmpty).toList();
    final tanitim = k.tanitimOku().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ozetSatiri('Randevu', e.randevuAlinmasin ? 'Hayır. Müşteri randevu alamaz.' : 'Evet. Müşteri randevu alabilir.'),
        _ozetSatiri(
          'Çalışma',
          k.is724Oku()
              ? '7/24. Nöbet ${k.nobetBasOku()}–${k.nobetBitOku()}.'
              : 'Açılış ${k.acilisOku()}, kapanış ${k.kapanisOku()}.',
        ),
        _ozetSatiri('Günler', gun.isEmpty ? 'Seçilmedi' : gun),
        _ozetSatiri('Kanallar', kanalYazi.isEmpty ? 'Yok' : kanalYazi),
        _ozetSatiri(
          'Çalışanlar',
          !k.personelOdakliOku()
              ? 'Hayır. Müşteri kişi seçmez.'
              : (kisiler.isEmpty ? 'Evet. Personel eklenmedi.' : 'Evet. ${kisiler.join(', ')}'),
        ),
        if (k.vitrin) _ozetSatiri('Tanıtım', tanitim.isEmpty ? 'Yazılmadı' : tanitim),
        _ozetSatiri('Hizmetler', hizmetler.isEmpty ? 'Yok' : hizmetler.join('\n')),
        _ozetSatiri(
          'Öncesi bildirim',
          e.hatirlatmaOnceAktif ? 'Evet. ${HatirlatmaSablonlari.dakikaEtiketi(onceDk)} önce.' : 'Hayır.',
        ),
        _ozetSatiri(
          'Sonrası bildirim',
          e.hatirlatmaSonraAktif ? 'Evet. ${HatirlatmaSablonlari.dakikaEtiketi(sonraDk)} sonra.' : 'Hayır.',
        ),
        _ozetSatiri('Red bildirimi', e.redBildirimAktif ? 'Evet.' : 'Hayır.'),
        _ozetSatiri('Kimler alabilsin', e.randevuSadeceYonetici ? 'Sadece Yönetici' : 'Müşteri ve Yönetici'),
        if (k.onGorusmeUygun) _ozetSatiri('Randevu şekli', _randevuSekliOzeti(e)),
        _ozetSatiri('Onay', e.randevuOnayModu == 'Otomatik' ? 'Otomatik onaylansın' : 'Ben onaylayacağım'),
        _ozetSatiri(
          'Süresi dolan',
          e.sureDolanOnaylanmasin ? 'Evet. 10 dakika dolunca onaylanamaz.' : 'Hayır. Süre dolsa da onaylanır.',
        ),
        _ozetSatiri(
          'Aynı gün',
          e.ayniGunRandevuEngelle ? 'Evet. Aynı güne 1 randevu.' : 'Hayır. Aynı güne birden fazla randevu serbest.',
        ),
        _ozetSatiri('Ajanda', e.ajandayiKendimAyarlayacagim ? 'Siz hazırlayacaksınız.' : 'Günler otomatik açılır.'),
        _ozetSatiri('İleri gün', '${e.maksimumRandevuGunu.clamp(1, 365)} gün'),
        _ozetSatiri('Geç iptal', saat == 0 ? 'Kapalı' : '$saat saat'),
        _ozetSatiri('Kara liste', esik == 0 ? 'Kapalı' : '$esik kez'),
        _ozetSatiri(
          'Sadakat',
          e.sadakatAktif ? 'Evet. Her ${e.sadakatAdet}. randevuda %${e.sadakatYuzde}.' : 'Hayır.',
        ),
        _ozetSatiri(
          'Aralıklı slot',
          e.slotAralikliGoster ? 'Evet. Saat aralığı görünür, örneğin 10:00-11:00.' : 'Hayır. Yalnızca başlangıç saati.',
        ),
        if (k.vitrin) _ozetSatiri('Vitrin', k.galeri().isEmpty ? 'Fotoğraf yok' : '${k.galeri().length} fotoğraf'),
      ],
    );
  }
}
