import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:almely_randevu/ekranlar/giris.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/onesignal_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'package:almely_randevu/ekranlar/esnaf_ajanda_ekrani.dart';
import 'package:almely_randevu/ekranlar/esnaf_parametre_ekrani.dart';
import 'package:almely_randevu/ekranlar/esnaf_randevu_onay_ekrani.dart';

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
  List<Map<String, dynamic>> personeller = [];
  bool _personelOdakli = false;
  bool _degisiklikVar = false;
  final Map<String, String> _kanalDegisimleri = {};
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

  final List<TextEditingController> _hizmetSureControllerList = [];
  String _gpsDurum = "Konumu Güncelle";
  final _konumServisi = KonumServisi();
  late EsnafModeli _guncelEsnaf;

  StreamSubscription? _esnafAboneligi;

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

    personeller = (widget.esnaf.personeller ?? []).map((p) {
      if (p is Map) return Map<String, dynamic>.from(p);
      return {"isim": p.toString(), "kanal": ""};
    }).toList();

    for (var h in hizmetler) {
      _hizmetSureControllerList.add(TextEditingController(text: h["sure"].toString()));
    }

    final cs = widget.esnaf.calismaSaatleri;
    if (cs != null) {
      slotAraligi = cs['slotDakika'] ?? cs['slotAraligi'] ?? 30;
      if (cs['acilis'] != null) acilisSaat = cs['acilis'];
      if (cs['kapanis'] != null) kapanisSaat = cs['kapanis'];
      _is724 = cs['is724'] ?? (acilisSaat == "00:00" && kapanisSaat == "00:00");

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
    _esnafAboneligi?.cancel();
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
      final List globalPersoneller = personeller;
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

        if (cleanKanalNames.isNotEmpty) {
          docIds = cleanKanalNames.map((k) => "${tarihId}_$k").toList();
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
        'kanallar': globalKanallar.map((k) => k.toString().trim()).toList(),
        'aktifGunler': tumAktifGunler,
        'hizmetler': hizmetler,
        'personeller': personeller,
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
        hizmetler = List<Map<String, dynamic>>.from(data['hizmetler'] ?? []);
        kanallar = List<String>.from(data['kanallar'] ?? []);
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
          'acilis': _is724 ? "00:00" : acilisSaat,
          'kapanis': _is724 ? "00:00" : kapanisSaat,
          'is724': _is724,
          'slotDakika': slotAraligi,
        },
        'hizmetler': hizmetler,
        'kanallar': kanallar,
        'personeller': personeller,
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5, // Metinler büyüdüğü için oran biraz azaltıldı
      children: [
        if (!_guncelEsnaf.randevuAlinmasin && _guncelEsnaf.ajandayiKendimAyarlayacagim)
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
            final controller = TextEditingController();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Yeni Kanal"),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: "Kanal Adı"),
                  textCapitalization: TextCapitalization.words,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
                  TextButton(
                    onPressed: () {
                      final ad = controller.text.trim();
                      if (ad.isNotEmpty) {
                        setState(() {
                          kanallar.add(ad);
                          _degisiklikVar = true;
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Ekle"),
                  ),
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
        // initialValue güncellemelerinde sorun çıkmaması için state-güvenli controller yaklaşımı
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
                TextFormField(
                  controller: isimController,
                  decoration: const InputDecoration(labelText: "Hizmet Adı"),
                ),
                TextFormField(
                  controller: sureController,
                  decoration: const InputDecoration(
                    labelText: "Süre (Dakika)",
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
            final isimController = TextEditingController();
            final sureController = TextEditingController(text: "30");
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
                        TextField(controller: isimController, decoration: const InputDecoration(labelText: "Hizmet Adı")),
                        TextField(
                          controller: sureController,
                          decoration: const InputDecoration(labelText: "Süre (Dakika)"),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_adController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _cikisYap(context),
            tooltip: "Çıkış Yap",
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _verileriTazele),
          const SizedBox(width: 48), // global ? için yer
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
                  if (_guncelEsnaf.ajandayiKendimAyarlayacagim)
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

                  _yonetimButonlari(),
                  const SizedBox(height: 15),

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
                          if (_is724) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _saatSecici(
                                    "Nöbet Başlangıç",
                                    _nobetBaslangic,
                                    (v) => setState(() {
                                      _nobetBaslangic = v;
                                      _degisiklikVar = true;
                                    })
                                  ),
                                  const Icon(Icons.swap_horiz, color: Colors.grey),
                                  _saatSecici(
                                    "Nöbet Bitiş",
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
                          if (!_is724) ...[
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
                      baslik: "Randevu Kanalları",
                      initiallyExpanded: false,
                      bilgiAciklama: _getKanalAciklama(),
                      icerik: _kanallarWidget()
                    ),
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
              ),
            );
          },
        ),
    );
  }

}


