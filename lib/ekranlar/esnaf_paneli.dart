import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/bildirim_servisi.dart';
import '../servisler/konum_servisi.dart';
import 'durak_takip_ekrani.dart';
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

  bool get _isSofor => widget.soforTel != null;

  StreamSubscription? _talepAboneligi;
  StreamSubscription? _esnafAboneligi;
  Timer? _konumTimer;

  @override
  void initState() {
    super.initState();
    BildirimServisi.bildirimDinle(widget.esnaf.telefon);
    _taksiTalepleriniDinle();
    _esnafVerileriniDinle();
    
    if (_isSofor) {
      _otomatikKonumPaylasiminiBaslat();
    }
    _adController = TextEditingController(text: widget.esnaf.isletmeAdi);
    _telController = TextEditingController(text: widget.esnaf.telefon);
    _ilController = TextEditingController(text: widget.esnaf.il);
    _ilceController = TextEditingController(text: widget.esnaf.ilce);
    _adresController = TextEditingController(text: widget.esnaf.adres);
    _latController = TextEditingController(text: widget.esnaf.konum.latitude.toString());
    _lonController = TextEditingController(text: widget.esnaf.konum.longitude.toString());

    _adController.addListener(_onTextChanged);
    _telController.addListener(_onTextChanged);
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
          if (data['soforTel'] != null && _isSofor && data['soforTel'] != widget.soforTel) {
            continue;
          }
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
                "Yeni Taksi Talebi!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _talepSatiri(Icons.person, "Müşteri", data['musteriAd'] ?? 'Müşteri'),
                    const SizedBox(height: 10),
                    _talepSatiri(Icons.location_on, "Adres", data['adres'] ?? 'Seçilen Konum'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Talebi üstlenmek istiyor musunuz?",
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

                        // 2. Aracı sıradan çıkar ve meşgul yap (Tüm ekranlarda güncellenmesi için)
                        if (plaka != null) {
                          var esDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
                          if (esDoc.exists) {
                            List<dynamic> gAraclar = List.from(esDoc.data()?['araclar'] ?? []);
                            int i = gAraclar.indexWhere((a) => a['plaka'] == plaka);
                            if (i != -1) {
                              gAraclar[i]['durakta'] = false;
                              gAraclar[i]['siraZamani'] = 0;
                              gAraclar[i]['durum'] = 'Meşgul'; // Listede kırmızıya döner
                              await esDoc.reference.update({'araclar': gAraclar});
                            }
                          }
                        }

                        if (context.mounted) Navigator.pop(context);
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

  Widget _talepSatiri(IconData ikon, String baslik, String icerik) {
    return Row(
      children: [
        Icon(ikon, size: 18, color: Colors.indigo.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(icerik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
              TextField(controller: _adController, decoration: const InputDecoration(labelText: "İşletme Adı")),
              TextField(controller: _telController, decoration: const InputDecoration(labelText: "Telefon"), keyboardType: TextInputType.phone),
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

  void _verileriTazele() async {
    var doc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
    if (doc.exists && mounted) {
      var data = doc.data()!;
      setState(() {
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
    try {
      await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
        'isletmeAdi': _adController.text,
        'telefon': _telController.text,
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
        'personeller': personeller,
        'araclar': araclar.map((a) {
          // Eski 'sofor' alanını temizle (artık soforAd ve soforTel kullanılıyor)
          final yeniArac = Map<String, dynamic>.from(a);
          yeniArac.remove('sofor');
          return yeniArac;
        }).toList(),
      });
      if (!mounted) return;
      setState(() => _degisiklikVar = false);
      if (!sessiz) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tüm ayarlar başarıyla kaydedildi!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    }
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
            MaterialPageRoute(builder: (c) => DurakTakipEkrani(esnaf: widget.esnaf, soforTel: widget.soforTel)),
          );
        },
      );
    }

    return Column(
      children: [
        Row(
          children: [
            if (isTaksi) ...[
              Expanded(
                child: _ozelButon(
                  ikon: Icons.local_taxi,
                  renk: Colors.green,
                  metin: "Canlı Durak\nTakip",
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.push(MaterialPageRoute(builder: (c) => DurakTakipEkrani(esnaf: widget.esnaf, soforTel: widget.soforTel)));
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _ozelButon(
                ikon: Icons.list_alt,
                renk: Colors.indigo,
                metin: "Randevu\nYönetimi",
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.push(MaterialPageRoute(builder: (c) => EsnafAjandaEkrani(esnaf: widget.esnaf)));
                },
              ),
            ),
            if (!isTaksi) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ozelButon(
                  ikon: Icons.tune,
                  renk: Colors.orange,
                  metin: "İşletme\nParametreleri",
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await navigator.push(MaterialPageRoute(builder: (c) => EsnafParametreEkrani(esnafId: widget.esnaf.id)));
                    _verileriTazele();
                  },
                ),
              ),
            ]
          ],
        ),
        if (isTaksi) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ozelButon(
                  ikon: Icons.tune,
                  renk: Colors.orange,
                  metin: "İşletme\nParametreleri",
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await navigator.push(MaterialPageRoute(builder: (c) => EsnafParametreEkrani(esnafId: widget.esnaf.id)));
                    _verileriTazele();
                  },
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _ozelButon({required IconData ikon, required Color renk, required String metin, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Column(
          children: [
            Icon(ikon, color: renk, size: 28),
            const SizedBox(height: 8),
            Text(metin, textAlign: TextAlign.center, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
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
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("${arac['soforAd'] ?? "İsimsiz"} (${arac['soforTel'] ?? "No Yok"})", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _aracDuzenle(idx),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        araclar.removeAt(idx);
                        // Kalan araçların sıralamasını (siraZamani) bozmamak için dokunmuyoruz,
                        // sadece listeden çıkarıyoruz.
                        _degisiklikVar = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _yeniAracEkle,
          icon: const Icon(Icons.add),
          label: const Text("Yeni Araç Ekle"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            backgroundColor: Colors.blue.shade50,
            foregroundColor: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  void _aracDuzenle(int index) {
    var arac = araclar[index];
    TextEditingController pController = TextEditingController(text: arac['plaka']);
    TextEditingController sAdController = TextEditingController(text: arac['soforAd']);
    TextEditingController sTelController = TextEditingController(text: arac['soforTel']);

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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                araclar[index]['plaka'] = pController.text.trim().toUpperCase();
                araclar[index]['soforAd'] = sAdController.text.trim();
                araclar[index]['soforTel'] = sTelController.text.trim();
                _degisiklikVar = true;
              });
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              if (pController.text.isNotEmpty && sAdController.text.isNotEmpty) {
                setState(() {
                  araclar.add({
                    "plaka": pController.text.trim().toUpperCase(),
                    "soforAd": sAdController.text.trim(),
                    "soforTel": sTelController.text.trim(),
                    "durakta": false,
                    "durum": "Müsait",
                    "konum": null,
                    "siraZamani": DateTime.now().millisecondsSinceEpoch, // Kuyruk sırası için zaman damgası
                  });
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
                  onPressed: () => setState(() { kanallar.removeAt(idx); _degisiklikVar = true; }),
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
                title: const Text("Yeni Kanal (Masa/Oda/Koltuk)"),
                content: TextField(onChanged: (v) => yeni = v, decoration: const InputDecoration(hintText: "Örn: Masa 1")),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                  TextButton(onPressed: () {
                    if (yeni.isNotEmpty) {
                      setState(() { kanallar.add(yeni); _degisiklikVar = true; });
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
    String kanal = kanallar[idx];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kanalı Düzenle"),
        content: TextFormField(
          initialValue: kanal,
          onChanged: (v) => kanal = v,
          decoration: const InputDecoration(labelText: "Kanal Adı (Masa/Oda/Koltuk)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(onPressed: () {
            if (kanal.isNotEmpty) {
              setState(() {
                kanallar[idx] = kanal;
                _degisiklikVar = true;
              });
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
    String kanal = p["kanal"] ?? "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Personeli Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: isim,
              onChanged: (v) => isim = v,
              decoration: const InputDecoration(labelText: "Personel Adı"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: kanal,
              items: [
                const DropdownMenuItem(value: "", child: Text("Tüm Kanallar")),
                ...kanallar.map((k) => DropdownMenuItem(value: k, child: Text(k))),
              ],
              onChanged: (v) => kanal = v ?? "",
              decoration: const InputDecoration(labelText: "Bağlı Olduğu Kanal"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(onPressed: () {
            if (isim.isNotEmpty) {
              setState(() {
                personeller[idx] = {"isim": isim, "kanal": kanal};
                _degisiklikVar = true;
              });
              Navigator.pop(context);
            }
          }, child: const Text("Güncelle")),
        ],
      ),
    );
  }

  void _hizmetDuzenle(int idx) {
    var h = hizmetler[idx];
    String isim = h["isim"] ?? "";
    int sure = h["sure"] ?? 30;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hizmeti Düzenle"),
        content: Column(
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          TextButton(onPressed: () {
            if (isim.isNotEmpty) {
              setState(() {
                hizmetler[idx] = {"isim": isim, "sure": sure};
                if (idx < _hizmetSureControllerList.length) {
                  _hizmetSureControllerList[idx].text = sure.toString();
                }
                _degisiklikVar = true;
              });
              Navigator.pop(context);
            }
          }, child: const Text("Güncelle")),
        ],
      ),
    );
  }

  Widget _personellerWidget() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text("Randevular Personel Adına Alınsın"),
          subtitle: const Text("Müşteriler randevu alırken personel seçebilir."),
          value: _personelOdakli,
          onChanged: (v) => setState(() { _personelOdakli = v; _degisiklikVar = true; }),
        ),
        const Divider(),
        ...personeller.asMap().entries.map((entry) {
          int idx = entry.key;
          var p = entry.value;
          return ListTile(
            title: Text(p["isim"] ?? "İsimsiz"),
            subtitle: Text("Kanal: ${p["kanal"]?.toString().isEmpty ?? true ? 'Tümü' : p["kanal"]}"),
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
                      initialValue: kanal,
                      items: [
                        const DropdownMenuItem(value: "", child: Text("Tüm Kanallar")),
                        ...kanallar.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                      ],
                      onChanged: (v) => kanal = v ?? "",
                      decoration: const InputDecoration(labelText: "Bağlı Olduğu Kanal"),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                  TextButton(onPressed: () {
                    if (isim.isNotEmpty) {
                      setState(() { personeller.add({"isim": isim, "kanal": kanal}); _degisiklikVar = true; });
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
          return ListTile(
            title: Text(h["isim"] ?? "Hizmet"),
            subtitle: Text("${h["sure"] ?? 30} Dakika"),
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
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Yeni Hizmet"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(onChanged: (v) => isim = v, decoration: const InputDecoration(labelText: "Hizmet Adı")),
                    TextField(
                      onChanged: (v) => sure = int.tryParse(v) ?? 30,
                      decoration: const InputDecoration(labelText: "Süre (Dakika)"),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                  TextButton(onPressed: () {
                    if (isim.isNotEmpty) {
                      setState(() {
                        hizmetler.add({"isim": isim, "sure": sure});
                        _hizmetSureControllerList.add(TextEditingController(text: sure.toString()));
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
          label: const Text("Hizmet Ekle"),
        ),
      ],
    );
  }

  Widget _bolumKart({required String baslik, required Widget icerik, String? bilgiAciklama, bool initiallyExpanded = true}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            if (bilgiAciklama != null)
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                onPressed: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(title: Text(baslik), content: Text(bilgiAciklama), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Anladım"))]),
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: icerik,
          ),
        ],
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
          Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deger == "Seçilmedi" ? Colors.red : Colors.blue)),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_degisiklikVar) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Değişiklikler Kaydedilmedi!"),
        content: const Text("Yaptığınız değişiklikler var. Kaydetmeden çıkmak istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("HAYIR")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("EVET, ÇIK"),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (bekleyenler.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (c) => EsnafRandevuYonetimEkrani(esnafId: widget.esnaf.id))
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notification_important, color: Colors.orange),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  "${bekleyenler.length} Randevu Onay Bekliyor",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
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
                        baslik: "Filo Yönetimi (Araç Kayıtları)", 
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
                                    ? "Sistem her gün her saat açık" 
                                    : "Mesai saatleri geçerli",
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
                                    content: Text(value ? "7/24 Modu Aktif Edildi" : "Özel Mesai Moduna Geçildi"),
                                    backgroundColor: value ? Colors.orange : Colors.blue,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _saatSecici("Açılış", acilisSaat, (v) => setState(() { acilisSaat = v; _degisiklikVar = true; })),
                              const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                              _saatSecici("Kapanış", kapanisSaat, (v) => setState(() { kapanisSaat = v; _degisiklikVar = true; })),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Randevu Aralığı (Slot)", style: TextStyle(color: Colors.grey)),
                              DropdownButton<int>(
                                value: slotAraligi,
                                items: [15, 30, 45, 60].map((m) => DropdownMenuItem(value: m, child: Text("$m dk"))).toList(),
                                onChanged: (v) => setState(() { slotAraligi = v!; _degisiklikVar = true; }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _bolumKart(baslik: "Çalışma Günleri", initiallyExpanded: false, icerik: _gunlerIcerik()),
                    _bolumKart(baslik: "Randevu Kanalları", initiallyExpanded: false, bilgiAciklama: _getKanalAciklama(), icerik: _kanallarWidget()),
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
                            Text("KAYDET", 
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
      padding: const EdgeInsets.all(16),
      itemCount: siraliAraclar.length,
      separatorBuilder: (context, index) => const Divider(),
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
          leading: CircleAvatar(
            backgroundColor: durumRengi.withValues(alpha: 0.1),
            child: Icon(durumIkonu, color: durumRengi),
          ),
          title: Row(
            children: [
              Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold)),
              if (kendiAraci)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: const Text("Siz", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          subtitle: Text("${arac['soforAd'] ?? 'Şoför Belirtilmemiş'} - $durum ${durakta ? '(Durakta)' : ''}"),
          trailing: (soforTel == null || kendiAraci)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        arac['durakta'] = !durakta;
                        if (arac['durakta']) {
                          arac['siraZamani'] = DateTime.now().millisecondsSinceEpoch;
                          arac['durum'] = 'Müsait';
                        } else {
                          arac['siraZamani'] = 0;
                        }
                        onKaydet();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: durakta ? Colors.orange.shade50 : Colors.green.shade50,
                        foregroundColor: durakta ? Colors.orange : Colors.green,
                        elevation: 0,
                      ),
                      child: Text(
                        kendiAraci ? (durakta ? "Sıradan Çık" : "Sıraya Gir") : (durakta ? "Sıradan Çıkar" : "Sıraya Al"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (String yeniDurum) {
                        arac['durum'] = yeniDurum;
                        onKaydet();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'Müsait', child: Text("Müsait")),
                        const PopupMenuItem(value: 'Meşgul', child: Text("Meşgul")),
                        const PopupMenuItem(value: 'Mola', child: Text("Mola")),
                      ],
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
