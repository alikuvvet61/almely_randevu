import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';

import 'durak_takip_ekrani.dart';
import 'esnaf_ajanda_ekrani.dart';
import 'esnaf_parametre_ekrani.dart';
import 'esnaf_randevu_onay_ekrani.dart';
import 'randevu_ekrani.dart';
import 'taksi_cizelge_ekrani.dart';

class EsnafPaneli extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;
  final bool openFilo;
  final bool openMesai;

  const EsnafPaneli({super.key, required this.esnaf, this.soforTel, this.openFilo = false, this.openMesai = false});

  @override
  State<EsnafPaneli> createState() => _EsnafPaneliState();
}

class _EsnafPaneliState extends State<EsnafPaneli> {
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
  List<Map<String, dynamic>> kiralikAraclar = [];
  List<Map<String, dynamic>> personeller = [];
  List<Map<String, dynamic>> araclar = [];
  bool _personelOdakli = false;
  bool _degisiklikVar = false;
  final Map<String, String> _kanalDegisimleri = {};
  String _randevuOnayModu = 'Manuel';
  bool _ayniGunRandevuEngelle = false;
  bool _slotAralikliGoster = false;
  String _nobetBaslangic = "08:00";
  String _nobetBitis = "20:00";

  final Map<String, bool> _calismaGunleri = {
    "Pazartesi": false,
    "Salı": false,
    "Çarşamba": false,
    "Perşembe": false,
    "Cuma": false,
    "Cumartesi": false,
    "Pazar": false,
  };

  final List<TextEditingController> _hizmetSureControllerList = [];
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
    BildirimServisi.tokenKaydet(widget.esnaf.telefon);
    BildirimServisi.bildirimDinle(widget.esnaf.telefon);

    if (_isSofor) {
      BildirimServisi.tokenKaydet(widget.soforTel!);
      BildirimServisi.bildirimDinle(widget.soforTel!);
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
    if (widget.esnaf.kategori == 'Araç Kiralama') {
      kiralikAraclar = (widget.esnaf.kanallar ?? []).map<Map<String, dynamic>>((k) {
        if (k is Map) return Map<String, dynamic>.from(k);
        
        // --- BAŞLANGIÇTA KURTARMA MANTIĞI ---
        String raw = k.toString();
        if (raw.startsWith('{') && raw.endsWith('}')) {
          try {
            Map<String, dynamic> recovered = {};
            RegExp regExp = RegExp(r'([a-zA-Z0-9]+):\s?([^,}]+)');
            for (var match in regExp.allMatches(raw)) {
              String key = match.group(1)!;
              String value = match.group(2)!.trim();
              if (value == 'null' || value.isEmpty) continue;
              if (['koltuk', 'bagaj', 'yas', 'ehliyet'].contains(key)) {
                recovered[key] = int.tryParse(value);
              } else if (['teminat', 'puan'].contains(key)) {
                recovered[key] = double.tryParse(value);
              } else if (key == 'klima') {
                recovered[key] = value == 'true';
              } else {
                recovered[key] = value;
              }
            }
            if (recovered.containsKey('ad')) return recovered;
          } catch (e) { debugPrint("Açılış kurtarma hatası: $e"); }
        }
        return {"ad": k.toString()};
      }).toList();
      kanallar = kiralikAraclar.map((a) => a["ad"].toString()).toList();
    } else {
      kanallar = List<String>.from(widget.esnaf.kanallar ?? []);
    }
    _personelOdakli = widget.esnaf.randevularPersonelAdinaAlinsin;
    _randevuOnayModu = widget.esnaf.randevuOnayModu.isEmpty ? 'Manuel' : widget.esnaf.randevuOnayModu;
    _ayniGunRandevuEngelle = widget.esnaf.ayniGunRandevuEngelle;
    _slotAralikliGoster = widget.esnaf.slotAralikliGoster;
    _nobetBaslangic = widget.esnaf.nobetBaslangic ?? "08:00";
    _nobetBitis = widget.esnaf.nobetBitis ?? "20:00";

    personeller = (widget.esnaf.personeller ?? []).map((p) {
      if (p is Map) return Map<String, dynamic>.from(p);
      return {"isim": p.toString(), "kanal": ""};
    }).toList();

    araclar = List<Map<String, dynamic>>.from(widget.esnaf.araclar);

    for (var h in hizmetler) {
      _hizmetSureControllerList.add(TextEditingController(text: h["sure"].toString()));
    }

    final cs = widget.esnaf.calismaSaatleri;
    if (cs != null) {
      slotAraligi = cs['slotDakika'] ?? cs['slotAraligi'] ?? 30;
      if (cs['acilis'] != null) acilisSaat = cs['acilis'];
      if (cs['kapanis'] != null) kapanisSaat = cs['kapanis'];
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
    for (var c in _hizmetSureControllerList) {
      c.dispose();
    }
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
            if (widget.esnaf.kategori == 'Araç Kiralama') {
              kiralikAraclar = (data['kanallar'] ?? []).map<Map<String, dynamic>>((k) {
                if (k is Map) return Map<String, dynamic>.from(k);
                
                // KURTARMA MANTIĞI: String'e dönüşmüş veriyi Map'e çevir
                String raw = k.toString();
                if (raw.startsWith('{') && raw.endsWith('}')) {
                  try {
                    Map<String, dynamic> recovered = {};
                    RegExp regExp = RegExp(r'([a-zA-Z0-9]+):\s?([^,}]+)');
                    for (var match in regExp.allMatches(raw)) {
                      String key = match.group(1)!;
                      String value = match.group(2)!.trim();
                      if (['koltuk', 'bagaj', 'yas', 'ehliyet'].contains(key)) {
                        recovered[key] = int.tryParse(value);
                      } else if (['teminat', 'puan'].contains(key)) {
                        recovered[key] = double.tryParse(value);
                      } else if (key == 'klima') {
                        recovered[key] = value == 'true';
                      } else {
                        recovered[key] = value;
                      }
                    }
                    if (recovered.containsKey('ad')) return recovered;
                  } catch (e) { debugPrint("Kurtarma hatası: $e"); }
                }
                return {"ad": k.toString()};
              }).toList();
              kanallar = kiralikAraclar.map((a) => a["ad"].toString()).toList();
            } else {
              kanallar = List<String>.from(data['kanallar'] ?? []);
            }
            personeller = (data['personeller'] ?? []).map<Map<String, dynamic>>((p) {
              if (p is Map) return Map<String, dynamic>.from(p);
              return {"isim": p.toString(), "kanal": ""};
            }).toList();
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

  int _idealSlotHesapla() {
    int ideal = 30;
    List<int> sureler = hizmetler
        .map((h) => int.tryParse(h['sure'].toString()) ?? 0)
        .where((s) => s > 0)
        .toList();

    if (sureler.isNotEmpty) {
      int gcd(int a, int b) {
        while (b != 0) {
          var t = b;
          b = a % b;
          a = t;
        }
        return a;
      }

      ideal = sureler[0];
      for (int i = 1; i < sureler.length; i++) {
        ideal = gcd(ideal, sureler[i]);
      }
    }
    if (ideal < 5) ideal = 5;
    if (ideal > 60) ideal = 60;
    return ideal;
  }

  Future<bool> _topluAjandaOnarim() async {
    if (!mounted) return false;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // İDEAL SLOTU HESAPLA
    int idealSlot = _idealSlotHesapla();

    bool? onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajanda Defteri Yapısı Güncellensin mi?"),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: "Hizmet sürelerinizle tam uyumlu olması için tüm ajanda defteri kayıtlarınız "),
              TextSpan(text: "$idealSlot dakikalık", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const TextSpan(text: " yeni sisteme göre otomatik güncellenecektir.\n\n"),
              const TextSpan(text: "Mevcut randevularınız korunacaktır. Bu işlem biraz zaman alabilir.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Güncelle")),
        ],
      ),
    );

    if (onay != true || !mounted) return false;

    // Async gap sonrası BuildContext kullanımı için mounted kontrolü
    if (!context.mounted) return false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 15),
                Text("Ajanda Defteri Kayıtları Onarılıyor...", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Lütfen bekleyin", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Önce yerel slot aralığını güncelle
      setState(() {
        slotAraligi = idealSlot;
      });

      // Ana dokümanı kaydet
      await _kaydet(sessiz: true);
      if (!mounted) return false;

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;
      final List globalKanallar = kanallar; // State içindeki güncel liste
      final List globalPersoneller = widget.esnaf.kategori == 'Taksi'
          ? araclar.map((a) => {"isim": a['plaka'], "kanal": a['soforAd'] ?? ""}).toList()
          : personeller;
      final String bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Benzersiz tarihleri ayıkla (yyyy-MM-dd) ve sadece BUGÜN + GELECEK olanları al
      Set<String> tarihler = (_guncelEsnaf.aktifGunler ?? [])
          .map((e) => e.toString().split('_')[0])
          .where((t) => t.compareTo(bugun) >= 0) // Geçmişe dokunma
          .toSet();
      tarihler.add(bugun);

      List<String> yeniAktifGunler = [];

      for (var tarihId in tarihler) {
        // Çok kanallı yapı desteği (Suffix mantığını StreamBuilder ile eşitle)
        List<String> docIds = [];
        
        final List<String> cleanKanalNames = globalKanallar.map<String>((k) {
          if (k is Map) return (k['ad'] ?? k['plaka'] ?? k['aracTuru'] ?? '').toString().trim();
          return k.toString().trim();
        }).where((k) => k.isNotEmpty).toList();

        if (cleanKanalNames.isNotEmpty && widget.esnaf.kategori != 'Taksi') {
          docIds = cleanKanalNames.map((k) => "${tarihId}_$k").toList();
        } else if (widget.esnaf.kategori == 'Taksi' && araclar.isNotEmpty) {
          docIds = araclar
              .where((a) => a['plaka'] != null && a['plaka'].toString().trim().isNotEmpty)
              .map((a) => "${tarihId}_${a['plaka'].toString().trim()}")
              .toList();
        }

        if (docIds.isEmpty) {
          docIds = ["${tarihId}_Uygulama"];
        }

        for (var docId in docIds) {
          yeniAktifGunler.add(docId);
          final docRef = FirebaseFirestore.instance
              .collection('esnaflar')
              .doc(widget.esnaf.id)
              .collection('ajanda')
              .doc(docId);

          batch.set(docRef, {
            'tarih': tarihId,
            'slotDakika': idealSlot,
            'slotAraligi': idealSlot,
            'acilis': acilisSaat,
            'kapanis': kapanisSaat,
            'kanallar': cleanKanalNames,
            'personeller': globalPersoneller,
            'guncellemeTarihi': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          operationCount++;
          if (operationCount >= 480) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            operationCount = 0;
          }
        }
      }

      // Geçmişteki aktif günleri koru, güncellenenleri ekle (Tekilleştirerek)
      List<String> gecmisAktifGunler = (_guncelEsnaf.aktifGunler ?? [])
          .where((e) => e.toString().split('_')[0].compareTo(bugun) < 0)
          .map((e) => e.toString().trim())
          .toList();

      // Aktif günleri birleştir ve tekilleştir
      final tumAktifGunler = <String>{...gecmisAktifGunler, ...yeniAktifGunler}.toList();

      batch.update(FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id), {
        'calismaSaatleri.slotDakika': idealSlot,
        'calismaSaatleri.slotAraligi': idealSlot,
        'calismaSaatleri.acilis': acilisSaat,
        'calismaSaatleri.kapanis': kapanisSaat,
        'kanallar': widget.esnaf.kategori == 'Araç Kiralama' ? kiralikAraclar : globalKanallar.map((k) => k.toString().trim()).toList(),
        'aktifGunler': tumAktifGunler,
        'hizmetler': hizmetler,
        'personeller': widget.esnaf.kategori == 'Taksi'
            ? araclar.map((a) => {"isim": a['plaka'], "kanal": a['soforAd'] ?? ""}).toList()
            : personeller,
        'araclar': araclar.map((a) {
          final yeniArac = Map<String, dynamic>.from(a);
          yeniArac.remove('sofor');
          return yeniArac;
        }).toList(),
      });

      await batch.commit(); // EKSİK OLAN COMMIT GERİ EKLENDİ

      await _verileriTazele();

      if (mounted) {
        setState(() {});
        // Yükleme diyaloğunu kapat
        if (navigator.canPop()) navigator.pop();
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Tüm ajanda defteri yapıları $idealSlot dk olarak onarıldı."), backgroundColor: Colors.green),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;
      if (navigator.canPop()) navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
      return false;
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
        if (widget.esnaf.kategori == 'Araç Kiralama') {
          kiralikAraclar = (data['kanallar'] ?? []).map<Map<String, dynamic>>((k) {
            if (k is Map) return Map<String, dynamic>.from(k);
            return {"ad": k.toString()};
          }).toList();
          kanallar = kiralikAraclar.map((a) => a["ad"].toString()).toList();
        } else {
          kanallar = List<String>.from(data['kanallar'] ?? []);
        }
        _randevuOnayModu = data['randevuOnayModu'] ?? 'Manuel';
        _ayniGunRandevuEngelle = data['ayniGunRandevuEngelle'] ?? false;
        _slotAralikliGoster = data['slotAralikliGoster'] ?? false;
        _nobetBaslangic = data['nobetBaslangic'] ?? "08:00";
        _nobetBitis = data['nobetBitis'] ?? "20:00";
        _personelOdakli = data['randevularPersonelAdinaAlinsin'] ?? false;
        personeller = (data['personeller'] ?? []).map<Map<String, dynamic>>((p) {
          if (p is Map) return Map<String, dynamic>.from(p);
          return {"isim": p.toString(), "kanal": ""};
        }).toList();

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
          'slotDakika': slotAraligi,
          'durakAracSayisi': widget.esnaf.calismaSaatleri?['durakAracSayisi'],
          'tahminiDakika': widget.esnaf.calismaSaatleri?['tahminiDakika'],
        },
        'hizmetler': hizmetler,
        'kanallar': widget.esnaf.kategori == 'Araç Kiralama' ? kiralikAraclar : kanallar,
        'personeller': widget.esnaf.kategori == 'Taksi'
            ? araclar.map((a) => {"isim": a['plaka'], "kanal": a['soforAd'] ?? ""}).toList()
            : personeller,
        'araclar': araclar.map((a) {

          final yeniArac = Map<String, dynamic>.from(a);
          yeniArac.remove('sofor');
          return yeniArac;
        }).toList(),
      });

      // Kanal isimleri değiştiyse randevuları da toplu güncelle
      if (_kanalDegisimleri.isNotEmpty) {
        final randevuSnap = await FirebaseFirestore.instance
            .collection('randevular')
            .where('esnafId', isEqualTo: widget.esnaf.id)
            .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        int count = 0;

        for (var doc in randevuSnap.docs) {
          final data = doc.data();
          String? mevcutKanalRaw = data['kanal'];
          if (mevcutKanalRaw != null) {
            String mevcutKanal = mevcutKanalRaw.trim();
            if (_kanalDegisimleri.containsKey(mevcutKanal)) {
              batch.update(doc.reference, {'kanal': _kanalDegisimleri[mevcutKanal]});
              count++;
              if (count >= 500) {
                await batch.commit();
                batch = FirebaseFirestore.instance.batch();
                count = 0;
              }
            }
          }
        }

        if (count > 0) await batch.commit();
        _kanalDegisimleri.clear();
      }

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

  Widget _uyariBanneri(Map<String, dynamic>? ajandaData, bool exists) {
    int ideal = _idealSlotHesapla();
    bool slotUyumsuz = false;

    for (var h in hizmetler) {
      int s = int.tryParse(h['sure'].toString()) ?? 0;
      if (s > 0 && (slotAraligi == 0 || s % slotAraligi != 0)) {
        slotUyumsuz = true;
        break;
      }
    }

    if (slotAraligi != ideal) slotUyumsuz = true;

    // Ajanda dökümanı bazlı kontroller
    int? ajandaSlot = (ajandaData?['slotDakika'] ?? ajandaData?['slotAraligi'])?.toInt();
    int etkinAjandaSlot = ajandaSlot ?? slotAraligi;
    bool ajandaHizmetUyumsuz = exists && (etkinAjandaSlot != ideal);
    bool ajandaGlobalUyumsuz = exists && (etkinAjandaSlot != slotAraligi);

    // Saat Uyumsuzluğu Kontrolü
    String esnafAcilis = acilisSaat;
    String esnafKapanis = kapanisSaat;

    bool saatUyumsuz = false;
    bool dunyaYeni = !exists;

    if (exists && ajandaData != null) {
      String ajandaAcilis = ajandaData['acilis'] ?? esnafAcilis;
      String ajandaKapanis = ajandaData['kapanis'] ?? esnafKapanis;

      if (ajandaAcilis != esnafAcilis || ajandaKapanis != esnafKapanis) {
        saatUyumsuz = true;
      }
    }

    // Döküman yoksa VEYA saat uyumsuzsa VEYA slot/hizmet uyumsuzsa göster
    if (dunyaYeni || saatUyumsuz || ajandaHizmetUyumsuz || ajandaGlobalUyumsuz || slotUyumsuz) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dunyaYeni ? Colors.blue.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dunyaYeni ? Colors.blue.shade200 : Colors.red.shade200)
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: dunyaYeni ? Colors.blue : Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dunyaYeni ? "Ajanda Hazır Değil!" : "Ayarlar Uyumsuz!",
                          style: TextStyle(fontWeight: FontWeight.bold, color: dunyaYeni ? Colors.blue : Colors.red, fontSize: 15)
                        ),
                        Text(
                          dunyaYeni
                            ? "Müşterilerinizin randevu alabilmesi için ajanda defterinizin oluşturulması gerekmektedir."
                            : (ajandaHizmetUyumsuz
                                ? "Hizmet süreleriniz mevcut $etkinAjandaSlot dk'lık ajanda yapısına uymuyor. Yeni seçilen süreye göre ajandanız $ideal dk aralıklarında güncellenecektir."
                                : "İşletme ayarlarınızda (çalışma saatleri vb.) değişiklik tespit edildi. Mevcut ajanda yapısı güncellenecektir."),
                          style: const TextStyle(fontSize: 13, color: Colors.black87)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!dunyaYeni) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final basarili = await _topluAjandaOnarim();
                      if (basarili) {
                        await _verileriTazele();
                        if (mounted) setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("AJANDAYI ŞİMDİ ONAR VE DÜZELT",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _yonetimButonlari() {
    bool isTaksi = widget.esnaf.kategori == 'Taksi';

    if (_isSofor) {
      return _ozelButon(
        ikon: Icons.local_taxi,
        renk: Colors.green,
        metin: "Canlı Durak Takip",
        onTap: () {
          final navigator = Navigator.of(context);
          navigator.push(
            MaterialPageRoute(builder: (c) => DurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel)),
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
            icon: Icons.calendar_month,
            baslik: "Ajanda Defteri",
            altBaslik: "Saatleri Yönet",
            renk: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsnafAjandaEkrani(esnaf: _guncelEsnaf))),
          ),
        if (!_guncelEsnaf.randevuAlinmasin)
          _yonetimKarti(
            icon: Icons.history,
            baslik: "Randevu Kayıtları",
            altBaslik: "Onaylananlar",
            renk: Colors.indigo,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id, esnaf: widget.esnaf))),
          ),
        if (isTaksi) ...[
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => DurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel))),
          ),
        ],
        _yonetimKarti(
          icon: Icons.settings_suggest,
          baslik: "Gelişmiş Ayarlar",
          altBaslik: "Sistem Parametreleri",
          renk: Colors.blueGrey,
          onTap: () async {
            final navigator = Navigator.of(context);
            await navigator.push(MaterialPageRoute(builder: (c) => EsnafParametreEkrani(esnafId: widget.esnaf.id)));
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
        if (widget.esnaf.kategori == 'Araç Kiralama')
          _yonetimKarti(
            icon: Icons.add_task_rounded,
            baslik: "Randevu Ver",
            altBaslik: "Hızlı Kiralama",
            renk: Colors.green.shade800,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => RandevuEkrani(
                    esnaf: _guncelEsnaf,
                    kullaniciTel: null,
                  ),
                ),
              );
            },
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
                      Row(
                        children: [
                          Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (arac['sinif'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(arac['sinif'], style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
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
    String? seciliSinif = arac['sinif'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Aracı Düzenle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: pController, decoration: const InputDecoration(labelText: "Plaka"), textCapitalization: TextCapitalization.characters),
                TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Şoför Adı")),
                TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Şoför Telefon"), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                StreamBuilder<List<String>>(
                  stream: FirestoreServisi().aracSiniflariniGetir(),
                  builder: (context, snapshot) {
                    final siniflar = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: siniflar.contains(seciliSinif) ? seciliSinif : null,
                      decoration: const InputDecoration(labelText: "Araç Sınıfı"),
                      items: siniflar.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setDialogState(() => seciliSinif = v),
                    );
                  }
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
                Navigator.pop(context);
              },
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  araclar[index]['plaka'] = pController.text.trim().toUpperCase();
                  araclar[index]['soforAd'] = sAdController.text.trim();
                  araclar[index]['soforTel'] = sTelController.text.trim();
                  araclar[index]['sinif'] = seciliSinif;
                  _degisiklikVar = true;
                });
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                Navigator.pop(context);
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
    String? seciliSinif;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni Araç Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: pController, decoration: const InputDecoration(labelText: "Plaka"), textCapitalization: TextCapitalization.characters),
                TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Şoför Adı")),
                TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Şoför Telefon"), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                StreamBuilder<List<String>>(
                  stream: FirestoreServisi().aracSiniflariniGetir(),
                  builder: (context, snapshot) {
                    final siniflar = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: siniflar.contains(seciliSinif) ? seciliSinif : null,
                      decoration: const InputDecoration(labelText: "Araç Sınıfı"),
                      items: siniflar.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setDialogState(() => seciliSinif = v),
                    );
                  }
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
                Navigator.pop(context);
              },
              child: const Text("Vazgeç"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  araclar.add({
                    'plaka': pController.text.trim().toUpperCase(),
                    'soforAd': sAdController.text.trim(),
                    'soforTel': sTelController.text.trim(),
                    'sinif': seciliSinif,
                    'nobetSirasi': null,
                    'durum': 'Aktif',
                    'durakta': false,
                  });
                  _degisiklikVar = true;
                });
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                Navigator.pop(context);
              },
              child: const Text("Ekle"),
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

  Widget _kanallarWidget() {
    return Column(
      children: [
        if (widget.esnaf.kategori == 'Araç Kiralama')
          ...kiralikAraclar.asMap().entries.map((entry) {
            int idx = entry.key;
            var a = entry.value;
            return ListTile(
              leading: a["resim"] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      a["resim"],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.directions_car, color: Colors.blue),
              title: Text(a["ad"] ?? "İsimsiz Araç"),
              subtitle: Text("${a["yakit"] ?? 'Yakıt Belirtilmedi'} • ${a["vites"] ?? 'Vites Belirtilmedi'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _aracKiralamaDuzenle(idx),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _kanalSil(idx),
                  ),
                ],
              ),
            );
          })
        else
          ...kanallar.asMap().entries.map((entry) {
          int idx = entry.key;
          String k = entry.value;
          return ListTile(
            title: Text(k),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _kanalDuzenle(idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() {
                    String rawSilinen = kanallar[idx];
                    String silinenKanal = rawSilinen.trim();
                    kanallar.removeAt(idx);

                    // Silinen kanala bağlı personelleri temizle
                    List<Map<String, dynamic>> yeniPersonelListesi = [];
                    for (var p in personeller) {
                      Map<String, dynamic> pMap = Map<String, dynamic>.from(p);
                      String pKanalRaw = (pMap["kanal"] ?? "").toString();

                      if (pKanalRaw == rawSilinen ||
                          pKanalRaw.trim() == silinenKanal ||
                          pKanalRaw.trim().toLowerCase() == silinenKanal.toLowerCase()) {
                        pMap["kanal"] = "";
                      }
                      yeniPersonelListesi.add(pMap);
                    }
                    personeller = yeniPersonelListesi;

                    _degisiklikVar = true;
                  }),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _aracKiralamaDuzenle(null),
          icon: const Icon(Icons.add),
          label: const Text("Yeni Araç Ekle"),
        ),
      ],
    );
  }

  void _kanalSil(int idx) {
    setState(() {
      String rawSilinen = kanallar[idx];
      String silinenKanal = rawSilinen.trim();
      kanallar.removeAt(idx);
      if (widget.esnaf.kategori == 'Araç Kiralama') {
        kiralikAraclar.removeAt(idx);
      }

      // Silinen kanala bağlı personelleri temizle
      List<Map<String, dynamic>> yeniPersonelListesi = [];
      for (var p in personeller) {
        Map<String, dynamic> pMap = Map<String, dynamic>.from(p);
        String pKanalRaw = (pMap["kanal"] ?? "").toString();

        if (pKanalRaw == rawSilinen ||
            pKanalRaw.trim() == silinenKanal ||
            pKanalRaw.trim().toLowerCase() == silinenKanal.toLowerCase()) {
          pMap["kanal"] = "";
        }
        yeniPersonelListesi.add(pMap);
      }
      personeller = yeniPersonelListesi;

      _degisiklikVar = true;
    });
  }

  void _aracKiralamaDuzenle(int? idx) {
    final isYeni = idx == null;
    final data = isYeni ? <String, dynamic>{} : kiralikAraclar[idx];

    final mC = TextEditingController(text: data["marka"]);
    final modC = TextEditingController(text: data["model"]);
    final pC = TextEditingController(text: data["plaka"]);
    final kC = TextEditingController(text: data["koltuk"]?.toString());
    final bC = TextEditingController(text: data["bagaj"]?.toString());
    final yC = TextEditingController(text: data["yas"]?.toString());
    final eC = TextEditingController(text: data["ehliyet"]?.toString());
    final tC = TextEditingController(text: data["teminat"]?.toString());

    String? sYakit = data["yakit"];
    String? sVites = data["vites"];
    String? sATuru = data["aracTuru"];
    String? sSinif = data["sinif"];
    String? sTip = data["tip"];
    String? rUrl = data["resim"];
    bool klima = data["klima"] ?? true;
    bool yukleniyor = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isYeni ? "Yeni Araç Ekle" : "Araç Bilgileri"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Kamera'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
                              ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeri'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
                            ],
                          ),
                        ),
                      );
                      if (source == null || !context.mounted) return;
                      try {
                        final image = await picker.pickImage(source: source, imageQuality: 50);
                        if (image == null || !context.mounted) return;
                        setDialogState(() => yukleniyor = true);
                        final storageRef = FirebaseStorage.instance.ref().child("arac_resimleri/${DateTime.now().millisecondsSinceEpoch}.jpg");
                        if (kIsWeb) {
                          await storageRef.putData(await image.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
                        } else {
                          await storageRef.putFile(File(image.path));
                        }
                        final url = await storageRef.getDownloadURL();
                        if (context.mounted) setDialogState(() { rUrl = url; yukleniyor = false; });
                      } catch (e) {
                        if (context.mounted) setDialogState(() => yukleniyor = false);
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          height: 120, width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                          child: yukleniyor ? const Center(child: CircularProgressIndicator()) : rUrl != null 
                            ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(rUrl!, fit: BoxFit.cover))
                            : const Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.blueGrey),
                        ),
                        if (rUrl != null && !yukleniyor)
                          Positioned(
                            top: 5, right: 5,
                            child: GestureDetector(
                              onTap: () => setDialogState(() => rUrl = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(children: [Expanded(child: TextField(controller: mC, decoration: const InputDecoration(labelText: "Marka"))), const SizedBox(width: 10), Expanded(child: TextField(controller: modC, decoration: const InputDecoration(labelText: "Model")))]),
                  TextField(controller: pC, decoration: const InputDecoration(labelText: "Plaka")),
                  const SizedBox(height: 10),
                  StreamBuilder<List<String>>(
                    stream: FirestoreServisi().aracTurleriniGetir(),
                    builder: (context, snapshot) {
                      final turler = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: turler.contains(sATuru) ? sATuru : null,
                        decoration: const InputDecoration(labelText: "Araç Türü (Yönetici)"),
                        items: turler.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setDialogState(() => sATuru = v),
                      );
                    }
                  ),
                  StreamBuilder<List<String>>(
                    stream: FirestoreServisi().aracSiniflariniGetir(),
                    builder: (context, snapshot) {
                      final siniflar = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: siniflar.contains(sSinif) ? sSinif : null,
                        decoration: const InputDecoration(labelText: "Araç Sınıfı"),
                        items: siniflar.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setDialogState(() => sSinif = v),
                      );
                    }
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: sYakit,
                    decoration: const InputDecoration(labelText: "Yakıt Tipi"),
                    items: ["Dizel", "Benzin", "Hibrit", "Elektrik"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => sYakit = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: sVites,
                    decoration: const InputDecoration(labelText: "Vites Tipi"),
                    items: ["Otomatik", "Manuel"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => sVites = v),
                  ),
                  StreamBuilder<List<String>>(
                    stream: FirestoreServisi().aracTurleriniGetir(),
                    builder: (context, snapshot) {
                      final turler = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: turler.contains(sTip) ? sTip : null,
                        decoration: const InputDecoration(labelText: "Araç Tipi"),
                        items: turler.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setDialogState(() => sTip = v),
                      );
                    }
                  ),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: kC, decoration: const InputDecoration(labelText: "Koltuk"), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: bC, decoration: const InputDecoration(labelText: "Bagaj (Litre)"), keyboardType: TextInputType.number)),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text("Klima"),
                    value: klima,
                    onChanged: (v) => setDialogState(() => klima = v),
                  ),
                  const Divider(),
                  const Text("Kiralama Koşulları", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  TextField(controller: yC, decoration: const InputDecoration(labelText: "Minimum Müşteri Yaşı"), keyboardType: TextInputType.number),
                  TextField(controller: eC, decoration: const InputDecoration(labelText: "Min. Ehliyet Yılı"), keyboardType: TextInputType.number),
                  TextField(controller: tC, decoration: const InputDecoration(labelText: "Teminat (₺)"), keyboardType: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  mC.dispose(); modC.dispose(); pC.dispose(); kC.dispose(); bC.dispose(); yC.dispose(); eC.dispose(); tC.dispose();
                  Navigator.pop(context);
                },
                child: const Text("Vazgeç"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (mC.text.isEmpty) return;
                  final tamAd = "${mC.text} ${modC.text} (${pC.text})";
                  final yeniArac = {
                    "ad": tamAd, "marka": mC.text, "model": modC.text, "plaka": pC.text, "aracTuru": sATuru, 
                    "sinif": sSinif, "yakit": sYakit, "vites": sVites, "tip": sTip, "resim": rUrl,
                    "koltuk": int.tryParse(kC.text), "bagaj": int.tryParse(bC.text), "klima": klima,
                    "yas": int.tryParse(yC.text), "ehliyet": int.tryParse(eC.text), "teminat": double.tryParse(tC.text),
                  };
                  setState(() {
                    if (isYeni) { kiralikAraclar.add(yeniArac); kanallar.add(tamAd); } 
                    else { kiralikAraclar[idx] = yeniArac; kanallar[idx] = tamAd; }
                    _degisiklikVar = true;
                  });
                  mC.dispose(); modC.dispose(); pC.dispose(); kC.dispose(); bC.dispose(); yC.dispose(); eC.dispose(); tC.dispose();
                  Navigator.pop(context);
                },
                child: Text(isYeni ? "Ekle" : "Güncelle"),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _kanalDuzenle(int idx) {
    final controller = TextEditingController(text: kanallar[idx]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.esnaf.kategori == 'Araç Kiralama' ? "Araç Bilgileri" : "Kanalı Düzenle"),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: widget.esnaf.kategori == 'Araç Kiralama' ? "Araç" : "Kanal Adı"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(onPressed: () async {
            final String eskiTamIsim = kanallar[idx];
            final String yeniIsim = controller.text.trim();
            final String eskiTemizIsim = eskiTamIsim.trim();

            if (yeniIsim.isNotEmpty) {
              bool isimDegisti = yeniIsim != eskiTemizIsim;
              bool formatDegisti = yeniIsim != eskiTamIsim;

              if (isimDegisti || formatDegisti) {
                setState(() {
                  // 1. Ana kanallar listesini güncelle
                  kanallar[idx] = yeniIsim;

                  if (isimDegisti) {
                    // 2. Personelleri OTOMATİK GÜNCELLE (Senkronizasyon)
                    personeller = personeller.map((p) {
                      final pMap = Map<String, dynamic>.from(p);
                      final String pKanal = (pMap["kanal"] ?? "").toString().trim();

                      // Eğer personelin kanalı, düzenlenen eski kanal ismiyle eşleşiyorsa (harf duyarsız)
                      if (pKanal == eskiTemizIsim || pKanal.toLowerCase() == eskiTemizIsim.toLowerCase()) {
                        pMap["kanal"] = yeniIsim;
                      }
                      return pMap;
                    }).toList();

                    // 3. Firestore Takibi (Randevuların toplu güncellenmesi için)
                    _kanalDegisimleri.forEach((key, value) {
                      if (value == eskiTemizIsim) {
                        _kanalDegisimleri[key] = yeniIsim;
                      }
                    });
                    _kanalDegisimleri[eskiTemizIsim] = yeniIsim;
                  }
                  _degisiklikVar = true;
                });

                // Hemen kaydet (Böylece banner tetiklenebilir hale gelir)
                await _kaydet(sessiz: true);
              }
              if (context.mounted) Navigator.pop(context);
            }
          }, child: const Text("Güncelle")),
        ],
      ),
    );
  }

  void _personelDuzenle(int idx) {
    var p = personeller[idx];
    String isim = p["isim"] ?? "";
    String kanal = (p["kanal"] ?? "").toString().trim();

    showDialog(
      context: context,
      builder: (context) {
        // State-safe controller approach to avoid issues with initialValue updates
        return AlertDialog(
          title: const Text("Personeli Düzenle"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: isim,
                    onChanged: (v) => isim = v,
                    decoration: const InputDecoration(labelText: "Personel Adı"),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: kanallar.any((k) => k.trim() == kanal)
                        ? kanallar.firstWhere((k) => k.trim() == kanal)
                        : "",
                    items: [
                      const DropdownMenuItem(value: "", child: Text("Tüm Kanallar")),
                      ...kanallar.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        kanal = v ?? "";
                      });
                    },
                    decoration: const InputDecoration(labelText: "Bağlı Olduğu Kanal"),
                  ),
                ],
              );
            }
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
            TextButton(onPressed: () async {
              if (isim.trim().isNotEmpty) {
                setState(() {
                  personeller[idx] = {"isim": isim.trim(), "kanal": kanal};
                  _degisiklikVar = true;
                });
                // Hemen kaydet (Böylece banner tetiklenebilir hale gelir)
                await _kaydet(sessiz: true);
                if (context.mounted) Navigator.pop(context);
              }
            }, child: const Text("Güncelle")),
          ],
        );
      },
    );
  }

  void _hizmetDuzenle(int idx) {
    var h = hizmetler[idx];
    final isimController = TextEditingController(text: h["isim"] ?? "");
    final sureController = TextEditingController(text: (h["sure"] ?? 30).toString());
    final ucretController = TextEditingController(text: (h["ucret"] ?? 0).toString().replaceAll(".0", ""));
    bool ucretGoster = h["ucretGoster"] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Hizmeti Düzenle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.esnaf.kategori == 'Araç Kiralama') ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Hizmet Adı"),
                    initialValue: ["Saatlik Kiralama", "Günlük Kiralama"].contains(isimController.text) 
                        ? isimController.text 
                        : "Saatlik Kiralama",
                    items: const [
                      DropdownMenuItem(value: "Saatlik Kiralama", child: Text("Saatlik Kiralama")),
                      DropdownMenuItem(value: "Günlük Kiralama", child: Text("Günlük Kiralama")),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        if (v != null) {
                          isimController.text = v;
                          if (v == "Saatlik Kiralama") {
                            sureController.text = "120";
                          } else {
                            sureController.text = "1440";
                          }
                        }
                      });
                    },
                  ),
                ] else
                  TextFormField(
                    controller: isimController,
                    decoration: const InputDecoration(labelText: "Hizmet Adı"),
                  ),
                TextFormField(
                  controller: sureController,
                  decoration: InputDecoration(
                    labelText: "Süre (Dakika)",
                    helperText: widget.esnaf.kategori == 'Araç Kiralama' 
                      ? (isimController.text.toLowerCase().contains("saatlik") ? "Min 2 Saat, Max 8 Saat" : "24 Saat ve Katları")
                      : null,
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: ucretController,
                  decoration: const InputDecoration(labelText: "Ücret (Opsiyonel)", suffixText: "TL"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text("Ücreti Müşteriye Göster"),
                  value: ucretGoster,
                  onChanged: (v) => setModalState(() => ucretGoster = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
            TextButton(
              onPressed: () {
                final isim = isimController.text.trim();
                final sure = int.tryParse(sureController.text) ?? 30;
                final ucret = double.tryParse(ucretController.text) ?? 0;

                if (isim.isEmpty) return;

                if (widget.esnaf.kategori == 'Araç Kiralama') {
                  if (isim.toLowerCase().contains("saatlik")) {
                    if (sure < 120 || sure > 480) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Saatlik kiralama 2 ile 8 saat arasında (120-480 dk) olmalıdır."))
                      );
                      return;
                    }
                  } else if (isim.toLowerCase().contains("günlük")) {
                    if (sure < 1440 || sure % 1440 != 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Günlük kiralama 24 saatlik periyotlar (1440 dk) halinde olmalıdır."))
                      );
                      return;
                    }
                  }
                }

                setState(() {
                  hizmetler[idx] = {
                    "isim": isim,
                    "sure": sure,
                    "ucret": ucret,
                    "ucretGoster": ucretGoster,
                  };
                  if (idx < _hizmetSureControllerList.length) {
                    _hizmetSureControllerList[idx].text = sure.toString();
                  }
                  _degisiklikVar = true;
                });
                Navigator.pop(context);
              },
              child: const Text("Güncelle"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personellerWidget() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text("Personel Odaklı Sistem"),
          subtitle: const Text("Randevular doğrudan personel adına alınsın."),
          value: _personelOdakli,
          onChanged: (v) => setState(() { _personelOdakli = v; _degisiklikVar = true; }),
        ),
        const Divider(),
        ...personeller.asMap().entries.map((entry) {
          int idx = entry.key;
          var p = entry.value;
          return ListTile(
            title: Text(p["isim"] ?? "İsimsiz"),
            subtitle: Text("Kanal: ${p["kanal"]?.toString().isEmpty ?? true ? "Tüm Kanallar" : p["kanal"]}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _personelDuzenle(idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() { personeller.removeAt(idx); _degisiklikVar = true; }),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            String isim = "";
            String kanal = "";
            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  title: const Text("Yeni Personel"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(onChanged: (v) => isim = v, decoration: const InputDecoration(labelText: "Personel Adı")),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: kanal,
                        items: [
                          const DropdownMenuItem(value: "", child: Text("Tüm Kanallar")),
                          ...kanallar.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            kanal = v ?? "";
                          });
                        },
                        decoration: const InputDecoration(labelText: "Bağlı Olduğu Kanal"),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
                    TextButton(onPressed: () {
                      if (isim.isNotEmpty) {
                        setState(() {
                          personeller.add({"isim": isim.trim(), "kanal": kanal});
                          _degisiklikVar = true;
                        });
                        Navigator.pop(context);
                      }
                    }, child: const Text("Ekle")),
                  ],
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Personel Ekle"),
        ),
      ],
    );
  }

  Widget _hizmetlerWidget() {
    return Column(
      children: [
        ...hizmetler.asMap().entries.map((entry) {
          int idx = entry.key;
          var h = entry.value;
          bool showPrice = h["ucretGoster"] ?? false;
          double ucret = (h["ucret"] ?? 0).toDouble();

          return ListTile(
            title: Text(h["isim"] ?? "Hizmet"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${h["sure"] ?? 30} dakika"),
                Text(
                  ucret > 0
                      ? "Ücret: ${ucret.toStringAsFixed(0)} TL ${showPrice ? '(Görünür)' : '(Gizli)'}"
                      : "Ücret: Ücretsiz ${showPrice ? '(Görünür)' : '(Gizli)'}",
                  style: TextStyle(fontSize: 12, color: showPrice ? Colors.green : Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _hizmetDuzenle(idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() {
                    hizmetler.removeAt(idx);
                    _hizmetSureControllerList.removeAt(idx);
                    _degisiklikVar = true;
                  }),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final isimController = TextEditingController(
              text: widget.esnaf.kategori == 'Araç Kiralama' ? "Saatlik Kiralama" : ""
            );
            final sureController = TextEditingController(
              text: widget.esnaf.kategori == 'Araç Kiralama' ? "120" : "30"
            );
            final ucretController = TextEditingController(text: "0");
            bool ucretGoster = false;

            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setModalState) => AlertDialog(
                  title: const Text("Yeni Hizmet"),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.esnaf.kategori == 'Araç Kiralama') ...[
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: "Hizmet Adı"),
                            initialValue: "Saatlik Kiralama",
                            items: const [
                              DropdownMenuItem(value: "Saatlik Kiralama", child: Text("Saatlik Kiralama")),
                              DropdownMenuItem(value: "Günlük Kiralama", child: Text("Günlük Kiralama")),
                            ],
                            onChanged: (v) {
                              setModalState(() {
                                if (v != null) {
                                  isimController.text = v;
                                  if (v == "Saatlik Kiralama") {
                                    sureController.text = "120";
                                  } else {
                                    sureController.text = "1440";
                                  }
                                }
                              });
                            },
                          ),
                        ] else
                          TextField(controller: isimController, decoration: const InputDecoration(labelText: "Hizmet Adı")),
                        TextField(
                          controller: sureController,
                          decoration: InputDecoration(
                            labelText: "Süre (Dakika)",
                            helperText: widget.esnaf.kategori == 'Araç Kiralama' 
                              ? (isimController.text.toLowerCase().contains("saatlik") ? "Min 2 Saat, Max 8 Saat" : "24 Saat ve Katları")
                              : null,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: ucretController,
                          decoration: const InputDecoration(labelText: "Ücret (Opsiyonel)", suffixText: "TL"),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          title: const Text("Ücreti Müşteriye Göster"),
                          value: ucretGoster,
                          onChanged: (v) => setModalState(() => ucretGoster = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
                    TextButton(onPressed: () {
                      final isim = isimController.text.trim();
                      final sure = int.tryParse(sureController.text) ?? 30;
                      final ucret = double.tryParse(ucretController.text) ?? 0;

                      if (isim.isNotEmpty) {
                        if (widget.esnaf.kategori == 'Araç Kiralama') {
                          if (isim.toLowerCase().contains("saatlik")) {
                            if (sure < 120 || sure > 480) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Saatlik kiralama 2 ile 8 saat arasında (120-480 dk) olmalıdır."))
                              );
                              return;
                            }
                          } else if (isim.toLowerCase().contains("günlük")) {
                            if (sure < 1440 || sure % 1440 != 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Günlük kiralama 24 saatlik periyotlar (1440 dk) halinde olmalıdır."))
                              );
                              return;
                            }
                          }
                        }

                        setState(() {
                          hizmetler.add({
                            "isim": isim,
                            "sure": sure,
                            "ucret": ucret,
                            "ucretGoster": ucretGoster
                          });
                          _hizmetSureControllerList.add(TextEditingController(text: sure.toString()));
                          _degisiklikVar = true;
                        });
                        if (!mounted) return;
                        Navigator.pop(context);
                      }
                    }, child: const Text("Ekle")),
                  ],
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Hizmet Ekle"),
        ),
      ],
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

  String _getKanalAciklama() {
    switch (widget.esnaf.kategori) {
      case 'Taksi':
        return "Örn: 'Durak', 'Peron', 'Bekleme Noktası'. Müşteriler randevu alırken hangi duraktan veya perondan araç istediklerini seçebilir.";
      case 'Kuaför':
      case 'Berber':
        return "Örn: 'Koltuk 1', 'VİP Oda', 'Yıkama Tezgahı'. Müşteriler randevu alırken hizmet alacakları koltuğu seçebilir.";
      case 'Restoran':
      case 'Kafe':
        return "Örn: 'Masa 1', 'Teras', 'Loca', 'Bahçe'. Müşteriler rezervasyon yaparken oturacakları yeri seçebilir.";
      case 'Halı Saha':
        return "Örn: 'Saha A', 'Kapalı Saha', 'VİP Saha'. Müşteriler hangi sahada oynamak istediklerini seçebilir.";
      case 'Oto Yıkama':
        return "Örn: 'Kanal 1', 'Peron A', 'Detaylı Temizlik Alanı'. Müşteriler araçlarını hangi perona bırakacaklarını seçebilir.";
      case 'Araç Kiralama':
        return "Örn: '34 ABC 123 - Fiat Egea', '61 ALM 001 - VW Passat'. Her bir araç bir kanal olarak tanımlanır, böylece çakışmalar önlenir.";
      default:
        return "Örn: 'Bölüm 1', 'Masa', 'Koltuk', 'Oda'. Müşteriler randevu alırken hizmet alacakları bu kanallardan birini seçebilir.";
    }
  }

  String _getHizmetAciklama() {
    switch (widget.esnaf.kategori) {
      case 'Taksi':
        return "Örn: 'Şehir İçi Transfer', 'Havaalanı', 'İlçe Gezisi'. Bu hizmetlerin ortalama sürelerini belirlemek, takvim planlamanızı otomatik düzenler.";
      case 'Kuaför':
      case 'Berber':
        return "Örn: 'Saç Kesim', 'Sakal Traşı', 'Fön'. Her hizmetin süresini belirleyerek randevuların çakışmasını önleyebilirsiniz.";
      case 'Araç Kiralama':
        return "Kiralama hizmetlerinizi 'Saatlik' (120-480 dk) veya 'Günlük' (1440 dk) olarak tanımlayabilirsiniz. Sistem bu sürelere göre araç takvimini otomatik kapatır.";
      default:
        return "Hizmetlerinizin ortalama süresini belirlemek (Örn: 30 dk, 1 saat), randevu aralıklarını otomatik olarak en verimli şekilde düzenler.";
    }
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

  Future<bool> _onWillPop() async {
    if (!_degisiklikVar) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Değişiklikler Kaydedilmedi"),
        content: const Text("Yaptığınız değişiklikler kaybolacak. Çıkmak istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hayır")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Evet, Çık"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSofor) {
      return DurakTakipEkrani(esnaf: _guncelEsnaf, soforTel: widget.soforTel);
    }

    return PopScope(
      canPop: !_degisiklikVar,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_adController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
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
                  // Ajanda Uyarı Bannerı
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('esnaflar')
                        .doc(widget.esnaf.id)
                        .collection('ajanda')
                        .where('tarih', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()))
                        .limit(1)
                        .snapshots(),
                    builder: (context, ajandaSnap) {
                      final bool exists = ajandaSnap.hasData && ajandaSnap.data!.docs.isNotEmpty;

                      // Eğer hiç gelecek ajanda yoksa, hazır olmadığını bildir
                      if (!exists) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue.shade200)
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, color: Colors.blue, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Ajanda Defteriniz Henüz Hazır Değil! Randevu alımını başlatmak için ajanda oluşturun.",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Eğer ajanda varsa, normal uyarı banner'ını (sadece mismatch/uyumsuzluk için) göster
                      final data = exists ? ajandaSnap.data!.docs.first.data() as Map<String, dynamic>? : null;
                      return _uyariBanneri(data, exists);
                    },
                  ),

                  if (bekleyenler.isNotEmpty && !_guncelEsnaf.randevuAlinmasin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id, esnaf: widget.esnaf))
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
                  
                  if (widget.esnaf.kategori == 'Araç Kiralama') ...[
                    _bolumKart(
                      baslik: "Araç Filomuz",
                      initiallyExpanded: true,
                      icerik: Column(
                        children: kiralikAraclar.map((a) {
                          String ad = a["ad"] ?? "İsimsiz Araç";
                          String? resim = a["resim"];
                          String? plaka = a["plaka"];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: (resim != null && resim.isNotEmpty)
                                      ? Image.network(resim, width: 90, height: 65, fit: BoxFit.cover)
                                      : Container(width: 90, height: 65, color: Colors.grey.shade100, child: const Icon(Icons.directions_car, color: Colors.grey)),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plaka != null && plaka.isNotEmpty ? "$ad ($plaka)" : ad,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (plaka != null && plaka.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade100),
                                          ),
                                          child: Text(
                                            plaka,
                                            style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => RandevuEkrani(
                                esnaf: _guncelEsnaf,
                                kullaniciTel: null,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 24),
                        label: const Text("Randevu Ver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                          shadowColor: Colors.blue.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],

                  _yonetimButonlari(),
                  const SizedBox(height: 15),

                  if (!_isSofor) ...[
                    if (widget.esnaf.kategori == 'Taksi') ...[
                      _bolumKart(
                        baslik: "Filo Yönetimi",
                        initiallyExpanded: widget.openFilo,
                        icerik: _filoWidget()
                      ),
                    ],
                    _bolumKart(
                      baslik: "Mesai Saatleri",
                      initiallyExpanded: widget.openMesai,
                      icerik: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: (acilisSaat == "00:00" && kapanisSaat == "00:00")
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (acilisSaat == "00:00" && kapanisSaat == "00:00")
                                    ? Colors.orange
                                    : Colors.grey.shade300
                              ),
                            ),
                            child: SwitchListTile(
                              title: const Text("7/24 Çalışma Modu",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (acilisSaat == "00:00" && kapanisSaat == "00:00")
                                    ? "Sistem her gün her saat açık."
                                    : "Mesai saatleri geçerli.",
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: (acilisSaat == "00:00" && kapanisSaat == "00:00"),
                              activeThumbColor: Colors.orange,
                              activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                              secondary: Icon(Icons.auto_mode,
                                color: (acilisSaat == "00:00" && kapanisSaat == "00:00") ? Colors.orange : Colors.grey),
                              onChanged: (bool value) {
                                setState(() {
                                  if (value) {
                                    acilisSaat = "00:00";
                                    kapanisSaat = "00:00";
                                    _calismaGunleri.updateAll((key, value) => true);
                                  } else {
                                    acilisSaat = "08:00";
                                    kapanisSaat = "20:00";
                                  }
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
                          if (acilisSaat == "00:00" && kapanisSaat == "00:00") ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _saatSecici(
                                    widget.esnaf.kategori == 'Araç Kiralama' ? "Başlangıç" : "Nöbet Başlangıç",
                                    _nobetBaslangic,
                                    (v) => setState(() {
                                      _nobetBaslangic = v;
                                      _degisiklikVar = true;
                                    })
                                  ),
                                  const Icon(Icons.swap_horiz, color: Colors.grey),
                                  _saatSecici(
                                    widget.esnaf.kategori == 'Araç Kiralama' ? "Bitiş" : "Nöbet Bitiş",
                                    _nobetBitis,
                                    (v) => setState(() {
                                      _nobetBitis = v;
                                      _degisiklikVar = true;
                                    })
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!(acilisSaat == "00:00" && kapanisSaat == "00:00")) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _saatSecici("Açılış", acilisSaat, (v) => setState(() { acilisSaat = v; _degisiklikVar = true; _idealSlotHesapla(); }),),
                                const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                                _saatSecici("Kapanış", kapanisSaat, (v) => setState(() { kapanisSaat = v; _degisiklikVar = true; _idealSlotHesapla(); }),),
                              ],
                            ),
                            const Divider(height: 32),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Randevu Aralığı (Slot)", style: TextStyle(color: Colors.grey)),
                              DropdownButton<int>(
                                value: [10, 15, 20, 30, 45, 60].contains(slotAraligi) ? slotAraligi : 30,
                                items: [10, 15, 20, 30, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text("$m dakika"))).toList(),
                                onChanged: (v) => setState(() { slotAraligi = v!; _degisiklikVar = true; }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _bolumKart(baslik: "Çalışma Günleri", initiallyExpanded: false, icerik: _gunlerIcerik()),
                    _bolumKart(
                      baslik: widget.esnaf.kategori == 'Araç Kiralama' ? "Kiralık Araçlar" : "Randevu Kanalları",
                      initiallyExpanded: false,
                      bilgiAciklama: _getKanalAciklama(),
                      icerik: _kanallarWidget()
                    ),
                    if (widget.esnaf.kategori != 'Taksi')
                      if (widget.esnaf.kategori != 'Araç Kiralama')
                      _bolumKart(baslik: "Personeller", initiallyExpanded: false, icerik: _personellerWidget()),

                    _bolumKart(
                      baslik: "Hizmetler ve Süreleri",
                      initiallyExpanded: false,
                      bilgiAciklama: _getHizmetAciklama(),
                      icerik: _hizmetlerWidget(),
                    ),
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
      ),
    );
  }
}


