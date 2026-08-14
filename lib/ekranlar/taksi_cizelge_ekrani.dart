import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import 'esnaf_paneli.dart';

class TaksiCizelgeEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  const TaksiCizelgeEkrani({super.key, required this.esnaf});

  @override
  State<TaksiCizelgeEkrani> createState() => _TaksiCizelgeEkraniState();
}

class _TaksiCizelgeEkraniState extends State<TaksiCizelgeEkrani> {
  final List<String> gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  List<Map<String, dynamic>> araclar = [];
  bool yukleniyor = true;
  bool kaydediliyor = false;
  bool get degisiklikVar => degisenAylar.isNotEmpty;
  DateTime seciliAy = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, Map<String, dynamic>> aylikVeri = {};
  Set<String> yuklenenAylar = {};
  Set<String> degisenAylar = {};

  Set<String> seciliAraclar = {};
  String? seciliDurum;
  String? operasyonModu; // 'ekle' veya 'sil'
  Set<String> seciliGunler = {};
  DateTime seciliGun = DateTime.now();
  String _seciliKapsam = "AY"; // HAFTA, AY, YIL

  final TextEditingController _aracAramaController = TextEditingController();
  String _aracAramaFiltresi = "";

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  @override
  void dispose() {
    _aracAramaController.dispose();
    super.dispose();
  }

  Future<void> _verileriGetir({bool temizle = true}) async {
    String ayKey = DateFormat('yyyy-MM').format(seciliAy);
    
    // Her durumda bu ayın seçimlerini temizleyelim ki kafa karışmasın
    setState(() {
      seciliGunler.clear();
      // Secili günü bu aya sabitle
      if (seciliGun.year != seciliAy.year || seciliGun.month != seciliAy.month) {
        // Eğer bugün bu aydaysa bugünü seç, değilse ayın 1'ini
        DateTime simdi = DateTime.now();
        if (simdi.year == seciliAy.year && simdi.month == seciliAy.month) {
          seciliGun = simdi;
        } else {
          seciliGun = DateTime(seciliAy.year, seciliAy.month, 1);
        }
      }
      // Eğer bu ay henüz yüklenmediyse yükleme moduna geç
      if (!yuklenenAylar.contains(ayKey)) {
        yukleniyor = true;
      }
    });

    // Eğer temizleme istenmiyorsa ve bu ay zaten yüklendiyse tekrar çekme
    if (!temizle && yuklenenAylar.contains(ayKey)) {
      setState(() => yukleniyor = false);
      return;
    }

    if (temizle) {
      setState(() {
        seciliAraclar.clear();
        seciliDurum = null;
        operasyonModu = null;
      });
    }

    try {
      final esnafDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
      final ajandaDoc = await FirebaseFirestore.instance
          .collection('esnaflar')
          .doc(widget.esnaf.id)
          .collection('taksi_ajanda')
          .doc(ayKey)
          .get();

      if (mounted) {
        setState(() {
          yuklenenAylar.add(ayKey);
          araclar = List<Map<String, dynamic>>.from(esnafDoc.data()?['araclar'] ?? []);
          Map<String, dynamic> gelenVeri = ajandaDoc.data() ?? {};
          
          if (temizle) {
            aylikVeri.removeWhere((key, _) => key.startsWith(ayKey));
            gelenVeri.forEach((key, value) {
              aylikVeri[key] = Map<String, dynamic>.from(value);
            });
            degisenAylar.remove(ayKey);
          } else {
            gelenVeri.forEach((key, value) {
              if (!aylikVeri.containsKey(key)) {
                aylikVeri[key] = Map<String, dynamic>.from(value);
              }
            });
          }
          yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => yukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veri Getirme Hatası: $e")));
      }
    }
  }

  Future<void> _ajandaKaydet() async {
    if (degisenAylar.isEmpty || kaydediliyor) return;

    setState(() => kaydediliyor = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final aylarList = degisenAylar.toList();

      // Firestore batch limit is 500. chunking for robustness.
      for (var i = 0; i < aylarList.length; i += 500) {
        final end = (i + 500 < aylarList.length) ? i + 500 : aylarList.length;
        final chunk = aylarList.sublist(i, end);

        final batch = firestore.batch();

        for (String ayKey in chunk) {
          Map<String, Map<String, dynamic>> ayData = {};

          // aylikVeri içinden bu aya ait olanları (ve içi dolu olanları) topla
          aylikVeri.forEach((tarih, data) {
            if (tarih.startsWith(ayKey) && data.isNotEmpty) {
              ayData[tarih] = data;
            }
          });

          batch.set(
            firestore
                .collection('esnaflar')
                .doc(widget.esnaf.id)
                .collection('taksi_ajanda')
                .doc(ayKey),
            ayData,
            SetOptions(merge: false),
          );
        }

        await batch.commit();
      }

      if (mounted) {
        setState(() {
          degisenAylar.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Ajanda Defteri kayıtları başarıyla Firebase'e kaydedildi"),
          backgroundColor: Colors.green,
        ));
        _verileriGetir(temizle: false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Kaydetme Hatası: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: "Tekrar Dene",
            onPressed: () => _ajandaKaydet(),
            textColor: Colors.white,
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => kaydediliyor = false);
    }
  }

  void _gunDetayGoster(DateTime tarih) {
    String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      Map<String, dynamic> currentGunData = aylikVeri[tarihKey] ?? {};
      return AlertDialog(
        title: Text("${DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih)} Detayı"),
        content: SizedBox(
          width: double.maxFinite, 
          child: currentGunData.isEmpty 
            ? const Text("Kayıt yok.") 
            : ListView(
                shrinkWrap: true, 
                children: currentGunData.entries.map((e) => ListTile(
                  title: Text(e.key), 
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red), 
                    onPressed: () { 
                      setState(() { 
                        currentGunData.remove(e.key); 
                        if (currentGunData.isEmpty) aylikVeri.remove(tarihKey); 
                        String ayKey = tarihKey.substring(0, 7);
                        degisenAylar.add(ayKey);
                      }); 
                      setDialogState(() {}); 
                    }
                  )
                )).toList()
              )
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat"))],
      );
    }));
  }

  Future<bool> _cikisOnayi() async {
    if (!degisiklikVar) return true;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kaydedilmemiş Değişiklikler"),
        content: const Text("Kaydedilmemiş değişiklikleriniz var. Çıkmak istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet, Çık", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }



  void _executePlanLoop(void Function(DateTime tarih, String ayKey) action) {
    if (_seciliKapsam == "GÜN") {
      String ayKey = DateFormat('yyyy-MM').format(seciliGun);
      action(seciliGun, ayKey);
    } else if (_seciliKapsam == "HAFTA") {
      for (int i = 0; i < 7; i++) {
        DateTime tarih = seciliGun.add(Duration(days: i));
        String ayKey = DateFormat('yyyy-MM').format(tarih);
        action(tarih, ayKey);
      }
    } else if (_seciliKapsam == "AY") {
      int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
      for (int i = seciliGun.day; i <= gunSayisi; i++) {
        DateTime tarih = DateTime(seciliAy.year, seciliAy.month, i);
        String ayKey = DateFormat('yyyy-MM').format(tarih);
        action(tarih, ayKey);
      }
    } else if (_seciliKapsam == "YIL") {
      for (int m = seciliAy.month; m <= 12; m++) {
        int gunSayisi = DateTime(seciliAy.year, m + 1, 0).day;
        int basDay = (m == seciliAy.month) ? seciliGun.day : 1;
        for (int i = basDay; i <= gunSayisi; i++) {
          DateTime tarih = DateTime(seciliAy.year, m, i);
          String ayKey = DateFormat('yyyy-MM').format(tarih);
          action(tarih, ayKey);
        }
      }
    }
  }

  void _topluIslemUygula() {
    setState(() {
      _executePlanLoop((tarih, ayKey) {
        String tKey = DateFormat('yyyy-MM-dd').format(tarih);
        final gunMap = Map<String, dynamic>.from(aylikVeri[tKey] ?? {});
        bool degisti = false;

        if (operasyonModu == 'ekle' && seciliDurum != null) {
          for (var p in seciliAraclar) {
            String mevcut = gunMap[p]?.toString() ?? "";
            if (seciliDurum == 'I') {
              if (mevcut != 'I') {
                gunMap[p] = 'I';
                degisti = true;
              }
            } else {
              // Eklenecek durum (seciliDurum) 'C', 'N' veya 'CN' olabilir (>> butonu durumunda)
              String yeni = mevcut;
              if (mevcut == 'I') {
                yeni = seciliDurum!;
              } else {
                // seciliDurum içindeki her bir karakteri (C, N) mevcut duruma ekle (yoksa)
                for (var char in seciliDurum!.split('')) {
                  if (!yeni.contains(char)) yeni += char;
                }
              }
              
              // Alfabetik sırala (CN)
              List<String> chars = yeni.split('');
              chars.sort();
              String siraliYeni = chars.join('');
              
              if (mevcut != siraliYeni) {
                gunMap[p] = siraliYeni;
                degisti = true;
              }
            }
          }
        } else if (operasyonModu == 'sil') {
          for (var p in seciliAraclar) {
            if (gunMap.containsKey(p)) {
              gunMap.remove(p);
              degisti = true;
            }
          }
        }

        if (degisti) {
          degisenAylar.add(ayKey);
          if (gunMap.isEmpty) {
            aylikVeri.remove(tKey);
          } else {
            aylikVeri[tKey] = gunMap;
          }
        }
      });
      seciliGunler.clear(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _cikisOnayi();
        if (mounted && shouldPop) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Nöbet Çizelgesi & Ajanda Defteri"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _verileriGetir(temizle: true),
            ),
          ],
        ),
        body: yukleniyor ? const Center(child: CircularProgressIndicator()) : _aylikAjandaDefteriSekmesi(),
      ),
    );
  }

  Widget _aylikAjandaDefteriSekmesi() {
    int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
    int baslangicBosluk = DateTime(seciliAy.year, seciliAy.month, 1).weekday - 1;
    return Column(children: [
      // 1. TARİH SEÇİMİ (TAKVİM)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        color: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() {
                seciliAy = DateTime(seciliAy.year, seciliAy.month - 1, 1);
                _verileriGetir(temizle: false);
              }),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('MMMM yyyy', 'tr_TR').format(seciliAy), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (degisiklikVar)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_notifications_rounded, size: 12, color: Colors.orange.shade900),
                        const SizedBox(width: 4),
                        Text(
                          "KAYDEDİLMEMİŞ DEĞİŞİKLİKLER",
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() {
                seciliAy = DateTime(seciliAy.year, seciliAy.month + 1, 1);
                _verileriGetir(temizle: false);
              }),
            ),
          ],
        ),
      ),
      
      // Gün Başlıkları
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: gunler.map((g) => Expanded(
            child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600))),
          )).toList(),
        ),
      ),

      // Takvim Grid
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, 
          childAspectRatio: 1.6,
        ),
        itemCount: gunSayisi + baslangicBosluk,
        itemBuilder: (context, index) {
          if (index < baslangicBosluk) return const SizedBox.shrink();
          int gun = index - baslangicBosluk + 1;
          DateTime tarih = DateTime(seciliAy.year, seciliAy.month, gun);
          String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
          final gunData = aylikVeri[tarihKey] ?? {};
          bool isSelected = seciliGun.day == gun && seciliGun.month == seciliAy.month && seciliGun.year == seciliAy.year;

          return InkWell(
            onTap: () {
              setState(() {
                seciliGun = tarih;
              });
            },
            onLongPress: () => _gunDetayGoster(tarih),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade200, 
                  width: isSelected ? 1.5 : 0.5
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      gun.toString(), 
                      style: TextStyle(
                        color: Colors.black, 
                        fontSize: 15, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )
                    ),
                  ),
                  if (gunData.isNotEmpty)
                    Positioned(
                      bottom: 2,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _ozetGostergeleriOlustur(gunData),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),

      // 2. ARAÇ LİSTESİ (TÜM FİLO - GÜN ODAKLI)
      Expanded(
        child: _seciliGunDetayPaneli(DateFormat('yyyy-MM-dd').format(seciliGun)),
      ),

      // Alt Aksiyonlar
      _altAksiyonlar(),
    ]);
  }



  Widget _altAksiyonlar() {
    final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
    final gunData = aylikVeri[gunKey] ?? {};

    // Seçili günde 'N' (Nöbet) olarak işaretlenmiş plakaları bul
    final nobetliPlakalar = gunData.entries
        .where((e) => e.value?.toString().contains('N') == true)
        .map((e) => e.key)
        .toList();

    // Mevcut filtreye veya seçime göre ilgili araçları belirleyelim (1-1 butonu için)
    final hedefPlakalar = seciliAraclar.isNotEmpty 
        ? seciliAraclar 
        : araclar.where((a) {
            if (_aracAramaFiltresi.isEmpty) return true;
            final plaka = (a['plaka'] ?? "").toString().toLowerCase();
            final sofor = (a['soforAd'] ?? a['sofor'] ?? "").toString().toLowerCase();
            return plaka.contains(_aracAramaFiltresi.toLowerCase()) || 
                   sofor.contains(_aracAramaFiltresi.toLowerCase());
          }).map((a) => a['plaka']?.toString()).toSet();

    final bool gundeDurumVar = gunData.entries.any((e) {
      final v = e.value?.toString() ?? "";
      return hedefPlakalar.contains(e.key) && (v.contains('C') || v.contains('N') || v.contains('I'));
    });

    final calisanPlakalar = gunData.entries
        .where((e) => e.value?.toString().contains('C') == true)
        .map((e) => e.key)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Seçili Araçlara Plan Oluştur (Sadece Çalışan araçlar varsa görünür)
          if (calisanPlakalar.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        seciliAraclar = calisanPlakalar.toSet();
                        seciliDurum = 'C';
                        operasyonModu = 'ekle';
                      });
                      _planOlusturOnayiAl(calisanPlakalar.length);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text(
                      "Seçili Araçlara Plan Oluştur",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // 2. Nöbet Planlama Butonu (Sadece nöbet seçili araç varsa görünür)
          if (nobetliPlakalar.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _nobetSirasiniOnayla(nobetliPlakalar),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      "Nöbet Planı Oluştur",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade700, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // 1-1 Çalışma Düzeni Butonu
          if (gundeDurumVar) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        seciliDurum = '1-1';
                        operasyonModu = 'ekle';
                        if (_seciliKapsam == "GÜN") _seciliKapsam = "AY";
                      });
                      _topluIslemOnayiAl();
                    },
                    icon: const Icon(Icons.sync_alt, size: 18),
                    label: const Text("1 gün çalış 1 gün istirahat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade600,
                      side: BorderSide(color: Colors.teal.shade600, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Kaydet Butonu
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (degisiklikVar && !kaydediliyor) ? _ajandaKaydet : null, 
                  icon: kaydediliyor 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload, size: 18),
                  label: const Text("TÜMÜNÜ KAYDET"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _nobetSirasiniOnayla(List<String> nobetliPlakalar) {
    if (nobetliPlakalar.isEmpty) return;
    final seciliPlaka = nobetliPlakalar.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String kapsamText = _seciliKapsam == "GÜN" ? "sadece bugün" : (_seciliKapsam == "HAFTA" ? "1 hafta boyunca" : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar"));

          return AlertDialog(
            title: const Text("Nöbet Planı Oluştur"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kapsamSeciciWidget(setDialogState),
                const SizedBox(height: 20),
                Text("${DateFormat('dd MMMM').format(seciliGun)} için nöbetçi seçildi.", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Nasıl bir nöbet çizelgesi oluşturulsun? ($kapsamText)", style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                if (nobetliPlakalar.length == 1) ...[
                  _nobetSecenekButonu(
                    icon: Icons.pin_drop,
                    color: Colors.orange,
                    baslik: "$seciliPlaka Aracını Sabitle",
                    altBaslik: "$kapsamText her gün bu araç nöbetçi olur.",
                    onTap: () {
                      Navigator.pop(context);
                      _nobetSirasiniUygula(mode: 'SABITLE', plakalar: nobetliPlakalar);
                    },
                  ),
                  const Divider(),
                  _nobetSecenekButonu(
                    icon: Icons.format_list_numbered,
                    color: Colors.blue,
                    baslik: "Tüm Filoyu Sırayla Ata",
                    altBaslik: "$seciliPlaka'dan başlayarak tüm araçları № sırasına göre $kapsamText dağıtır.",
                    onTap: () {
                      Navigator.pop(context);
                      _nobetSirasiniUygula(mode: 'TUMU_SIRALI', plakalar: nobetliPlakalar);
                    },
                  ),
                ] else ...[
                  _nobetSecenekButonu(
                    icon: Icons.loop,
                    color: Colors.green,
                    baslik: "Seçilileri Kendi Arasında Döndür",
                    altBaslik: "Bugün seçilen ${nobetliPlakalar.length} aracı № sırasına göre $kapsamText sırayla dağıtır.",
                    onTap: () {
                      Navigator.pop(context);
                      _nobetSirasiniUygula(mode: 'SECILILERI_DONDUR', plakalar: nobetliPlakalar);
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ],
          );
        }
      ),
    );
  }

  Widget _nobetSecenekButonu({
    required IconData icon,
    required Color color,
    required String baslik,
    required String altBaslik,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(altBaslik, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  void _nobetSirasiniUygula({required String mode, required List<String> plakalar}) {
    if (plakalar.isEmpty) return;

    setState(() {
      List<String> havuz = [];
      
      if (mode == 'SABITLE') {
        havuz = [plakalar.first];
      } else if (mode == 'TUMU_SIRALI') {
        // Tüm araçları № sırasına göre al
        List<Map<String, dynamic>> tumu = List.from(araclar);
        tumu.sort((a, b) {
          int siraA = a['nobetSirasi'] ?? 999;
          int siraB = b['nobetSirasi'] ?? 999;
          return siraA.compareTo(siraB);
        });
        
        List<String> siraliPlakalar = tumu.map((a) => a['plaka'].toString()).toList();
        
        // Başlangıç aracının indeksini bul
        int startIndex = siraliPlakalar.indexOf(plakalar.first);
        if (startIndex == -1) startIndex = 0;
        
        // Havuzu bu indeksten başlayacak şekilde yeniden düzenle
        havuz = [
          ...siraliPlakalar.sublist(startIndex),
          ...siraliPlakalar.sublist(0, startIndex)
        ];
      } else if (mode == 'SECILILERI_DONDUR') {
        List<Map<String, dynamic>> secilenler = araclar
            .where((a) => plakalar.contains(a['plaka']))
            .toList();
        secilenler.sort((a, b) {
          int siraA = a['nobetSirasi'] ?? 999;
          int siraB = b['nobetSirasi'] ?? 999;
          return siraA.compareTo(siraB);
        });
        havuz = secilenler.map((a) => a['plaka'].toString()).toList();
      }

      if (havuz.isEmpty) return;

      int dayIndex = 0;
      _executePlanLoop((tarih, ayKey) {
        String tKey = DateFormat('yyyy-MM-dd').format(tarih);
        final gunMap = Map<String, dynamic>.from(aylikVeri[tKey] ?? {});
        
        // 1. O günkü mevcut nöbetçileri bu gruptan temizle (Diğer durumları koruyarak)
        Map<String, dynamic> yeniGunMap = {};
        gunMap.forEach((plaka, durum) {
          String s = durum.toString().replaceAll('N', '');
          if (s.isNotEmpty) yeniGunMap[plaka] = s;
        });

        // 2. Yeni nöbetçiyi ata (Mevcut durumuna ekle)
        String atanacakPlaka = havuz[dayIndex % havuz.length];
        String mevcut = yeniGunMap[atanacakPlaka]?.toString() ?? "";
        if (!mevcut.contains('N')) {
          String birlesik = mevcut + 'N';
          List<String> chars = birlesik.split('');
          chars.sort();
          yeniGunMap[atanacakPlaka] = chars.join('');
        }
        
        aylikVeri[tKey] = yeniGunMap;
        degisenAylar.add(ayKey);
        dayIndex++;
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Nöbet planı başarıyla oluşturuldu. Kaydetmeyi unutmayın.")),
    );
  }



  void _topluIslemOnayiAl() {
    if (seciliDurum == '1-1') {
      final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
      final gunData = aylikVeri[gunKey] ?? {};

      // Bugün 'Çalış' (C) olarak işaretlenen araçları belirle
      final calisanPlakalar = gunData.entries
          .where((e) => e.value?.toString().contains('C') == true)
          .map((e) => e.key)
          .toList();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            String kapsamText = _seciliKapsam == "HAFTA" ? "1 hafta boyunca" : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar");
            String mesaj;
            
            if (calisanPlakalar.isEmpty) {
              mesaj = "Bugün için hiçbir araç 'Çalış' (Mavi) olarak seçilmemiş. Lütfen önce bugünkü çalışma düzenini belirleyin.";
            } else {
              mesaj = "Seçili ${calisanPlakalar.length} aracın bugün çalışacağı, diğer tüm araçların istirahat edeceği şekilde $kapsamText '1 gün çalış 1 gün istirahat' düzeni uygulansın mı?";
            }

            return AlertDialog(
              title: const Text("1 Gün Çalış 1 Gün İstirahat"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _kapsamSeciciWidget(setDialogState, showDay: false),
                  const SizedBox(height: 20),
                  Text(mesaj, textAlign: TextAlign.center),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
                if (calisanPlakalar.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _uygula1e1();
                    });
                  },
                  child: const Text("Uygula"),
                ),
              ],
            );
          }
        ),
      );
      return;
    }

    final actionText = operasyonModu == 'sil' ? "temizleme" : "atama";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Toplu İşlem Onayı"),
        content: Text("Seçili araçlar için ${DateFormat('dd MMMM').format(seciliGun)}'den itibaren ay sonuna kadar toplu $actionText yapılacaktır. Devam etmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _topluIslemUygula();
            },
            child: const Text("Uygula"),
          ),
        ],
      ),
    );
  }

  void _planOlusturOnayiAl(int aracSayisi) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String mesaj;
          if (_seciliKapsam == "GÜN") {
            mesaj = "Seçili $aracSayisi aracın sadece bugün için çalıştırılmasını uygun görüyor musunuz?";
          } else {
            String kapsamText = _seciliKapsam == "HAFTA" ? "1 hafta boyunca" : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar");
            mesaj = "Seçili $aracSayisi aracın seçili günden itibaren $kapsamText çalıştırılmasını uygun görüyor musunuz?";
          }

          return AlertDialog(
            title: const Text("Plan oluştur"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _kapsamSeciciWidget(setDialogState),
                const SizedBox(height: 20),
                Text(mesaj),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _topluIslemUygula();
                },
                child: const Text("Uygula"),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _kapsamSeciciWidget(StateSetter setDialogState, {bool showDay = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          if (showDay) _kapsamButonu("GÜN", "Gün", setDialogState),
          _kapsamButonu("HAFTA", "Hafta", setDialogState),
          _kapsamButonu("AY", "Ay", setDialogState),
          _kapsamButonu("YIL", "Yıl", setDialogState),
        ],
      ),
    );
  }

  Widget _kapsamButonu(String kapsam, String etiket, StateSetter setDialogState) {
    bool secili = _seciliKapsam == kapsam;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _seciliKapsam = kapsam);
          setDialogState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: secili ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: secili ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
          ),
          child: Text(
            etiket,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: secili ? FontWeight.bold : FontWeight.normal,
              color: secili ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  void _kayitSilOnayiAl() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String kapsamText = _seciliKapsam == "GÜN" ? "sadece bugün için" : (_seciliKapsam == "HAFTA" ? "1 hafta boyunca" : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar"));
          String baslangicText = _seciliKapsam == "GÜN" ? "" : "seçili günden itibaren ";

          return AlertDialog(
            title: const Text("Kayıtları Sil"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _kapsamButonu("GÜN", "Gün", setDialogState),
                      _kapsamButonu("HAFTA", "Hafta", setDialogState),
                      _kapsamButonu("AY", "Ay", setDialogState),
                      _kapsamButonu("YIL", "Yıl", setDialogState),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "$baslangicText$kapsamText tüm çalışma ve nöbet kayıtlarının silinmesini onaylıyor musunuz?",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("VAZGEÇ")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _topluKayitTemizle();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("SİL"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _topluKayitTemizle() {
    setState(() {
      operasyonModu = 'sil';
      // Tüm araçları etkilemesi için seciliAraclar'ı geçici olarak doldur
      final hamAraclar = araclar.map((a) => a['plaka']?.toString() ?? "").where((p) => p.isNotEmpty).toSet();
      seciliAraclar = hamAraclar;
      
      _executePlanLoop((tarih, ayKey) {
        String tKey = DateFormat('yyyy-MM-dd').format(tarih);
        aylikVeri[tKey] = {}; // Günü boşalt
        degisenAylar.add(ayKey);
      });
      
      seciliAraclar.clear();
      operasyonModu = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Kayıtlar temizlendi. Kaydetmeyi unutmayın."), backgroundColor: Colors.orange),
    );
  }

  Widget _seciliGunDetayPaneli(String tarihKey) {
    DateTime tarih = DateFormat('yyyy-MM-dd').parse(tarihKey);
    final gunData = aylikVeri[tarihKey] ?? {};

    // Filtrelenmiş araç listesi
    final filtrelenmisAraclar = araclar.where((a) {
      if (_aracAramaFiltresi.isEmpty) return true;
      final plaka = (a['plaka'] ?? "").toString().toLowerCase();
      final sofor = (a['soforAd'] ?? a['sofor'] ?? "").toString().toLowerCase();
      return plaka.contains(_aracAramaFiltresi.toLowerCase()) || 
             sofor.contains(_aracAramaFiltresi.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(tarih),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _kayitSilOnayiAl(),
                    icon: const Icon(Icons.delete_forever, size: 16, color: Colors.red),
                    label: const Text("Kayıt Sil", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12), 
                      minimumSize: const Size(80, 32),
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("${filtrelenmisAraclar.length}/${araclar.length} Araç", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: TextField(
                  controller: _aracAramaController,
                  onChanged: (val) => setState(() => _aracAramaFiltresi = val),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Plaka veya Şoför Ara...",
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.blue),
                    suffixIcon: _aracAramaFiltresi.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18), 
                          onPressed: () => setState(() {
                            _aracAramaController.clear();
                            _aracAramaFiltresi = "";
                          })
                        ) 
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: filtrelenmisAraclar.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            // ignore: deprecated_member_use
            cacheExtent: 500.0,
            itemBuilder: (context, index) {
              final arac = filtrelenmisAraclar[index];
              final plaka = (arac['plaka'] ?? "").toString();
              final sofor = (arac['soforAd'] ?? arac['sofor'] ?? "").toString();
              final nSira = arac['nobetSirasi'];
              final mevcutDurum = gunData[plaka]; // Varsayılan 'C' kaldırıldı, null olabilir.

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              InkWell(
                                onTap: () => _nobetSirasiDegistir(arac),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Text(
                                    nSira != null ? "№ $nSira" : "№ ?",
                                    style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (sofor.isNotEmpty) Text(sofor, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _durumButonu(tarihKey, plaka, 'C', 'Çalış', Colors.blue, mevcutDurum?.toString().contains('C') == true),
                        const SizedBox(width: 3),
                        _durumButonu(tarihKey, plaka, 'N', 'Nöbet', Colors.orange, mevcutDurum?.toString().contains('N') == true),
                        const SizedBox(width: 3),
                        _durumButonu(tarihKey, plaka, 'I', 'İst.', Colors.purple, mevcutDurum?.toString().contains('I') == true),
                        if (mevcutDurum != null && mevcutDurum.toString().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.fast_forward, size: 20, color: Colors.blue),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _tekAracTopluIslemOnayi(plaka, mevcutDurum, false),
                            tooltip: "Seçilenden İleri Uygula",
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _tekAracTopluIslemOnayi(String plaka, String durum, bool is1e1) {
    if (is1e1) {
      // 1-1 kuralı için seciliAraclar listesini geçici olarak bu plaka ile güncelle ve ana onay fonksiyonunu çağır
      setState(() {
        seciliAraclar.clear();
        seciliAraclar.add(plaka);
        seciliDurum = '1-1';
      });
      _topluIslemOnayiAl();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Toplu Uygula"),
        content: Text("$plaka aracının '$durum' durumu bu günden itibaren ay sonuna kadar uygulansın mı?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                seciliAraclar.clear();
                seciliAraclar.add(plaka);
                if (is1e1) {
                  _uygula1e1();
                } else {
                  seciliDurum = durum;
                  operasyonModu = 'ekle';
                  _topluIslemUygula();
                }
              });
            },
            child: const Text("Uygula"),
          ),
        ],
      ),
    );
  }

  void _nobetSirasiDegistir(Map<String, dynamic> arac) {
    final controller = TextEditingController(text: arac['nobetSirasi']?.toString() ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${arac['plaka']} Nöbet Sırası"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Sıra Numarası", hintText: "Örn: 1"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              int? yeniSira = int.tryParse(controller.text.trim());
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              
              if (yeniSira != null) {
                setState(() {
                  arac['nobetSirasi'] = yeniSira;
                });
                
                try {
                  await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
                    'araclar': araclar,
                  });
                  messenger.showSnackBar(const SnackBar(content: Text("Nöbet sırası güncellendi"), duration: Duration(seconds: 1)));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text("Hata: $e")));
                }
              }
              nav.pop();
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  Widget _durumButonu(String tarihKey, String plaka, String deger, String etiket, Color renk, bool secili) {
    return GestureDetector(
      onTap: () {
        if (deger == 'N') {
           // Nöbet kontrolleri (Zaten _durumChip içinde var, oraya da bakılabilir ama burada direkt uygulayalım)
           if (widget.esnaf.nobetBaslangic == null || widget.esnaf.nobetBaslangic!.isEmpty || widget.esnaf.nobetBaslangic == "Seçilmedi") {
             _hizliYonlendir("Nöbet Saatleri Eksik", "Nöbet saatlerini ayarlamak ister misiniz?", true, false);
             return;
           }
        }

        setState(() {
          final gunMap = Map<String, dynamic>.from(aylikVeri[tarihKey] ?? {});
          String mevcut = gunMap[plaka]?.toString() ?? "";

          if (deger == 'I') {
            // İstirahat tekildir ve diğerlerini siler
            if (mevcut == 'I') {
              gunMap.remove(plaka);
            } else {
              gunMap[plaka] = 'I';
            }
          } else {
            // Çalış (C) veya Nöbet (N)
            if (mevcut == 'I') {
              gunMap[plaka] = deger;
            } else if (mevcut.contains(deger)) {
              // Zaten varsa çıkar
              String yeni = mevcut.replaceAll(deger, '');
              if (yeni.isEmpty) {
                gunMap.remove(plaka);
              } else {
                gunMap[plaka] = yeni;
              }
            } else {
              // Diğerini de ekle (C + N = CN)
              String yeni = mevcut + deger;
              // Her zaman alfabetik sırada tutalım (CN)
              List<String> chars = yeni.split('');
              chars.sort();
              gunMap[plaka] = chars.join('');
            }
          }

          aylikVeri[tarihKey] = gunMap;
          degisenAylar.add(tarihKey.substring(0, 7));
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: secili ? renk : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: secili ? renk : Colors.grey.shade300),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            color: secili ? Colors.white : Colors.grey.shade700,
            fontSize: 12,
            fontWeight: secili ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _hizliYonlendir(String baslik, String icerik, bool openMesai, bool openFilo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(baslik),
        content: Text(icerik),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => EsnafPaneli(esnaf: widget.esnaf, openMesai: openMesai, openFilo: openFilo)));
            },
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  void _uygula1e1() {
    final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
    final gunData = aylikVeri[gunKey] ?? {};

    // 1. Seçili günde 'C' (Çalış) olarak işaretlenmiş plakaları ve durumlarını belirle
    final Map<String, String> baslangicDurumlari = {};
    for (var entry in gunData.entries) {
      if (entry.value?.toString().contains('C') == true) {
        baslangicDurumlari[entry.key] = entry.value.toString();
      }
    }

    // 2. Tüm araç listesini al (Plaka bazlı)
    final tumPlakalar = araclar
        .map((a) => a['plaka']?.toString() ?? "")
        .where((p) => p.isNotEmpty)
        .toSet();

    if (baslangicDurumlari.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu düzeni başlatmak için önce bugün çalışacak araçları seçmelisiniz!"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      int dayIndex = 0;
      _executePlanLoop((tarih, ayKey) {
        String tKey = DateFormat('yyyy-MM-dd').format(tarih);
        final gunMap = Map<String, dynamic>.from(aylikVeri[tKey] ?? {});
        bool siraACalissin = (dayIndex % 2 == 0);
        bool degisti = false;

        for (var p in tumPlakalar) {
          // Mevcut durumdan NÖBET bilgisini asla silme, aynen al
          String mevcut = gunMap[p]?.toString() ?? "";
          bool nobetiVar = mevcut.contains('N');

          String yeniHal;
          if (baslangicDurumlari.containsKey(p)) {
            // Grup A: Bugün 'Çalış' seçilenler -> C, I, C, I...
            yeniHal = siraACalissin ? 'C' : 'I';
          } else {
            // Grup B: Bugün seçilmeyenler -> I, C, I, C...
            yeniHal = siraACalissin ? 'I' : 'C';
          }

          // [KRİTİK]: Eğer o gün Nöbeti varsa, yeni durumla birleştir
          if (nobetiVar) {
            if (yeniHal == 'I') {
              // İstirahat sırası gelse bile nöbeti olduğu için N kalmalı
              yeniHal = 'N';
            } else if (yeniHal == 'C') {
              // Çalışma sırası ve nöbeti varsa CN olmalı
              yeniHal = 'CN';
            }
          }

          if (mevcut != yeniHal) {
            gunMap[p] = yeniHal;
            degisti = true;
          }
        }

        if (degisti) {
          aylikVeri[tKey] = gunMap;
          degisenAylar.add(ayKey);
        }
        dayIndex++;
      });
      seciliGunler.clear(); 
    });
  }

  List<Widget> _ozetGostergeleriOlustur(Map<String, dynamic> gunData) {
    int calisan = 0;
    int istirahat = 0;
    int nobetci = 0;

    gunData.forEach((key, value) {
      String status = value?.toString() ?? "";
      if (status.contains('C')) {
        calisan++;
      }
      if (status.contains('I')) {
        istirahat++;
      }
      if (status.contains('N')) {
        nobetci++;
      }
    });

    List<Widget> gostergeler = [];
    if (calisan > 0) gostergeler.add(_ozetDot(Colors.blue));
    if (istirahat > 0) gostergeler.add(_ozetDot(Colors.purple));
    if (nobetci > 0) gostergeler.add(_ozetDot(Colors.orange));

    return gostergeler;
  }

  Widget _ozetDot(Color renk) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: renk,
        shape: BoxShape.circle,
      ),
    );
  }
}
