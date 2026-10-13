import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/musteri_ceza_kaydi.dart';
import '../yardimcilar/hatirlatma_sablonlari.dart';
import '../yardimcilar/hizmet_paketi.dart';

/// Genel esnaf ayarları (Taksi ve Araç Kiralama hariç).
class EsnafParametreEkrani extends StatefulWidget {
  final String esnafId;
  const EsnafParametreEkrani({super.key, required this.esnafId});

  @override
  State<EsnafParametreEkrani> createState() => _EsnafParametreEkraniState();
}

class _EsnafParametreEkraniState extends State<EsnafParametreEkrani> {
  final _firestoreServisi = FirestoreServisi();
  bool _yukleniyor = true;
  EsnafModeli? _esnaf;

  late TextEditingController _onceBaslikCtrl;
  late TextEditingController _onceSablonCtrl;
  late TextEditingController _sonraBaslikCtrl;
  late TextEditingController _sonraSablonCtrl;
  late TextEditingController _onayBaslikCtrl;
  late TextEditingController _onaySablonCtrl;
  late TextEditingController _redBaslikCtrl;
  late TextEditingController _redSablonCtrl;

  @override
  void initState() {
    super.initState();
    _onceBaslikCtrl = TextEditingController();
    _onceSablonCtrl = TextEditingController();
    _sonraBaslikCtrl = TextEditingController();
    _sonraSablonCtrl = TextEditingController();
    _onayBaslikCtrl = TextEditingController();
    _onaySablonCtrl = TextEditingController();
    _redBaslikCtrl = TextEditingController();
    _redSablonCtrl = TextEditingController();
    _verileriGetir();
  }

  @override
  void dispose() {
    _onceBaslikCtrl.dispose();
    _onceSablonCtrl.dispose();
    _sonraBaslikCtrl.dispose();
    _sonraSablonCtrl.dispose();
    _onayBaslikCtrl.dispose();
    _onaySablonCtrl.dispose();
    _redBaslikCtrl.dispose();
    _redSablonCtrl.dispose();
    super.dispose();
  }

  void _sablonKontrolleriniDoldur(EsnafModeli e) {
    _onceBaslikCtrl.text = HatirlatmaSablonlari.onceBaslik(e);
    _onceSablonCtrl.text = HatirlatmaSablonlari.onceIcerik(e);
    _sonraBaslikCtrl.text = HatirlatmaSablonlari.sonraBaslik(e);
    _sonraSablonCtrl.text = HatirlatmaSablonlari.sonraIcerik(e);
    _onayBaslikCtrl.text = HatirlatmaSablonlari.onayBaslik(e);
    _onaySablonCtrl.text = HatirlatmaSablonlari.onayIcerik(e);
    _redBaslikCtrl.text = HatirlatmaSablonlari.redBaslik(e);
    _redSablonCtrl.text = HatirlatmaSablonlari.redIcerik(e);
  }

  Future<void> _verileriGetir() async {
    _firestoreServisi.esnafGetir(widget.esnafId).first.then((esnaf) {
      if (mounted) {
        _sablonKontrolleriniDoldur(esnaf);
        setState(() {
          _esnaf = esnaf;
          _yukleniyor = false;
        });
      }
    });
  }

  List<dynamic> _onGorusmeSatiriniEkle(List<dynamic>? mevcut) {
    final liste = (mevcut ?? []).map((e) => e is Map ? Map<String, dynamic>.from(e) : e).toList();
    final varMi = liste.any((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)));
    if (!varMi) {
      liste.insert(0, {
        "isim": "Ön Görüşme",
        "sure": 30,
        "ucret": 0,
        "ucretGoster": true,
        "ilkGorusme": true,
      });
    }
    return liste;
  }

  String _sadakatAciklama() {
    final adetler = [2, 3, 4, 5, 6, 8, 10];
    final yuzdeler = [5, 10, 15, 20, 25, 50];
    final adet = adetler.contains(_esnaf!.sadakatAdet) ? _esnaf!.sadakatAdet : 5;
    final yuzde = yuzdeler.contains(_esnaf!.sadakatYuzde) ? _esnaf!.sadakatYuzde : 10;
    final kural = 'her $adet. onaylı randevuda kasada %$yuzde indirim notu düşer. Paket hakkı değişmez.';
    if (!_esnaf!.sadakatAktif) return 'Kapalı. Açılınca $kural';
    return 'Her $adet. onaylı randevuda kasada %$yuzde indirim notu düşer. Paket hakkı değişmez.';
  }

  Future<void> _guncelle(Map<String, dynamic> veriler) async {
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnafId, veriler);
      _verileriGetir();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ayarlar güncellendi"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sablonlariKaydet() async {
    await _guncelle({
      'hatirlatmaOnceBaslik': _onceBaslikCtrl.text.trim(),
      'hatirlatmaOnceSablon': _onceSablonCtrl.text.trim(),
      'hatirlatmaSonraBaslik': _sonraBaslikCtrl.text.trim(),
      'hatirlatmaSonraSablon': _sonraSablonCtrl.text.trim(),
      'onayBaslik': _onayBaslikCtrl.text.trim(),
      'onaySablon': _onaySablonCtrl.text.trim(),
      'redBaslik': _redBaslikCtrl.text.trim(),
      'redSablon': _redSablonCtrl.text.trim(),
    });
  }

  void _varsayilanaDon() {
    setState(() {
      _onceBaslikCtrl.text = HatirlatmaSablonlari.varsayilanOnceBaslik;
      _onceSablonCtrl.text = HatirlatmaSablonlari.varsayilanOnceIcerik;
      _sonraBaslikCtrl.text = HatirlatmaSablonlari.varsayilanSonraBaslik;
      _sonraSablonCtrl.text = HatirlatmaSablonlari.varsayilanSonraIcerik;
      _onayBaslikCtrl.text = HatirlatmaSablonlari.varsayilanOnayBaslik;
      _onaySablonCtrl.text = HatirlatmaSablonlari.varsayilanOnayIcerik;
      _redBaslikCtrl.text = HatirlatmaSablonlari.varsayilanRedBaslik;
      _redSablonCtrl.text = HatirlatmaSablonlari.varsayilanRedIcerik;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor || _esnaf == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("İşletme Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hatirlatmaKarti(),
          _parametreKart(
            baslik: "Randevu Ayarları",
            altBaslik: "İşletmenizin randevu alma kurallarını ve onay akışını buradan yönetin.",
            icon: Icons.event_note_rounded,
            icerik: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Randevu Alımını Durdur", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Aktif edilirse müşteriler 'Hemen Randevu Al' butonunu göremez."),
                  value: _esnaf!.randevuAlinmasin,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(
                        randevuAlinmasin: v,
                        randevuSadeceYonetici: v ? false : _esnaf!.randevuSadeceYonetici,
                      );
                    });
                    await _guncelle({
                      'randevuAlinmasin': v,
                      if (v) 'randevuSadeceYonetici': false,
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Yönetici geçmişe randevu oluşturabilsin", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Kapalıyken ajandada geçmiş saatler pasiftir. Açıkken geçmiş saate randevu yazabilirsiniz."),
                  value: _esnaf!.yoneticiGecmiseRandevu,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(yoneticiGecmiseRandevu: v);
                    });
                    await _guncelle({'yoneticiGecmiseRandevu': v});
                  },
                ),
                if (!_esnaf!.randevuAlinmasin) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Randevuları Sadece Yönetici versin", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Randevu alımı açıkken görünür. İşaretliyse müşteri kendi randevusunu alamaz; randevuyu siz verirsiniz."),
                    value: _esnaf!.randevuSadeceYonetici,
                    onChanged: (v) async {
                      setState(() {
                        _esnaf = _esnaf!.copyWith(randevuSadeceYonetici: v);
                      });
                      await _guncelle({'randevuSadeceYonetici': v});
                    },
                  ),
                ],
                if (HizmetPaketi.uygunMu(_esnaf!.kategori)) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "Sadece ön görüşme randevusu alınsın",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _esnaf!.onGorusmeZorunlu ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      _esnaf!.onGorusmeZorunlu
                          ? "Alttaki kural açıkken bu seçenek pasiftir."
                          : "Hizmetler’deki aynı anahtardır. Buradan açınca Hizmetler’de ön görüşme satırı da açılır. Açıksa müşteri yalnızca ön görüşme alır. Alttaki seçenek pasif kalır.",
                    ),
                    value: _esnaf!.onGorusmeZorunlu ? false : _esnaf!.sadeceOnGorusme,
                    onChanged: _esnaf!.onGorusmeZorunlu
                        ? null
                        : (v) async {
                      final hizmetler = v ? _onGorusmeSatiriniEkle(_esnaf!.hizmetler) : _esnaf!.hizmetler;
                      setState(() {
                        _esnaf = _esnaf!.copyWith(
                          sadeceOnGorusme: v,
                          onGorusmeZorunlu: v ? false : _esnaf!.onGorusmeZorunlu,
                          hizmetler: hizmetler,
                        );
                      });
                      await _guncelle({
                        'sadeceOnGorusme': v,
                        if (v) 'onGorusmeZorunlu': false,
                        if (v) 'hizmetler': hizmetler,
                      });
                    },
                  ),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Ön görüşme olmadan diğer hizmet açılmasın",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _esnaf!.sadeceOnGorusme ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        _esnaf!.sadeceOnGorusme
                            ? "Sadece ön görüşme açıkken bu seçenek pasiftir."
                            : "Müşteri önce ön görüşme alır. O randevunun saati geçip kayıt onaylıysa diğer hizmet ve paketler açılır. İleri tarihli randevu yetmez. Hizmetlerde ön görüşme açık olmalıdır.",
                      ),
                      value: _esnaf!.sadeceOnGorusme ? false : _esnaf!.onGorusmeZorunlu,
                      onChanged: _esnaf!.sadeceOnGorusme
                          ? null
                          : (v) async {
                        final hizmetler = _esnaf!.hizmetler ?? [];
                        final varMi = hizmetler.any((e) => e is Map && HizmetPaketi.ilkGorusmeMi(Map<String, dynamic>.from(e)));
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _esnaf = _esnaf!.copyWith(
                            onGorusmeZorunlu: v,
                            sadeceOnGorusme: v ? false : _esnaf!.sadeceOnGorusme,
                          );
                        });
                        await _guncelle({
                          'onGorusmeZorunlu': v,
                          if (v) 'sadeceOnGorusme': false,
                        });
                        if (v && !varMi && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text("Hizmetlerde “Ön görüşme yapılsın mı?” açık değil. Hizmet yoksa bu kural işlemez.")),
                          );
                        }
                      },
                    ),
                ],
                if (!_esnaf!.randevuAlinmasin) ...[
                  const Divider(),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Randevu Onay Modu", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Yeni randevular otomatik mi onaylansın yoksa sizin onayınız mı beklensin?",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_esnaf!.randevuOnayModu),
                    initialValue: _esnaf!.randevuOnayModu.isEmpty ? 'Manuel' : _esnaf!.randevuOnayModu,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Manuel',
                        child: Text("Manuel (Ben onaylayacağım)", style: TextStyle(fontSize: 15)),
                      ),
                      DropdownMenuItem(
                        value: 'Otomatik',
                        child: Text("Otomatik (Anında onaylansın)", style: TextStyle(fontSize: 15)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _guncelle({'randevuOnayModu': v});
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Süresi dolan randevu onaylanmasın", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Açıksa 10 dakikalık onay süresi dolan bekleyen kayıt onaylanamaz. Reddetme durur. Kapalıysa yine de onay sorulur."),
                    value: _esnaf!.sureDolanOnaylanmasin,
                    onChanged: (v) async {
                      setState(() {
                        _esnaf = _esnaf!.copyWith(sureDolanOnaylanmasin: v);
                      });
                      await _guncelle({'sureDolanOnaylanmasin': v});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("İşletmeye Aynı Gün Randevu Sınırı", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Bir müşteri bu işletmede aynı gün yalnızca 1 randevu alabilsin."),
                    value: _esnaf!.ayniGunRandevuEngelle,
                    onChanged: (v) => _guncelle({'ayniGunRandevuEngelle': v}),
                  ),
                ],
              ],
            ),
          ),
          _parametreKart(
            baslik: "Ajanda ve Takvim Ayarları",
            altBaslik: "Ajandanın manuel mi dinamik mi çalışacağını ve randevu aralıklarını belirleyin.",
            icon: Icons.calendar_month_rounded,
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Ajandayı Kendim Ayarlayacağım", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    "İşaretli olursa ajanda defterini manuel hazırlamanız gerekir. İşaretsiz olursa tam otomatik canlı sistem aktif olur.",
                  ),
                  value: _esnaf!.ajandayiKendimAyarlayacagim,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(ajandayiKendimAyarlayacagim: v);
                    });
                    await _guncelle({'ajandayiKendimAyarlayacagim': v});
                  },
                ),
                const Divider(),
                const SizedBox(height: 6),
                const Text("Maksimum Randevu İleri Süresi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  _esnaf!.ajandayiKendimAyarlayacagim
                      ? "Müşteri ve tekrarlayan seriler bugünden itibaren en fazla kaç gün ileriye randevu oluşturabilir? (Manuel ajandada açık günler yine sizin açtığınız günlerdir; seri bu pencereyi aşamaz.)"
                      : "Müşteriler bugünden itibaren en fazla kaç gün ilerisi için randevu alabilir? Tekrarlayan seriler de bu pencereyi aşamaz.",
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _esnaf!.maksimumRandevuGunu.toDouble().clamp(1, 365),
                        min: 1,
                        max: 365,
                        divisions: 364,
                        label: "${_esnaf!.maksimumRandevuGunu} Gün",
                        onChanged: (v) {
                          setState(() {
                            _esnaf = _esnaf!.copyWith(maksimumRandevuGunu: v.toInt());
                          });
                        },
                        onChangeEnd: (v) => _guncelle({'maksimumRandevuGunu': v.toInt()}),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        "${_esnaf!.maksimumRandevuGunu} Gün",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 6),
                const Text("Geç iptal sınırı", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Text(
                  "Randevuya bu kadar saat kala yapılan müşteri iptali “geç iptal” notu olarak işlenir. 0 = kural kapalı, normal iptal.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _secenekSlider(
                  secenekler: const [0, 1, 2, 3, 6, 12, 24],
                  deger: _esnaf!.iptalSinirSaati,
                  etiket: (v) => v == 0 ? "Kapalı" : "$v saat",
                  renk: Colors.deepOrange,
                  onDegisti: (v) => setState(() => _esnaf = _esnaf!.copyWith(iptalSinirSaati: v)),
                  onKaydet: (v) => _guncelle({'iptalSinirSaati': v}),
                ),
                const SizedBox(height: 12),
                const Text("Kara liste eşiği", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Text(
                  "Geç iptal + gelmedi toplamı bu sayıya ulaşınca müşteri bu işletmeden yeni randevu alamaz. 0 = kapalı.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _secenekSlider(
                  secenekler: const [0, 2, 3, 4, 5],
                  deger: _esnaf!.karaListeEsik,
                  etiket: (v) => v == 0 ? "Kapalı" : "$v not",
                  renk: Colors.red,
                  onDegisti: (v) => setState(() => _esnaf = _esnaf!.copyWith(karaListeEsik: v)),
                  onKaydet: (v) => _guncelle({'karaListeEsik': v}),
                ),
                const SizedBox(height: 8),
                _karaListeListesi(),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Sadakat indirimi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: Text(_sadakatAciklama()),
                  value: _esnaf!.sadakatAktif,
                  onChanged: (v) async {
                    setState(() => _esnaf = _esnaf!.copyWith(sadakatAktif: v));
                    await _guncelle({'sadakatAktif': v});
                  },
                ),
                if (_esnaf!.sadakatAktif) ...[
                  const Text("Her kaçıncı randevu?", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  _secenekSlider(
                    secenekler: const [2, 3, 4, 5, 6, 8, 10],
                    deger: [2, 3, 4, 5, 6, 8, 10].contains(_esnaf!.sadakatAdet) ? _esnaf!.sadakatAdet : 5,
                    etiket: (v) => "$v. randevu",
                    renk: Colors.green,
                    onDegisti: (v) => setState(() => _esnaf = _esnaf!.copyWith(sadakatAdet: v)),
                    onKaydet: (v) => _guncelle({'sadakatAdet': v}),
                  ),
                  const Text("İndirim oranı", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  _secenekSlider(
                    secenekler: const [5, 10, 15, 20, 25, 50],
                    deger: [5, 10, 15, 20, 25, 50].contains(_esnaf!.sadakatYuzde) ? _esnaf!.sadakatYuzde : 10,
                    etiket: (v) => "%$v",
                    renk: Colors.green,
                    onDegisti: (v) => setState(() => _esnaf = _esnaf!.copyWith(sadakatYuzde: v)),
                    onKaydet: (v) => _guncelle({'sadakatYuzde': v}),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Aralıklı Slot Gösterimi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    "Randevu saatleri '10:00' yerine '10:00 - 11:00' şeklinde aralıklı gösterilir (Örn: Halı Sahalar için).",
                  ),
                  value: _esnaf!.slotAralikliGoster,
                  onChanged: (v) => _guncelle({'slotAralikliGoster': v}),
                ),
              ],
            ),
          ),
          _parametreKart(
            baslik: "Personel ve Seçim Ayarları",
            altBaslik: "Müşterinin personel seçimi yapma zorunluluğunu ve randevu atamasını yönetin.",
            icon: Icons.people_alt_rounded,
            icerik: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Personel Odaklı Sistem", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Müşteri doğrudan personeli seçer. Personel seçimi zorunlu hale gelir."),
                  value: _esnaf!.randevularPersonelAdinaAlinsin,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(
                        randevularPersonelAdinaAlinsin: v,
                        personelSecimiZorunlu: v,
                      );
                    });
                    await _guncelle({
                      'randevularPersonelAdinaAlinsin': v,
                      'personelSecimiZorunlu': v,
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hatirlatmaKarti() {
    final ornekTarih = DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 1)));
    return Column(
      children: [
        _parametreKart(
          baslik: "Randevu Hatırlatmaları",
          altBaslik:
              "Onaylı randevularda OneSignal push + WhatsApp metni. Yer tutucular: {musteri} {isletme} {tarih} {saat} {hizmet} {personel} {neden}",
          icon: Icons.notifications_active_rounded,
          icerik: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Hatırlatmaları Aç", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: const Text("Kapalıysa hiçbir otomatik hatırlatma planlanmaz."),
            value: _esnaf!.hatirlatmaAktif,
            onChanged: (v) async {
              setState(() => _esnaf = _esnaf!.copyWith(hatirlatmaAktif: v));
              await _guncelle({'hatirlatmaAktif': v});
            },
          ),
        ),
        if (_esnaf!.hatirlatmaAktif) ...[
          _parametreKart(
            baslik: "Randevu Öncesi",
            altBaslik: "Randevu saatinden önce müşteriye gidecek bildirim.",
            icon: Icons.alarm_rounded,
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Öncesi hatırlatmayı kullan", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  value: _esnaf!.hatirlatmaOnceAktif,
                  onChanged: (v) async {
                    setState(() => _esnaf = _esnaf!.copyWith(hatirlatmaOnceAktif: v));
                    await _guncelle({'hatirlatmaOnceAktif': v});
                  },
                ),
                if (_esnaf!.hatirlatmaOnceAktif) ...[
                  const Text("Ne kadar önce?", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    key: ValueKey('once_${_esnaf!.hatirlatmaOnceDk}'),
                    initialValue: HatirlatmaSablonlari.onceDakikaSecenekleri.contains(_esnaf!.hatirlatmaOnceDk)
                        ? _esnaf!.hatirlatmaOnceDk
                        : 60,
                    decoration: _dropdownDeco(),
                    items: HatirlatmaSablonlari.onceDakikaSecenekleri
                        .map((d) => DropdownMenuItem(value: d, child: Text(HatirlatmaSablonlari.dakikaEtiketi(d))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _esnaf = _esnaf!.copyWith(hatirlatmaOnceDk: v));
                        _guncelle({'hatirlatmaOnceDk': v});
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _onceBaslikCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Öncesi başlık (push)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _onceSablonCtrl,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Öncesi şablon (push + WhatsApp)",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _onizlemeKutusu(
                    'Öncesi önizleme',
                    HatirlatmaSablonlari.doldur(
                      _onceSablonCtrl.text.isEmpty
                          ? HatirlatmaSablonlari.varsayilanOnceIcerik
                          : _onceSablonCtrl.text,
                      musteri: 'Ayşe',
                      isletme: _esnaf!.isletmeAdi,
                      tarih: ornekTarih,
                      saat: '14:00',
                      hizmet: 'Saatlik Kiralama',
                      personel: '',
                    ),
                  ),
                ],
              ],
            ),
          ),
          _parametreKart(
            baslik: "Randevu Sonrası",
            altBaslik: "Randevu bitişinden sonra teşekkür / yorum daveti.",
            icon: Icons.mark_email_read_outlined,
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Sonrası hatırlatmayı kullan", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  value: _esnaf!.hatirlatmaSonraAktif,
                  onChanged: (v) async {
                    setState(() => _esnaf = _esnaf!.copyWith(hatirlatmaSonraAktif: v));
                    await _guncelle({'hatirlatmaSonraAktif': v});
                  },
                ),
                if (_esnaf!.hatirlatmaSonraAktif) ...[
                  const Text("Bitişten ne kadar sonra?", style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    key: ValueKey('sonra_${_esnaf!.hatirlatmaSonraDk}'),
                    initialValue: HatirlatmaSablonlari.sonraDakikaSecenekleri.contains(_esnaf!.hatirlatmaSonraDk)
                        ? _esnaf!.hatirlatmaSonraDk
                        : 30,
                    decoration: _dropdownDeco(),
                    items: HatirlatmaSablonlari.sonraDakikaSecenekleri
                        .map((d) => DropdownMenuItem(value: d, child: Text(HatirlatmaSablonlari.dakikaEtiketi(d))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _esnaf = _esnaf!.copyWith(hatirlatmaSonraDk: v));
                        _guncelle({'hatirlatmaSonraDk': v});
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sonraBaslikCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Sonrası başlık (push)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sonraSablonCtrl,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Sonrası şablon (push + WhatsApp)",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _onizlemeKutusu(
                    'Sonrası önizleme',
                    HatirlatmaSablonlari.doldur(
                      _sonraSablonCtrl.text.isEmpty
                          ? HatirlatmaSablonlari.varsayilanSonraIcerik
                          : _sonraSablonCtrl.text,
                      musteri: 'Ayşe',
                      isletme: _esnaf!.isletmeAdi,
                      tarih: ornekTarih,
                      saat: '14:00',
                      hizmet: 'Saatlik Kiralama',
                      personel: '',
                    ),
                  ),
                ],
              ],
            ),
          ),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _sablonlariKaydet,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text("Şablonları Kaydet", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () {
                              _varsayilanaDon();
                              setState(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Varsayılan", style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final metin = HatirlatmaSablonlari.doldur(
                                _onceSablonCtrl.text.isEmpty
                                    ? HatirlatmaSablonlari.varsayilanOnceIcerik
                                    : _onceSablonCtrl.text,
                                musteri: 'Ayşe',
                                isletme: _esnaf!.isletmeAdi,
                                tarih: ornekTarih,
                                saat: '14:00',
                                hizmet: 'Saatlik Kiralama',
                                personel: '',
                              );
                              await Clipboard.setData(ClipboardData(text: metin));
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text("Öncesi WhatsApp metni panoya kopyalandı")),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade800,
                              side: BorderSide(color: Colors.green.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Kopyala", style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        _durumSablonKarti(
          baslik: 'Onay mesajı',
          altBaslik: 'Randevu onaylanınca veya otomatik onayda müşteriye gider.',
          acik: _esnaf!.onayBildirimAktif,
          anahtar: 'Onay bildirimini gönder',
          onAc: (v) async {
            setState(() => _esnaf = _esnaf!.copyWith(onayBildirimAktif: v));
            await _guncelle({'onayBildirimAktif': v});
          },
          baslikCtrl: _onayBaslikCtrl,
          sablonCtrl: _onaySablonCtrl,
          varsayilan: HatirlatmaSablonlari.varsayilanOnayIcerik,
          ornekTarih: ornekTarih,
        ),
        _durumSablonKarti(
          baslik: 'Red mesajı',
          altBaslik: 'Siz reddedince müşteriye gider. Müşterinin kendi iptali bu metni göndermez.',
          acik: _esnaf!.redBildirimAktif,
          anahtar: 'Red bildirimini gönder',
          onAc: (v) async {
            setState(() => _esnaf = _esnaf!.copyWith(redBildirimAktif: v));
            await _guncelle({'redBildirimAktif': v});
          },
          baslikCtrl: _redBaslikCtrl,
          sablonCtrl: _redSablonCtrl,
          varsayilan: HatirlatmaSablonlari.varsayilanRedIcerik,
          ornekTarih: ornekTarih,
          neden: 'Müsait değil',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _sablonlariKaydet,
            child: const Text('Onay ve red metnini kaydet'),
          ),
        ),
      ],
    );
  }

  Widget _durumSablonKarti({
    required String baslik,
    required String altBaslik,
    required bool acik,
    required String anahtar,
    required Future<void> Function(bool) onAc,
    required TextEditingController baslikCtrl,
    required TextEditingController sablonCtrl,
    required String varsayilan,
    required String ornekTarih,
    String neden = '',
  }) {
    return _parametreKart(
      baslik: baslik,
      altBaslik: altBaslik,
      icon: Icons.notifications_outlined,
      icerik: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(anahtar, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            value: acik,
            onChanged: (v) => onAc(v),
          ),
          if (acik) ...[
            TextField(
              controller: baslikCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sablonCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Şablon',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            _onizlemeKutusu(
              'Önizleme',
              HatirlatmaSablonlari.doldur(
                sablonCtrl.text.isEmpty ? varsayilan : sablonCtrl.text,
                musteri: 'Ayşe',
                isletme: _esnaf!.isletmeAdi,
                tarih: ornekTarih,
                saat: '14:00',
                hizmet: 'Özel ders',
                neden: neden,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _onizlemeKutusu(String baslik, String metin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$baslik:\n$metin',
        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.4),
      ),
    );
  }

  InputDecoration _dropdownDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _secenekSlider({
    required List<int> secenekler,
    required int deger,
    required String Function(int) etiket,
    required Color renk,
    required ValueChanged<int> onDegisti,
    required ValueChanged<int> onKaydet,
  }) {
    int index = 0;
    var enYakin = secenekler.first;
    for (var i = 0; i < secenekler.length; i++) {
      if ((secenekler[i] - deger).abs() < (enYakin - deger).abs()) {
        enYakin = secenekler[i];
        index = i;
      }
    }
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (secenekler.length - 1).toDouble(),
            divisions: secenekler.length - 1,
            label: etiket(secenekler[index]),
            onChanged: (v) {
              final secilen = secenekler[v.round()];
              if (secilen != deger) onDegisti(secilen);
            },
            onChangeEnd: (v) => onKaydet(secenekler[v.round()]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(etiket(secenekler[index]), style: TextStyle(fontWeight: FontWeight.bold, color: renk)),
        ),
      ],
    );
  }

  Widget _karaListeListesi() {
    final esnafId = _esnaf?.id;
    if (esnafId == null) return const SizedBox.shrink();
    return StreamBuilder<List<MusteriCezaKaydi>>(
      stream: _firestoreServisi.musteriCezaKayitlari(esnafId),
      builder: (context, snapshot) {
        final hepsi = snapshot.data ?? [];
        final kara = hepsi.where((k) => k.karaListede).toList();
        if (kara.isEmpty) {
          return Text(
            hepsi.isEmpty ? "Henüz ceza notu yok." : "Kara listede müşteri yok. Notu olan ${hepsi.length} kayıt eşik altında.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Kara listedekiler (${kara.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...kara.map((k) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(k.ad.isEmpty ? k.telefon : "${k.ad} · ${k.telefon}", style: const TextStyle(fontSize: 13)),
                  subtitle: Text("Geç iptal ${k.gecIptal} · Gelmedi ${k.gelmedi}${k.sonNot != null ? ' · ${k.sonNot}' : ''}"),
                  trailing: TextButton(
                    onPressed: () => _firestoreServisi.musteriKaraListedenCikar(esnafId, k.telefon),
                    child: const Text("Çıkar"),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _parametreKart({
    required String baslik,
    required String altBaslik,
    required IconData icon,
    required Widget icerik,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    baslik,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(altBaslik, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 18),
            icerik,
          ],
        ),
      ),
    );
  }
}
