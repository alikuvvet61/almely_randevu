import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'durak_takip_ekrani.dart';
import 'taksi_cizelge_ekrani.dart';
import 'esnaf_ajanda_ekrani.dart';
import 'esnaf_parametre_ekrani.dart';
import 'esnaf_randevu_onay_ekrani.dart';

class EsnafPaneli extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const EsnafPaneli({super.key, required this.esnaf, this.soforTel});

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
  List<Map<String, dynamic>> personeller = [];
  List<Map<String, dynamic>> araclar = [];
  bool _personelOdakli = false;
  bool _degisiklikVar = false;
  final Map<String, String> _kanalDegisimleri = {};
  String _randevuOnayModu = 'Manuel';
  bool _ayniGunRandevuEngelle = false;
  bool _slotAralikliGoster = false;

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
    kanallar = List<String>.from(widget.esnaf.kanallar ?? []);
    _personelOdakli = widget.esnaf.randevularPersonelAdinaAlinsin;
    _randevuOnayModu = widget.esnaf.randevuOnayModu.isEmpty ? 'Manuel' : widget.esnaf.randevuOnayModu;
    _ayniGunRandevuEngelle = widget.esnaf.ayniGunRandevuEngelle;
    _slotAralikliGoster = widget.esnaf.slotAralikliGoster;

    personeller = (widget.esnaf.personeller ?? []).map((p) {
      if (p is Map) return Map<String, dynamic>.from(p);
      return {"isim": p.toString(), "kanal": ""};
    }).toList();

    araclar = List<Map<String, dynamic>>.from(widget.esnaf.araclar ?? []);

    for (var h in hizmetler) {
      _hizmetSureControllerList.add(TextEditingController(text: h["sure"].toString()));
    }

    slotAraligi = widget.esnaf.calismaSaatleri?['slotDakika'] ??
                  widget.esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

    if (widget.esnaf.calismaSaatleri?['acilis'] != null) {
      acilisSaat = widget.esnaf.calismaSaatleri!['acilis'];
    }
    if (widget.esnaf.calismaSaatleri?['kapanis'] != null) {
      kapanisSaat = widget.esnaf.calismaSaatleri!['kapanis'];
    }

    if (widget.esnaf.calismaSaatleri?['gunler'] != null) {
      Map<String, dynamic> gelenGunler = widget.esnaf.calismaSaatleri!['gunler'];
      gelenGunler.forEach((key, value) {
        if (_calismaGunleri.containsKey(key)) {
          _calismaGunleri[key] = value;
        }
      });
    }

    Future.delayed(Duration.zero, () {
      if (mounted) setState(() => _degisiklikVar = false);
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
            kanallar = List<String>.from(data['kanallar'] ?? []);
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
      try {
        Position position = await Geolocator.getCurrentPosition();
        await _konumGuncelle(position.latitude, position.longitude);
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
        title: const Text("Ajanda Yapısı Güncellensin mi?"),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: "Hizmet sürelerinizle tam uyumlu olması için tüm ajandalarınız "),
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
                Text("Ajandalar Onarılıyor...", style: TextStyle(fontWeight: FontWeight.bold)),
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
      final aktifGunler = _guncelEsnaf.aktifGunler ?? [];
      
      for (var gunId in aktifGunler) {
        final docRef = FirebaseFirestore.instance
            .collection('esnaflar')
            .doc(widget.esnaf.id)
            .collection('ajanda')
            .doc(gunId);
            
        batch.update(docRef, {
          'slotDakika': idealSlot,
          'slotAraligi': idealSlot,
          'guncellemeTarihi': FieldValue.serverTimestamp(),
        });
        
        operationCount++;
        
        if (operationCount >= 499) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      batch.update(FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id), {
        'calismaSaatleri.slotDakika': idealSlot,
        'calismaSaatleri.slotAraligi': idealSlot,
      });

      await batch.commit();
      
      if (!mounted) return false;
      // Yakalanmış navigator kullanımı
      if (navigator.canPop()) navigator.pop(); 
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Tüm ajanda yapıları $idealSlot dk olarak onarıldı."), backgroundColor: Colors.green),
      );
      
      await _verileriTazele();
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
        kanallar = List<String>.from(data['kanallar'] ?? []);
        _randevuOnayModu = data['randevuOnayModu'] ?? 'Manuel';
        _ayniGunRandevuEngelle = data['ayniGunRandevuEngelle'] ?? false;
        _slotAralikliGoster = data['slotAralikliGoster'] ?? false;
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
        'calismaSaatleri': {
          'gunler': _calismaGunleri,
          'acilis': acilisSaat,
          'kapanis': kapanisSaat,
          'slotDakika': slotAraligi,
          'durakAracSayisi': widget.esnaf.calismaSaatleri?['durakAracSayisi'],
          'tahminiDakika': widget.esnaf.calismaSaatleri?['tahminiDakika'],
        },
        'hizmetler': hizmetler,
        'kanallar': kanallar,
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

  Widget _uyariBanneri() {
    int ideal = _idealSlotHesapla();
    bool uyumsuz = false;
    
    for (var h in hizmetler) {
      int s = int.tryParse(h['sure'].toString()) ?? 0;
      if (s > 0 && s % slotAraligi != 0) {
        uyumsuz = true;
        break;
      }
    }

    if (uyumsuz) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50, 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.red.shade200)
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Zaman Dilimi Uyumsuzluğu!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
                        Text("Hizmet süreleriniz mevcut $slotAraligi dk'lık ajanda yapısına uymuyor.", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _topluAjandaOnarim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("AJANDAYI ŞİMDİ ONAR VE DÜZELT", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (slotAraligi != ideal) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.shade200)),
          child: Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Ajanda Optimizasyonu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    Text("Mevcut hizmetlerinize göre ajanda dilimlerini $ideal dk yaparak daha düzenli bir görünüm sağlayabilirsiniz.", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _topluAjandaOnarim,
                child: const Text("OPTİMİZE ET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
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
        _yonetimKarti(
          icon: Icons.calendar_month,
          baslik: "Günlük Ajanda",
          altBaslik: "Saatleri Yönet",
          renk: Colors.blue,
          onTap: () async {
            final navigator = Navigator.of(context);
            int ideal = _idealSlotHesapla();
            if (slotAraligi != ideal) {
              bool basarili = await _topluAjandaOnarim();
              if (!basarili || !mounted) return;
            }
            navigator.push(MaterialPageRoute(builder: (c) => EsnafAjandaEkrani(esnaf: _guncelEsnaf)));
          },
        ),
        _yonetimKarti(
          icon: Icons.history,
          baslik: "Randevu Kayıtları",
          altBaslik: "Onaylananlar/Geçmiş",
          renk: Colors.indigo,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id, esnaf: widget.esnaf))),
        ),
        if (isTaksi) ...[
          _yonetimKarti(
            icon: Icons.table_chart,
            baslik: "Taksi Çizelge",
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
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      altBaslik,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aracı Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pController, decoration: const InputDecoration(labelText: "Plaka"), textCapitalization: TextCapitalization.characters),
            TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Şoför Adı")),
            TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Şoför Telefon"), keyboardType: TextInputType.phone),
          ],
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
    );
  }

  void _yeniAracEkle() {
    final pController = TextEditingController();
    final sAdController = TextEditingController();
    final sTelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Araç Ekle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pController, decoration: const InputDecoration(labelText: "Plaka"), textCapitalization: TextCapitalization.characters),
            TextField(controller: sAdController, decoration: const InputDecoration(labelText: "Şoför Adı")),
            TextField(controller: sTelController, decoration: const InputDecoration(labelText: "Şoför Telefon"), keyboardType: TextInputType.phone),
          ],
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
              if (pController.text.isNotEmpty) {
                setState(() {
                  araclar.add({
                    'plaka': pController.text.trim().toUpperCase(),
                    'soforAd': sAdController.text.trim(),
                    'soforTel': sTelController.text.trim(),
                    'durum': 'Müsait',
                    'durakta': false,
                  });
                  _degisiklikVar = true;
                });
                pController.dispose();
                sAdController.dispose();
                sTelController.dispose();
                Navigator.pop(context);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
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
          onPressed: () {
            String yeni = "";
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Yeni Kanal"),
                content: TextField(onChanged: (v) => yeni = v, decoration: const InputDecoration(hintText: "Örn: Masa 1")),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(onPressed: () {
            final temizYeni = yeni.trim();
            if (temizYeni.isNotEmpty) {
              setState(() { kanallar.add(temizYeni); _degisiklikVar = true; });
              Navigator.pop(context);
            }
          }, child: const Text("Ekle")),
                ],
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("Kanal Ekle"),
        ),
      ],
    );
  }

  void _kanalDuzenle(int idx) {
    final controller = TextEditingController(text: kanallar[idx]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kanalı Düzenle"),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Kanal Adı"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(onPressed: () {
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
              }
              Navigator.pop(context);
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
            TextButton(onPressed: () {
              if (isim.trim().isNotEmpty) {
                setState(() {
                  personeller[idx] = {"isim": isim.trim(), "kanal": kanal};
                  _degisiklikVar = true;
                });
                Navigator.pop(context);
              }
            }, child: const Text("Güncelle")),
          ],
        );
      },
    );
  }

  void _hizmetDuzenle(int idx) {
    var h = hizmetler[idx];
    String isim = h["isim"] ?? "";
    int sure = h["sure"] ?? 30;
    double ucret = (h["ucret"] ?? 0).toDouble();
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
                TextFormField(
                  initialValue: isim,
                  onChanged: (v) => isim = v,
                  decoration: const InputDecoration(labelText: "Hizmet Adı"),
                ),
                TextFormField(
                  initialValue: sure.toString(),
                  onChanged: (v) => sure = int.tryParse(v) ?? 30,
                  decoration: const InputDecoration(labelText: "Süre (Dakika)"),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  initialValue: ucret.toString().replaceAll(".0", ""),
                  onChanged: (v) => ucret = double.tryParse(v) ?? 0,
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
                if (isim.isNotEmpty) {
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
                }
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
              builder: (context) => AlertDialog(
                title: const Text("Yeni Personel"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(onChanged: (v) => isim = v, decoration: const InputDecoration(labelText: "Personel Adı")),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: "",
                      items: [
                        const DropdownMenuItem(value: "", child: Text("Tüm Kanallar")),
                        ...kanallar.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                      ],
                      onChanged: (v) {
                        kanal = v ?? "";
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
            String isim = "";
            int sure = 30;
            double ucret = 0;
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
                        TextField(onChanged: (v) => isim = v, decoration: const InputDecoration(labelText: "Hizmet Adı")),
                        TextField(
                          onChanged: (v) => sure = int.tryParse(v) ?? 30,
                          decoration: const InputDecoration(labelText: "Süre (Dakika)"),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          onChanged: (v) => ucret = double.tryParse(v) ?? 0,
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
                      if (isim.isNotEmpty) {
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
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.esnaf.isletmeAdi, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _verileriTazele),
          ],
        ),
        body: DurakTakipIcerigi(
          esnaf: widget.esnaf,
          soforTel: widget.soforTel,
          araclar: araclar,
          onKaydet: () => _kaydet(sessiz: true),
        ),
      );
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
            IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _esnafDuzenleFormu),
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

            // SLOT UYUMSUZLUK KONTROLÜ
            bool slotUyumsuz = false;
            for (var h in hizmetler) {
              int hSure = int.tryParse(h['sure'].toString()) ?? 0;
              if (hSure > 0 && hSure % slotAraligi != 0) {
                slotUyumsuz = true;
                break;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (slotUyumsuz)
                  // UYARI BANNERLARI
                  _uyariBanneri(),

                  if (bekleyenler.isNotEmpty)
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
                  _yonetimButonlari(),
                  const SizedBox(height: 15),

                  if (!_isSofor) ...[
                    if (widget.esnaf.kategori == 'Taksi') ...[
                      _bolumKart(
                        baslik: "Filo Yönetimi",
                        initiallyExpanded: false,
                        icerik: _filoWidget()
                      ),
                      const SizedBox(height: 15),
                    ],
                    _bolumKart(
                      baslik: "Mesai Saatleri",
                      initiallyExpanded: false,
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
                          if (!(acilisSaat == "00:00" && kapanisSaat == "00:00")) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _saatSecici("Açılış", acilisSaat, (v) => setState(() { acilisSaat = v; _degisiklikVar = true; })),
                                const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                                _saatSecici("Kapanış", kapanisSaat, (v) => setState(() { kapanisSaat = v; _degisiklikVar = true; })),
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
                    _bolumKart(baslik: "Randevu Kanalları", initiallyExpanded: false, bilgiAciklama: _getKanalAciklama(), icerik: _kanallarWidget()),
                    if (widget.esnaf.kategori != 'Taksi')
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

class DurakTakipIcerigi extends StatelessWidget {
  final dynamic esnaf;
  final String? soforTel;
  final List<Map<String, dynamic>> araclar;
  final VoidCallback onKaydet;

  const DurakTakipIcerigi({
    super.key,
    required this.esnaf,
    this.soforTel,
    required this.araclar,
    required this.onKaydet,
  });

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> siraliAraclar = List.from(araclar);
    siraliAraclar.sort((a, b) {
      int timeA = a['siraZamani'] ?? 0;
      int timeB = b['siraZamani'] ?? 0;
      return timeA.compareTo(timeB);
    });

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: siraliAraclar.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, idx) {
        final arac = siraliAraclar[idx];
        final bool durakta = arac['durakta'] ?? false;
        final String durum = arac['durum'] ?? 'Müsait';
        final bool kendiAraci = soforTel != null && arac['soforTel'] == soforTel;

        Color durumRengi = Colors.green;
        IconData durumIkonu = Icons.local_taxi;

        if (durum == 'Meşgul') {
          durumRengi = Colors.red;
          durumIkonu = Icons.do_not_disturb_on;
        } else if (durum == 'Mola') {
          durumRengi = Colors.purple;
          durumIkonu = Icons.coffee;
        }

        if (durakta) {
          durumRengi = Colors.orange;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: durumRengi.withValues(alpha: 0.1),
            child: Icon(durumIkonu, color: durumRengi, size: 22),
          ),
          title: Row(
            children: [
              Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (kendiAraci)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: const Text("SİZ", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          subtitle: Text(
            "${arac['soforAd'] ?? 'Şoför Belirtilmemiş'} - $durum ${durakta ? '(Durakta)' : ''}",
            style: const TextStyle(fontSize: 13),
          ),
          trailing: (soforTel == null || kendiAraci)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: durakta ? Colors.orange.shade50 : Colors.green.shade50,
                          foregroundColor: durakta ? Colors.orange : Colors.green,
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (!durakta) {
                            try {
                              Position pos = await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
                              );
                              
                              double lat = (esnaf is EsnafModeli) ? esnaf.konum.latitude : (esnaf['konum']?['latitude'] ?? 0.0);
                              double lon = (esnaf is EsnafModeli) ? esnaf.konum.longitude : (esnaf['konum']?['longitude'] ?? 0.0);

                              double hamMesafe = Geolocator.distanceBetween(
                                pos.latitude,
                                pos.longitude,
                                lat,
                                lon,
                              );

                              double netMesafe = hamMesafe - pos.accuracy;
                              if (netMesafe < 0) netMesafe = 0;

                              double limit = (esnaf is EsnafModeli)
                                  ? esnaf.konumDogrulamaMesafesi
                                  : (esnaf['konumDogrulamaMesafesi']?.toDouble() ?? 10.0);

                              if (netMesafe > limit) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Icon(Icons.location_off, color: Colors.red, size: 32),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Durakta Değilsiniz",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            "Sıraya girmek için durağın ${limit.round()} metre yakınında olmalısınız.\n\n"
                                            "Ölçülen: ${hamMesafe < 1000 ? "${hamMesafe.toStringAsFixed(1)} m" : "${(hamMesafe / 1000).toStringAsFixed(2)} km"}\n"
                                            "Hata Payı: ±${pos.accuracy < 1000 ? "${pos.accuracy.toStringAsFixed(1)} m" : "${(pos.accuracy / 1000).toStringAsFixed(2)} km"}\n"
                                            "Net Mesafe: ${netMesafe < 1000 ? "${netMesafe.toStringAsFixed(1)} m" : "${(netMesafe / 1000).toStringAsFixed(2)} km"}",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam")),
                                      ],
                                    ),
                                  );
                                }
                                return;
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Konum doğrulanamadı. Lütfen GPS'i kontrol edin."), backgroundColor: Colors.orange),
                                );
                              }
                              return;
                            }
                          }

                          arac['durakta'] = !durakta;
                          if (arac['durakta']) {
                            arac['siraZamani'] = DateTime.now().millisecondsSinceEpoch;
                            arac['durum'] = "Müsait";
                          } else {
                            arac['siraZamani'] = 0;
                          }
                          onKaydet();
                        },
                        child: Text(kendiAraci ? (durakta ? "Sıradan Çık" : "Sıraya Gir") : (durakta ? "Sıradan Çıkar" : "Sıraya Al")),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      height: 40,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 24),
                        onSelected: (String yeniDurum) {
                          arac['durum'] = yeniDurum;
                          onKaydet();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'Müsait', child: Text("Müsait", style: TextStyle(fontSize: 14))),
                          const PopupMenuItem(value: 'Meşgul', child: Text("Meşgul", style: TextStyle(fontSize: 14))),
                          const PopupMenuItem(value: 'Mola', child: Text("Mola", style: TextStyle(fontSize: 14))),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

