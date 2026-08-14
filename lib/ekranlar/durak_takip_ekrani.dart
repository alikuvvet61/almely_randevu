import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import 'surucu_dogrulama_ekrani.dart';
import 'surucu_profil_detay_ekrani.dart';

class DurakTakipEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const DurakTakipEkrani({super.key, required this.esnaf, this.soforTel});

  @override
  State<DurakTakipEkrani> createState() => _DurakTakipEkraniState();
}

class _DurakTakipEkraniState extends State<DurakTakipEkrani> {
  List<Map<String, dynamic>> araclar = [];
  Map<String, dynamic> gunlukAjanda = {};
  StreamSubscription? _aracSubscription;
  StreamSubscription? _ajandaSubscription;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
  }

  @override
  void dispose() {
    _aracSubscription?.cancel();
    _ajandaSubscription?.cancel();
    super.dispose();
  }

  void _verileriDinle() {
    // Araç listesini dinle
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
          _sirala();
        }
      }
    });

    // Bugünün ajanda defteri verisini dinle
    String ayKey = DateFormat('yyyy-MM').format(DateTime.now());
    String gunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _ajandaSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .collection('taksi_ajanda')
        .doc(ayKey)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        gunlukAjanda = Map<String, dynamic>.from(snapshot.data()?[gunKey] ?? {});
        _sirala();
      }
    });
  }

  bool _istirahatKontrol(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    // Manuel durum kontrolü
    if (arac['durum'] == 'İstirahatte') return true;
    // Çizelge (Ajanda Defteri) kontrolü
    if (gunlukAjanda.containsKey(plaka) && gunlukAjanda[plaka]?.toString().contains('I') == true) return true;
    
    // Haftalık şablon kontrolü
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
    bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
    if (!calisiyor) return true;

    return false;
  }

  void _sirala() {
    if (!mounted) return;
    setState(() {
      araclar.sort((a, b) {
        // 1. Öncelik: İstirahat durumu (İstirahatte olanlar EN ALTA)
        bool aIst = _istirahatKontrol(a);
        bool bIst = _istirahatKontrol(b);
        if (aIst != bIst) return aIst ? 1 : -1;

        // 2. Öncelik: Durakta olma durumu
        bool aDurakta = a['durakta'] == true;
        bool bDurakta = b['durakta'] == true;
        if (aDurakta != bDurakta) return aDurakta ? -1 : 1;

        // 3. Öncelik: Nöbet Sırası (Nöbetçiler en üstte olsun istenirse)
        int aNobetSira = a['nobetSirasi'] ?? 999999;
        int bNobetSira = b['nobetSirasi'] ?? 999999;
        if (aNobetSira != bNobetSira) return aNobetSira.compareTo(bNobetSira);

        // 4. Öncelik: Sıra zamanı (Duraktakiler için)
        if (aDurakta && bDurakta) {
          int aZaman = a['siraZamani'] ?? 0;
          int bZaman = b['siraZamani'] ?? 0;
          if (aZaman != bZaman) return aZaman.compareTo(bZaman);
        }

        // 5. Öncelik: Plaka
        return (a['plaka'] ?? "").compareTo(b['plaka'] ?? "");
      });
    });
  }

  String _getDurumEtiketi(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());

    // 1. Öncelik: Aylık Ajanda (Özel Gün Tanımı)
    if (gunlukAjanda.containsKey(plaka)) {
      String durum = gunlukAjanda[plaka].toString();
      if (durum.contains('I')) return "İSTİRAHAT";
      if (durum.contains('N')) return "NÖBETÇİ";
      return ""; // 'C' ise ekstra etiket gösterme
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  bool get _isSofor => widget.soforTel != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Canlı Durak Takip", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isSofor)
            IconButton(
              icon: const Icon(Icons.account_circle, size: 28, color: Colors.indigo),
              onPressed: () => _profilGoster(),
              tooltip: "Profilim",
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (araclar.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text("Henüz kayıtlı araç bulunmuyor.", style: TextStyle(color: Colors.grey))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    var arac = araclar[idx];
                    bool durakta = arac['durakta'] ?? false;
                    String durum = arac['durum'] ?? 'Müsait';
                    bool kendiAraci = _isSofor && arac['soforTel'] == widget.soforTel;
                    String ajandaEtiketi = _getDurumEtiketi(arac);
                    bool isNobetci = ajandaEtiketi == "NÖBETÇİ";

                    // Çizelge (Ajanda) kontrolü: Eğer çizelgede istirahat ise UI durumunu buna zorla
                    bool cizelgeIstirahat = ajandaEtiketi == "İSTİRAHAT";
                    if (cizelgeIstirahat) {
                      durum = 'İstirahatte';
                    }

                    Color durumRengi = Colors.green;
                    IconData durumIkonu = Icons.local_taxi;

                    if (durum == 'Meşgul') {
                      durumRengi = Colors.red;
                      durumIkonu = Icons.not_interested;
                    } else if (durum == 'Mola') {
                      durumRengi = Colors.orange;
                      durumIkonu = Icons.coffee_rounded;
                    } else if (durum == 'İstirahatte') {
                      // İstirahatte olan araçlar için kullanıcı isteği üzerine kırmızı rozet rengi
                      durumRengi = Colors.red; 
                      durumIkonu = Icons.hotel_rounded;
                    }

                    int siraNo = 0;
                    if (durakta) {
                      var duraktakiler = araclar.where((a) => a['durakta'] == true).toList();
                      siraNo = duraktakiler.indexOf(arac) + 1;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: isNobetci 
                              ? Colors.orange.withValues(alpha: 0.5) 
                              : Colors.grey.withValues(alpha: 0.1),
                          width: isNobetci ? 1.5 : 1,
                        ),
                      ),
                      color: kendiAraci ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    // İkon kutusu istirahatte ise gri, değilse durum rengi (veya sıra rengi)
                                    color: durakta ? Colors.blue.withValues(alpha: 0.1) : (durum == 'İstirahatte' ? Colors.grey : durumRengi).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: durakta
                                        ? Text(
                                            siraNo.toString(),
                                            style: TextStyle(color: Colors.blue.shade800, fontSize: 22, fontWeight: FontWeight.bold),
                                          )
                                        : Icon(durumIkonu, color: durum == 'İstirahatte' ? Colors.grey : durumRengi, size: 28),
                                  ),
                                ),
                                if (isNobetci)
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                      ),
                                      child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        arac['plaka'] ?? "Plaka Yok",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                      ),
                                      if (isNobetci)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.shield_rounded, color: Colors.orange, size: 18),
                                        ),
                                      if (kendiAraci)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text("SİZ", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    arac['soforAd'] ?? 'Şoför Belirtilmemiş',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _durumRozeti(durum, durumRengi),
                                      if (durakta) _durumRozeti(siraNo == 1 ? "SIRADAKİ" : "$siraNo. SIRA", Colors.blue),
                                      // Çizelge etiketi gösterimi (İstirahat durumu zaten rozette kırmızı gösterildiği için çakışma olmasın diye süzüyoruz)
                                      if (ajandaEtiketi.isNotEmpty && !(durum == 'İstirahatte' && ajandaEtiketi == 'İSTİRAHAT'))
                                        _durumRozeti(ajandaEtiketi, ajandaEtiketi == "NÖBETÇİ" ? Colors.orange.shade800 : Colors.red),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (widget.soforTel == null || kendiAraci)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (durakta || durum != 'İstirahatte')
                                    SizedBox(
                                      height: 44,
                                      width: 44,
                                      child: IconButton(
                                        onPressed: () => _sirayaGirCik(idx, durakta),
                                        icon: Icon(
                                          durakta ? Icons.logout_rounded : Icons.login_rounded,
                                          color: durakta ? Colors.orange : Colors.green,
                                          size: 32,
                                        ),
                                        tooltip: durakta ? "Sıradan Çık" : "Sıraya Gir",
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 44,
                                    width: 44,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 32),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (String action) async {
                                        if (action == 'DOGRULAMA') {
                                          Navigator.push(context, MaterialPageRoute(builder: (c) => SurucuDogrulamaEkrani(esnaf: widget.esnaf)));
                                          return;
                                        }
                                        setState(() {
                                          araclar[idx]['durum'] = action;
                                          if (action == 'İstirahatte') {
                                            araclar[idx]['durakta'] = false;
                                          }
                                        });
                                        _sirala(); // Anlık sıralama
                                        await _kaydet();
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'Müsait', child: Text("Müsait", style: TextStyle(fontSize: 16))),
                                        const PopupMenuItem(value: 'Meşgul', child: Text("Meşgul", style: TextStyle(fontSize: 16))),
                                        const PopupMenuItem(value: 'Mola', child: Text("Mola", style: TextStyle(fontSize: 16))),
                                        const PopupMenuItem(value: 'İstirahatte', child: Text("İstirahatte", style: TextStyle(fontSize: 16))),
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
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );

                  },
                  childCount: araclar.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _durumRozeti(String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: renk.withValues(alpha: 0.2)),
      ),
      child: Text(
        metin,
        style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }


  Future<void> _sirayaGirCik(int idx, bool durakta) async {
    if (!durakta) {
      String ajandaEtiketi = _getDurumEtiketi(araclar[idx]);
      if (araclar[idx]['durum'] == 'İstirahatte' || ajandaEtiketi == "İSTİRAHAT") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("İstirahatte olan araç sıraya giremez."), backgroundColor: Colors.red),
          );
        }
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

        // GPS hata payını düşerek net mesafeyi buluyoruz.
        double netMesafe = hamMesafe - pos.accuracy;
        if (netMesafe < 0) netMesafe = 0;

        double limit = widget.esnaf.konumDogrulamaMesafesi;

        if (netMesafe > limit) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Tamam", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konum doğrulanırken bir hata oluştu."), backgroundColor: Colors.orange),
          );
        }
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
    _sirala(); // Anlık sıralama
    await _kaydet();
  }

  void _profilGoster() {
    final kendiAracim = araclar.firstWhere((a) => a['soforTel'] == widget.soforTel, orElse: () => {});
    if (kendiAracim.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 50, color: Colors.indigo.shade700),
            ),
            const SizedBox(height: 15),
            Text(
              kendiAracim['soforAd'] ?? "İsimsiz Şoför",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              kendiAracim['plaka'] ?? "",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.soforTel ?? "",
                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_box_rounded, color: Colors.blue),
              ),
              title: const Text("Gelişmiş Sürücü Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Kimlik, Araç ve Finans Bilgileri"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => SurucuProfilDetayEkrani(esnaf: widget.esnaf, arac: kendiAracim)));
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit, color: Colors.blue),
              ),
              title: const Text("Temel Bilgileri Güncelle", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Ad, Soyad ve Telefon"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _aracDuzenle(kendiAracim);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.verified_user, color: Colors.indigo),
              ),
              title: const Text("Güvenlik Doğrulaması", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Ehliyet, Ruhsat ve Sigorta Belgeleri"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => SurucuDogrulamaEkrani(esnaf: widget.esnaf)));
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _aracDuzenle(Map<String, dynamic> arac) {
    final pController = TextEditingController(text: arac['plaka']);
    final sAdController = TextEditingController(text: arac['soforAd']);
    final sTelController = TextEditingController(text: arac['soforTel']);
    
    // Plaka eğer zaten doluysa pasif kalmalı, boşsa şoför kendi girebilmeli
    bool plakaPasif = (arac['plaka'] != null && arac['plaka'].toString().isNotEmpty);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Bilgilerimi Güncelle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pController, 
                  decoration: const InputDecoration(labelText: "Plaka"), 
                  textCapitalization: TextCapitalization.characters,
                  enabled: true, 
                ),
                TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Ad Soyad")),
                TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Telefon"), keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () async {
                String yeniPlaka = pController.text.trim().toUpperCase();
                String yeniAd = sAdController.text.trim();
                String yeniTel = sTelController.text.trim();

                setState(() {
                  arac['plaka'] = yeniPlaka;
                  arac['soforAd'] = yeniAd;
                  arac['soforTel'] = yeniTel;
                });

                // 1. Esnaf belgesini güncelle
                await _kaydet();

                // 2. Global kullanıcı profilini de mühürle (Manager'ın seçebilmesi için)
                await FirestoreServisi().kullaniciProfiliniGuncelle(yeniTel, {
                  'plaka': yeniPlaka,
                  'adSoyad': yeniAd,
                });

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }
}
