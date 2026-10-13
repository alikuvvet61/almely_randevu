import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../modeller/esnaf_modeli.dart';
import '../../servisler/bildirim_servisi.dart';
import '../../servisler/firestore_servisi.dart';
import 'taksi_surucu_dogrulama_ekrani.dart';
import 'taksi_mod_secim_ekrani.dart';
import '../../yardimcilar/telefon_girdisi.dart';
import '../../yardimcilar/plaka_girdisi.dart';
import '../../widgets/sallanan_profil_ikonu.dart';
import '../../widgets/ortak_profil_sayfasi.dart';
import '../../widgets/yonetici_ses_kutusu.dart';
import 'taksi_talep_dialogu.dart';
import 'taksi_yolculuk_karti.dart';

class TaksiDurakTakipEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const TaksiDurakTakipEkrani({super.key, required this.esnaf, this.soforTel});

  @override
  State<TaksiDurakTakipEkrani> createState() => _TaksiDurakTakipEkraniState();
}

class _TaksiDurakTakipEkraniState extends State<TaksiDurakTakipEkrani> {
  List<Map<String, dynamic>> araclar = [];
  Map<String, dynamic> gunlukAjanda = {};
  Set<String> _cizelgePlakalari = {};
  bool _ajandaGeldi = false;
  Map<String, Map<String, dynamic>> kullaniciProfilleri = {};
  StreamSubscription? _aracSubscription;
  StreamSubscription? _ajandaSubscription;
  StreamSubscription? _kullaniciSubscription;
  StreamSubscription? _profilSubscription;
  StreamSubscription? _talepAboneligi;
  StreamSubscription? _sahteAboneligi;
  final Set<String> _sahtePlakalar = {};
  late String? _aktifSoforTel;
  Map<String, dynamic>? _kendiKayit;
  bool _profilUyariGosterildi = false;
  bool _sahteKonum = false;

  @override
  void initState() {
    super.initState();
    _aktifSoforTel = widget.soforTel;
    if ((widget.soforTel ?? '').isNotEmpty) TaksiOturum.telefon = widget.soforTel!;
    _verileriDinle();
    _kendiProfiliDinle();
    _talepleriDinle();
    _sahtePlakalariDinle();
    _sahteKonumBak();
  }

  @override
  void dispose() {
    _aracSubscription?.cancel();
    _ajandaSubscription?.cancel();
    _kullaniciSubscription?.cancel();
    _profilSubscription?.cancel();
    _talepAboneligi?.cancel();
    _sahteAboneligi?.cancel();
    super.dispose();
  }

  Future<void> _sahteKonumBak() async {
    try {
      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 8));
      if (mounted && pos.isMocked) setState(() => _sahteKonum = true);
    } catch (_) {}
  }

  void _sahtePlakalariDinle() {
    _sahteAboneligi = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: widget.esnaf.id)
        .snapshots()
        .listen((snap) {
      final plakalar = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final durum = (data['durum'] ?? '').toString();
        if (durum != 'yolda' && durum != 'geldim' && durum != 'bindi') continue;
        if (data['sahteKonum'] != true) continue;
        final plaka = (data['plaka'] ?? '').toString().trim();
        if (plaka.isNotEmpty) plakalar.add(plaka);
      }
      if (!mounted) return;
      setState(() {
        _sahtePlakalar
          ..clear()
          ..addAll(plakalar);
      });
    });
  }

  void _talepleriDinle() {
    _talepAboneligi = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: widget.esnaf.id)
        .where('durum', isEqualTo: 'bekliyor')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added && change.type != DocumentChangeType.modified) continue;
        final data = change.doc.data();
        if (data == null || (data['durum'] ?? '').toString() != 'bekliyor') continue;
        final sofor = (data['soforTel'] ?? '').toString();
        final benim = FirestoreServisi().musteriTelefonAnahtari(sofor);
        final tel = FirestoreServisi().musteriTelefonAnahtari(_aktifSoforTel ?? '');
        if (benim.isNotEmpty && tel.isNotEmpty && benim != tel) continue;
        if (!mounted) return;
        taksiTalepPenceresiAc(context, doc: change.doc, esnaf: widget.esnaf, soforTel: _aktifSoforTel, isSofor: true);
      }
    });
  }

  void _verileriDinle() {
    _aracSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          List<Map<String, dynamic>> hamListe = List<Map<String, dynamic>>.from(data['araclar'] ?? []);
          araclar = hamListe;
          _kullanicilariDinle();
          _sirala();
        }
      }
    });

    String ayKey = DateFormat('yyyy-MM').format(DateTime.now());
    String gunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _ajandaSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .collection('taksi_ajanda')
        .doc(ayKey)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      try {
        _ajandayiIsle(snapshot.data(), gunKey);
      } catch (_) {
        _ajandaGeldi = true;
      }
      _sirala();
    }, onError: (_) {
      if (!mounted || _ajandaGeldi) return;
      setState(() => _ajandaGeldi = true);
    });
  }

  void _ajandayiIsle(Map<String, dynamic>? data, String gunKey) {
    final plakalar = <String>{};
    Map<String, dynamic> bugun = {};
    data?.forEach((tarih, gun) {
      if (gun is! Map) return;
      final gunMap = Map<String, dynamic>.from(gun);
      if (tarih == gunKey) bugun = gunMap;
      gunMap.forEach((plaka, durum) {
        final kod = durum?.toString() ?? '';
        if (!kod.contains('C') && !kod.contains('N') && !kod.contains('I')) return;
        final t = plaka.toString().trim();
        if (t.isEmpty) return;
        plakalar.add(t);
        plakalar.add(t.toUpperCase());
      });
    });
    gunlukAjanda = bugun;
    _cizelgePlakalari = plakalar;
    _ajandaGeldi = true;
  }

  bool _cizelgede(Map<String, dynamic> arac) {
    final plaka = (arac['plaka'] ?? '').toString().trim();
    if (plaka.isEmpty) return false;
    return _cizelgePlakalari.contains(plaka) || _cizelgePlakalari.contains(plaka.toUpperCase());
  }

  void _kullanicilariDinle() {
    _kullaniciSubscription?.cancel();
    final telefonlar = araclar
        .map((a) => a['soforTel']?.toString())
        .where((t) => t != null && t.isNotEmpty)
        .toSet()
        .toList();
    if (telefonlar.isEmpty) return;
    _kullaniciSubscription = FirebaseFirestore.instance
        .collection('kullanicilar')
        .where(FieldPath.documentId, whereIn: telefonlar.take(30).toList())
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var doc in snapshot.docs) {
            kullaniciProfilleri[doc.id] = Map<String, dynamic>.from(doc.data());
          }
        });
      }
    });
  }

  bool _istirahatKontrol(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    if (arac['durum'] == 'İstirahatte') return true;
    if (gunlukAjanda.containsKey(plaka) && gunlukAjanda[plaka]?.toString().contains('I') == true) return true;
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
    return !((arac['calismaGunleri'] ?? {})[gunAdi] ?? true);
  }

  void _sirala() {
    if (!mounted) return;
    setState(() {
      araclar.sort((a, b) {
        // 1. İstirahat (İstirahatte olanlar EN ALTA)
        bool aIst = _istirahatKontrol(a);
        bool bIst = _istirahatKontrol(b);
        if (aIst != bIst) return aIst ? 1 : -1;

        // 2. Durakta olma durumu
        bool aDurakta = a['durakta'] == true;
        bool bDurakta = b['durakta'] == true;
        if (aDurakta != bDurakta) return aDurakta ? -1 : 1;

        // 3. Nöbet Sırası
        int aNobetSira = a['nobetSirasi'] ?? 999999;
        int bNobetSira = b['nobetSirasi'] ?? 999999;
        if (aNobetSira != bNobetSira) return aNobetSira.compareTo(bNobetSira);

        // 4. Sıra zamanı (Duraktakiler için)
        if (aDurakta && bDurakta) {
          int aZaman = a['siraZamani'] ?? 0;
          int bZaman = b['siraZamani'] ?? 0;
          if (aZaman != bZaman) return aZaman.compareTo(bZaman);
        }

        // 5. Plaka
        return (a['plaka'] ?? "").compareTo(b['plaka'] ?? "");
      });
    });
  }

  String _getDurumEtiketi(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());

    // 1. Öncelik: Aylık Ajanda
    if (gunlukAjanda.containsKey(plaka)) {
      String durum = gunlukAjanda[plaka].toString();
      if (durum.contains('I')) return "İSTİRAHAT";
      if (durum.contains('N')) return "NÖBETÇİ";
      return "";
    }

    // 2. Öncelik: Haftalık Şablon
    bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
    if (!calisiyor) return "İSTİRAHAT";

    bool nobetci = ((arac['nobetBilgileri'] ?? {})[gunAdi] ?? {})['nobetci'] ?? false;
    if (nobetci) return "NÖBETÇİ";

    return "";
  }

  Future<void> _kaydet() async {
    try {
      await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
        'araclar': araclar,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  Future<void> _sirayaGirCik(int idx, bool durakta) async {
    if (!durakta) {
      String ajandaEtiketi = _getDurumEtiketi(araclar[idx]);
      if (araclar[idx]['durum'] == 'İstirahatte' || ajandaEtiketi == "İSTİRAHAT") {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İstirahatte olan araç sıraya giremez."), backgroundColor: Colors.red),
        );
        return;
      }
      try {
        var esDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
        GeoPoint guncelDurakKonumu = widget.esnaf.konum;

        if (esDoc.exists && esDoc.data()?['konum'] != null) {
          guncelDurakKonumu = esDoc.data()?['konum'];
        }

        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
        );
        double hamMesafe = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          guncelDurakKonumu.latitude,
          guncelDurakKonumu.longitude,
        );

        double netMesafe = hamMesafe - pos.accuracy;
        if (netMesafe < 0) netMesafe = 0;

        double limit = widget.esnaf.konumDogrulamaMesafesi;

        if (netMesafe > limit) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Icon(Icons.location_off, color: Colors.red, size: 40),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Durakta Değilsiniz",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Sıraya girmek için durağın ${limit.round()} metre yakınında olmalısınız.\n\n"
                    "Ölçülen: ${hamMesafe < 1000 ? "${hamMesafe.toStringAsFixed(1)} m" : "${(hamMesafe / 1000).toStringAsFixed(2)} km"}\n"
                    "Hata Payı: ±${pos.accuracy < 1000 ? "${pos.accuracy.toStringAsFixed(1)} m" : "${(pos.accuracy / 1000).toStringAsFixed(2)} km"}\n"
                    "Net Mesafe: ${netMesafe < 1000 ? "${netMesafe.toStringAsFixed(1)} m" : "${(netMesafe / 1000).toStringAsFixed(2)} km"}",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Tamam", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Konum doğrulanırken bir hata oluştu."), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() {
      araclar[idx]['durakta'] = !durakta;
      if (araclar[idx]['durakta']) {
        araclar[idx]['siraZamani'] = DateTime.now().millisecondsSinceEpoch;
        araclar[idx]['durum'] = 'Müsait';
      }
    });
    _sirala(); 
    await _kaydet();
  }

  bool _ayniTel(Object? a, Object? b) {
    final fs = FirestoreServisi();
    final x = fs.musteriTelefonAnahtari('${a ?? ''}');
    final y = fs.musteriTelefonAnahtari('${b ?? ''}');
    return x.isNotEmpty && x == y;
  }

  void _kendiProfiliDinle() {
    _profilSubscription?.cancel();
    final tel = _aktifSoforTel;
    if (tel == null || tel.trim().isEmpty) return;
    final ids = FirestoreServisi().telefonYazimlari(tel).where((id) => id.isNotEmpty).take(10).toList();
    if (ids.isEmpty) return;
    _profilSubscription = FirebaseFirestore.instance
        .collection('kullanicilar')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final birlesik = <String, dynamic>{};
      for (final doc in snapshot.docs) {
        final veri = Map<String, dynamic>.from(doc.data());
        for (final e in veri.entries) {
          final eski = birlesik[e.key];
          final eskiBos = eski == null || (eski is String && eski.trim().isEmpty);
          final yeniDolu = e.value is! String || e.value.toString().trim().isNotEmpty;
          if (eskiBos && yeniDolu) birlesik[e.key] = e.value;
        }
      }
      setState(() => _kendiKayit = birlesik);
      if (!_profilEksik || _profilUyariGosterildi) return;
      _profilUyariGosterildi = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil bilgilerinde eksik alan var.')),
      );
    });
  }

  bool get _profilEksik {
    if (_aktifSoforTel == null || _kendiKayit == null) return false;
    final ad = (_kendiKayit?['adSoyad'] ?? _kendiKayit?['ad'] ?? '').toString().trim();
    final adres = (_kendiKayit?['adres'] ?? '').toString().trim();
    final plaka = (_kendiKayit?['plaka'] ?? '').toString().trim();
    return ad.isEmpty || adres.isEmpty || plaka.isEmpty;
  }

  void _profilGoster() {
    final tel = _aktifSoforTel;
    if (tel == null || tel.isEmpty) return;
    ortakProfilAc(
      context: context,
      telefon: tel,
      isletmeDuzenle: (esnaf) => taksiIsletmeFormunuAc(context, esnaf),
      temelBilgileri: (_) {
        final kendi = araclar.cast<Map<String, dynamic>?>().firstWhere(
          (a) => _ayniTel(a?['soforTel'], _aktifSoforTel),
          orElse: () => null,
        );
        if (kendi == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu telefona bağlı araç bulunamadı.')));
          return;
        }
        _aracDuzenle(kendi);
      },
    );
  }

  void _aracDuzenle(Map<String, dynamic> arac) {
    final pController = TextEditingController(text: PlakaGirdisi.yaz('${arac['plaka'] ?? ''}').trimRight());
    final sAdController = TextEditingController(text: arac['soforAd']);
    final sTelController = TextEditingController(text: arac['soforTel']);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("Bilgilerimi Güncelle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pController, 
                  decoration: const InputDecoration(labelText: "Plaka", hintText: PlakaGirdisi.ornek), 
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: PlakaGirdisi.bicim,
                  enabled: true, 
                ),
                TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Ad Soyad")),
                TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Telefon", hintText: "05xx xxx xx xx"), keyboardType: TextInputType.phone, inputFormatters: TelefonGirdisi.bicim),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () async {
                final yeniPlaka = pController.text.trim().toUpperCase();
                final yeniAd = sAdController.text.trim();
                final yeniTel = sTelController.text.trim();
                final eskiPlaka = (arac['plaka'] ?? '').toString().trim().toUpperCase();
                final eskiTel = (arac['soforTel'] ?? '').toString().trim();

                if (yeniPlaka.isEmpty || yeniAd.isEmpty || !TelefonGirdisi.gecerli(yeniTel)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(yeniPlaka.isEmpty || yeniAd.isEmpty
                        ? "Plaka, ad ve telefon boş bırakılamaz."
                        : (TelefonGirdisi.hata(yeniTel) ?? "Geçerli bir telefon yazın."))),
                  );
                  return;
                }
                final temizTel = TelefonGirdisi.rakamlar(yeniTel);
                final plakaBaskasinda = araclar.any((a) => !identical(a, arac) && (a['plaka'] ?? '').toString().trim().toUpperCase() == yeniPlaka);
                final telBaskasinda = araclar.any((a) => !identical(a, arac) && _ayniTel(a['soforTel'], temizTel));
                if (plakaBaskasinda || telBaskasinda) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Bu plaka veya telefon durakta başka bir araçta kayıtlı.")),
                  );
                  return;
                }

                try {
                  await FirestoreServisi().soforKimliginiYay(
                    esnafId: widget.esnaf.id,
                    eskiTel: eskiTel,
                    yeniTel: temizTel,
                    eskiPlaka: eskiPlaka,
                    yeniPlaka: yeniPlaka,
                    yeniAd: yeniAd,
                  );
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text("Güncellenemedi: $e")),
                  );
                  return;
                }

                if (!mounted) return;
                setState(() {
                  arac['plaka'] = yeniPlaka;
                  arac['soforAd'] = yeniAd;
                  arac['soforTel'] = temizTel;
                  if (_ayniTel(_aktifSoforTel, eskiTel)) {
                    _aktifSoforTel = temizTel;
                  }
                });
                if (!_ayniTel(temizTel, eskiTel)) _kendiProfiliDinle();
                await _kaydet();
                if (temizTel != TelefonGirdisi.rakamlar(eskiTel)) {
                  await BildirimServisi.tokenKaydet(temizTel, role: 'esnaf');
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cizelgesizUst(List<Map<String, dynamic>> eksikler) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nöbet çizelgesi yok', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final a in eksikler)
              Text(
                _cizelgesizSatir(a),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 6),
            const Text('Çizelgeye yazınca bu listeye gelir.'),
          ],
        ),
      ),
    );
  }

  String _cizelgesizSatir(Map<String, dynamic> arac) {
    final ad = (arac['soforAd'] ?? '').toString().trim();
    final plaka = (arac['plaka'] ?? '').toString().trim();
    if (ad.isEmpty) return plaka.isEmpty ? 'İsimsiz' : plaka;
    if (plaka.isEmpty) return ad;
    return '$ad · $plaka';
  }

  Widget _durumRozeti(String text, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gorunen = <int>[
      for (var i = 0; i < araclar.length; i++)
        if (_cizelgede(araclar[i])) i,
    ];
    final cizelgesiz = araclar.where((a) => !_cizelgede(a)).toList();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Canlı Durak Takip", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
          tooltip: "Mod Değiştir",
          onPressed: () {
            YuzerMikrofon.hepsiniKapat();
            final girisTel = widget.soforTel ?? widget.esnaf.telefon;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (c) => TaksiModSecimEkrani(esnaf: widget.esnaf, girisTel: girisTel),
              ),
            );
          },
        ),
        actions: [
          if (widget.soforTel != null)
            SallananProfilIkonu(
              salla: _profilEksik,
              tooltip: 'Profilim',
              onPressed: _profilGoster,
            ),
          const SizedBox(width: 48), // global ? için yer
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (!_ajandaGeldi)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Nöbet çizelgesi yükleniyor'),
                ],
              ),
            )
          else ...[
            if (_sahteKonum)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    'Sahte konum açık. Sıra ve yolcu bu noktaya güvenmesin.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TaksiYolculukKarti(
                  esnafId: widget.esnaf.id,
                  soforTel: _aktifSoforTel,
                  plaka: (_kendiKayit?['plaka'] ?? '').toString(),
                  konumGonder: _aktifSoforTel != null,
                ),
              ),
            ),
            if (cizelgesiz.isNotEmpty)
              SliverToBoxAdapter(child: _cizelgesizUst(cizelgesiz)),
            if (gorunen.isEmpty && cizelgesiz.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    "Henüz kayıtlı araç bulunmuyor.",
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (gorunen.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, gosterim) {
                    final idx = gorunen[gosterim];
                    var arac = araclar[idx];
                    String plaka = arac['plaka'] ?? "";
                    bool durakta = arac['durakta'] ?? false;
                    String durum = arac['durum'] ?? 'Müsait';
                    String durumEtiketi = _getDurumEtiketi(arac);
                    bool isNobetci = durumEtiketi == "NÖBETÇİ";
                    bool kendiAraci = _ayniTel(arac['soforTel'], _aktifSoforTel);

                    if (durumEtiketi == "İSTİRAHAT") durum = 'İstirahatte';

                    Color durumRengi = Colors.green;
                    IconData durumIkonu = Icons.local_taxi;
                    if (durum == 'Meşgul') {
                      durumRengi = Colors.red;
                      durumIkonu = Icons.not_interested;
                    } else if (durum == 'Mola') {
                      durumRengi = Colors.orange;
                      durumIkonu = Icons.coffee_rounded;
                    } else if (durum == 'İstirahatte') {
                      durumRengi = Colors.redAccent;
                      durumIkonu = Icons.hotel_rounded;
                    }

                    int siraNo = 0;
                    if (durakta) {
                      var duraktakiler = araclar.where((a) => a['durakta'] == true && _cizelgede(a)).toList();
                      siraNo = duraktakiler.indexOf(arac) + 1;
                    }

                    final String tel = (arac['soforTel'] ?? "").toString();
                    final userData = kullaniciProfilleri[tel] ?? {};
                    String? fotoUrl = userData['fotoUrl'];
                    final belgeler = userData['belgeler'] ?? {};
                    if (belgeler['selfie']?['status'] == 'Onaylandı') fotoUrl = belgeler['selfie']['url'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      color: kendiAraci ? const Color(0xFFE3F2FD) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: isNobetci
                              ? Colors.orange.withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.1),
                          width: isNobetci ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 55, height: 55,
                                  decoration: BoxDecoration(
                                    color: durakta ? Colors.blue.withValues(alpha: 0.1) : (durum == 'İstirahatte' ? Colors.grey : durumRengi).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: durakta
                                        ? Text(
                                            siraNo.toString(),
                                            style: TextStyle(color: Colors.blue.shade800, fontSize: 22, fontWeight: FontWeight.bold),
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: fotoUrl != null
                                              ? Image.network(
                                                  fotoUrl,
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 150,
                                                  errorBuilder: (c, e, s) => Icon(durumIkonu, color: durum == 'İstirahatte' ? Colors.grey : durumRengi, size: 28),
                                                )
                                              : Icon(durumIkonu, color: durum == 'İstirahatte' ? Colors.grey : durumRengi, size: 28),
                                          ),
                                  ),
                                ),
                                if (isNobetci)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                      child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                      if (isNobetci) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.shield_rounded, color: Colors.orange, size: 18)),
                                      if (kendiAraci) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: const Text("SİZ", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  Text(arac['soforAd'] ?? 'Şoför', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8, runSpacing: 6,
                                    children: [
                                      _durumRozeti(durum, durumRengi),
                                      if (durakta) _durumRozeti(siraNo == 1 ? "SIRADAKİ" : "$siraNo. SIRA", Colors.blue),
                                      if ((_sahteKonum && kendiAraci) || _sahtePlakalar.contains(plaka))
                                        _durumRozeti('SAHTE KONUM', Colors.red),
                                      if (durumEtiketi.isNotEmpty && !(durum == 'İstirahatte' && durumEtiketi == 'İSTİRAHAT'))
                                         _durumRozeti(durumEtiketi, durumEtiketi == "NÖBETÇİ" ? Colors.orange.shade800 : Colors.red),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (durakta || durum != 'İstirahatte')
                                  IconButton(
                                    icon: Icon(durakta ? Icons.logout_rounded : Icons.login_rounded, color: durakta ? Colors.orange : Colors.green, size: 32), 
                                    onPressed: () => _sirayaGirCik(idx, durakta)
                                  ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) async {
                                    if (val == 'DOGRULAMA') {
                                      Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiSurucuDogrulamaEkrani(esnaf: widget.esnaf, soforTel: _aktifSoforTel)));
                                      return;
                                    }
                                    setState(() {
                                      arac['durum'] = val;
                                      if (val == 'İstirahatte') arac['durakta'] = false;
                                    });
                                    _sirala();
                                    await _kaydet();
                                  },
                                  itemBuilder: (c) => [
                                    const PopupMenuItem(value: 'Müsait', child: Text('Müsait')),
                                    const PopupMenuItem(value: 'Meşgul', child: Text('Meşgul')),
                                    const PopupMenuItem(value: 'Mola', child: Text('Mola')),
                                    const PopupMenuItem(value: 'İstirahatte', child: Text('İstirahatte')),
                                    if (kendiAraci) ...[
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'DOGRULAMA', 
                                        child: Row(
                                          children: [
                                            Icon(Icons.verified_user, color: Colors.indigo, size: 20),
                                            SizedBox(width: 8),
                                            Text("Güvenlik Doğrulaması", style: TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: gorunen.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
