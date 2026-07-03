import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/ekranlar/taksi_cizelge_ekrani.dart';

class EsnafAjandaEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  const EsnafAjandaEkrani({super.key, required this.esnaf});

  @override
  State<EsnafAjandaEkrani> createState() => _EsnafAjandaEkraniState();
}

class _EsnafAjandaEkraniState extends State<EsnafAjandaEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  DateTime _seciliTarih = DateTime.now();
  DateTime? _baslangicTarihi;
  DateTime? _bitisTarihi;
  
  String? _seciliAcilisSaat;
  String? _seciliKapanisSaat;
  int _slotAraligi = 30;
  bool _setupVarsayilanlariYuklendi = false;

  bool _ogleArasiVar = false;
  String _ogleBaslangic = "12:00";
  String _ogleBitis = "13:00";
  final Set<String> _seciliKanallar = {};
  
  bool _birGunCalisBirGunYat = false;
  DateTime? _birGunCalisIlkGun;
  int _periyotDeger = 1;
  String _periyotBirim = "Ay"; // Gün, Ay, Yıl
  late TextEditingController _periyotController;

  late Stream<EsnafModeli> _esnafStream;
  Stream<DocumentSnapshot>? _ajandaStream;

  final Map<String, bool> _calismaGunleri = {
    "Pazartesi": true,
    "Salı": true,
    "Çarşamba": true,
    "Perşembe": true,
    "Cuma": true,
    "Cumartesi": true,
    "Pazar": true,
  };

  @override
  void initState() {
    super.initState();
    _esnafStream = _firestoreServisi.esnafGetir(widget.esnaf.id);
    
    if (widget.esnaf.kanallar != null && widget.esnaf.kanallar!.isNotEmpty) {
      final k = widget.esnaf.kanallar!.first;
      String kanalId;
      if (k is Map) {
        kanalId = k['ad']?.toString() ?? k['plaka']?.toString() ?? k['aracTuru']?.toString() ?? k.toString();
      } else {
        kanalId = k.toString();
      }
      _seciliKanallar.add(kanalId);
    } else if (widget.esnaf.kategori == 'Taksi' && (widget.esnaf.aracOdakliSistem || widget.esnaf.randevularPersonelAdinaAlinsin) && widget.esnaf.araclar.isNotEmpty) {
      _seciliKanallar.add(widget.esnaf.araclar.first['plaka']);
    } else {
      _seciliKanallar.add("Uygulama");
    }
    
    _seciliAcilisSaat = widget.esnaf.calismaSaatleri?['acilis'] ?? "09:00";
    _seciliKapanisSaat = widget.esnaf.calismaSaatleri?['kapanis'] ?? "18:00";
    _periyotController = TextEditingController(text: _periyotDeger.toString());
    
    // Her zaman hesaplanan ideal değeri kullan
    _slotAraligi = _hesaplaIdealSlot(widget.esnaf.hizmetler);


    _ajandaStreamGuncelle();
    
    // [YENİ] Esnaf için her sayfada canlı bildirim dinleyiciyi mühürleyelim
    BildirimServisi.bildirimDinle(widget.esnaf.telefon, context: context);
  }

  @override
  void dispose() {
    _periyotController.dispose();
    super.dispose();
  }

  void _ajandaStreamGuncelle() {
    if (widget.esnaf.id.isEmpty) return;
    setState(() {
      // Eğer araçlar seçiliyse Durak dışındaki ilk kanalı dinle, yoksa ilkini seç
      String? kanal = _seciliKanallar.firstWhere((k) => k != 'Durak', orElse: () => _seciliKanallar.isNotEmpty ? _seciliKanallar.first : "");
      
      _ajandaStream = _firestoreServisi.gunlukAjandaSnapStream(
        widget.esnaf.id, 
        _seciliTarih, 
        kanal.isNotEmpty ? kanal : null
      );
    });
  }

  int _hesaplaIdealSlot(List<dynamic>? hizmetler) {
    if (hizmetler == null || hizmetler.isEmpty) return 30;
    List<int> sureler = hizmetler
        .map((h) => int.tryParse(h['sure'].toString()) ?? 0)
        .where((s) => s > 0)
        .toList();
    if (sureler.isEmpty) return 30;

    int gcd(int a, int b) {
      while (b != 0) {
        var t = b;
        b = a % b;
        a = t;
      }
      return a;
    }

    int sonuc = sureler[0];
    for (int i = 1; i < sureler.length; i++) {
      sonuc = gcd(sonuc, sureler[i]);
    }
    
    // 15 ve 30 söz konusuysa, 15 dk en idealidir.
    // gcd(15, 30) = 15 sonucunu zaten verecektir.
    // Eğer sonuç 30'un böleni ise (5, 10, 15), bunu kullanmaya devam et.

    if (sonuc < 5) return 5;
    if (sonuc > 120) return 120;
    return sonuc;
  }

  Future<void> _saatSec(bool acilis) async {
    String? mevcut = acilis ? _seciliAcilisSaat : _seciliKapanisSaat;
    TimeOfDay initial;
    
    if (mevcut != null && mevcut != "24:00") {
      try {
        initial = TimeOfDay.fromDateTime(DateFormat("HH:mm").parse(mevcut));
      } catch (e) {
        initial = acilis ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 0, minute: 0);
      }
    } else {
      initial = acilis ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 0, minute: 0);
    }

    final t = await showTimePicker(
      context: context, 
      initialTime: initial, 
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );

    if (t != null) {
      if (!mounted) return;
      setState(() {
        final s = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
        if (acilis) {
          _seciliAcilisSaat = s;
        } else {
          _seciliKapanisSaat = s;
        }
      });
    }
  }


  Future<bool> _topluAjandaOnarim(EsnafModeli esnaf) async {
    if (!mounted) return false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    int idealSlot = _hesaplaIdealSlot(esnaf.hizmetler);

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
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      // Esnafın güncel mesai saatlerini, kanal ve personel yapısını al
      String guncelAcilis = esnaf.calismaSaatleri?['acilis'] ?? "09:00";
      String guncelKapanis = esnaf.calismaSaatleri?['kapanis'] ?? "18:00";
      int guncelSlot = esnaf.calismaSaatleri?['slotDakika'] ?? esnaf.calismaSaatleri?['slotAraligi'] ?? idealSlot;
      List guncelKanallar = esnaf.kanallar ?? [];
      List guncelPersoneller = esnaf.personeller ?? [];

      final String bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String seciliTarihStr = DateFormat('yyyy-MM-dd').format(_seciliTarih);

      // Benzersiz tarihleri ayıkla (yyyy-MM-dd) ve sadece BUGÜN + GELECEK olanları al
      Set<String> tarihler = (esnaf.aktifGunler ?? [])
          .map((e) => e.toString().split('_')[0])
          .where((t) => t.compareTo(bugun) >= 0) // Geçmişe dokunma
          .toSet();
      
      // Seçili tarih bugün veya gelecekse ekle
      if (seciliTarihStr.compareTo(bugun) >= 0) {
        tarihler.add(seciliTarihStr);
      }
      tarihler.add(bugun);

      List<String> yeniAktifGunler = [];
      int operationCount = 0;

      for (var tarihId in tarihler) {
        // Çok kanallı yapı desteği (Suffix mantığını Panel ile eşitle)
        List<String> docIds = [];
        if (guncelKanallar.isNotEmpty && esnaf.kategori != 'Taksi') {
          docIds = guncelKanallar.map((k) {
            if (k is Map) return "${tarihId}_${k['ad'] ?? k['plaka'] ?? k['aracTuru']}";
            return "${tarihId}_$k";
          }).toList();
        } else if (esnaf.kategori == 'Taksi' && esnaf.araclar.isNotEmpty) {
          docIds = esnaf.araclar.map((a) => "${tarihId}_${a['plaka']}").toList();
        } else {
          docIds = ["${tarihId}_Uygulama"];
        }

        for (var dId in docIds) {
          yeniAktifGunler.add(dId);
          final docRef = FirebaseFirestore.instance
              .collection('esnaflar')
              .doc(esnaf.id)
              .collection('ajanda')
              .doc(dId);
              
          batch.set(docRef, {
            'tarih': tarihId,
            'slotDakika': guncelSlot,
            'slotAraligi': guncelSlot,
            'acilis': guncelAcilis,
            'kapanis': guncelKapanis,
            'kanallar': guncelKanallar,
            'personeller': guncelPersoneller,
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
      List<String> gecmisAktifGunler = (esnaf.aktifGunler ?? [])
          .where((e) => e.toString().split('_')[0].compareTo(bugun) < 0)
          .map((e) => e.toString())
          .toList();

      final tumAktifGunler = <String>{...gecmisAktifGunler, ...yeniAktifGunler}.toList();

      batch.update(FirebaseFirestore.instance.collection('esnaflar').doc(esnaf.id), {
        'calismaSaatleri.slotDakika': guncelSlot,
        'calismaSaatleri.slotAraligi': guncelSlot,
        'calismaSaatleri.acilis': guncelAcilis,
        'calismaSaatleri.kapanis': guncelKapanis,
        'aktifGunler': tumAktifGunler,
      });

      await batch.commit();
      
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop(); // Loader'ı kapat
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Ajanda yapısı $guncelSlot dk ($guncelAcilis-$guncelKapanis) olarak onarıldı."), backgroundColor: Colors.green),
      );
      
      return true;
    } catch (e) {
      if (!mounted) return false;
      Navigator.of(context, rootNavigator: true).pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  void _aracKiralamaHizliKurulum(EsnafModeli esnaf) async {
    bool? onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hızlı Ajanda Kurulumu"),
        content: const Text(
          "Tüm araçlarınız için bugünden itibaren 30 günlük 7/24 ajanda programı otomatik olarak oluşturulacaktır.\n\n"
          "Mevcut randevularınız etkilenmez. Devam etmek istiyor musunuz?"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            child: const Text("Evet, Kurulumu Başlat"),
          ),
        ],
      ),
    );

    if (onay != true || !mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.purple),
                SizedBox(height: 15),
                Text("Otomatik Yapılandırılıyor...", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Lütfen bekleyin", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      )
    );

    try {
      final List<DateTime> tarihler = [];
      final bugun = DateTime.now();
      for (int i = 0; i < 30; i++) {
        tarihler.add(DateTime(bugun.year, bugun.month, bugun.day + i));
      }

      final List<String> tumKanalIsimleri = (esnaf.kanallar ?? []).map<String>((k) {
        if (k is Map) return (k['ad'] ?? k['plaka'] ?? k['aracTuru'] ?? '').toString().trim();
        return k.toString().trim();
      }).where((k) => k.isNotEmpty).toList();

      for (String kanal in tumKanalIsimleri) {
        // Araç Kiralama için 24 saatlik periyot başlangıç saatine göre ayarlanır
        String baslangic = esnaf.nobetBaslangic ?? "00:00";
        await _firestoreServisi.ajandaOlustur(
          esnafId: esnaf.id,
          tarihler: tarihler,
          kanal: kanal,
          acilis: baslangic,
          kapanis: baslangic,
          slotAraligi: _slotAraligi,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Loader'ı kapat
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("30 günlük ajanda başarıyla yapılandırıldı."), backgroundColor: Colors.purple)
      );
      _ajandaStreamGuncelle();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _ajandaOlustur(EsnafModeli esnaf) async {
    final is724 = esnaf.calismaSaatleri?['acilis'] == '00:00' && esnaf.calismaSaatleri?['kapanis'] == '00:00';

    if (_birGunCalisBirGunYat || esnaf.kategori == 'Taksi') {
      if (_birGunCalisIlkGun == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen başlangıç günü seçin")));
        return;
      }
      _baslangicTarihi = _birGunCalisIlkGun;
      if (_periyotBirim == "Gün") {
        _bitisTarihi = _birGunCalisIlkGun!.add(Duration(days: _periyotDeger));
      } else if (_periyotBirim == "Ay") {
        _bitisTarihi = DateTime(_birGunCalisIlkGun!.year, _birGunCalisIlkGun!.month + _periyotDeger, _birGunCalisIlkGun!.day);
      } else {
        _bitisTarihi = DateTime(_birGunCalisIlkGun!.year + _periyotDeger, _birGunCalisIlkGun!.month, _birGunCalisIlkGun!.day);
      }
    }

    if (_baslangicTarihi == null || _bitisTarihi == null || _seciliAcilisSaat == null || _seciliKapanisSaat == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun")));
      return;
    }

    if (_seciliKanallar.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen en az bir kanal seçin")));
      return;
    }

    // Çakışma kontrolü ve Akıllı Güncelleme
    List<String> mevcutAjandalar = [];
    List<DateTime> olusturulacakTarihler = [];

    int gunSayisi = _bitisTarihi!.difference(_baslangicTarihi!).inDays;
    
    if (_birGunCalisBirGunYat) {
      // 1/1 Sistemi Mantığı
      for (String kanal in _seciliKanallar.where((k) => k != 'Durak')) {
        DateTime? ilkGun = _birGunCalisIlkGun ?? _baslangicTarihi;
        if (ilkGun == null) continue;
        
        DateTime tempGun = ilkGun;
        while (tempGun.isBefore(_bitisTarihi!.add(const Duration(days: 1)))) {
          String tStr = DateFormat('yyyy-MM-dd').format(tempGun);
          String tKanal = kanal.trim();
          String docId = tKanal.isNotEmpty ? "${tStr}_$tKanal" : tStr;
          
          if ((esnaf.aktifGunler ?? []).contains(docId)) {
            mevcutAjandalar.add("${DateFormat('dd/MM').format(tempGun)} ($tKanal)");
          }
          tempGun = tempGun.add(const Duration(days: 2));
        }
      }
    } else {
      // Normal Mantık
      for (int i = 0; i <= gunSayisi; i++) {
        DateTime gun = _baslangicTarihi!.add(Duration(days: i));
        String gunAdi = DateFormat('EEEE', 'tr_TR').format(gun);
        
        if (is724 || _calismaGunleri[gunAdi] == true) {
          olusturulacakTarihler.add(gun);
          String tStr = DateFormat('yyyy-MM-dd').format(gun);
          
          for (String kanal in _seciliKanallar) {
            String tKanal = kanal.trim();
            String docId = tKanal.isNotEmpty ? "${tStr}_$tKanal" : tStr;
            if ((esnaf.aktifGunler ?? []).contains(docId)) {
               mevcutAjandalar.add("${DateFormat('dd/MM').format(gun)} ($tKanal)");
            }
          }
        }
      }
    }

    if (!_birGunCalisBirGunYat && olusturulacakTarihler.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uygun gün bulunamadı")));
      return;
    }

    int secim = 1; // 1: Güncelle, 2: Sadece Eksikler
    if (mevcutAjandalar.isNotEmpty) {
      int? sonuc = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sync, color: Colors.orange),
              SizedBox(width: 10),
              Text("Ajanda Defterini Güncelle"),
            ],
          ),
          content: Text(
            "Seçtiğiniz aralıkta (${mevcutAjandalar.length} kayıt) zaten ajanda defteri kaydı bulunuyor.\n\n"
            "Bu işlem mevcut randevularınızı SILMEZ, sadece çalışma saatlerini ve zaman dilimlerini (slot) günceller.\n\n"
            "Mevcut kayıtları güncelleyebilir veya sadece eksik günleri ekleyerek devam edebilirsiniz."
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text("Vazgeç")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text("Sadece Eksikleri Ekle"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 1),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text("Evet, Güncelle"),
            ),
          ],
        ),
      );
      if (sonuc == null || sonuc == 0) return;
      secim = sonuc;
    }
    
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      if (_birGunCalisBirGunYat) {
        for (String kanal in _seciliKanallar.where((k) => k != 'Durak')) {
          DateTime? ilkGun = _birGunCalisIlkGun ?? _baslangicTarihi;
          if (ilkGun == null) continue;

          List<DateTime> kanalTarihleri = [];
          DateTime tempGun = ilkGun;
          while (tempGun.isBefore(_bitisTarihi!.add(const Duration(days: 1)))) {
            if (secim == 2) {
              String tStr = DateFormat('yyyy-MM-dd').format(tempGun);
              String tKanal = kanal.trim();
              String docId = tKanal.isNotEmpty ? "${tStr}_$tKanal" : tStr;
              if (!(esnaf.aktifGunler ?? []).contains(docId)) {
                kanalTarihleri.add(tempGun);
              }
            } else {
              kanalTarihleri.add(tempGun);
            }
            tempGun = tempGun.add(const Duration(days: 2));
          }

          if (kanalTarihleri.isNotEmpty) {
            await _firestoreServisi.ajandaOlustur(
              esnafId: widget.esnaf.id,
              tarihler: kanalTarihleri,
              kanal: kanal.trim(),
              acilis: _seciliAcilisSaat!,
              kapanis: _seciliKapanisSaat!,
              ogleBaslangic: _ogleArasiVar ? _ogleBaslangic : null,
              ogleBitis: _ogleArasiVar ? _ogleBitis : null,
              slotAraligi: _slotAraligi,
            );
          }
        }
      } else {
        for (String kanal in _seciliKanallar) {
          List<DateTime> tarihler = List.from(olusturulacakTarihler);
          if (secim == 2) {
            tarihler.removeWhere((t) {
              String tStr = DateFormat('yyyy-MM-dd').format(t);
              String docId = kanal.trim().isNotEmpty ? "${tStr}_${kanal.trim()}" : tStr;
              return (esnaf.aktifGunler ?? []).contains(docId);
            });
          }

          if (tarihler.isNotEmpty) {
            String baslangic = (is724 && esnaf.kategori == 'Araç Kiralama') 
                ? (esnaf.nobetBaslangic ?? "00:00") 
                : (is724 ? "00:00" : _seciliAcilisSaat!);
            
            String bitis = (is724 && esnaf.kategori == 'Araç Kiralama')
                ? baslangic
                : (is724 ? "00:00" : _seciliKapanisSaat!);

            await _firestoreServisi.ajandaOlustur(
              esnafId: widget.esnaf.id,
              tarihler: tarihler,
              kanal: kanal.trim(),
              acilis: baslangic,
              kapanis: bitis,
              ogleBaslangic: (!is724 && _ogleArasiVar) ? _ogleBaslangic : null,
              ogleBitis: (!is724 && _ogleArasiVar) ? _ogleBitis : null,
              slotAraligi: _slotAraligi,
            );
          }
        }
      }
      
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text("Ajanda Defteri kaydı başarıyla oluşturuldu"), backgroundColor: Colors.green));
      _ajandaStreamGuncelle();
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  void _ajandaSilOnay() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Ajanda Defteri Kaydını Sil"),
        content: Text("${DateFormat('dd/MM/yyyy').format(_seciliTarih)} tarihli ajanda defteri kaydını seçili ${_seciliKanallar.length} araç/kanal için silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              // Onaylı randevu kontrolü (Seçili tüm kanallar için)
              bool onayliVar = false;
              for (var kanal in _seciliKanallar) {
                if (await _firestoreServisi.onayliRandevuVarMi(widget.esnaf.id, _seciliTarih, kanal)) {
                  onayliVar = true;
                  break;
                }
              }
              
              if (!mounted) return;

              if (onayliVar) {
                navigator.pop(); // Onay kutusunu kapat
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Hata"),
                    content: const Text("Seçili araçlardan birinde bu tarihte onaylanmış randevu bulunduğu için ajandayı silemezsiniz. Lütfen önce randevuları iptal edin."),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam"))],
                  ),
                );
                return;
              }

              // 1. Onay kutusunu kapat
              navigator.pop();
              
              // 2. İşlem devam ederken yükleme göstergesi aç
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              try {
                for (var kanal in _seciliKanallar) {
                  await _firestoreServisi.ajandaSil(widget.esnaf.id, _seciliTarih, kanal);
                }
                
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text("Ajanda Defteri kayıtları silindi"), backgroundColor: Colors.green)
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _topluAjandaSilFormu() {
    DateTimeRange? secilenAralik;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Toplu Ajanda Defteri Sil"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Silmek istediğiniz tarih aralığını seçin. Onaylı randevusu olan günler silinmeyecektir.", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text("Tarih Aralığı Seç"),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: const Locale('tr', 'TR'),
                );
                if (range != null) {
                  secilenAralik = range;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (secilenAralik == null) {
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Lütfen tarih aralığı seçin")));
                return;
              }

              navigator.pop(); // Diyaloğu kapat
              
              showDialog(
                context: context, 
                barrierDismissible: false, 
                builder: (c) => const Center(child: CircularProgressIndicator())
              );

              try {
                for (var kanal in _seciliKanallar) {
                  await _firestoreServisi.topluAjandaSil(
                    esnafId: widget.esnaf.id,
                    baslangic: secilenAralik!.start,
                    bitis: secilenAralik!.end,
                    kanal: kanal,
                  );
                }
                
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text("Seçilen aralıktaki boş ajanda defteri kayıtları silindi"), backgroundColor: Colors.green)
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop(); // Yükleme göstergesini kapat
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text("Seçilenleri Sil"),
          ),
        ],
      ),
    );
  }

  List<String> _slotlariUret(Map<String, dynamic> data, EsnafModeli esnaf) {
    List<String> list = [];
    try {
      String acilisStr = data['acilis'] ?? esnaf.calismaSaatleri?['acilis'] ?? "09:00";
      String kapanisStr = data['kapanis'] ?? esnaf.calismaSaatleri?['kapanis'] ?? "19:00";
      int slot = data['slotDakika'] ?? data['slotAraligi'] ?? 
                 esnaf.calismaSaatleri?['slotDakika'] ?? 
                 esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

      if (slot <= 0) return [];

      DateTime bas = DateFormat("HH:mm").parse(acilisStr);
      DateTime bit = DateFormat("HH:mm").parse(kapanisStr);
      
      // Eğer başlangıç ve bitiş aynıysa (7/24 tam gün) veya bitiş başlangıçtan önceyse (ertesi gün)
      if (bit.isBefore(bas) || bit.isAtSameMomentAs(bas) || kapanisStr == "00:00" || kapanisStr == "24:00") {
        bit = bit.add(const Duration(days: 1));
      }
      
      DateTime temp = bas;
      while (temp.isBefore(bit)) {
        list.add(DateFormat("HH:mm").format(temp));
        temp = temp.add(Duration(minutes: slot));
      }
    } catch (e) {
      debugPrint("Slot hatası: $e");
    }
    return list;
  }

  int _saatiDakikayaCevir(String saat) {
    final parcalar = saat.split(':');
    return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
  }

  String _dakikayiSaateCevir(int toplamDakika) {
    int saat = (toplamDakika ~/ 60) % 24;
    int dakika = toplamDakika % 60;
    return "${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}";
  }

  bool _isSlotInRange(String slot, RandevuModeli r, Map<String, dynamic> ajanda, EsnafModeli esnaf) {
    // 1. Slotun zamanını belirle (Seçili gün + slot saati)
    final sParcalar = slot.split(':');
    DateTime slotTime = DateTime(_seciliTarih.year, _seciliTarih.month, _seciliTarih.day,
        int.parse(sParcalar[0]), int.parse(sParcalar[1]));

    // 2. Randevu aralığını belirle
    final rParcalar = r.saat.split(':');
    DateTime rStart = DateTime(r.tarih.year, r.tarih.month, r.tarih.day,
        int.parse(rParcalar[0]), int.parse(rParcalar[1]));
    DateTime rEnd = rStart.add(Duration(minutes: r.sure));

    // 3. Çakışma kontrolü (Slot zamanı, randevu başlangıç ve bitişi arasındaysa)
    return (slotTime.isAtSameMomentAs(rStart) || slotTime.isAfter(rStart)) && slotTime.isBefore(rEnd);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.esnaf.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Hata")),
        body: const Center(child: Text("Esnaf ID bulunamadı. Lütfen tekrar giriş yapın.")),
      );
    }
    return StreamBuilder<EsnafModeli>(
      stream: _esnafStream,
      builder: (context, esnafSnapshot) {
        final guncelEsnaf = esnafSnapshot.data ?? widget.esnaf;

        if (esnafSnapshot.hasData && !_setupVarsayilanlariYuklendi) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _seciliAcilisSaat = guncelEsnaf.calismaSaatleri?['acilis'] ?? _seciliAcilisSaat;
                _seciliKapanisSaat = guncelEsnaf.calismaSaatleri?['kapanis'] ?? _seciliKapanisSaat;
                
                int ideal = _hesaplaIdealSlot(guncelEsnaf.hizmetler);
                _slotAraligi = ideal;
                
                _setupVarsayilanlariYuklendi = true;
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text("${guncelEsnaf.isletmeAdi} Ajanda Defteri", style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              if (guncelEsnaf.kategori == 'Araç Kiralama')
                IconButton(
                  icon: const Icon(Icons.auto_fix_high, color: Colors.purple),
                  onPressed: () => _aracKiralamaHizliKurulum(guncelEsnaf),
                  tooltip: "30 Günlük Otomatik Kurulum",
                ),
              StreamBuilder<DocumentSnapshot>(
                stream: _ajandaStream,
                builder: (context, snapshot) {
                  bool exists = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;
                  if (!exists) return const SizedBox.shrink();

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data == null) return const SizedBox.shrink();

                  final kapaliSlotlarRaw = data['kapaliSlotlar'] ?? {};
                  final slotlar = _slotlariUret(data, guncelEsnaf);
                  
                  bool tumuKapali = false;
                  if (slotlar.isNotEmpty) {
                    if (kapaliSlotlarRaw is Map) {
                      tumuKapali = slotlar.every((s) => kapaliSlotlarRaw.containsKey(s));
                    } else if (kapaliSlotlarRaw is List) {
                      tumuKapali = slotlar.every((s) => kapaliSlotlarRaw.contains(s));
                    }
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.date_range_rounded, color: Colors.blue),
                        onPressed: () => _topluAjandaSilFormu(),
                        tooltip: "Tarih Aralığı Sil",
                      ),
                      IconButton(
                        icon: Icon(tumuKapali ? Icons.lock_open_rounded : Icons.lock_rounded, color: tumuKapali ? Colors.green : Colors.orange),
                        onPressed: () => _tumuKapatAcFormu(data, tumuKapali),
                        tooltip: tumuKapali ? "Tüm Günü Aç" : "Tüm Günü Kapat",
                      ),
                      IconButton(onPressed: _ajandaSilOnay, icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red)),
                    ],
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
            StreamBuilder<DocumentSnapshot>(
              stream: _ajandaStream,
              builder: (context, snapshot) {
                // Veri yüklenirken sessiz kal
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                
                final bool exists = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;
                final data = exists ? snapshot.data!.data() as Map<String, dynamic>? : null;

                int ideal = _hesaplaIdealSlot(guncelEsnaf.hizmetler);
                
                // Esnafın genel ayarlarındaki saatler (CANLI VERİ)
                String esnafAcilis = guncelEsnaf.calismaSaatleri?['acilis'] ?? "09:00";
                String esnafKapanis = guncelEsnaf.calismaSaatleri?['kapanis'] ?? "18:00";
                int esnafSlot = guncelEsnaf.calismaSaatleri?['slotDakika'] ?? guncelEsnaf.calismaSaatleri?['slotAraligi'] ?? ideal;
                
                // Ajanda verisi (varsa) - Tip güvenliği için toInt() ekliyoruz
                String ajandaAcilis = data?['acilis'] ?? esnafAcilis;
                String ajandaKapanis = data?['kapanis'] ?? esnafKapanis;
                int? mevcutSlot = (data?['slotDakika'] ?? data?['slotAraligi'])?.toInt();
                
                // Bugünü belirle
                final DateTime simdi = DateTime.now();
                final bool gecmisGun = _seciliTarih.isBefore(DateTime(simdi.year, simdi.month, simdi.day));

                // Uyumsuzluk Kontrolü (Sadece bugün ve gelecek için)
                bool saatUyumsuz = !gecmisGun && exists && (esnafAcilis != ajandaAcilis || esnafKapanis != ajandaKapanis);

                // Eğer mevcut slot hem ideal değilse hem de esnafın genel ayarı değilse uyumsuz say
                bool slotUyumsuz = !gecmisGun && exists && (mevcutSlot != null && mevcutSlot != ideal && mevcutSlot != esnafSlot);

                // Global ayar farklı olsa bile, eğer mevcut slot IDEAL ise veya MEVCUT ayar ise uyarıyı baskıla
                bool globalSlotFarkli = !gecmisGun && exists && (mevcutSlot != null && mevcutSlot != esnafSlot && mevcutSlot != ideal);
                
                // Personel/Kanal Kontrolü
                bool kanalUyumsuz = false;
                if (!gecmisGun && exists) {
                  final List globalKanallar = (guncelEsnaf.kanallar ?? []).map((e) => e.toString()).toList();
                  final List ajandaKanallari = (data?['kanallar'] ?? []).map((e) => e.toString()).toList();
                  
                  if (globalKanallar.length != ajandaKanallari.length) {
                    kanalUyumsuz = true;
                  } else {
                    for (var k in globalKanallar) {
                      if (!ajandaKanallari.contains(k)) {
                        kanalUyumsuz = true;
                        break;
                      }
                    }
                  }
                }

                // Seçili kanalın hala geçerli olup olmadığını kontrol et (Flicker engelleme)
                bool secimGecersiz = _seciliKanallar.isNotEmpty && 
                    !_seciliKanallar.every((k) => 
                        (guncelEsnaf.kanallar ?? []).map((e) {
                          if (e is Map) return e['ad']?.toString() ?? e['plaka']?.toString() ?? e['aracTuru']?.toString() ?? e.toString();
                          return e.toString();
                        }).contains(k) ||
                        (guncelEsnaf.kategori == 'Taksi' && guncelEsnaf.araclar.any((a) => a['plaka'] == k)) ||
                        k == "Uygulama"
                    );

                // Tam Senkronizasyon Kontrolü (Pointer Listesi ve İçerik Doğrulaması)
                bool pointerUyumsuz = false;
                if (!gecmisGun) {
                   final String tarihStr = DateFormat('yyyy-MM-dd').format(_seciliTarih);
                   
                   // 1. Beklenen ID'ler (Güncel Kanallara Göre)
                   List<String> beklenenIds = [];
                   if (guncelEsnaf.kategori == 'Taksi' && guncelEsnaf.araclar.isNotEmpty) {
                     beklenenIds = guncelEsnaf.araclar.map((a) => "${tarihStr}_${a['plaka']}").toList();
                   } else if (guncelEsnaf.kanallar != null && guncelEsnaf.kanallar!.isNotEmpty) {
                     beklenenIds = guncelEsnaf.kanallar!.map((k) => "${tarihStr}_$k").toList();
                   } else {
                     beklenenIds = ["${tarihStr}_Uygulama"];
                   }
                   
                   // 2. Mevcut Pointerlar (Esnaf dokümanındaki aktifGunler)
                   final List<String> mevcutPointerlar = (guncelEsnaf.aktifGunler ?? [])
                       .map((e) => e.toString())
                       .where((e) => e.startsWith(tarihStr))
                       .toList();
                   
                   // 3. Karşılaştırma: Sayı tutmalı ve her beklenen ID listede olmalı
                   if (beklenenIds.length != mevcutPointerlar.length) {
                     pointerUyumsuz = true;
                   } else {
                     for (var bId in beklenenIds) {
                       if (!mevcutPointerlar.contains(bId)) { pointerUyumsuz = true; break; }
                     }
                   }
                }
                
                // Final Karar: Herhangi bir uyumsuzluk varsa kırmızı onarma bannerını göster
                // ÖNEMLİ: Eğer ajanda verisi ile esnafın global ayarları (slot, saat) tutuyorsa (tolerans payı dahil), uyarı gösterme.
                bool kritikUyumsuzluk = (saatUyumsuz || slotUyumsuz || globalSlotFarkli || kanalUyumsuz || pointerUyumsuz);
                
                // Kontrol: Eğer slot'lar teknik olarak aynıysa veya slot aralığı 0'dan büyükse ve hizmet sürelerini bölüyorsa uyarıyı bastır
                if (mevcutSlot != null && ideal == mevcutSlot) {
                  kritikUyumsuzluk = false;
                }

                if (exists && !secimGecersiz && !gecmisGun && kritikUyumsuzluk) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.red.shade200),
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
                                    const Text(
                                      "Ayarlar Uyumsuz!",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)
                                    ),
                                    Text(
                                      slotUyumsuz 
                                        ? "Hizmet süreleriniz veya genel slot ayarınız ($esnafSlot dk) mevcut $mevcutSlot dk'lık ajanda yapısına uymuyor. Yeni ayarlara göre ajandanız $ideal dk aralıklarında güncellenecektir."
                                        : "İşletme ayarlarınızda (çalışma saatleri, personel vb.) değişiklik tespit edildi. Mevcut ajanda yapısı güncellenecektir.",
                                      style: const TextStyle(fontSize: 13, color: Colors.black87)
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final basarili = await _topluAjandaOnarim(guncelEsnaf);
                                if (basarili) {
                                  _ajandaStreamGuncelle();
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
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
              _tarihSecici(guncelEsnaf),
              const Divider(height: 1),
              _kanalSecici(guncelEsnaf),
              const Divider(height: 1),
              Expanded(
                child: _seciliKanallar.isEmpty 
                  ? _kanalSecilmediMesaji(guncelEsnaf)
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _firestoreServisi.taksiAjandasiSnapStream(guncelEsnaf.id, _seciliTarih),
                      builder: (context, taksiSnap) {
                        Map<String, dynamic> gunlukNobetVerisi = {};
                        if (taksiSnap.hasData && taksiSnap.data != null && taksiSnap.data!.exists) {
                          String gunKey = DateFormat('yyyy-MM-dd').format(_seciliTarih);
                          final dynamic rawData = taksiSnap.data!.get(gunKey);
                          if (rawData is Map) {
                            gunlukNobetVerisi = Map<String, dynamic>.from(rawData);
                          }
                        }

                        return StreamBuilder<DocumentSnapshot>(
                          stream: _ajandaStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            
                            String tarihStr = DateFormat('yyyy-MM-dd').format(_seciliTarih);
                            
                            bool herhangiBiriAktif = _seciliKanallar.any((kanal) {
                              String temizKanal = kanal.trim();
                              String anahtar = temizKanal.isNotEmpty ? "${tarihStr}_$temizKanal" : tarihStr;
                              return (guncelEsnaf.aktifGunler ?? []).contains(anahtar);
                            });

                            if (!herhangiBiriAktif) {
                              // Çizelge kontrolü: Eğer çizelgede 'I' (İstirahat) ise mesaj göster
                              if (guncelEsnaf.kategori == 'Taksi' && _seciliKanallar.length == 1) {
                                String plaka = _seciliKanallar.first;
                                if (gunlukNobetVerisi[plaka] == 'I') {
                                  return _istirahatGunuMesaji(guncelEsnaf);
                                }
                              }
                              return _ajandaKurulumFormu(guncelEsnaf);
                            }
                            
                            Map<String, dynamic> ajandaVerisi;
                            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                              ajandaVerisi = snapshot.data!.data() as Map<String, dynamic>? ?? guncelEsnaf.calismaSaatleri ?? {'acilis': '09:00', 'kapanis': '19:00', 'slotDakika': 30};
                            } else {
                              ajandaVerisi = guncelEsnaf.calismaSaatleri ?? {'acilis': '09:00', 'kapanis': '19:00', 'slotDakika': 30};
                            }
                            
                            // Eğer ajanda kuruluysa ama çizelgede 'I' ise, yine de uyarı verilebilir veya gösterilebilir.
                            // Burada mevcut randevuları görmek için slot görünümüne devam ediyoruz.
                            
                            // UYUMSUZLUK KONTROLÜ
                            int ideal = _hesaplaIdealSlot(guncelEsnaf.hizmetler);
                            int? mevcut = ajandaVerisi['slotDakika'] ?? ajandaVerisi['slotAraligi'];
                            bool uyumsuz = (mevcut != null && mevcut != ideal);
                            
                            if (uyumsuz) {
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: Colors.red.shade200),
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
                                                    Text("İdeal slot: $ideal dk. Mevcut: $mevcut dk. Randevularda kayma olabilir.", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                final basarili = await _topluAjandaOnarim(guncelEsnaf);
                                                if (basarili) {
                                                  _ajandaStreamGuncelle();
                                                }
                                              },
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
                                  ),
                                  Expanded(child: _gunlukSlotGorunumu(guncelEsnaf, ajandaVerisi)),
                                ],
                              );
                            }

                            return _gunlukSlotGorunumu(guncelEsnaf, ajandaVerisi);
                          },
                        );
                      }
                    ),
              ),
            ],
          ),
        );
      }
    );
  }


  void _tumuKapatAcFormu(Map<String, dynamic> data, bool ac) {
    if (ac) {
      for (var kanal in _seciliKanallar) {
        _firestoreServisi.gunuKapatAc(widget.esnaf.id, _seciliTarih, kanal, [], false);
      }
      return;
    }

    String? seciliNeden;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tüm Günü Kapat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kapatma nedeni seçin", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            StreamBuilder<List<String>>(
              stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final nedenler = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: null,
                  items: nedenler.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => seciliNeden = v,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (seciliNeden == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir neden seçin")));
                return;
              }
              final navigator = Navigator.of(ctx);
              final slotlar = _slotlariUret(data, widget.esnaf);
              final randevular = await _firestoreServisi.randevulariGetir(widget.esnaf.id, _seciliTarih).first;
              
              List<String> yeniKapatilacaklar = [];
              for (var s in slotlar) {
                bool dolu = randevular.any((r) => (_seciliKanallar.contains(r.randevuKanali)) && _isSlotInRange(s, r, data, widget.esnaf));
                if (!dolu) yeniKapatilacaklar.add(s);
              }
              for (var kanal in _seciliKanallar) {
                await _firestoreServisi.gunuKapatAc(widget.esnaf.id, _seciliTarih, kanal, yeniKapatilacaklar, true, neden: seciliNeden);
              }
              if (navigator.mounted) navigator.pop();
            },
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  void _aylikOzetTakvimiGoster(EsnafModeli esnaf) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime gosterilenAy = _seciliTarih;
        return StreamBuilder<EsnafModeli>(
          stream: _firestoreServisi.esnafGetir(esnaf.id),
          builder: (context, esnafSnapshot) {
            final guncelEsnaf = esnafSnapshot.data ?? esnaf;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Dolu günleri hesapla (aktifGunler listesinden)
                Set<int> doluGunler = {};
                for (var entry in guncelEsnaf.aktifGunler ?? []) {
                  if (entry.contains('_')) {
                    var parts = entry.split('_');
                    String datePart = parts[0];
                    String kanalPart = parts[1];
                    
                    // Seçili kanallardan biri için ajanda oluşturulmuş mu?
                    if (_seciliKanallar.contains(kanalPart)) {
                      DateTime? d = DateTime.tryParse(datePart);
                      if (d != null && d.year == gosterilenAy.year && d.month == gosterilenAy.month) {
                        doluGunler.add(d.day);
                      }
                    }
                  } else {
                    DateTime? d = DateTime.tryParse(entry);
                    if (d != null && d.year == gosterilenAy.year && d.month == gosterilenAy.month) {
                      doluGunler.add(d.day);
                    }
                  }
                }

                final ilkGun = DateTime(gosterilenAy.year, gosterilenAy.month, 1);
                final sonGun = DateTime(gosterilenAy.year, gosterilenAy.month + 1, 0);
                final bosluklar = (ilkGun.weekday - 1);

                return AlertDialog(
                  titlePadding: EdgeInsets.zero,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.black54),
                          onPressed: () => setDialogState(() => gosterilenAy = DateTime(gosterilenAy.year, gosterilenAy.month - 1)),
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'tr_TR').format(gosterilenAy).toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.black54),
                          onPressed: () => setDialogState(() => gosterilenAy = DateTime(gosterilenAy.year, gosterilenAy.month + 1)),
                        ),
                      ],
                    ),
                  ),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 350,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['Pt', 'Sa', 'Çr', 'Pr', 'Cu', 'Ct', 'Pz']
                              .map((g) => Expanded(child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12))))).toList(),
                        ),
                        const Divider(),
                        Expanded(
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                            itemCount: bosluklar + sonGun.day,
                            itemBuilder: (context, index) {
                              if (index < bosluklar) return const SizedBox.shrink();
                              int gun = index - bosluklar + 1;
                              bool dolu = doluGunler.contains(gun);
                              bool secili = gun == _seciliTarih.day && gosterilenAy.month == _seciliTarih.month && gosterilenAy.year == _seciliTarih.year;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _seciliTarih = DateTime(gosterilenAy.year, gosterilenAy.month, gun);
                                    _ajandaStreamGuncelle();
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: secili ? Colors.blue.shade100 : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: secili ? Border.all(color: Colors.blue, width: 1.5) : null,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          gun.toString(),
                                          style: TextStyle(
                                            fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                                            color: secili ? Colors.blue.shade900 : Colors.black87,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            color: dolu ? Colors.green : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.green),
                              SizedBox(width: 8),
                              Text("Çalışma Günü", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat")),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  Widget _ozelTarihSecici({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required EsnafModeli esnaf,
  }) {
    DateTime gosterilenAy = initialDate;
    DateTime secili = initialDate;

    return StreamBuilder<EsnafModeli>(
      stream: _firestoreServisi.esnafGetir(esnaf.id),
      builder: (context, snapshot) {
        final guncelEsnaf = snapshot.data ?? esnaf;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Set<int> doluGunler = {};
            for (var entry in guncelEsnaf.aktifGunler ?? []) {
              if (entry.contains('_')) {
                var parts = entry.split('_');
                if (_seciliKanallar.contains(parts[1])) {
                  DateTime? d = DateTime.tryParse(parts[0]);
                  if (d != null && d.year == gosterilenAy.year && d.month == gosterilenAy.month) {
                    doluGunler.add(d.day);
                  }
                }
              } else {
                DateTime? d = DateTime.tryParse(entry);
                if (d != null && d.year == gosterilenAy.year && d.month == gosterilenAy.month) {
                  doluGunler.add(d.day);
                }
              }
            }

            final ilkGun = DateTime(gosterilenAy.year, gosterilenAy.month, 1);
            final sonGun = DateTime(gosterilenAy.year, gosterilenAy.month + 1, 0);
            final bosluklar = (ilkGun.weekday - 1);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setDialogState(() => gosterilenAy = DateTime(gosterilenAy.year, gosterilenAy.month - 1)),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'tr_TR').format(gosterilenAy).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setDialogState(() => gosterilenAy = DateTime(gosterilenAy.year, gosterilenAy.month + 1)),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Pt', 'Sa', 'Çr', 'Pr', 'Cu', 'Ct', 'Pz'].map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))).toList(),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                      itemCount: sonGun.day + bosluklar,
                      itemBuilder: (context, index) {
                        if (index < bosluklar) return const SizedBox.shrink();
                        final gun = index - bosluklar + 1;
                        final buTarih = DateTime(gosterilenAy.year, gosterilenAy.month, gun);
                        final dolu = doluGunler.contains(gun);
                        final isSelected = secili.day == gun && secili.month == gosterilenAy.month && secili.year == gosterilenAy.year;

                        return GestureDetector(
                          onTap: () => setDialogState(() => secili = buTarih),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected ? Border.all(color: Colors.blue) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  gun.toString(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.blue : Colors.black,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (dolu)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: Colors.green),
                          SizedBox(width: 8),
                          Text("Çalışma Günü", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, secili),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text("Tamam"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tarihSecici(EsnafModeli esnaf) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left, size: 24), 
            onPressed: () {
              _seciliTarih = _seciliTarih.subtract(const Duration(days: 1));
              _ajandaStreamGuncelle();
            }
          ),
          TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.calendar_today, size: 20),
            label: Text(
              DateFormat('dd MMM yyyy', 'tr_TR').format(_seciliTarih), 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)
            ),
            onPressed: () => _aylikOzetTakvimiGoster(esnaf),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right, size: 24), 
            onPressed: () {
              _seciliTarih = _seciliTarih.add(const Duration(days: 1));
              _ajandaStreamGuncelle();
            }
          ),
        ],
      ),
    );
  }

  Widget _kanalSecici(EsnafModeli esnaf) {
    List<String> tumKanallar = [];
    
    // 1. Taksi ve Araç Odaklı ise, plakaları ekle
    final isTaksi = esnaf.kategori == 'Taksi';
    final aracModu = isTaksi && esnaf.aracOdakliSistem;

    if (isTaksi && (aracModu || esnaf.randevularPersonelAdinaAlinsin) && esnaf.araclar.isNotEmpty) {
      for (var arac in esnaf.araclar) {
        String plaka = arac['plaka'] ?? "";
        
        if (plaka.isNotEmpty && !tumKanallar.contains(plaka)) {
          tumKanallar.add(plaka);
        }
      }
    }
    
    // 2. Diğer kanalları da ekle (Eğer araç odaklı değilse veya ek kanal varsa)
    if (!aracModu && esnaf.kanallar != null && esnaf.kanallar!.isNotEmpty) {
      for (var k in esnaf.kanallar!) {
        String kanal;
        if (k is Map) {
          kanal = k['ad']?.toString() ?? k['plaka']?.toString() ?? k['aracTuru']?.toString() ?? k.toString();
        } else {
          kanal = k.toString();
        }
        
        if (kanal.isNotEmpty && !tumKanallar.contains(kanal)) {
          tumKanallar.add(kanal);
        }
      }
    }

    // Hiç kanal yoksa varsayılan bir kanal ekle (Hata almamak için)
    if (tumKanallar.isEmpty) {
      tumKanallar.add("Uygulama");
    }

    // Aktif kanal listede yoksa veya isim değişmişse ilkini seç
    bool secimGecersiz = _seciliKanallar.isNotEmpty && !_seciliKanallar.every((k) => tumKanallar.contains(k));
    
    if ((_seciliKanallar.isEmpty || secimGecersiz) && tumKanallar.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _seciliKanallar.clear();
            _seciliKanallar.add(tumKanallar.first);
            _ajandaStreamGuncelle();
          });
        }
      });
    }

    return Container(
      height: 65,
      width: double.infinity,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: tumKanallar.length,
        itemBuilder: (context, index) {
          String kanalAdi = tumKanallar[index];
          String? soforAdi;

          // Taksi ise şoför adını çek
          if (esnaf.kategori == 'Taksi' && (esnaf.aracOdakliSistem || esnaf.randevularPersonelAdinaAlinsin)) {
             final a = esnaf.araclar.cast<Map<String, dynamic>?>().firstWhere(
                (element) => element?['plaka'] == kanalAdi,
                orElse: () => null,
              );
              if (a != null) {
                soforAdi = a['soforAd'] ?? a['sofor'] ?? '';
              }
          }

          if (soforAdi == null && esnaf.randevularPersonelAdinaAlinsin) {
            final p = esnaf.personeller?.firstWhere(
              (element) => element is Map && element['kanal'] == kanalAdi,
              orElse: () => null,
            );
            if (p != null) soforAdi = p['isim'];
          }

          // Araç Kiralama için detay bilgisini çek
          if (esnaf.kategori == 'Araç Kiralama' && soforAdi == null) {
            final a = esnaf.kanallar?.firstWhere(
              (element) {
                if (element is! Map) return false;
                String name = element['ad']?.toString() ?? element['plaka']?.toString() ?? element['aracTuru']?.toString() ?? "";
                return name == kanalAdi;
              },
              orElse: () => null,
            );
            if (a != null && a is Map) {
              soforAdi = "${a['aracTuru'] ?? ''} ${a['vites'] ?? ''}".trim();
            }
          }

          final isSelected = _seciliKanallar.contains(kanalAdi);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              visualDensity: VisualDensity.comfortable,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(kanalAdi, 
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.blue.shade900
                    )
                  ),
                  if (soforAdi != null && soforAdi.isNotEmpty) 
                    Text(soforAdi, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white70 : Colors.black54)),
                ],
              ),
              selected: isSelected,
              selectedColor: Colors.blue,
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? Colors.blue : Colors.blue.shade100)
              ),
              showCheckmark: false,
              onSelected: (s) {
                String tarihStr = DateFormat('yyyy-MM-dd').format(_seciliTarih);
                bool herhangiBiriAktif = _seciliKanallar.any((k) {
                  String kTemiz = k.trim();
                  String anahtar = kTemiz.isNotEmpty ? "${tarihStr}_$kTemiz" : tarihStr;
                  return (widget.esnaf.aktifGunler ?? []).contains(anahtar);
                });

                setState(() {
                  if (s) {
                    if (herhangiBiriAktif) {
                      _seciliKanallar.clear();
                    }
                    _seciliKanallar.add(kanalAdi);
                  } else {
                    if (_seciliKanallar.length > 1) {
                      _seciliKanallar.remove(kanalAdi);
                    }
                  }
                  _ajandaStreamGuncelle();
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _kanalSecilmediMesaji(EsnafModeli esnaf) {
    String label = "bir kanal\nveya personel";
    if (esnaf.aracOdakliSistem) label = "bir araç";
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 80, color: Colors.blue.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            "Lütfen üst listeden $label seçin",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _istirahatGunuMesaji(EsnafModeli esnaf) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.nightlight_round, size: 70, color: Colors.orange.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              "${_seciliKanallar.first} için İstirahat Günü",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              "Bu araç bugün çalışmıyor (1/1 Dönüşüm Sistemi).\nRandevu eklemek için önce ajanda defteri kaydı oluşturmalısınız.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            if (esnaf.randevuAlinmasin == true)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  "(Randevu alımı şu an kapalıdır)",
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                // Manuel olarak ajanda oluşturma formunu göster
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("İstisna Durum"),
                    content: const Text("Bu araç bugün normalde istirahatte. Yine de ajanda defteri kaydı oluşturup randevu almak istiyor musunuz?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Setup formuna geçmek için geçici bir state veya dialog kullanılabilir
                          // Şimdilik sadece formu göstermesi için bir yol sunuyoruz
                          setState(() {
                             // Zorla formu göstermek için bir yöntem? 
                             // En temizi _ajandaKurulumFormu'nu bir bottomSheet veya Dialog olarak açmak
                          });
                        },
                        child: const Text("Evet, Defteri Oluştur"),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Yine de Defteri Oluştur"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ajandaKurulumFormu(EsnafModeli esnaf) {
    final is724 = esnaf.calismaSaatleri?['acilis'] == '00:00' && esnaf.calismaSaatleri?['kapanis'] == '00:00';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (esnaf.randevuAlinmasin == true)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "DİKKAT: İşletmenizde randevu alımı şu an kapalıdır. Yeni ajanda oluşturmanız müşterilerin randevu almasını sağlamayacaktır.",
                      style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          const Icon(Icons.event_busy, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Bu tarih için ajanda defteri kaydı henüz oluşturulmamış", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                          const Text("Ajanda Defteri Hazırlığı", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      if (_seciliKanallar.any((k) => k != 'Durak')) 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("${_seciliKanallar.where((k) => k != 'Durak').length} Araç Seçili", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                    ],
                  ),
                  if (esnaf.kategori == 'Taksi') ...[
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text("Seçili araçlar için çalışılacak ilk günü seç", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context, 
                                  initialDate: _birGunCalisIlkGun ?? _baslangicTarihi ?? DateTime.now(), 
                                  firstDate: DateTime.now().subtract(const Duration(days: 7)), 
                                  lastDate: DateTime.now().add(const Duration(days: 365))
                                );
                                if (d != null) setState(() => _birGunCalisIlkGun = d);
                              },
                              icon: const Icon(Icons.calendar_month, size: 20),
                              label: Text(
                                _birGunCalisIlkGun == null 
                                  ? "İlk Gün Seç" 
                                  : DateFormat('dd/MM/yyyy').format(_birGunCalisIlkGun!),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text("Ne kadarlık plan oluşturmak istiyorsunuz?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 40,
                                child: TextField(
                                  controller: _periyotController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: "Sayı",
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (v) {
                                    final val = int.tryParse(v);
                                    if (val != null && val > 0) {
                                      setState(() => _periyotDeger = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _periyotBirim,
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 15, color: Colors.black),
                                    items: ["Gün", "Ay", "Yıl"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                    onChanged: (v) => setState(() => _periyotBirim = v!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _birGunCalisBirGunYat ? null : () async {
                              final d = await showDialog<DateTime>(
                                context: context,
                                builder: (context) => _ozelTarihSecici(
                                  context: context,
                                  initialDate: _baslangicTarihi ?? _seciliTarih,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  esnaf: esnaf,
                                ),
                              );
                              if (d != null) setState(() => _baslangicTarihi = d);
                            },
                            child: Text(_baslangicTarihi == null ? "Başlangıç" : DateFormat('dd/MM/yyyy').format(_baslangicTarihi!)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _birGunCalisBirGunYat ? null : () async {
                              final d = await showDialog<DateTime>(
                                context: context,
                                builder: (context) => _ozelTarihSecici(
                                  context: context,
                                  initialDate: _bitisTarihi ?? _baslangicTarihi ?? _seciliTarih,
                                  firstDate: _baslangicTarihi ?? DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  esnaf: esnaf,
                                ),
                              );
                              if (d != null) setState(() => _bitisTarihi = d);
                            },
                            child: Text(_bitisTarihi == null ? "Bitiş" : DateFormat('dd/MM/yyyy').format(_bitisTarihi!)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (esnaf.kategori == 'Taksi') ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("1 Gün Çalış 1 Gün İstirahat (1/1)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      subtitle: const Text("Araçlar için dönüşümlü çalışma sistemi", style: TextStyle(fontSize: 13)),
                      value: _birGunCalisBirGunYat,
                      onChanged: (v) => setState(() => _birGunCalisBirGunYat = v),
                    ),
                    const Divider(),
                  ],
                  if (is724) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100, width: 1)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              _birGunCalisBirGunYat 
                                ? "İşletmeniz 7/24 modundadır. 1/1 sistemi seçili olduğu için mesai saatleri otomatik 00:00-00:00 olarak ayarlanacaktır."
                                : "İşletmeniz 7/24 çalışma modundadır. Gün ve saat seçimi yapmanıza gerek yoktur. Tüm günler otomatik olarak 00:00-00:00 arası oluşturulacaktır.",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!is724 || (_birGunCalisBirGunYat && !is724)) ...[
                    if (!_birGunCalisBirGunYat) ...[
                      const SizedBox(height: 20),
                      const Text("Çalışma Günleri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _calismaGunleri.keys.map((gun) => FilterChip(
                          label: Text(gun, style: const TextStyle(fontSize: 14)),
                          selected: _calismaGunleri[gun]!,
                          onSelected: (v) => setState(() => _calismaGunleri[gun] = v),
                        )).toList(),
                      ),
                    ],
                    if (!is724) ...[
                      const SizedBox(height: 20),
                      const Text("Mesai Saatleri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Başlangıç", style: TextStyle(fontSize: 14, color: Colors.green)), 
                              subtitle: Text(_seciliAcilisSaat ?? "--:--", style: const TextStyle(fontWeight: FontWeight.bold)), 
                              onTap: () => _saatSec(true)
                            )
                          ),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Bitiş", style: TextStyle(fontSize: 14, color: Colors.red)), 
                              subtitle: Text(_seciliKapanisSaat ?? "--:--", style: const TextStyle(fontWeight: FontWeight.bold)), 
                              onTap: () => _saatSec(false)
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text("Öğle Arası", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Öğle arası uygula", style: TextStyle(fontSize: 15)),
                        value: _ogleArasiVar,
                        onChanged: (v) => setState(() => _ogleArasiVar = v),
                      ),
                      if (_ogleArasiVar) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(_ogleBaslangic.split(":")[0]), minute: int.parse(_ogleBaslangic.split(":")[1])));
                                  if (t != null) setState(() => _ogleBaslangic = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                                },
                                child: Text("Başlangıç: $_ogleBaslangic"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(_ogleBitis.split(":")[0]), minute: int.parse(_ogleBitis.split(":")[1])));
                                  if (t != null) setState(() => _ogleBitis = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                                },
                                child: Text("Bitiş: $_ogleBitis"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      bool uyumsuzlukVar = false;
                      for (var h in esnaf.hizmetler ?? []) {
                        int sure = int.tryParse(h['sure'].toString()) ?? 0;
                        if (sure > 0 && sure % _slotAraligi != 0) {
                          uyumsuzlukVar = true;
                          break;
                        }
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: [5, 10, 15, 20, 30, 45, 60, 90, 120].contains(_slotAraligi) ? _slotAraligi : 30,
                            decoration: InputDecoration(
                              labelText: "Slot Aralığı (Dakika)", 
                              border: const OutlineInputBorder(),
                              focusedBorder: uyumsuzlukVar 
                                  ? const OutlineInputBorder(borderSide: BorderSide(color: Colors.orange, width: 2))
                                  : null,
                            ),
                            items: [5, 10, 15, 20, 30, 45, 60, 90, 120].map((e) => DropdownMenuItem(value: e, child: Text("$e dakika"))).toList(),
                            onChanged: (v) => setState(() => _slotAraligi = v!),
                          ),
                          if (uyumsuzlukVar)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Bazı hizmet süreleriniz ($_slotAraligi dk) ile tam bölünmüyor. Randevu alırken kaymalar olabilir.",
                                        style: TextStyle(color: Colors.orange.shade900, fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _ajandaOlustur(esnaf),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text("Ajanda Defterini Şimdi Oluştur ve Başlat", style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
          if (esnaf.kategori == 'Taksi')
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 20),
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiCizelgeEkrani(esnaf: esnaf))),
                icon: const Icon(Icons.table_chart),
                label: const Text("Nöbet Çizelgesine Git"),
              ),
            ),
        ],
      ),
    );
  }

  void _esnafRandevuEkleFormu(String saat, int slotDakika, List<dynamic> hizmetler, {List<dynamic>? esnafAraclar}) {
    final adController = TextEditingController();
    final telController = TextEditingController();
    List<Map<String, dynamic>> seciliHizmetler = [];
    List<String> seciliPlakalar = [];

    bool periyodik = false;
    String tekrarTipi = 'Haftalık'; // 'Günlük' veya 'Haftalık'
    int tekrarSayisi = 4; // Kaç gün veya kaç hafta

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("$saat Randevu Ekle"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: adController, decoration: const InputDecoration(labelText: "Müşteri Ad Soyad")),
                TextField(controller: telController, decoration: const InputDecoration(labelText: "Telefon Numarası"), keyboardType: TextInputType.phone),
                const SizedBox(height: 15),
                if (widget.esnaf.kategori == 'Taksi' && (widget.esnaf.aracOdakliSistem || widget.esnaf.randevularPersonelAdinaAlinsin) && esnafAraclar != null && esnafAraclar.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Araç Seçin (Çoklu Seçim)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: esnafAraclar.length,
                      itemBuilder: (context, index) {
                        final arac = esnafAraclar[index];
                        final plaka = arac['plaka'] ?? "";
                        final isSelected = seciliPlakalar.contains(plaka);
                        final sofor = arac['soforAd'] ?? arac['sofor'] ?? '';
                        return CheckboxListTile(
                          title: Text(sofor.isNotEmpty ? "$plaka ($sofor)" : plaka, style: const TextStyle(fontSize: 13)),
                          value: isSelected,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                seciliPlakalar.add(plaka);
                              } else {
                                seciliPlakalar.remove(plaka);
                              }
                            });
                          },
                          dense: true,
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
                CheckboxListTile(
                  title: const Text("Tekrarlayan Randevu", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Belirli aralıklarla otomatik ekle", style: TextStyle(fontSize: 11)),
                  value: periyodik,
                  onChanged: (v) => setModalState(() => periyodik = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (periyodik) ...[
                  DropdownButtonFormField<String>(
                    initialValue: tekrarTipi,
                    decoration: const InputDecoration(labelText: "Tekrar Aralığı", isDense: true),
                    items: ['Günlük', 'Haftalık'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setModalState(() => tekrarTipi = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: [2, 3, 4, 5, 6, 7, 14, 21, 28, 30].contains(tekrarSayisi) ? tekrarSayisi : 4,
                    decoration: InputDecoration(labelText: tekrarTipi == 'Günlük' ? "Kaç Gün Boyunca?" : "Kaç Hafta Boyunca?", isDense: true),
                    items: (tekrarTipi == 'Günlük' 
                      ? [2, 3, 4, 5, 6, 7, 14, 30] 
                      : [2, 3, 4, 5, 6, 8, 10, 12]
                    ).map((e) => DropdownMenuItem(value: e, child: Text("$e ${tekrarTipi == 'Günlük' ? 'Gün' : 'Hafta'}"))).toList(),
                    onChanged: (v) => setModalState(() => tekrarSayisi = v!),
                  ),
                ],
                const SizedBox(height: 15),
                const Text("Hizmet Seçin (Birden fazla seçilebilir)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const Divider(),
                ...hizmetler.map((h) {
                  bool secili = seciliHizmetler.any((x) => x['isim'] == h['isim']);
                  return CheckboxListTile(
                    title: Text("${h['isim']} (${h['sure']} dk)"),
                    value: secili,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          seciliHizmetler.add(Map<String, dynamic>.from(h));
                        } else {
                          seciliHizmetler.removeWhere((x) => x['isim'] == h['isim']);
                        }
                      });
                    },
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                if (adController.text.isEmpty || telController.text.isEmpty || seciliHizmetler.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurun")));
                  return;
                }
                
                int toplamSure = 0;
                String birlesikHizmet = seciliHizmetler.map((x) {
                  toplamSure += int.tryParse(x['sure'].toString()) ?? 0;
                  return x['isim'];
                }).join(' + ');

                // Taksi için araç seçimi kontrolü
                if (widget.esnaf.kategori == 'Taksi' && (widget.esnaf.aracOdakliSistem || widget.esnaf.randevularPersonelAdinaAlinsin) && seciliPlakalar.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text("Lütfen en az bir araç seçin")));
                  return;
                }

                showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

                try {
                  List<String> eklenecekKanallar = (widget.esnaf.kategori == 'Taksi' && (widget.esnaf.aracOdakliSistem || widget.esnaf.randevularPersonelAdinaAlinsin))
                      ? seciliPlakalar 
                      : [_seciliKanallar.isNotEmpty ? _seciliKanallar.first : ""];

                  int basariliSayisi = 0;
                  List<String> cakisanTarihlerPlakalar = [];

                  for (String kanal in eklenecekKanallar) {
                    // 1. Ana Randevu Çakışma Kontrolü
                    bool cakisiyor = await _firestoreServisi.randevuCakisiyorMu(
                      esnafId: widget.esnaf.id,
                      tarih: _seciliTarih,
                      saat: saat,
                      sure: toplamSure,
                      kanal: kanal,
                    );

                    if (cakisiyor) {
                      cakisanTarihlerPlakalar.add("${DateFormat('dd/MM').format(_seciliTarih)} ($kanal)");
                      continue;
                    }

                    final String seriId = periyodik ? "SERI_${DateTime.now().millisecondsSinceEpoch}_$kanal" : '';
                    final yeniRandevu = RandevuModeli(
                      id: '',
                      esnafId: widget.esnaf.id,
                      esnafAdi: widget.esnaf.isletmeAdi,
                      esnafTel: widget.esnaf.telefon,
                      kullaniciAd: adController.text,
                      kullaniciTel: telController.text,
                      tarih: _seciliTarih,
                      saat: saat,
                      sure: toplamSure,
                      hizmetAdi: birlesikHizmet,
                      durum: 'Onaylandı',
                      randevuKanali: kanal,
                      seriId: seriId,
                    );

                    await _firestoreServisi.randevuEkle(yeniRandevu);
                    basariliSayisi++;

                    // Periyodik Tekrar Mantığı
                    if (periyodik) {
                      for (int i = 1; i < tekrarSayisi; i++) {
                        int eklenecekGun = tekrarTipi == 'Günlük' ? i : i * 7;
                        DateTime gelecekTarih = _seciliTarih.add(Duration(days: eklenecekGun));
                        
                        bool pCakisiyor = await _firestoreServisi.randevuCakisiyorMu(
                          esnafId: widget.esnaf.id,
                          tarih: gelecekTarih,
                          saat: saat,
                          sure: toplamSure,
                          kanal: kanal,
                        );

                        if (!pCakisiyor) {
                          final tekrarRandevu = yeniRandevu.copyWith(tarih: gelecekTarih);
                          await _firestoreServisi.randevuEkle(tekrarRandevu);
                          basariliSayisi++;
                        } else {
                          cakisanTarihlerPlakalar.add("${DateFormat('dd/MM').format(gelecekTarih)} ($kanal)");
                        }
                      }
                    }
                  }

                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop(); // Loader'ı kapat
                  navigator.pop(); // Formu kapat
                  
                  String mesaj = eklenecekKanallar.length > 1 
                      ? "$basariliSayisi adet randevu (farklı araçlar için) oluşturuldu." 
                      : "Randevu eklendi.";
                  
                  if (periyodik && eklenecekKanallar.length == 1) {
                    mesaj = "$basariliSayisi adet randevu oluşturuldu.";
                  }

                  if (cakisanTarihlerPlakalar.isNotEmpty) {
                    mesaj += "\nÇakışma nedeniyle atlananlar: ${cakisanTarihlerPlakalar.join(', ')}";
                  }
                  
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("İşlem Sonucu"),
                      content: Text(mesaj),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Tamam"))],
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    messenger.showSnackBar(SnackBar(content: Text("Hata oluştu: $e"), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gunlukSlotGorunumu(EsnafModeli esnaf, Map<String, dynamic> ajanda) {
    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.randevulariGetir(esnaf.id, _seciliTarih),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final slotlar = _slotlariUret(ajanda, esnaf);
        final randevular = snapshot.data ?? [];
        final kapaliSlotlarRaw = ajanda['kapaliSlotlar'] ?? {};
        
        if (slotlar.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Hatalı saat ayarları. Lütfen mesai saatlerini kontrol edin.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12))));

        final Set<String> islenmisRandevular = {};
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: slotlar.length,
          itemBuilder: (context, index) {
            final saat = slotlar[index];
            final r = randevular.where((x) => (_seciliKanallar.contains(x.randevuKanali)) && _isSlotInRange(saat, x, ajanda, esnaf)).toList();
            
            int slotDakika = ajanda['slotDakika'] ?? ajanda['slotAraligi'] ?? 
                             esnaf.calismaSaatleri?['slotDakika'] ?? 
                             esnaf.calismaSaatleri?['slotAraligi'] ?? 30;

            String bitisSaati;
            if (r.isNotEmpty) {
              int baslangicDakika = _saatiDakikayaCevir(r.first.saat);
              bitisSaati = _dakikayiSaateCevir(baslangicDakika + r.first.sure);
            } else {
              bitisSaati = _dakikayiSaateCevir(_saatiDakikayaCevir(saat) + slotDakika);
            }

            if (r.isEmpty) {
              bool kapaliMi = false;
              String neden = "Kapatıldı";
              
              if (kapaliSlotlarRaw is Map) {
                kapaliMi = kapaliSlotlarRaw.containsKey(saat);
                neden = kapaliSlotlarRaw[saat] ?? "Kapatıldı";
              } else if (kapaliSlotlarRaw is List) {
                kapaliMi = kapaliSlotlarRaw.contains(saat);
              }

              bool ogleArasiMi = false;
              if (ajanda['ogleBaslangic'] != null && ajanda['ogleBitis'] != null) {
                int sDk = _saatiDakikayaCevir(saat);
                int oBasDk = _saatiDakikayaCevir(ajanda['ogleBaslangic']);
                int oBitDk = _saatiDakikayaCevir(ajanda['ogleBitis']);
                
                if (sDk >= oBasDk && sDk < oBitDk) {
                  if (saat == ajanda['ogleBaslangic']) {
                    ogleArasiMi = true;
                    kapaliMi = true;
                    neden = "Öğle Arası";
                  } else {
                    return const SizedBox.shrink();
                  }
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                height: 60,
                decoration: BoxDecoration(
                  color: ogleArasiMi ? Colors.blue.withValues(alpha: 0.05) : (kapaliMi ? Colors.grey.withValues(alpha: 0.05) : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ogleArasiMi 
                      ? Colors.blue.withValues(alpha: 0.2) 
                      : (kapaliMi ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1))
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 105,
                      decoration: BoxDecoration(
                        color: ogleArasiMi ? Colors.blue.withValues(alpha: 0.1) : (kapaliMi ? Colors.grey.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.02)),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                      ),
                      child: Center(
                        child: _saatGostergesi(
                          ogleArasiMi ? ajanda['ogleBaslangic'] : saat, 
                          ogleArasiMi ? ajanda['ogleBitis'] : bitisSaati, 
                          ogleArasiMi ? true : esnaf.slotAralikliGoster, 
                          ogleArasiMi ? Colors.blue : (kapaliMi ? Colors.grey : Colors.blue.shade700)
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: kapaliMi ? null : () => _esnafRandevuEkleFormu(saat, slotDakika, esnaf.hizmetler ?? [], esnafAraclar: esnaf.araclar),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Text(
                                ogleArasiMi ? "Öğle Arası" : (kapaliMi ? "Kapalı" : "Boş Slot"), 
                                style: TextStyle(
                                  color: ogleArasiMi ? Colors.blue : (kapaliMi ? Colors.grey.shade600 : Colors.black54), 
                                  fontSize: 17, 
                                  fontWeight: ogleArasiMi ? FontWeight.bold : FontWeight.w500,
                                )
                              ),
                              if (kapaliMi && neden.isNotEmpty && !ogleArasiMi)
                                Expanded(
                                  child: Text(
                                    " ($neden)", 
                                    style: const TextStyle(fontSize: 14, color: Colors.redAccent, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!ogleArasiMi) 
                      IconButton(
                        icon: Icon(kapaliMi ? Icons.lock_rounded : Icons.lock_open_rounded, color: kapaliMi ? Colors.red.shade300 : Colors.green.shade300, size: 26),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        onPressed: () => _slotKapatAcFormu(saat, kapaliMi),
                      ),
                    if (ogleArasiMi) 
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.restaurant_rounded, color: Colors.blue, size: 26),
                      ),
                    if (!kapaliMi) 
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.blue, size: 26),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        onPressed: () => _esnafRandevuEkleFormu(saat, slotDakika, esnaf.hizmetler ?? [], esnafAraclar: esnaf.araclar),
                      ),
                  ],
                ),
              );
            }

            return Column(
              children: r.map((randevu) {
                if (islenmisRandevular.contains(randevu.id)) return const SizedBox.shrink();
                islenmisRandevular.add(randevu.id);

                // Randevu zamanlarını belirle
                final rParcalar = randevu.saat.split(':');
                DateTime rStart = DateTime(randevu.tarih.year, randevu.tarih.month, randevu.tarih.day,
                    int.parse(rParcalar[0]), int.parse(rParcalar[1]));
                DateTime rEnd = rStart.add(Duration(minutes: randevu.sure));
                
                // Mevcut slot zamanını belirle
                final sParcalar = saat.split(':');
                DateTime currentSlot = DateTime(_seciliTarih.year, _seciliTarih.month, _seciliTarih.day,
                    int.parse(sParcalar[0]), int.parse(sParcalar[1]));

                bool isFirstSlot = (currentSlot.isAtSameMomentAs(rStart) || (currentSlot.isAfter(rStart) && currentSlot.subtract(Duration(minutes: slotDakika)).isBefore(rStart)));
                bool isLastSlot = currentSlot.add(Duration(minutes: slotDakika)).isAfter(rEnd) || currentSlot.add(Duration(minutes: slotDakika)).isAtSameMomentAs(rEnd);

                return Container(
                  margin: EdgeInsets.only(bottom: isLastSlot ? 6 : 0),
                  height: 70, 
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.05),
                    border: Border(
                      left: BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                      right: BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                      top: isFirstSlot ? BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1) : BorderSide.none,
                      bottom: isLastSlot ? BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1) : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 105,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.vertical(
                            top: isFirstSlot ? const Radius.circular(7) : Radius.zero,
                            bottom: isLastSlot ? const Radius.circular(7) : Radius.zero,
                          ),
                        ),
                        child: Center(
                          child: _saatGostergesi(
                            randevu.saat == saat ? randevu.saat : saat, 
                            bitisSaati, 
                            esnaf.slotAralikliGoster, 
                            Colors.orange.shade800
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _randevuIslemMenusu(randevu),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isFirstSlot) ...[
                                        Text(
                                          randevu.kullaniciAd, 
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange.shade900),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          randevu.hizmetAdi, 
                                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ] else 
                                        Text(
                                          "Kiralama Devam Ediyor...", 
                                          style: TextStyle(color: Colors.orange.shade700, fontSize: 13, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isFirstSlot) ...[
                                  if (_seciliKanallar.length > 1) 
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(randevu.randevuKanali ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ),
                                  Text(
                                    randevu.kullaniciTel, 
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isFirstSlot || isLastSlot)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                        )
                      else 
                        const SizedBox(width: 40),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }


  void _slotKapatAcFormu(String saat, bool kapali) {
    if (kapali) {
      for (var kanal in _seciliKanallar) {
        _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, kanal, saat, false);
      }
      return;
    }

    String? seciliNeden;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$saat Saati Kapat"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kapatma nedeni seçin", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            StreamBuilder<List<String>>(
              stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final nedenler = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: null,
                  items: nedenler.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                  onChanged: (v) => seciliNeden = v,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (seciliNeden == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir neden seçin")));
                return;
              }
              final navigator = Navigator.of(ctx);
              for (var kanal in _seciliKanallar) {
                await _firestoreServisi.slotKapatAc(widget.esnaf.id, _seciliTarih, kanal, saat, true, neden: seciliNeden);
              }
              if (navigator.mounted) navigator.pop();
            },
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  Widget _saatGostergesi(String baslangic, String bitis, bool aralikliMi, Color renk) {
    if (!aralikliMi) {
      return SizedBox(
        width: 85,
        child: Center(child: Text(baslangic, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: renk))),
      );
    }
    return Text(
      "$baslangic\n$bitis",
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: renk, height: 1.1),
    );
  }

  void _randevuIslemMenusu(RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.kullaniciAd, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("${r.hizmetAdi} - ${r.saat}", style: const TextStyle(color: Colors.grey)),
            if (r.seriId != null && r.seriId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                  child: const Text("Periyodik Randevu Serisi", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ),
            const Divider(height: 40),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _aksiyonButonu(ikon: Icons.phone, renk: Colors.blue, etiket: "Ara", onTap: () => launchUrl(Uri.parse("tel:${r.kullaniciTel}"))),
                _aksiyonButonu(ikon: Icons.message, renk: Colors.green, etiket: "WhatsApp", onTap: () {
                  String mesaj = "Merhaba ${r.kullaniciAd}, ${widget.esnaf.isletmeAdi} işletmesindeki ${DateFormat('dd/MM').format(r.tarih)} saat ${r.saat} randevunuz hakkında...";
                  launchUrl(Uri.parse("https://wa.me/${r.kullaniciTel}?text=${Uri.encodeComponent(mesaj)}"), mode: LaunchMode.externalApplication);
                }),
                _aksiyonButonu(ikon: Icons.cancel, renk: Colors.red, etiket: "İptal Et", onTap: () { Navigator.pop(context); _randevuIptalOnay(r); }),
                if (r.seriId != null && r.seriId!.isNotEmpty)
                  _aksiyonButonu(ikon: Icons.delete_forever, renk: Colors.black, etiket: "Seriyi Sil", onTap: () { Navigator.pop(context); _seriSilOnay(r.seriId!); }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _seriSilOnay(String seriId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Tüm Seriyi Sil"),
        content: const Text("Bu randevu serisine ait gelecekteki tüm randevular silinecektir. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogContext);
              await _firestoreServisi.randevuSerisiniSil(seriId);
              if (nav.mounted) nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Randevu serisi silindi")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text("Tümünü Sil"),
          ),
        ],
      ),
    );
  }

  Widget _aksiyonButonu({required IconData ikon, required Color renk, required String etiket, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: renk.withValues(alpha: 0.1), child: Icon(ikon, color: renk)),
          const SizedBox(height: 8),
          Text(etiket, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  void _randevuIptalOnay(RandevuModeli r) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Randevuyu İptal Et"),
        content: const Text("Randevuyu iptal etmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogContext);
              await _firestoreServisi.randevuIptalEt(r.id, "Esnaf tarafından iptal edildi");
              if (nav.mounted) nav.pop();
              messenger.showSnackBar(const SnackBar(content: Text("Randevu iptal edildi")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("İptal Et"),
          ),
        ],
      ),
    );
  }
}
