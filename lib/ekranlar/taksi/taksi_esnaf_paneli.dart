import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:almely_randevu/ekranlar/giris_secim_ekrani.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/onesignal_servisi.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';

import 'package:almely_randevu/ekranlar/taksi/taksi_durak_takip_ekrani.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_cizelge_ekrani.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_rehber_ekrani.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_parametre_ekrani.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_esnaf_randevu_onay_ekrani.dart';

class TaksiEsnafPaneli extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;
  final bool openFilo;
  final bool openMesai;

  const TaksiEsnafPaneli({super.key, required this.esnaf, this.soforTel, this.openFilo = false, this.openMesai = false});

  @override
  State<TaksiEsnafPaneli> createState() => _TaksiEsnafPaneliState();
}

class _TaksiEsnafPaneliState extends State<TaksiEsnafPaneli> {
  late TextEditingController _adController;
  late TextEditingController _telController;
  late TextEditingController _whatsappController;
  late TextEditingController _randevuTelController;
  late TextEditingController _ilController;
  late TextEditingController _ilceController;
  late TextEditingController _adresController;
  late TextEditingController _latController;
  late TextEditingController _lonController;

  String acilisSaat = "Seçilmedi";
  String kapanisSaat = "Seçilmedi";
  late int slotAraligi;
  List<Map<String, dynamic>> hizmetler = [];
  List<String> kanallar = [];
  List<Map<String, dynamic>> araclar = [];
  bool _personelOdakli = false;
  bool _degisiklikVar = false;
  String _randevuOnayModu = 'Manuel';
  bool _ayniGunRandevuEngelle = false;
  bool _slotAralikliGoster = false;
  String _nobetBaslangic = "08:00";
  String _nobetBitis = "20:00";
  bool _is724 = false;

  final Map<String, bool> _calismaGunleri = {
    "Pazartesi": false,
    "Salı": false,
    "Çarşamba": false,
    "Perşembe": false,
    "Cuma": false,
    "Cumartesi": false,
    "Pazar": false,
  };

  String _gpsDurum = "Konumu Güncelle";
  final _konumServisi = KonumServisi();
  late EsnafModeli _guncelEsnaf;

  bool get _isSofor => widget.soforTel != null;

  StreamSubscription? _talepAboneligi;
  StreamSubscription? _esnafAboneligi;
  Timer? _konumTimer;

  @override
  void initState() {
    super.initState();
    // [YENİ] Esnaf için merkezi giriş kontrollerini başlat
    // Hem Mobil hem Web için ortak merkezi mantık çalışacak.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      BildirimServisi.girisKontrolleri(widget.soforTel ?? widget.esnaf.telefon, esnafMi: true, esnafId: widget.esnaf.id);
      }
    });

    // [YENİ] Web ve Mobil'de canlı bildirim dinleyiciyi mühürleyelim
    BildirimServisi.bildirimDinle(widget.soforTel ?? widget.esnaf.telefon);

    // TEŞHİS: Bildirim servisini bağla
    BildirimServisi.tokenKaydet(widget.esnaf.telefon, role: 'esnaf');

    if (_isSofor) {
      BildirimServisi.tokenKaydet(widget.soforTel!, role: 'esnaf');
      _otomatikKonumPaylasiminiBaslat();
    }

    _taksiTalepleriniDinle();
    _esnafVerileriniDinle();
    _guncelEsnaf = widget.esnaf;
    _adController = TextEditingController(text: widget.esnaf.isletmeAdi);
    _telController = TextEditingController(text: widget.esnaf.telefon);
    _whatsappController = TextEditingController(text: widget.esnaf.whatsapp ?? "");
    _randevuTelController = TextEditingController(text: widget.esnaf.telefonRandevu ?? "");
    _ilController = TextEditingController(text: widget.esnaf.il);
    _ilceController = TextEditingController(text: widget.esnaf.ilce);
    _adresController = TextEditingController(text: widget.esnaf.adres);
    _latController = TextEditingController(text: widget.esnaf.konum.latitude.toString());
    _lonController = TextEditingController(text: widget.esnaf.konum.longitude.toString());

    _adController.addListener(_onTextChanged);
    _telController.addListener(_onTextChanged);
    _whatsappController.addListener(_onTextChanged);
    _randevuTelController.addListener(_onTextChanged);
    _ilController.addListener(_onTextChanged);
    _ilceController.addListener(_onTextChanged);
    _adresController.addListener(_onTextChanged);

    hizmetler = List<Map<String, dynamic>>.from(widget.esnaf.hizmetler ?? []);
    kanallar = List<String>.from(widget.esnaf.kanallar ?? []);
    _personelOdakli = widget.esnaf.randevularPersonelAdinaAlinsin;
    _randevuOnayModu = widget.esnaf.randevuOnayModu.isEmpty ? 'Manuel' : widget.esnaf.randevuOnayModu;
    _ayniGunRandevuEngelle = widget.esnaf.ayniGunRandevuEngelle;
    _slotAralikliGoster = widget.esnaf.slotAralikliGoster;
    _nobetBaslangic = widget.esnaf.nobetBaslangic ?? "08:00";
    _nobetBitis = widget.esnaf.nobetBitis ?? "20:00";

    araclar = List<Map<String, dynamic>>.from(widget.esnaf.araclar);

    final cs = widget.esnaf.calismaSaatleri;
    if (cs != null) {
      slotAraligi = cs['slotDakika'] ?? cs['slotAraligi'] ?? 30;
      if (cs['acilis'] != null) acilisSaat = cs['acilis'];
      if (cs['kapanis'] != null) kapanisSaat = cs['kapanis'];
      _is724 = cs['is724'] ?? (acilisSaat == "00:00" && kapanisSaat == "00:00");
      
      // 7/24 modunda 00:00 kayıtlıysa gündüz mesai varsayılanlarını göster
      if (_is724 && acilisSaat == "00:00" && kapanisSaat == "00:00") {
        acilisSaat = "08:00";
        kapanisSaat = "20:00";
      }

      if (cs['gunler'] != null) {
        Map<String, dynamic> gelenGunler = cs['gunler'];
        gelenGunler.forEach((key, value) {
          if (_calismaGunleri.containsKey(key)) {
            _calismaGunleri[key] = value;
          }
        });
      }
    } else {
      slotAraligi = 30;
    }

    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() => _degisiklikVar = false);
      }
    });
  }

  void _onTextChanged() {
    if (!_degisiklikVar && mounted) {
      setState(() => _degisiklikVar = true);
    }
  }

  @override
  void dispose() {
    _talepAboneligi?.cancel();
    _esnafAboneligi?.cancel();
    _konumTimer?.cancel();
    _konumTimer = null;
    _adController.dispose();
    _telController.dispose();
    _whatsappController.dispose();
    _randevuTelController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _adresController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _gpsDurum = "Konumu Güncelle";
    debugPrint(_konumServisi.toString());
    super.dispose();
  }

  void _esnafVerileriniDinle() {
    _esnafAboneligi = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null && !_degisiklikVar) {
          // Sadece yerelde bir değişiklik (yazma/silme) yokken veritabanından güncelle
          setState(() {
            _guncelEsnaf = EsnafModeli.fromMap(data, snapshot.id);
            araclar = List<Map<String, dynamic>>.from(data['araclar'] ?? []);
            hizmetler = List<Map<String, dynamic>>.from(data['hizmetler'] ?? []);
            kanallar = List<String>.from(data['kanallar'] ?? []);
          });
        }
      }
    });
  }

  void _taksiTalepleriniDinle() {
    _talepAboneligi = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: widget.esnaf.id)
        .where('durum', isEqualTo: 'bekliyor')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;

          // Eğer bu araç bir şoföre atanmışsa ve talep başka bir şoföre gitmişse gösterme
          if (data['soforTel'] != null && _isSofor && data['soforTel'] != widget.soforTel) {
            continue;
          }

          // Uygulama ön plandaysa hem diyalog göster hem de sesli uyarıyı tetikle
          _talepBildirimiGoster(change.doc);
        }
      }
    });
  }

  void _otomatikKonumPaylasiminiBaslat() {
    _konumTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (!mounted || _konumTimer == null || !_konumTimer!.isActive) return;
      try {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted) {
          await _konumGuncelle(position.latitude, position.longitude);
        }
      } catch (e) {
        debugPrint("Konum alınamadı: $e");
      }
    });
  }

  Future<void> _konumGuncelle(double lat, double lon) async {
    if (widget.soforTel == null) return;

    List<Map<String, dynamic>> yeniAraclar = List.from(araclar);
    int index = yeniAraclar.indexWhere((a) => a['soforTel'] == widget.soforTel);

    if (index != -1) {
      yeniAraclar[index]['konum'] = GeoPoint(lat, lon);
      await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
        'araclar': yeniAraclar,
      });
    }
  }

  void _talepBildirimiGoster(DocumentSnapshot doc) {
    if (!mounted) return;
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_taxi, size: 50, color: Colors.orange),
              const SizedBox(height: 15),
              const Text(
                "Yeni Taksi Talebi",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    _talepSatiri(Icons.person, "Müşteri", data['musteriAd'] ?? 'Müşteri'),
                    const SizedBox(height: 12),
                    _talepSatiri(Icons.phone, "Müşteri Telefon", data['musteriTel'] ?? 'Bilinmiyor'),
                    const SizedBox(height: 12),
                    _talepSatiri(Icons.location_on, "Adres / Konum", data['adres'] ?? 'Konum Belirtilmemiş'),
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text("TAHMİNİ VARIŞ VE MESAFE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              "${data['tahminiSure'] ?? '--'} dk",
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigo),
                            ),
                            const Text("Süre", style: TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                        if (data['mesafe'] != null)
                          Column(
                            children: [
                              Builder(builder: (context) {
                                double m = (data['mesafe'] as num).toDouble();
                                return Text(
                                  m < 1000 ? "${m.toStringAsFixed(0)} m" : "${(m / 1000).toStringAsFixed(1)} km",
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.orange),
                                );
                              }),
                              const Text("Mesafe", style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                      ],
                    ),
                    if (data['plaka'] != null) ...[
                      const Divider(height: 25),
                      _talepSatiri(Icons.directions_car, "İstenen Araç", data['plaka']),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Talebi üstlenmek ister misiniz?",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Kapat", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final talepData = doc.data() as Map<String, dynamic>;
                        final plaka = talepData['plaka'];

                        // 1. Talebi güncelle
                        await doc.reference.update({
                          'durum': 'kabul_edildi',
                          'soforTel': widget.soforTel ?? 'Yönetici',
                          'kabulZamani': FieldValue.serverTimestamp(),
                        });

                        // Müşteriye bildirim gönder
                        if (talepData['musteriTel'] != null) {
                          BildirimServisi.bildirimGonder(
                            kullaniciTel: talepData['musteriTel'],
                            baslik: "Taksiniz Yolda!",
                            icerik: plaka != null ? "$plaka plakalı aracımız yola çıktı, size doğru geliyor." : "Aracımız yola çıktı, size doğru geliyor.",
                          );
                        }

                        // 2. Aracı sıradan çıkar ve meşgul yap
                        if (plaka != null) {
                          var esDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
                          if (esDoc.exists) {
                            List<dynamic> gAraclar = List.from(esDoc.data()?['araclar'] ?? []);
                            int i = gAraclar.indexWhere((a) => a['plaka'] == plaka);
                            if (i != -1) {
                              gAraclar[i]['durakta'] = false;
                              gAraclar[i]['siraZamani'] = 0;
                              gAraclar[i]['durum'] = "Meşgul";
                              await esDoc.reference.update({'araclar': gAraclar});
                            }
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(context); // Bildirim penceresini kapat
                          // Şoföre Navigasyon Sorusu
                          _navigasyonSor(talepData['musteriKonum'], talepData['adres']);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text("Kabul Et", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _navigasyonSor(dynamic konum, String? adres) {
    if (konum == null) return;

    double lat;
    double lon;

    if (konum is GeoPoint) {
      lat = konum.latitude;
      lon = konum.longitude;
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Colors.green),
            SizedBox(width: 10),
            Text("Navigasyon"),
          ],
        ),
        content: Text("Müşterinin konumuna navigasyon başlatılsın mı?\n\nAdres: ${adres ?? 'Belirtilmedi'}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hayır", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Başlat"),
          ),
        ],
      ),
    );
  }

  Widget _talepSatiri(IconData ikon, String baslik, String icerik) {
    return Row(
      children: [
        Icon(ikon, size: 20, color: Colors.indigo.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(icerik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _profesyonelAdresGetir() async {
    try {
      final konumBilgisi = await _konumServisi.konumuVeAdresiGetir();
      if (konumBilgisi != null && !konumBilgisi.containsKey('hata')) {
        setState(() {
          _latController.text = konumBilgisi['enlem'] ?? "";
          _lonController.text = konumBilgisi['boylam'] ?? "";
          _ilController.text = konumBilgisi['il'] ?? "";
          _ilceController.text = konumBilgisi['ilce'] ?? "";
          _adresController.text = konumBilgisi['tamAdres'] ?? "";
          _degisiklikVar = true;
          _gpsDurum = "Konum Güncellendi";
        });
        return;
      } else {
        throw Exception(konumBilgisi?['hata'] ?? "Bilinmeyen hata");
      }
    } catch (e) {
      setState(() => _gpsDurum = "Hata!");
      debugPrint("Adres getirme hatası: $e");
    }
  }


  void _esnafDuzenleFormu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İşletme Bilgilerini Düzenle"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı", prefixIcon: Icon(Icons.business))),
              TextField(controller: _telController, decoration: const InputDecoration(labelText: "İletişim Telefonu", hintText: "5xx xxx xx xx", prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
              TextField(controller: _whatsappController, decoration: InputDecoration(labelText: "WhatsApp (Opsiyonel)", hintText: "5xx xxx xx xx", prefixIcon: Icon(Icons.chat_bubble_outline, color: Colors.green)), keyboardType: TextInputType.phone),
              TextField(controller: _randevuTelController, decoration: const InputDecoration(labelText: "Randevu Hattı (Opsiyonel)", hintText: "5xx xxx xx xx", prefixIcon: Icon(Icons.phone_callback, color: Colors.orange)), keyboardType: TextInputType.phone),
              const Divider(height: 30),
              Row(
                children: [
                  Expanded(child: TextField(controller: _ilController, decoration: const InputDecoration(labelText: "İl"))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _ilceController, decoration: const InputDecoration(labelText: "İlçe"))),
                ],
              ),
              TextField(controller: _adresController, decoration: const InputDecoration(labelText: "Tam Adres"), maxLines: 2),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: _latController, decoration: const InputDecoration(labelText: "Enlem"), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _lonController, decoration: const InputDecoration(labelText: "Boylam"), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _profesyonelAdresGetir,
                icon: const Icon(Icons.my_location),
                label: Text(_gpsDurum),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat")),
          ElevatedButton(
            onPressed: () {
              setState(() => _degisiklikVar = true);
              Navigator.pop(context);
            },
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  Future<void> _verileriTazele() async {
    var doc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
    if (doc.exists && mounted) {
      var data = doc.data()!;
      setState(() {
        _guncelEsnaf = EsnafModeli.fromMap(data, doc.id);
        _whatsappController.text = _guncelEsnaf.whatsapp ?? "";
        _randevuTelController.text = _guncelEsnaf.telefonRandevu ?? "";
        araclar = List<Map<String, dynamic>>.from(data['araclar'] ?? []);
        hizmetler = List<Map<String, dynamic>>.from(data['hizmetler'] ?? []);
        kanallar = List<String>.from(data['kanallar'] ?? []);
        _randevuOnayModu = data['randevuOnayModu'] ?? 'Manuel';
        _ayniGunRandevuEngelle = data['ayniGunRandevuEngelle'] ?? false;
        _slotAralikliGoster = data['slotAralikliGoster'] ?? false;
        _nobetBaslangic = data['nobetBaslangic'] ?? "08:00";
        _nobetBitis = data['nobetBitis'] ?? "20:00";
        _personelOdakli = data['randevularPersonelAdinaAlinsin'] ?? false;

        var cs = data['calismaSaatleri'] as Map<String, dynamic>?;
        if (cs != null) {
          acilisSaat = cs['acilis'] ?? "Seçilmedi";
          kapanisSaat = cs['kapanis'] ?? "Seçilmedi";
          slotAraligi = cs['slotDakika'] ?? cs['slotAraligi'] ?? 30;
          if (cs['gunler'] != null) {
            Map<String, dynamic> g = cs['gunler'];
            g.forEach((k, v) { if (_calismaGunleri.containsKey(k)) _calismaGunleri[k] = v; });
          }
        }
        _degisiklikVar = false;
      });
    }
  }

  Future<void> _kaydet({bool sessiz = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
        'isletmeAdi': _adController.text,
        'telefon': _telController.text,
        'whatsapp': _whatsappController.text,
        'telefonRandevu': _randevuTelController.text,
        'il': _ilController.text,
        'ilce': _ilceController.text,
        'adres': _adresController.text,
        'konum': GeoPoint(double.parse(_latController.text), double.parse(_lonController.text)),
        'randevularPersonelAdinaAlinsin': _personelOdakli,
        'randevuOnayModu': _randevuOnayModu,
        'ayniGunRandevuEngelle': _ayniGunRandevuEngelle,
        'slotAralikliGoster': _slotAralikliGoster,
        'nobetBaslangic': _nobetBaslangic,
        'nobetBitis': _nobetBitis,
        'calismaSaatleri': {
          'gunler': _calismaGunleri,
          'acilis': acilisSaat,
          'kapanis': kapanisSaat,
          'is724': _is724,
          'slotDakika': slotAraligi,
          'durakAracSayisi': widget.esnaf.calismaSaatleri?['durakAracSayisi'],
          'tahminiDakika': widget.esnaf.calismaSaatleri?['tahminiDakika'],
        },
        'hizmetler': hizmetler,
        'kanallar': kanallar,
        'personeller': araclar.map((a) => {"isim": a['plaka'], "kanal": a['soforAd'] ?? ""}).toList(),
        'araclar': araclar.map((a) {

          final yeniArac = Map<String, dynamic>.from(a);
          yeniArac.remove('sofor');
          return yeniArac;
        }).toList(),
      });

      if (!mounted) return;
      setState(() => _degisiklikVar = false);
      if (!sessiz) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("Tüm ayarlar başarıyla kaydedildi."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    }
  }


  Widget _yonetimButonlari() {
    if (_isSofor) {
      return _ozelButon(
        ikon: Icons.local_taxi,
        renk: Colors.green,
        metin: "Canlı Durak Takip",
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.push(
            MaterialPageRoute(builder: (c) => TaksiDurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel)),
          );
        },
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5, // Metinler büyüdüğü için oran biraz azaltıldı
      children: [
        if (!_guncelEsnaf.randevuAlinmasin)
          _yonetimKarti(
            icon: Icons.history,
            baslik: "Randevu Kayıtları",
            altBaslik: "Onaylananlar",
            renk: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiEsnafRandevuOnayEkrani(esnafId: widget.esnaf.id, esnaf: widget.esnaf))),
          ),
        _yonetimKarti(
          icon: Icons.table_chart,
          baslik: "Nöbet Çizelgesi",
          altBaslik: "Nöbet ve İstirahat",
          renk: Colors.orange,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiCizelgeEkrani(esnaf: _guncelEsnaf))),
        ),
        _yonetimKarti(
          icon: Icons.local_taxi,
          baslik: "Durak Takip",
          altBaslik: "Sıra ve Konum",
          renk: Colors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiDurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel))),
        ),
        _yonetimKarti(
          icon: Icons.settings_suggest,
          baslik: "Gelişmiş Ayarlar",
          altBaslik: "Sistem Parametreleri",
          renk: Colors.blueGrey,
          onTap: () async {
            final navigator = Navigator.of(context);
            await navigator.push(MaterialPageRoute(builder: (c) => TaksiParametreEkrani(esnafId: widget.esnaf.id)));
            _verileriTazele();
          },
        ),
        _yonetimKarti(
          icon: Icons.business,
          baslik: "İşletme Profili",
          altBaslik: "Bilgileri Güncelle",
          renk: Colors.deepPurple,
          onTap: _esnafDuzenleFormu,
        ),
      ],
    );
  }

  Widget _yonetimKarti({
    required IconData icon,
    required String baslik,
    required String altBaslik,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: renk.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: renk.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: renk, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      altBaslik,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ozelButon({required IconData ikon, required Color renk, required String metin, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: renk.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(ikon, color: renk, size: 36),
            const SizedBox(height: 12),
            Text(metin, textAlign: TextAlign.center, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }


  void _cikisYap(BuildContext context) async {
    final devamEt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Oturumunuz kapatılacak ve bildirim alımı durdurulacaktır. Devam etmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Evet, Çıkış Yap"),
          ),
        ],
      ),
    );

    if (devamEt == true) {
      // 1. Bildirim sistemlerini durdur
      BildirimServisi.servisiDurdur();
      await OneSignalServisi.oturumuKapat();
      
      if (!context.mounted) return;
      // 2. Ana ekrana dön
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (c) => const GirisSecimSayfasi()),
        (route) => false,
      );
    }
  }


  Widget _filoWidget() {
    return Column(
      children: [
        ...araclar.asMap().entries.map((entry) {
          int idx = entry.key;
          var arac = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_taxi, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${arac['soforAd'] ?? 'İsimsiz'} (${arac['soforTel'] ?? 'No Yok'})", style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                  onPressed: () => _aracDuzenle(idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  onPressed: () {
                    setState(() {
                      araclar.removeAt(idx);
                      _degisiklikVar = true;
                    });
                  },
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: _yeniAracEkle,
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Yeni Araç Ekle"),
          ),
        ),
      ],
    );
  }

  void _aracDuzenle(int index) {
    var arac = araclar[index];
    final pController = TextEditingController(text: arac['plaka']);
    final sAdController = TextEditingController(text: arac['soforAd']);
    final sTelController = TextEditingController(text: arac['soforTel']);
    final nSiraController = TextEditingController(text: (arac['nobetSirasi'] ?? "").toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Aracı Düzenle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirestoreServisi().tumKullanicilariGetir(),
                  builder: (context, snapshot) {
                    final kullanicilar = (snapshot.data ?? [])
                        .where((u) => u['plaka'] != null && 
                                     u['plaka'].toString().isNotEmpty && 
                                     (u['adSoyad'] ?? u['ad']) != null)
                        .toList();
                    
                    return DropdownButtonFormField<String>(
                      initialValue: kullanicilar.any((u) => u['tel'] == sTelController.text) ? sTelController.text : null,
                      decoration: const InputDecoration(labelText: "Kayıtlı Şoförlerden Seç"),
                      hint: const Text("Şoför Seçiniz"),
                      items: kullanicilar.map((u) => DropdownMenuItem(
                        value: u['tel'].toString(),
                        child: Text("${u['adSoyad'] ?? u['ad']} (${u['plaka']})"),
                      )).toList(),
                      onChanged: (v) {
                        final secili = kullanicilar.firstWhere((u) => u['tel'] == v);
                        setDialogState(() {
                          pController.text = (secili['plaka'] ?? "").toString();
                          sAdController.text = (secili['adSoyad'] ?? secili['ad'] ?? "").toString();
                          sTelController.text = v ?? "";
                        });
                      },
                    );
                  }
                ),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 5),
                TextField(
                  controller: pController, 
                  decoration: const InputDecoration(labelText: "Plaka"), 
                  textCapitalization: TextCapitalization.characters,
                  enabled: false,
                ),
                TextField(
                  controller: sAdController, 
                  decoration: const InputDecoration(labelText: "Şoför Adı"),
                  enabled: false,
                ),
                TextField(
                  controller: sTelController, 
                  decoration: const InputDecoration(labelText: "Şoför Telefon"), 
                  keyboardType: TextInputType.phone,
                  enabled: false,
                ),
                TextField(
                  controller: nSiraController, 
                  decoration: const InputDecoration(labelText: "Nöbet Sırası (№)"), 
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                nSiraController.dispose();
                Navigator.pop(context);
              },
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () async {
                String eskiPlaka = (arac['plaka'] ?? "").toString().trim().toUpperCase();
                String yeniPlaka = pController.text.trim().toUpperCase();
                int? yeniNobetSira = int.tryParse(nSiraController.text.trim());

                // [YENİ] Mükerrer Nöbet Sırası Kontrolü
                if (yeniNobetSira != null) {
                  bool siraZatenVar = araclar.asMap().entries.any((entry) => 
                      entry.key != index && entry.value['nobetSirasi'] == yeniNobetSira);
                  
                  if (siraZatenVar) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("№ $yeniNobetSira sırası zaten başka bir araca atanmış!"),
                        backgroundColor: Colors.red.shade700,
                      )
                    );
                    return;
                  }
                }

                if (eskiPlaka.isNotEmpty && yeniPlaka != eskiPlaka) {
                  bool? devamEt = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Plaka Değişikliği Onayı"),
                      content: Text(
                        "Bilgilendirme: Yapılan değişiklik sistem üzerinde '$eskiPlaka' geçen yerleri '$yeniPlaka' e çevirecektir. Devam etmek istiyor musunuz?"
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Devam Et"),
                        ),
                      ],
                    ),
                  );

                  if (devamEt != true) return;

                  await FirestoreServisi().globalPlakaGuncelle(
                    esnafId: widget.esnaf.id,
                    eskiPlaka: eskiPlaka,
                    yeniPlaka: yeniPlaka,
                  );
                }

                setState(() {
                  araclar[index]['plaka'] = yeniPlaka;
                  araclar[index]['soforAd'] = sAdController.text.trim();
                  araclar[index]['soforTel'] = sTelController.text.trim();
                  araclar[index]['nobetSirasi'] = yeniNobetSira;
                  _degisiklikVar = true;
                });
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                nSiraController.dispose();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }

  void _yeniAracEkle() {
    final pController = TextEditingController();
    final sAdController = TextEditingController();
    final sTelController = TextEditingController();
    final nSiraController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni Araç Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirestoreServisi().tumKullanicilariGetir(),
                  builder: (context, snapshot) {
                    final mevcutTelefonlar = araclar.map((a) => a['soforTel']?.toString()).toSet();

                    final kullanicilar = (snapshot.data ?? [])
                        .where((u) => u['plaka'] != null && 
                                     u['plaka'].toString().isNotEmpty && 
                                     (u['adSoyad'] ?? u['ad']) != null &&
                                     !mevcutTelefonlar.contains(u['tel'])) // Zaten ekli olanları filtrele
                        .toList();

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Kayıtlı Şoförlerden Seç"),
                      hint: const Text("Şoför Seçiniz"),
                      items: kullanicilar.map((u) => DropdownMenuItem(
                        value: u['tel'].toString(),
                        child: Text("${u['adSoyad'] ?? u['ad']} (${u['plaka']})"),
                      )).toList(),
                      onChanged: (v) {
                        final secili = kullanicilar.firstWhere((u) => u['tel'] == v);
                        setDialogState(() {
                          pController.text = (secili['plaka'] ?? "").toString();
                          sAdController.text = (secili['adSoyad'] ?? secili['ad'] ?? "").toString();
                          sTelController.text = v ?? "";
                        });
                      },
                    );
                  }
                ),
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 5),
                TextField(
                  controller: pController, 
                  decoration: const InputDecoration(labelText: "Plaka"), 
                  textCapitalization: TextCapitalization.characters,
                  enabled: false,
                ),
                TextField(
                  controller: sAdController, 
                  decoration: const InputDecoration(labelText: "Şoför Adı"),
                  enabled: false,
                ),
                TextField(
                  controller: sTelController, 
                  decoration: const InputDecoration(labelText: "Şoför Telefon"), 
                  keyboardType: TextInputType.phone,
                  enabled: false,
                ),
                TextField(
                  controller: nSiraController, 
                  decoration: const InputDecoration(labelText: "Nöbet Sırası (№)"), 
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                nSiraController.dispose();
                Navigator.pop(context);
              },
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () {
                int? yeniNobetSira = int.tryParse(nSiraController.text.trim());

                // [YENİ] Mükerrer Nöbet Sırası Kontrolü
                if (yeniNobetSira != null) {
                  bool siraZatenVar = araclar.any((a) => a['nobetSirasi'] == yeniNobetSira);
                  if (siraZatenVar) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("№ $yeniNobetSira sırası zaten başka bir araca atanmış!"),
                        backgroundColor: Colors.red.shade700,
                      )
                    );
                    return;
                  }
                }

                setState(() {
                  araclar.add({
                    'plaka': pController.text.trim().toUpperCase(),
                    'soforAd': sAdController.text.trim(),
                    'soforTel': sTelController.text.trim(),
                    'nobetSirasi': yeniNobetSira,
                    'durum': 'Aktif',
                    'durakta': false,
                  });
                  _degisiklikVar = true;
                });
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                nSiraController.dispose();
                Navigator.pop(context);
              },
              child: const Text("Ekle"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bolumKart({required String baslik, required Widget icerik, String? bilgiAciklama, bool initiallyExpanded = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          title: Row(
            children: [
              Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
              if (bilgiAciklama != null)
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(baslik),
                      content: Text(bilgiAciklama),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Anladım"))]
                    ),
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: icerik,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gunlerIcerik() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Haftanın Tamamı", style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    bool hepsiSecili = _calismaGunleri.values.every((v) => v);
                    _calismaGunleri.updateAll((key, value) => !hepsiSecili);
                    _degisiklikVar = true;
                  });
                },
                child: Text(_calismaGunleri.values.every((v) => v) ? "Tümünü Kaldır" : "Tümünü Seç"),
              ),
            ],
          ),
        ),
        const Divider(),
        ..._calismaGunleri.keys.map((gun) {
          return CheckboxListTile(
            title: Text(gun),
            value: _calismaGunleri[gun],
            onChanged: (val) {
              setState(() {
                _calismaGunleri[gun] = val!;
                _degisiklikVar = true;
              });
            },
          );
        }),
      ],
    );
  }


  Widget _altBaslikIkonlu(String metin, IconData ikon, Color renk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Icon(ikon, size: 20, color: renk),
          const SizedBox(width: 8),
          Text(
            metin,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: renk.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }

  Widget _saatSecici(String etiket, String deger, Function(String) onSec) {
    return InkWell(
      onTap: () async {
        TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
        if (deger != "Seçilmedi") {
          initial = TimeOfDay(hour: int.parse(deger.split(":")[0]), minute: int.parse(deger.split(":")[1]));
        }

        TimeOfDay? t = await showTimePicker(
          context: context,
          initialTime: initial,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!)
        );
        if (t != null) onSec("${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
      },
      child: Column(
        children: [
          Text(etiket, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(deger, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: deger == "Seçilmedi" ? Colors.red : Colors.blue)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isSofor) {
      return TaksiDurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_adController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.blueGrey),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const TaksiRehberEkrani(mod: 'yonetici')));
            },
            tooltip: "Kullanım Rehberi",
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _cikisYap(context),
            tooltip: "Çıkış Yap",
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _verileriTazele),
        ],
      ),
        body: StreamBuilder<List<RandevuModeli>>(
          stream: FirebaseFirestore.instance
              .collection('randevular')
              .where('esnafId', isEqualTo: widget.esnaf.id)
              .snapshots()
              .map((snapshot) => snapshot.docs.map((doc) => RandevuModeli.fromMap(doc.data(), doc.id)).toList()),
          builder: (context, snapshot) {
            final hepsi = snapshot.data ?? [];
            final bekleyenler = hepsi.where((r) => r.durum == 'Onay bekliyor' || r.durum == 'Beklemede').toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (bekleyenler.isNotEmpty && !_guncelEsnaf.randevuAlinmasin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => TaksiEsnafRandevuOnayEkrani(esnafId: widget.esnaf.id, esnaf: widget.esnaf))
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade400, Colors.orange.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notification_important, color: Colors.white),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${bekleyenler.length} Randevu Onay Bekliyor",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const Text(
                                      "Hemen incelemek için tıklayın",
                                      style: TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),


                  _yonetimButonlari(),
                  const SizedBox(height: 15),

                  if (!_isSofor) ...[
                    _bolumKart(
                      baslik: "Filo Yönetimi",
                      initiallyExpanded: widget.openFilo,
                      icerik: _filoWidget(),
                    ),
                    _bolumKart(
                      baslik: "Mesai Saatleri",
                      initiallyExpanded: widget.openMesai,
                      icerik: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: _is724
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _is724
                                    ? Colors.orange.withValues(alpha: 0.3)
                                    : Colors.grey.shade300
                              ),
                            ),
                            child: SwitchListTile(
                              title: const Text("7/24 Çalışma Modu",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                _is724
                                    ? "Sistem her gün her saat açık."
                                    : "Mesai saatleri geçerli.",
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _is724,
                              activeThumbColor: Colors.orange,
                              activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                              secondary: Icon(Icons.auto_mode,
                                color: _is724 ? Colors.orange : Colors.grey),
                              onChanged: (bool value) {
                                setState(() {
                                  _is724 = value;
                                  _degisiklikVar = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(value ? "7/24 Çalışma Modu Aktif" : "Özel Mesai Moduna Geçildi"),
                                    backgroundColor: value ? Colors.orange : Colors.blue,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          _altBaslikIkonlu("Gündüz Mesai Saatleri", Icons.wb_sunny_outlined, Colors.orange.shade800),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _saatSecici("Açılış", acilisSaat, (v) => setState(() { acilisSaat = v; _degisiklikVar = true; }),),
                              const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                              _saatSecici("Kapanış", kapanisSaat, (v) => setState(() { kapanisSaat = v; _degisiklikVar = true; }),),
                            ],
                          ),
                          if (_is724) ...[
                            const Divider(height: 32, color: Colors.transparent),
                            _altBaslikIkonlu("Nöbetçi Saatleri", Icons.nightlight_round, Colors.indigo.shade900),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _saatSecici("Nöbet Başlangıç", _nobetBaslangic, (v) => setState(() { _nobetBaslangic = v; _degisiklikVar = true; })),
                                  const Icon(Icons.swap_horiz, color: Colors.grey),
                                  _saatSecici("Nöbet Bitiş", _nobetBitis, (v) => setState(() { _nobetBitis = v; _degisiklikVar = true; })),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _bolumKart(baslik: "Çalışma Günleri", initiallyExpanded: false, icerik: _gunlerIcerik()),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _kaydet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 10),
                            Text("AYARLARI KAYDET",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            );
          },
        ),
    );
  }


}


