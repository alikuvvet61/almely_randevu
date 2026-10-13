import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:almely_randevu/widgets/kaydedilmemis_uyari.dart';
import 'package:almely_randevu/yardimcilar/telefon_girdisi.dart';

/// İşletme penceresi açıldığındaki metin. Kapat, kaydetmeden çıkınca buna döner.
class IsletmeFormAnligi {
  IsletmeFormAnligi.cek({
    required List<TextEditingController> kontroller,
    required IsletmeBasvuruBilgisi bilgi,
  })  : _metin = {for (final c in kontroller) c: c.text},
        _tur = bilgi.tur,
        _vergiLevhaUrl = bilgi.vergiLevhaUrl,
        _olanaklar = bilgi.olanaklar.toList(),
        _yeniLevha = bilgi.yeniLevha,
        _logoUrl = bilgi.logoUrl,
        _yeniLogo = bilgi.yeniLogo;

  final Map<TextEditingController, String> _metin;
  final String _tur;
  final String _vergiLevhaUrl;
  final List<String> _olanaklar;
  final dynamic _yeniLevha;
  final String _logoUrl;
  final dynamic _yeniLogo;

  bool farkVar(IsletmeBasvuruBilgisi bilgi) {
    if (bilgi.tur != _tur || bilgi.vergiLevhaUrl != _vergiLevhaUrl || bilgi.yeniLevha != _yeniLevha) return true;
    if (bilgi.logoUrl != _logoUrl || bilgi.yeniLogo != _yeniLogo) return true;
    if (bilgi.olanaklar.length != _olanaklar.length || !bilgi.olanaklar.containsAll(_olanaklar)) return true;
    for (final e in _metin.entries) {
      if (e.key.text != e.value) return true;
    }
    return false;
  }

  void geriYukle(IsletmeBasvuruBilgisi bilgi) {
    for (final e in _metin.entries) {
      e.key.text = e.value;
    }
    bilgi.tur = _tur;
    bilgi.vergiLevhaUrl = _vergiLevhaUrl;
    bilgi.yeniLevha = _yeniLevha;
    bilgi.logoUrl = _logoUrl;
    bilgi.yeniLogo = _yeniLogo;
    bilgi.olanaklar
      ..clear()
      ..addAll(_olanaklar);
  }
}

/// Değişiklik yoksa true. Varsa sorar. Kaydetmeden çık eski metne döner ve yazar. Kaydet, onayla true ise kapanır.
Future<bool> isletmeFormKapanisi({
  required BuildContext context,
  required IsletmeFormAnligi anlik,
  required IsletmeBasvuruBilgisi bilgi,
  required bool acilisKirli,
  required void Function(bool kirli) kirliYaz,
  required bool Function() onayla,
}) {
  if (!anlik.farkVar(bilgi)) return Future.value(true);
  return kaydedilmemisDevam(
    context,
    true,
    kaydet: () async {},
    kayitTamam: onayla,
    kaydetmedenCik: () async {
      kirliYaz(true);
      anlik.geriYukle(bilgi);
      kirliYaz(acilisKirli);
    },
  );
}

/// Kayıtta tür Şahıs veya Şirket durur. Ekranda kooperatif de şirket tarafındadır.
String isletmeTuruYazisi(String tur) {
  if (tur == 'Şahıs') return 'Şahıs işletmesi';
  if (tur == 'Şirket') return 'Şirket veya kooperatif';
  return tur;
}

/// İşletmemi ekle başvurusundan işletme kaydına yazılan alanlar.
class IsletmeBasvuruBilgisi {
  final email = TextEditingController();
  final yetkili = TextEditingController();
  final vergiNo = TextEditingController();
  final sabitTel = TextEditingController();
  final web = TextEditingController();
  final instagram = TextEditingController();
  final mersis = TextEditingController();
  final sicil = TextEditingController();
  final tanitim = TextEditingController();
  String tur = '';
  String vergiLevhaUrl = '';
  final olanaklar = <String>{};
  String kayitliTur = '';
  String kayitliVergiNo = '';
  String kayitliLevhaUrl = '';
  String bazTur = '';
  String bazVergiNo = '';
  String bazLevhaUrl = '';
  bool doldu = false;
  bool onayBekliyor = false;
  String redNotu = '';
  dynamic yeniLevha;
  String logoUrl = '';
  dynamic yeniLogo;
  String? kayitMesaji;
  Map<String, dynamic>? bekleyenVergi;

  void doldur(Map<String, dynamic> data) {
    email.text = (data['email'] ?? '').toString();
    yetkili.text = (data['yetkiliAd'] ?? '').toString();
    vergiNo.text = (data['vergiNo'] ?? '').toString();
    sabitTel.text = (data['sabitTel'] ?? '').toString();
    web.text = (data['web'] ?? '').toString();
    instagram.text = (data['instagram'] ?? '').toString();
    mersis.text = (data['mersisNo'] ?? '').toString();
    sicil.text = (data['ticaretSicilNo'] ?? '').toString();
    tanitim.text = (data['tanitim'] ?? '').toString();
    kayitliTur = (data['isletmeTuru'] ?? '').toString();
    kayitliVergiNo = (data['vergiNo'] ?? '').toString();
    kayitliLevhaUrl = (data['vergiLevhaUrl'] ?? '').toString();
    doldu = true;
    logoUrl = (data['logoUrl'] ?? '').toString();
    yeniLogo = null;
    yeniLevha = null;
    bekleyenVergi = null;
    kayitMesaji = null;
    final guncelleme = data['vergiGuncelleme'];
    onayBekliyor = guncelleme is Map && guncelleme['durum']?.toString() == 'Bekliyor';
    redNotu = !onayBekliyor && guncelleme is Map && guncelleme['durum']?.toString() == 'Reddedildi'
        ? (guncelleme['redNotu'] ?? '').toString()
        : '';
    if (onayBekliyor) {
      tur = (guncelleme['isletmeTuru'] ?? kayitliTur).toString();
      vergiNo.text = (guncelleme['vergiNo'] ?? kayitliVergiNo).toString();
      vergiLevhaUrl = (guncelleme['vergiLevhaUrl'] ?? kayitliLevhaUrl).toString();
    } else {
      tur = kayitliTur;
      vergiNo.text = kayitliVergiNo;
      vergiLevhaUrl = kayitliLevhaUrl;
    }
    bazTur = tur;
    bazVergiNo = vergiNo.text.trim();
    bazLevhaUrl = vergiLevhaUrl;
    olanaklar
      ..clear()
      ..addAll(((data['olanaklar'] as List?) ?? const []).map((e) => e.toString()));
  }

  Map<String, dynamic> toMap({bool tanitimYaz = true}) {
    return {
      'email': email.text.trim(),
      'yetkiliAd': yetkili.text.trim(),
      if (doldu) 'vergiNo': kayitliVergiNo,
      if (doldu) 'vergiLevhaUrl': kayitliLevhaUrl,
      if (doldu) 'isletmeTuru': kayitliTur,
      'sabitTel': TelefonGirdisi.rakamlar(sabitTel.text),
      'web': web.text.trim(),
      'instagram': instagram.text.trim(),
      'mersisNo': tur == 'Şirket' ? mersis.text.trim() : '',
      'ticaretSicilNo': tur == 'Şirket' ? sicil.text.trim() : '',
      'logoUrl': logoUrl,
      'olanaklar': olanaklar.toList(),
      if (tanitimYaz) 'tanitim': tanitim.text.trim(),
    };
  }

  bool get yasalDegisti =>
      tur != bazTur || vergiNo.text.trim() != bazVergiNo || yeniLevha != null;

  String? yasalEngel() {
    if (!yasalDegisti) return null;
    if (tur != 'Şahıs' && tur != 'Şirket') return 'İşletme türünü seçin.';
    final hane = tur == 'Şirket' ? 10 : 11;
    if (vergiNo.text.trim().length != hane) {
      return tur == 'Şirket'
          ? 'Şirket için vergi kimlik numarası 10 hane olmalı.'
          : 'Şahıs için T.C. kimlik numarası 11 hane olmalı.';
    }
    final sirketEvragi = tur == 'Şirket' && (tur != bazTur || vergiNo.text.trim() != bazVergiNo);
    if (sirketEvragi && yeniLevha == null) {
      return 'Şirket için yeni vergi levhası yükleyin.';
    }
    return null;
  }

  /// null = kayıt sürdürülebilir. Dolu metin kaydı durdurur.
  Future<String?> yasalHazirla(
    Future<String?> Function(dynamic dosya, String yol) yukle,
    String esnafId,
  ) async {
    bekleyenVergi = null;
    kayitMesaji = null;
    if (yeniLogo != null) {
      final yol = 'esnaf_logo/$esnafId/logo.jpg';
      final yuklenen = await yukle(yeniLogo, yol);
      if (yuklenen == null || yuklenen.trim().isEmpty) return 'Logo yüklenemedi.';
      logoUrl = yuklenen.trim();
      yeniLogo = null;
    }
    final engel = yasalEngel();
    if (engel != null) return engel;
    if (!yasalDegisti) return null;
    var url = vergiLevhaUrl.trim().isNotEmpty ? vergiLevhaUrl : kayitliLevhaUrl;
    if (yeniLevha != null) {
      final yol = 'esnaf_vergi/$esnafId/levha_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final yuklenen = await yukle(yeniLevha, yol);
      if (yuklenen == null || yuklenen.trim().isEmpty) return 'Vergi levhası yüklenemedi.';
      url = yuklenen.trim();
    }
    bekleyenVergi = {
      'durum': 'Bekliyor',
      'isletmeTuru': tur,
      'vergiNo': vergiNo.text.trim(),
      'vergiLevhaUrl': url,
    };
    kayitMesaji = 'Vergi bilgisi yönetici onayına gönderildi. Onaylanana kadar kayıtlı levha geçerlidir.';
    return null;
  }

  Map<String, dynamic> vergiGuncellemeAlani(Object tarih) {
    if (bekleyenVergi == null) return {};
    return {
      'vergiGuncelleme': {
        ...bekleyenVergi!,
        'tarih': tarih,
      },
    };
  }

  void dispose() {
    email.dispose();
    yetkili.dispose();
    vergiNo.dispose();
    sabitTel.dispose();
    web.dispose();
    instagram.dispose();
    mersis.dispose();
    sicil.dispose();
    tanitim.dispose();
  }
}

List<String> isletmeFormEksikleri({
  required String ad,
  required String telefon,
  required String whatsapp,
  required String randevuHatti,
  required String il,
  required String ilce,
  required String adres,
  required String enlem,
  required String boylam,
  required IsletmeBasvuruBilgisi bilgi,
}) {
  final eksik = <String>[];
  if (ad.trim().isEmpty) eksik.add('İşletme adı');
  final tel = TelefonGirdisi.hata(telefon);
  if (tel != null) eksik.add(tel);
  final wa = TelefonGirdisi.hata(whatsapp, bosOlabilir: true);
  if (wa != null) eksik.add('WhatsApp: $wa');
  final randevu = TelefonGirdisi.hata(randevuHatti, bosOlabilir: true);
  if (randevu != null) eksik.add('Randevu hattı: $randevu');
  if (il.trim().isEmpty) eksik.add('İl');
  if (ilce.trim().isEmpty) eksik.add('İlçe');
  if (adres.trim().isEmpty) eksik.add('Açık adres');
  final lat = double.tryParse(enlem.trim().replaceAll(',', '.'));
  final lon = double.tryParse(boylam.trim().replaceAll(',', '.'));
  if (lat == null || lon == null || (lat == 0 && lon == 0)) eksik.add('Konum');
  if (bilgi.tur != 'Şahıs' && bilgi.tur != 'Şirket') {
    eksik.add('İşletme türü');
  } else {
    final hane = bilgi.tur == 'Şirket' ? 10 : 11;
    if (bilgi.vergiNo.text.trim().length != hane) {
      eksik.add(bilgi.tur == 'Şirket' ? 'Vergi Kimlik No (10 hane)' : 'T.C. Kimlik No (11 hane)');
    }
  }
  if (bilgi.vergiLevhaUrl.trim().isEmpty && bilgi.yeniLevha == null) eksik.add('Vergi levhası');
  final levha = bilgi.yasalEngel();
  if (levha != null && levha.contains('yükleyin')) eksik.add(levha);
  if (bilgi.yetkili.text.trim().isEmpty) eksik.add('Yetkili adı soyadı');
  final posta = bilgi.email.text.trim();
  if (!posta.contains('@') || !posta.split('@').last.contains('.')) eksik.add('E-posta');
  final sabit = TelefonGirdisi.hata(bilgi.sabitTel.text, bosOlabilir: true);
  if (sabit != null) eksik.add('Sabit telefon: $sabit');
  return eksik;
}

void isletmeEksikleriniGoster(BuildContext context, List<String> eksik) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eksik alanlar'),
      content: Text(eksik.map((e) => '• $e').join('\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
      ],
    ),
  );
}

class IsletmeBasvuruAlanlari extends StatefulWidget {
  final IsletmeBasvuruBilgisi bilgi;
  final String kategori;
  final String mesaiYazi;
  final TextEditingController? tanitim;
  final VoidCallback? degisti;

  const IsletmeBasvuruAlanlari({
    super.key,
    required this.bilgi,
    required this.kategori,
    required this.mesaiYazi,
    this.tanitim,
    this.degisti,
  });

  @override
  State<IsletmeBasvuruAlanlari> createState() => _IsletmeBasvuruAlanlariState();
}

class _IsletmeBasvuruAlanlariState extends State<IsletmeBasvuruAlanlari> {
  void _degisti() => widget.degisti?.call();

  @override
  Widget build(BuildContext context) {
    final bilgi = widget.bilgi;
    final tanitim = widget.tanitim ?? bilgi.tanitim;
    final vergiHane = bilgi.tur == 'Şirket' ? 10 : 11;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        const Text('Başvuru bilgileri', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (widget.kategori.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Kategori: ${widget.kategori}'),
          ),
        if (widget.mesaiYazi.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.mesaiYazi),
          ),
        if (bilgi.onayBekliyor)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Yeni vergi bilgisi yönetici onayında. Onaylanana kadar kayıtlı levha geçerlidir.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        if (bilgi.redNotu.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Vergi güncellemesi reddedildi: ${bilgi.redNotu}', style: const TextStyle(color: Colors.red)),
          ),
        const Text('İşletme türü', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Şahıs işletmesi'),
              selected: bilgi.tur == 'Şahıs',
              onSelected: (_) {
                setState(() => bilgi.tur = 'Şahıs');
                _degisti();
              },
            ),
            ChoiceChip(
              label: const Text('Şirket veya kooperatif'),
              selected: bilgi.tur == 'Şirket',
              onSelected: (_) {
                setState(() => bilgi.tur = 'Şirket');
                _degisti();
              },
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Levha sizin adınıza ise şahıs, bir şirket ya da kooperatif adına ise ikinciyi seçin.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        TextField(
          controller: bilgi.vergiNo,
          onChanged: (_) => _degisti(),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(vergiHane),
          ],
          decoration: InputDecoration(
            labelText: bilgi.tur == 'Şirket' ? 'Vergi Kimlik No (VKN)' : 'T.C. Kimlik No',
            hintText: bilgi.tur == 'Şirket' ? '10 hane' : '11 hane',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (bilgi.vergiLevhaUrl.trim().isEmpty && bilgi.yeniLevha == null)
              const Text('Vergi levhası yüklenmemiş', style: TextStyle(color: Colors.grey))
            else if (bilgi.vergiLevhaUrl.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () => _levhaAc(bilgi.vergiLevhaUrl),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Vergi levhasını gör'),
              ),
            if (bilgi.tur == 'Şirket')
              TextButton.icon(
                onPressed: _yeniLevhaSec,
                icon: Icon(bilgi.yeniLevha == null ? Icons.upload_file : Icons.check_circle, color: bilgi.yeniLevha == null ? null : Colors.green),
                label: Text(bilgi.yeniLevha == null ? 'Yeni vergi levhasını yükle' : 'Yeni levha seçildi'),
              ),
          ],
        ),
        TextField(controller: bilgi.yetkili, onChanged: (_) => _degisti(), decoration: const InputDecoration(labelText: 'Yetkili adı soyadı')),
        TextField(controller: bilgi.email, onChanged: (_) => _degisti(), keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
        TextField(
          controller: bilgi.sabitTel,
          onChanged: (_) => _degisti(),
          keyboardType: TextInputType.phone,
          inputFormatters: TelefonGirdisi.bicim,
          decoration: const InputDecoration(labelText: 'Sabit telefon', hintText: '0462...'),
        ),
        TextField(controller: bilgi.web, onChanged: (_) => _degisti(), decoration: const InputDecoration(labelText: 'Web sitesi')),
        TextField(controller: bilgi.instagram, onChanged: (_) => _degisti(), decoration: const InputDecoration(labelText: 'Instagram')),
        TextField(controller: tanitim, onChanged: (_) => _degisti(), maxLines: 2, maxLength: 300, decoration: const InputDecoration(labelText: 'Kısa tanıtım')),
        if (bilgi.tur == 'Şirket') ...[
          TextField(controller: bilgi.mersis, onChanged: (_) => _degisti(), decoration: const InputDecoration(labelText: 'MERSİS no')),
          TextField(controller: bilgi.sicil, onChanged: (_) => _degisti(), decoration: const InputDecoration(labelText: 'Ticaret sicil no')),
        ],
        const SizedBox(height: 8),
        OlanakSecici(
          secilenler: bilgi.olanaklar,
          degisti: (ad) {
            setState(() {
              if (bilgi.olanaklar.contains(ad)) {
                bilgi.olanaklar.remove(ad);
              } else {
                bilgi.olanaklar.add(ad);
              }
            });
            _degisti();
          },
        ),
      ],
    );
  }

  Future<void> _yeniLevhaSec() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
    if (image == null || !mounted) return;
    final dynamic veri = kIsWeb ? await image.readAsBytes() : File(image.path);
    if (!mounted) return;
    setState(() => widget.bilgi.yeniLevha = veri);
    _degisti();
  }

  void _levhaAc(String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        final yukseklik = (MediaQuery.sizeOf(ctx).height - 240).clamp(220.0, 560.0);
        return AlertDialog(
          title: const Text('Vergi levhası'),
          content: SizedBox(
            width: double.maxFinite,
            height: yukseklik,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
        );
      },
    );
  }
}

/// Dört olanak her zaman iki satırda durur. Seçilince genişleyip sonuncuyu kesmez.
class OlanakSecici extends StatelessWidget {
  final Set<String> secilenler;
  final ValueChanged<String> degisti;

  const OlanakSecici({super.key, required this.secilenler, required this.degisti});

  static const _adlar = ['Otopark', 'Wi-Fi', 'Klima', 'Çocuk alanı'];

  @override
  Widget build(BuildContext context) {
    Widget cip(String ad) {
      final secili = secilenler.contains(ad);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: secili ? Colors.blue.shade50 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: secili ? Colors.blue : Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => degisti(ad),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    if (secili) ...[
                      Icon(Icons.check, size: 16, color: Colors.blue.shade800),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        ad,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secili ? Colors.blue.shade800 : Colors.black87,
                          fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [cip(_adlar[0]), cip(_adlar[1])]),
        const SizedBox(height: 8),
        Row(children: [cip(_adlar[2]), cip(_adlar[3])]),
      ],
    );
  }
}
