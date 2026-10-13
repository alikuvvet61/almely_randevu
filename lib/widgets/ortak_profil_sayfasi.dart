import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../ekranlar/ana_ekran.dart';
import '../ekranlar/calisan_basvuru_listesi_ekrani.dart';
import '../ekranlar/calisan_basvurusu_ekrani.dart';
import '../ekranlar/giris.dart';
import '../ekranlar/taksi/taksi_surucu_dogrulama_ekrani.dart';
import '../ekranlar/taksi/taksi_surucu_profil_detay_ekrani.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/bildirim_servisi.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/konum_servisi.dart';
import '../servisler/onesignal_servisi.dart';
import '../yardimcilar/plaka_girdisi.dart';
import '../yardimcilar/telefon_girdisi.dart';

/// Müşteri, sürücü ve yönetici profil simgesi aynı sayfayı açar.
/// Kişi, işletme ve araç kayıtları ayrı yazılır.
Future<void> ortakProfilAc({
  required BuildContext context,
  required String telefon,
  void Function(EsnafModeli esnaf)? isletmeDuzenle,
  void Function(Map<String, dynamic> arac)? temelBilgileri,
  void Function(Map<String, dynamic> userData, Map<String, dynamic>? basvuru)? isletmeBasvurusu,
  void Function(Map<String, dynamic> basvuru)? basvuruBekliyor,
  Future<bool> Function()? cikisOncesi,
  VoidCallback? profilKapandi,
}) async {
  final firestore = FirestoreServisi();
  final userData = await firestore.kullaniciKaydiBul(telefon) ?? <String, dynamic>{};
  final esnaf = await firestore.telefonIleEsnafGetir(telefon);
  final basvuru = esnaf == null ? await firestore.esnafBasvurusuGetir(telefon) : null;
  final calisanBasvuru = await firestore.calisanBasvurusuGetir(telefon);
  if (!context.mounted) return;

  final anahtar = firestore.musteriTelefonAnahtari(telefon);
  final sofor = esnaf != null &&
      anahtar.isNotEmpty &&
      esnaf.araclar.any((a) => firestore.musteriTelefonAnahtari('${a['soforTel'] ?? ''}') == anahtar);
  final sahip = esnaf != null && anahtar.isNotEmpty && firestore.musteriTelefonAnahtari(esnaf.telefon) == anahtar;
  final durakSahibi = sahip && esnaf.kategori == 'Taksi' && !sofor;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _baslik(userData, telefon, sofor),
            ..._kisiGrup(context, sheet, telefon, userData, sofor),
            ..._isletmeGrup(
              context,
              sheet,
              telefon,
              userData,
              esnaf,
              basvuru,
              calisanBasvuru,
              sahip,
              durakSahibi,
              isletmeDuzenle,
              isletmeBasvurusu,
              basvuruBekliyor,
            ),
            ..._surucuGrup(context, sheet, telefon, esnaf, sofor, temelBilgileri),
            ..._hesapGrup(context, sheet, telefon, esnaf != null, cikisOncesi),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
  profilKapandi?.call();
}

Widget _baslik(Map<String, dynamic> userData, String telefon, bool sofor) {
  final ad = (userData['adSoyad'] ?? userData['ad'] ?? 'İsimsiz Kullanıcı').toString();
  final foto = (userData['fotoUrl'] ?? '').toString().trim();
  final plaka = (userData['plaka'] ?? '').toString().trim();
  final adres = (userData['adres'] ?? '').toString().trim();
  return Column(
    children: [
      CircleAvatar(
        radius: 40,
        backgroundColor: Colors.indigo.shade50,
        backgroundImage: foto.isEmpty ? null : NetworkImage(foto),
        child: foto.isEmpty ? Icon(Icons.person, size: 50, color: Colors.indigo.shade700) : null,
      ),
      const SizedBox(height: 12),
      Text(ad, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      if (sofor && plaka.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(plaka, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ),
      if (adres.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
          child: Text(adres, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(telefon, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
      ),
    ],
  );
}

List<Widget> _grup(String baslik, List<Widget> satirlar) {
  if (satirlar.isEmpty) return const [];
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(baslik, style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey.shade700)),
      ),
    ),
    ...satirlar,
  ];
}

List<Widget> _kisiGrup(BuildContext sayfa, BuildContext sheet, String telefon, Map<String, dynamic> userData, bool sofor) {
  return _grup('Kişi', [
    _satir(
      ikon: Icons.edit,
      renk: Colors.blue,
      baslik: 'Profil Bilgilerim',
      alt: sofor ? 'Ad, adres, plaka ve fotoğraf' : 'Ad, adres ve fotoğraf',
      onTap: () {
        Navigator.pop(sheet);
        kisiProfiliniDuzenle(sayfa: sayfa, telefon: telefon, userData: userData, sofor: sofor);
      },
    ),
  ]);
}

List<Widget> _isletmeGrup(
  BuildContext sayfa,
  BuildContext sheet,
  String telefon,
  Map<String, dynamic> userData,
  EsnafModeli? esnaf,
  Map<String, dynamic>? basvuru,
  Map<String, dynamic>? calisanBasvuru,
  bool sahip,
  bool durakSahibi,
  void Function(EsnafModeli esnaf)? isletmeDuzenle,
  void Function(Map<String, dynamic> userData, Map<String, dynamic>? basvuru)? isletmeBasvurusu,
  void Function(Map<String, dynamic> basvuru)? basvuruBekliyor,
) {
  final satirlar = <Widget>[];
  if (esnaf != null && sahip) {
    satirlar.add(_satir(
      ikon: Icons.storefront_outlined,
      renk: Colors.indigo,
      baslik: 'İşletme bilgilerini düzenle',
      alt: esnaf.isletmeAdi,
      onTap: () {
        Navigator.pop(sheet);
        isletmeDuzenle?.call(esnaf);
      },
    ));
    satirlar.add(_satir(
      ikon: Icons.storefront_outlined,
      renk: Colors.red,
      baslik: 'İşletme bilgilerini sil',
      alt: 'İşletme kaydı kalkar. Randevular durur.',
      kirmizi: true,
      onTap: () {
        Navigator.pop(sheet);
        _isletmeSil(sayfa, esnaf, telefon);
      },
    ));
  } else if (esnaf == null) {
    if (basvuru != null) satirlar.add(_isletmeBasvuruKarti(basvuru));
    final durum = basvuru?['durum']?.toString();
    satirlar.add(_satir(
      ikon: Icons.storefront_outlined,
      renk: Colors.indigo,
      baslik: durum == 'Bekliyor' ? 'Başvurunuz inceleniyor' : 'İşletmemi ekle',
      alt: durum == 'Bekliyor'
          ? 'Başvurunuz yukarıda. Onay bekliyor.'
          : durum == 'Reddedildi'
              ? 'Reddedildi. Yeniden yazmak için dokunun.'
              : 'Vergi numarası ve levha olmadan başvuru olmaz.',
      onTap: () {
        Navigator.pop(sheet);
        if (durum == 'Bekliyor' && basvuru != null) {
          basvuruBekliyor?.call(basvuru);
        } else {
          isletmeBasvurusu?.call(userData, basvuru);
        }
      },
    ));
  }
  satirlar.addAll(_calismaSatirlari(sayfa, sheet, telefon, userData, esnaf, calisanBasvuru, durakSahibi));
  return _grup('İşletme', satirlar);
}

List<Widget> _surucuGrup(
  BuildContext sayfa,
  BuildContext sheet,
  String telefon,
  EsnafModeli? esnaf,
  bool sofor,
  void Function(Map<String, dynamic> arac)? temelBilgileri,
) {
  if (esnaf == null || !sofor) return const [];
  final firestore = FirestoreServisi();
  final anahtar = firestore.musteriTelefonAnahtari(telefon);
  Map<String, dynamic> arac = {};
  for (final a in esnaf.araclar) {
    if (firestore.musteriTelefonAnahtari('${a['soforTel'] ?? ''}') == anahtar) {
      arac = Map<String, dynamic>.from(a);
      break;
    }
  }
  return _grup('Sürücü', [
    _satir(
      ikon: Icons.account_box_rounded,
      renk: Colors.blue,
      baslik: 'Gelişmiş Sürücü Paneli',
      alt: 'Kimlik, Araç ve Finans Bilgileri',
      onTap: () {
        Navigator.pop(sheet);
        Navigator.push(sayfa, MaterialPageRoute(builder: (c) => TaksiSurucuProfilDetayEkrani(esnaf: esnaf, arac: arac)));
      },
    ),
    _satir(
      ikon: Icons.edit,
      renk: Colors.blue,
      baslik: 'Temel Bilgileri Güncelle',
      alt: 'Plaka, ad ve telefon. Çizelge ve fotoğraf da güncellenir.',
      onTap: () {
        Navigator.pop(sheet);
        if (temelBilgileri != null) {
          temelBilgileri(arac);
          return;
        }
        if (arac.isEmpty) {
          ScaffoldMessenger.of(sayfa).showSnackBar(const SnackBar(content: Text('Bu telefona bağlı araç bulunamadı.')));
          return;
        }
        _temelBilgileriAc(sayfa, esnaf, arac);
      },
    ),
    _satir(
      ikon: Icons.verified_user,
      renk: Colors.indigo,
      baslik: 'Güvenlik Doğrulaması',
      alt: 'Ehliyet, ruhsat, sigorta ve taksimetre',
      onTap: () {
        Navigator.pop(sheet);
        Navigator.push(
          sayfa,
          MaterialPageRoute(builder: (c) => TaksiSurucuDogrulamaEkrani(esnaf: esnaf, soforTel: telefon)),
        );
      },
    ),
  ]);
}

List<Widget> _calismaSatirlari(
  BuildContext sayfa,
  BuildContext sheet,
  String telefon,
  Map<String, dynamic> userData,
  EsnafModeli? esnaf,
  Map<String, dynamic>? basvuru,
  bool durakSahibi,
) {
  final durum = basvuru?['durum']?.toString();
  final ayrilma = durum == 'Kabul' || durum == 'İptal bekliyor';
  final basvuruSatiri = esnaf == null || durakSahibi || ayrilma;
  if (basvuru == null && !basvuruSatiri) return const [];
  final satirlar = <Widget>[];
  if (basvuru != null) satirlar.add(CalisanBasvuruDurumKarti(basvuru: basvuru));
  if (ayrilma) {
    satirlar.add(_satir(
      ikon: Icons.badge_outlined,
      renk: Colors.teal,
      baslik: durum == 'İptal bekliyor' ? 'İptal onay bekliyor' : 'İşletmeden çıkıyorum',
      alt: durum == 'İptal bekliyor' ? 'Dokununca talep geri alınır.' : 'İptal, başvuruyu kabul eden kişiye gider.',
      onTap: () {
        Navigator.pop(sheet);
        if (durum == 'İptal bekliyor') {
          _iptaliGeriAl(sayfa, telefon);
        } else {
          _isletmedenCik(sayfa, telefon);
        }
      },
    ));
  } else if (esnaf == null || durakSahibi) {
    satirlar.add(_satir(
      ikon: Icons.badge_outlined,
      renk: Colors.teal,
      baslik: _calisanBaslik(durum),
      alt: durakSahibi && basvuru == null
          ? 'Kendi durağınızda şoförseniz plakanızı yazın. Araç filonuza eklenir.'
          : _calisanAlt(basvuru),
      onTap: () {
        Navigator.pop(sheet);
        Navigator.push(
          sayfa,
          MaterialPageRoute(
            builder: (c) => CalisanBasvurusuEkrani(
              telefon: telefon,
              adSoyad: (userData['adSoyad'] ?? userData['ad'] ?? '').toString(),
            ),
          ),
        );
      },
    ));
  }
  return satirlar;
}

List<Widget> _hesapGrup(
  BuildContext sayfa,
  BuildContext sheet,
  String telefon,
  bool isletmeyeBagli,
  Future<bool> Function()? cikisOncesi,
) {
  return _grup('Hesap', [
    _satir(
      ikon: Icons.person_off_outlined,
      renk: Colors.red,
      baslik: 'Kaydımı sil',
      alt: 'Ad ve profil silinir. Randevular işletmede kalır.',
      kirmizi: true,
      onTap: () {
        Navigator.pop(sheet);
        _kaydiSil(sayfa, telefon, isletmeyeBagli);
      },
    ),
    _satir(
      ikon: Icons.logout,
      renk: Colors.red,
      baslik: 'Çıkış Yap',
      alt: 'Hesap kapanır. Bildirim durur.',
      kirmizi: true,
      onTap: () {
        Navigator.pop(sheet);
        () async {
          if (cikisOncesi != null && !await cikisOncesi()) return;
          if (!sayfa.mounted) return;
          await _cikisYap(sayfa);
        }();
      },
    ),
  ]);
}

Widget _satir({
  required IconData ikon,
  required MaterialColor renk,
  required String baslik,
  required String alt,
  required VoidCallback onTap,
  bool kirmizi = false,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blueGrey.shade200),
    ),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: renk.shade50, borderRadius: BorderRadius.circular(10)),
        child: Icon(ikon, color: renk),
      ),
      title: Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, color: kirmizi ? Colors.red : null)),
      subtitle: Text(alt),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

Widget _isletmeBasvuruKarti(Map<String, dynamic> basvuru) {
  final durum = (basvuru['durum'] ?? '').toString();
  final inceliyor = durum == 'Bekliyor';
  final reddedildi = durum == 'Reddedildi';
  final renk = inceliyor ? Colors.orange : (reddedildi ? Colors.red : Colors.green);
  final yazi = inceliyor ? 'İnceleniyor' : (reddedildi ? 'Reddedildi' : 'Onaylandı');
  final not = (basvuru['redNotu'] ?? '').toString().trim();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: renk.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: renk.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('İşletme başvurunuz', style: TextStyle(fontWeight: FontWeight.bold, color: renk.shade800)),
        const SizedBox(height: 6),
        Text((basvuru['isletmeAdi'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        Text('Durum: $yazi', style: TextStyle(color: renk.shade800, fontWeight: FontWeight.w600)),
        if (not.isNotEmpty) Text('Not: $not'),
      ],
    ),
  );
}

String _calisanBaslik(String? durum) {
  switch (durum) {
    case 'Bekliyor':
      return 'Başvurunuz inceleniyor';
    case 'Reddedildi':
      return 'Başvurunuz reddedildi';
    case 'İptal':
      return 'Başvurunuz iptal edildi';
    default:
      return 'İşletmede çalışıyorum';
  }
}

String _calisanAlt(Map<String, dynamic>? basvuru) {
  final durum = basvuru?['durum']?.toString();
  final ad = (basvuru?['isletmeAdi'] ?? '').toString();
  switch (durum) {
    case 'Bekliyor':
      return '$ad kabulünü bekliyor.';
    case 'Reddedildi':
    case 'İptal':
      return 'Yeniden başvurmak için dokunun.';
    default:
      return 'Kategori ve görev seçip işletmeye başvurun.';
  }
}

Future<void> kisiProfiliniDuzenle({
  required BuildContext sayfa,
  required String telefon,
  required Map<String, dynamic> userData,
  required bool sofor,
}) async {
  final pController = TextEditingController(text: PlakaGirdisi.yaz('${userData['plaka'] ?? ''}').trimRight());
  final sAdController = TextEditingController(text: (userData['adSoyad'] ?? userData['ad'] ?? '').toString());
  final adresController = TextEditingController(text: (userData['adres'] ?? '').toString());
  final telController = TextEditingController(text: telefon);
  final konumServisi = KonumServisi();
  dynamic secilenResimVerisi;

  await showDialog<void>(
    context: sayfa,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Profil Bilgilerim'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
                  if (image == null) return;
                  if (kIsWeb) {
                    final bytes = await image.readAsBytes();
                    setDialogState(() => secilenResimVerisi = bytes);
                  } else {
                    setDialogState(() => secilenResimVerisi = File(image.path));
                  }
                },
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage: secilenResimVerisi != null
                      ? (kIsWeb ? MemoryImage(secilenResimVerisi as Uint8List) : FileImage(secilenResimVerisi as File)) as ImageProvider
                      : ((userData['fotoUrl'] ?? '').toString().isNotEmpty ? NetworkImage(userData['fotoUrl'].toString()) : null),
                  child: secilenResimVerisi == null && (userData['fotoUrl'] ?? '').toString().isEmpty
                      ? const Icon(Icons.camera_alt, color: Colors.indigo)
                      : null,
                ),
              ),
              const SizedBox(height: 15),
              TextField(controller: sAdController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
              TextField(
                controller: telController,
                decoration: const InputDecoration(labelText: 'Telefon', hintText: '05xx xxx xx xx'),
                keyboardType: TextInputType.phone,
                inputFormatters: TelefonGirdisi.bicim,
              ),
              if (sofor)
                TextField(
                  controller: pController,
                  decoration: const InputDecoration(labelText: 'Plaka', hintText: PlakaGirdisi.ornek),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: PlakaGirdisi.bicim,
                ),
              TextField(
                controller: adresController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Adres',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: () async {
                      final konum = await konumServisi.konumuVeAdresiGetir();
                      if (konum != null && konum['tamAdres'] != null) {
                        setDialogState(() => adresController.text = konum['tamAdres']!);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              final telefonMesaji = TelefonGirdisi.hata(telController.text);
              if (telefonMesaji != null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(telefonMesaji)));
                return;
              }
              final guncelVeri = <String, dynamic>{
                'adSoyad': sAdController.text.trim(),
                'adres': adresController.text.trim(),
                if (sofor) 'plaka': pController.text.trim().toUpperCase(),
              };
              if (secilenResimVerisi != null) {
                final yol = 'profil_resimleri/${telefon}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final url = await FirestoreServisi().dosyaYukle(secilenResimVerisi, yol);
                if (url != null) guncelVeri['fotoUrl'] = url;
              }
              await FirestoreServisi().kullaniciProfiliniGuncelle(telefon, guncelVeri);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!sayfa.mounted) return;
              ScaffoldMessenger.of(sayfa).showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _temelBilgileriAc(BuildContext context, EsnafModeli esnaf, Map<String, dynamic> arac) async {
  final pController = TextEditingController(text: PlakaGirdisi.yaz('${arac['plaka'] ?? ''}').trimRight());
  final sAdController = TextEditingController(text: (arac['soforAd'] ?? '').toString());
  final sTelController = TextEditingController(text: (arac['soforTel'] ?? '').toString());
  final firestore = FirestoreServisi();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bilgilerimi Güncelle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pController,
              decoration: const InputDecoration(labelText: 'Plaka', hintText: PlakaGirdisi.ornek),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: PlakaGirdisi.bicim,
            ),
            TextField(controller: sAdController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            TextField(
              controller: sTelController,
              decoration: const InputDecoration(labelText: 'Telefon', hintText: '05xx xxx xx xx'),
              keyboardType: TextInputType.phone,
              inputFormatters: TelefonGirdisi.bicim,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () async {
            final yeniPlaka = pController.text.trim().toUpperCase();
            final yeniAd = sAdController.text.trim();
            final yeniTel = sTelController.text.trim();
            final eskiPlaka = (arac['plaka'] ?? '').toString().trim().toUpperCase();
            final eskiTel = (arac['soforTel'] ?? '').toString().trim();
            if (yeniPlaka.isEmpty || yeniAd.isEmpty || !TelefonGirdisi.gecerli(yeniTel)) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(TelefonGirdisi.hata(yeniTel) ?? 'Plaka, ad ve telefon boş bırakılamaz.')),
              );
              return;
            }
            final temizTel = TelefonGirdisi.rakamlar(yeniTel);
            final doc = await FirebaseFirestore.instance.collection('esnaflar').doc(esnaf.id).get();
            final liste = ((doc.data()?['araclar'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final benim = firestore.musteriTelefonAnahtari(eskiTel);
            final baskasi = liste.any((a) {
              final ayni = firestore.musteriTelefonAnahtari('${a['soforTel'] ?? ''}') == benim;
              if (ayni) return false;
              final plaka = (a['plaka'] ?? '').toString().trim().toUpperCase();
              return plaka == yeniPlaka || firestore.musteriTelefonAnahtari('${a['soforTel'] ?? ''}') == firestore.musteriTelefonAnahtari(temizTel);
            });
            if (baskasi) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Bu plaka veya telefon durakta başka bir araçta kayıtlı.')),
              );
              return;
            }
            var bulundu = false;
            for (final kayit in liste) {
              if (firestore.musteriTelefonAnahtari('${kayit['soforTel'] ?? ''}') != benim) continue;
              kayit['plaka'] = yeniPlaka;
              kayit['soforAd'] = yeniAd;
              kayit['soforTel'] = temizTel;
              bulundu = true;
              break;
            }
            if (!bulundu) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Araç kaydı bulunamadı.')));
              return;
            }
            try {
              await doc.reference.update({'araclar': liste});
              await firestore.soforKimliginiYay(
                esnafId: esnaf.id,
                eskiTel: eskiTel,
                yeniTel: temizTel,
                eskiPlaka: eskiPlaka,
                yeniPlaka: yeniPlaka,
                yeniAd: yeniAd,
              );
              if (temizTel != TelefonGirdisi.rakamlar(eskiTel)) {
                await BildirimServisi.tokenKaydet(temizTel, role: 'esnaf');
              }
            } catch (e) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Güncellenemedi: $e')));
              return;
            }
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
          },
          child: const Text('Güncelle'),
        ),
      ],
    ),
  );
}

Future<void> _isletmeSil(BuildContext context, EsnafModeli esnaf, String telefon) async {
  final unvan = esnaf.isletmeAdi.trim().isEmpty ? 'İşletme' : esnaf.isletmeAdi.trim();
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('İşletme bilgilerini sil'),
      content: Text('$unvan kaydı silinecektir. Onaylıyor musunuz?\n\nRandevu kayıtları durur.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  try {
    await FirestoreServisi().esnafSil(esnaf.id);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e'), backgroundColor: Colors.red));
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (c) => AnaEkran(kullaniciTel: telefon)),
    (route) => false,
  );
}

Future<void> _isletmedenCik(BuildContext context, String telefon) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('İşletmeden çıkıyorum'),
      content: const Text('İptal, başvuruyu kabul eden kişiye gider. O onaylayınca bu işletmede çalışmazsınız.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İptal iste')),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final hata = await FirestoreServisi().calisanIptalIste(telefon);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata ?? 'İptal talebi işletmeye gitti.')));
}

Future<void> _iptaliGeriAl(BuildContext context, String telefon) async {
  final hata = await FirestoreServisi().calisanIptalGeriAl(telefon);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata ?? 'İptal talebi geri alındı.')));
}

Future<void> _kaydiSil(BuildContext context, String telefon, bool isletmeyeBagli) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kaydı sil'),
      content: Text(
        isletmeyeBagli
            ? 'Kişi kaydınız silinir. İşletme kaydı durur. Aldığınız randevular işletmede kalır.'
            : 'Adınız ve profiliniz silinir. Aldığınız randevular işletmede kalır. Aynı numarayla tekrar girince adınız yeniden sorulur.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Kaydı sil'),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  try {
    await FirestoreServisi().kullaniciKaydiSil(telefon);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt silinemedi: $e')));
    return;
  }
  BildirimServisi.servisiDurdur();
  await OneSignalServisi.oturumuKapat();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (c) => const GirisSecimSayfasi()),
    (route) => false,
  );
}

Future<void> _cikisYap(BuildContext context) async {
  final devam = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çıkış Yap'),
      content: const Text('Oturumunuz kapatılacak ve bildirim alımı durdurulacaktır. Devam etmek istiyor musunuz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Evet, Çıkış Yap'),
        ),
      ],
    ),
  );
  if (devam != true || !context.mounted) return;
  BildirimServisi.servisiDurdur();
  await OneSignalServisi.oturumuKapat();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (c) => const GirisSecimSayfasi()),
    (route) => false,
  );
}
