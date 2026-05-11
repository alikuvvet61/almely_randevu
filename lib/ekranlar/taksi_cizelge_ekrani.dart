import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';

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

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _verileriGetir({bool temizle = true}) async {
    String ayKey = DateFormat('yyyy-MM').format(seciliAy);
    
    // Her durumda bu ayın seçimlerini temizleyelim ki kafa karışmasın
    setState(() {
      seciliGunler.clear();
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
          content: Text("Tüm değişiklikler başarıyla Firebase'e kaydedildi"),
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

  void _topluSil() {
    setState(() {
      for (var gunKey in seciliGunler) {
        String ayKey = gunKey.substring(0, 7);
        degisenAylar.add(ayKey);
        
        if (aylikVeri.containsKey(gunKey)) {
          if (seciliAraclar.isEmpty) {
            aylikVeri.remove(gunKey);
          } else {
            Map<String, dynamic> gununVerisi = Map<String, dynamic>.from(aylikVeri[gunKey]!);
            for (var plaka in seciliAraclar) {
              gununVerisi.remove(plaka);
            }
            
            if (gununVerisi.isEmpty) {
              aylikVeri.remove(gunKey);
            } else {
              aylikVeri[gunKey] = gununVerisi;
            }
          }
        }
      }
      seciliGunler.clear();
    });
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



  void _topluIslemUygula() {
    setState(() {
      // Eğer bir gün seçiliyse o günden başla, değilse 1. günden başla
      int baslangicGun = 1;
      if (seciliGunler.isNotEmpty) {
        // "eğer ikinci seçilen ilk seçilenden küçükse küçükten başla büyükse büyük olandan başla"
        // Bu mantık son seçilen günün (seciliGunler.last) başlangıç noktası olmasını sağlar.
        baslangicGun = int.parse(seciliGunler.last.split('-').last);
      }

      int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
      
      // 1-1 modunda SEÇİLENDEN İLERİ örüntüyle doldur
      if (seciliDurum == '1-1' && operasyonModu == 'ekle') {
        final benzersizPlakalar = araclar.map((a) => (a['plaka'] ?? "").toString()).where((p) => p.isNotEmpty).toSet();
        
        // ÖNCE TÜM AYI TEMİZLE (Kayıtlılar/Nöbetler hariç)
        for (int i = 1; i <= gunSayisi; i++) {
          String tKey = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
          if (aylikVeri.containsKey(tKey)) {
            final gunMap = Map<String, dynamic>.from(aylikVeri[tKey]!);
            for (var p in benzersizPlakalar) {
              if (gunMap[p] != 'N') gunMap.remove(p);
            }
            if (gunMap.isEmpty) {
              aylikVeri.remove(tKey);
            } else {
              aylikVeri[tKey] = gunMap;
            }
          }
        }

        // ŞİMDİ ÖRÜNTÜYÜ UYGULA
        for (int i = baslangicGun; i <= gunSayisi; i++) {
          String tKey = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
          String ayKey = tKey.substring(0, 7);
          degisenAylar.add(ayKey);
          
          final gunMap = Map<String, dynamic>.from(aylikVeri[tKey] ?? {});
          bool calismaGunu = ((i - baslangicGun) % 2 == 0);
          
          for (var p in benzersizPlakalar) {
            if (gunMap[p] == 'N') continue;
            
            // Seçilen araçlar 'Çalış' ile başlar, seçilmeyenler 'İstirahat' ile başlar
            bool seciliMi = seciliAraclar.contains(p);
            if (seciliMi) {
              gunMap[p] = calismaGunu ? 'C' : 'I';
            } else {
              gunMap[p] = calismaGunu ? 'I' : 'C';
            }
          }
          aylikVeri[tKey] = gunMap;
        }
      } else {
        // Diğer modlar (Ekle-N, Ekle-Mola veya Sil) için baslangicGun'den sonrasını güncelle
        for (int i = baslangicGun; i <= gunSayisi; i++) {
          String tKey = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
          String ayKey = tKey.substring(0, 7);
          degisenAylar.add(ayKey);
          
          final gunMap = Map<String, dynamic>.from(aylikVeri[tKey] ?? {});
          if (operasyonModu == 'ekle') {
            for (var p in seciliAraclar) {
              if (gunMap[p] == 'N' && seciliDurum != 'N') continue;
              gunMap[p] = seciliDurum!;
            }
          } else {
            for (var p in seciliAraclar) {
              gunMap.remove(p);
            }
          }
          
          if (gunMap.isEmpty) {
            aylikVeri.remove(tKey);
          } else {
            aylikVeri[tKey] = gunMap;
          }
        }
      }
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
          title: const Text("Taksi Çizelge"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _verileriGetir(temizle: true),
            ),
          ],
        ),
        body: yukleniyor ? const Center(child: CircularProgressIndicator()) : _aylikAjandaSekmesi(),
      ),
    );
  }

  Widget _aylikAjandaSekmesi() {
    int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
    int baslangicBosluk = DateTime(seciliAy.year, seciliAy.month, 1).weekday - 1;
    return Column(children: [
      // 1. Ay Seçici ve Bilgi
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                seciliAy = DateTime(seciliAy.year, seciliAy.month - 1, 1);
                _verileriGetir(temizle: false);
              }),
            ),
            Column(
              children: [
                Text(DateFormat('MMMM yyyy', 'tr_TR').format(seciliAy), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Değişiklikler yereldir, kaydetmeyi unutmayın", style: TextStyle(fontSize: 13, color: Colors.orange)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                seciliAy = DateTime(seciliAy.year, seciliAy.month + 1, 1);
                _verileriGetir(temizle: false);
              }),
            ),
          ],
        ),
      ),
  // 2. İşlem Seçimi
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        const Text("İşlem Seçin:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: operasyonModu,
                hint: const Text("Ne yapmak istiyorsunuz?", style: TextStyle(fontSize: 14)),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue, size: 22),
                items: const [
                  DropdownMenuItem(value: 'ekle', child: Text("Araç Eklemek İstiyorum.", style: TextStyle(fontSize: 14))),
                  DropdownMenuItem(value: 'sil', child: Text("Araç Çıkarmak İstiyorum.", style: TextStyle(fontSize: 14))),
                ],
                onChanged: (val) => setState(() {
                  operasyonModu = val;
                  if (val == 'sil') seciliDurum = null;
                  seciliGunler.clear();
                }),
              ),
            ),
          ),
        ),
      ],
    ),
  ),

  // 3. Araç Seçimi & Durum Seçimi
  if (operasyonModu != null) ...[
    const Center(child: Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text("Araç Seçin", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))),
    _aracSecici(),

    // 4. Durum / Patern Seçimi
    if (operasyonModu == 'ekle') ...[
      const Center(child: Padding(padding: EdgeInsets.only(top: 8, bottom: 4), child: Text("Ajanda Durumu", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))),
      _durumSecici(),
    ],
    
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        operasyonModu == 'sil'
          ? (seciliGunler.isNotEmpty 
              ? "Seçilen günden itibaren ay sonuna kadar kayıtları temizlemek için alttaki 'İleri Temizle' butonuna dokunun." 
              : "Günlere dokunarak tek tek silebilir veya bir gün seçip ileriye doğru toplu temizlik yapabilirsiniz.")
          : (seciliDurum == '1-1' 
              ? "Seçili araçlar 'Çalış', diğerleri 'İstirahat' olacak şekilde tüm aya dönüşümlü 1-1 düzeni uygulanır. İşlemi başlatmak için bir güne dokunun veya 'İleri Uygula' butonunu kullanın."
              : "Güne dokunarak tekli atama yapabilir veya bir gün seçip 'İleri Uygula' butonuyla toplu işlem yapabilirsiniz."),
        style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    ),
  ],
  
  const Divider(height: 1),
  // Gün Başlıkları
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: gunler.map((g) => Expanded(
        child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600))),
      )).toList(),
    ),
  ),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.65),
          itemCount: gunSayisi + baslangicBosluk,
          itemBuilder: (context, index) {
            if (index < baslangicBosluk) return const SizedBox.shrink();
            int gun = index - baslangicBosluk + 1;
            DateTime tarih = DateTime(seciliAy.year, seciliAy.month, gun);
            String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
            final gunData = aylikVeri[tarihKey] ?? {};

            return InkWell(
              onTap: () {
                // İşlem modu seçilmediyse uyar
                if (seciliAraclar.isNotEmpty && operasyonModu == null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Lütfen önce bir işlem (Ekle/Çıkar) seçin"),
                      duration: Duration(milliseconds: 1000),
                    ),
                  );
                  return;
                }

                // Araç seçiliyken durum seçilmediyse gün seçimine izin verme
                if (seciliAraclar.isNotEmpty && operasyonModu == 'ekle' && seciliDurum == null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Lütfen önce bir durum veya patern seçin"),
                      duration: Duration(milliseconds: 700),
                    ),
                  );
                  return;
                }

                setState(() {
                  final bool secildi = !seciliGunler.contains(tarihKey);

                  // Gün seçimini yönet
                  if (secildi) {
                    if (seciliAraclar.isEmpty) {
                      seciliGunler.clear(); // Gezinti modunda tekli seçim
                    }
                    seciliGunler.add(tarihKey);
                  } else {
                    seciliGunler.remove(tarihKey);
                  }

                  // Atama/Silme İşlemi (Araç ve Mod seçiliyse)
                  if (seciliAraclar.isNotEmpty && operasyonModu != null) {
                    if (operasyonModu == 'ekle' && seciliDurum != null) {
                      if (seciliDurum == '1-1') {
                        // 1/1 DÜZEN MODU
                        int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
                        String ayKey = tarihKey.substring(0, 7);
                        degisenAylar.add(ayKey);
                        final benzersizPlakalar = araclar.map((a) => (a['plaka'] ?? "").toString()).where((p) => p.isNotEmpty).toSet();

                        // ÖNCE TÜM AYI TEMİZLE (Kayıtlılar/Nöbetler hariç)
                        for (int i = 1; i <= gunSayisi; i++) {
                          String tKey = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
                          if (aylikVeri.containsKey(tKey)) {
                            final gunMap = Map<String, dynamic>.from(aylikVeri[tKey]!);
                            for (var p in benzersizPlakalar) {
                              if (gunMap[p] != 'N') gunMap.remove(p);
                            }
                            if (gunMap.isEmpty) {
                              aylikVeri.remove(tKey);
                            } else {
                              aylikVeri[tKey] = gunMap;
                            }
                          }
                        }

                        // ŞİMDİ ÖRÜNTÜYÜ UYGULA
                        for (int i = gun; i <= gunSayisi; i++) {
                          String k = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
                          final gunMap = Map<String, dynamic>.from(aylikVeri[k] ?? {});
                          bool calismaGunu = ((i - gun) % 2 == 0);
                          
                          for (var p in benzersizPlakalar) {
                            if (gunMap[p] == 'N') continue; // Nöbetleri koru
                            
                            bool seciliMi = seciliAraclar.contains(p);
                            if (seciliMi) {
                              gunMap[p] = calismaGunu ? 'C' : 'I';
                            } else {
                              gunMap[p] = calismaGunu ? 'I' : 'C';
                            }
                          }
                          aylikVeri[k] = gunMap;
                        }
                        seciliGunler.clear(); 
                      } else {
                        // NORMAL ATAMA MODU
                        final gunMap = Map<String, dynamic>.from(aylikVeri[tarihKey] ?? {});
                        for (var p in seciliAraclar) {
                          // Nöbet dışındaki atamalarda Nöbeti koru? 
                          // Kullanıcı isteğine göre: Nöbetler özeldir.
                          if (gunMap[p] == 'N' && seciliDurum != 'N') continue;
                          gunMap[p] = seciliDurum!;
                        }
                        aylikVeri[tarihKey] = gunMap;
                        String ayKey = tarihKey.substring(0, 7);
                        degisenAylar.add(ayKey);
                      }
                    } else if (operasyonModu == 'sil') {
                      // SİLME MODU
                      final gunMap = Map<String, dynamic>.from(aylikVeri[tarihKey] ?? {});
                      for (var p in seciliAraclar) {
                        gunMap.remove(p);
                      }

                      if (gunMap.isEmpty) {
                        aylikVeri.remove(tarihKey);
                      } else {
                        aylikVeri[tarihKey] = gunMap;
                      }
                      String ayKey = tarihKey.substring(0, 7);
                      degisenAylar.add(ayKey);
                    }
                  }
                });
              },
              onLongPress: () => _gunDetayGoster(tarih),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: seciliGunler.contains(tarihKey) ? Colors.blue.shade50 : Colors.white,
                  border: Border.all(
                    color: seciliGunler.contains(tarihKey) ? Colors.blue : Colors.grey.shade300, 
                    width: seciliGunler.contains(tarihKey) ? 2.0 : 1.0
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          gun.toString(), 
                          style: TextStyle(
                            color: Colors.black, 
                            fontSize: 17, 
                            fontWeight: seciliGunler.contains(tarihKey) ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ),
                      if (gunData.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Wrap(
                            spacing: 1,
                            runSpacing: 1,
                            alignment: WrapAlignment.center,
                            children: _ozetGostergeleriOlustur(gunData),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ]))),
      if (seciliGunler.isNotEmpty && seciliGunler.length == 1)
        _seciliGunDetayPaneli(seciliGunler.first),
      Container(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: (degisiklikVar && !kaydediliyor) ? _ajandaKaydet : null, 
            style: ElevatedButton.styleFrom(
              backgroundColor: (degisiklikVar && !kaydediliyor) ? Colors.green.shade700 : Colors.grey.shade400, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: (degisiklikVar && !kaydediliyor) ? 4 : 0,
            ), 
            child: kaydediliyor 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Tüm Değişiklikleri Kaydet")
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: (kaydediliyor || seciliAraclar.isEmpty || operasyonModu == null || (operasyonModu == 'ekle' && seciliDurum == null)) ? null : () {
              final isForward = seciliGunler.isNotEmpty;
              final actionText = operasyonModu == 'sil' ? "temizleme" : "atama";
              final scopeText = isForward ? "seçilen günden itibaren ay sonuna kadar" : "tüm ay için";
              
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Toplu İşlem Onayı"),
                  content: Text("Seçili araçlar için $scopeText toplu $actionText yapılacaktır. Devam etmek istiyor musunuz?"),
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
            }, 
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              seciliGunler.isNotEmpty 
                ? (operasyonModu == 'sil' ? "Seçilenden İleri Temizle" : "Seçilenden İleri Uygula") 
                : (operasyonModu == 'sil' ? "Tüm Ayı Temizle" : "Tüm Aya Uygula"), 
              style: const TextStyle(fontSize: 15)
            )
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: (kaydediliyor || seciliGunler.isEmpty) ? null : _topluSil,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text("Seçiliyi Temizle", style: TextStyle(fontSize: 15))
          )),
        ]),
      ]))
    ]);
  }

  Widget _seciliGunDetayPaneli(String tarihKey) {
    final gunData = aylikVeri[tarihKey] ?? {};
    DateTime tarih = DateFormat('yyyy-MM-dd').parse(tarihKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih)} Detayı",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              if (gunData.isNotEmpty)
                Text("${gunData.length} Araç Kayıtlı", style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
            ],
          ),
          const Divider(),
          if (gunData.isEmpty)
            const Text("Bu güne ait kayıt bulunamadı.", style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.grey))
          else
            Builder(
              builder: (context) {
                // Veriyi sıralama: Önce Çalışan (C), sonra Nöbetçi (N), sonra İstirahat (I)
                final siraliGirisler = gunData.entries.toList()..sort((a, b) {
                  const oncelik = {'C': 0, 'N': 1, 'I': 2};
                  int fark = (oncelik[a.value] ?? 99).compareTo(oncelik[b.value] ?? 99);
                  if (fark != 0) return fark;
                  return a.key.compareTo(b.key); // Aynı durumdakileri plakaya göre alfabetik sırala
                });

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: siraliGirisler.map((e) {
                    final arac = araclar.firstWhere((a) => a['plaka'] == e.key, orElse: () => {});
                    final sofor = arac['soforAd'] ?? arac['sofor'] ?? "";
                    Color renk = Colors.blue;
                    if (e.value == 'I') {
                      renk = Colors.purple;
                    }
                    if (e.value == 'N') {
                      renk = Colors.orange;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: renk.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (sofor.isNotEmpty) Text(sofor, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(4)),
                            child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _ozetGostergeleriOlustur(Map<String, dynamic> gunData) {
    int calisan = 0;
    int istirahat = 0;
    int nobetci = 0;

    gunData.forEach((key, value) {
      if (value == 'C') {
        calisan++;
      } else if (value == 'I') {
        istirahat++;
      } else if (value == 'N') {
        nobetci++;
      }
    });

    List<Widget> gostergeler = [];
    if (calisan > 0) gostergeler.add(_ozetChip("$calisan Ç", Colors.blue));
    if (istirahat > 0) gostergeler.add(_ozetChip("$istirahat İ", Colors.purple));
    if (nobetci > 0) gostergeler.add(_ozetChip("$nobetci N", Colors.orange));

    return gostergeler;
  }

  Widget _ozetChip(String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        metin,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _aracSecici() {
    final benzersizPlakalar = araclar.map((a) => (a['plaka'] ?? "").toString()).where((p) => p.isNotEmpty).toSet();
    bool hepsiSecili = benzersizPlakalar.isNotEmpty && seciliAraclar.length >= benzersizPlakalar.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: hepsiSecili ? Colors.blue.shade100 : Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              label: Text(hepsiSecili ? "Bırak" : "Hepsi", style: const TextStyle(fontSize: 14)),
              onPressed: () {
                setState(() {
                  if (hepsiSecili) {
                    seciliAraclar.clear();
                  } else {
                    seciliAraclar.addAll(benzersizPlakalar);
                  }
                });
              },
            ),
          ),
          ...araclar.map((arac) {
            String plaka = arac['plaka'] ?? "";
            if (plaka.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                backgroundColor: Colors.white,
                selectedColor: Colors.blue.shade50,
                side: BorderSide(color: Colors.grey.shade300),
                label: Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                selected: seciliAraclar.contains(plaka),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    seciliAraclar.add(plaka);
                  } else {
                    seciliAraclar.remove(plaka);
                  }
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _durumSecici() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _durumChip('C', 'Çalış', Colors.blue),
          _durumChip('I', 'İst.', Colors.purple),
          _durumChip('N', 'Nöbet', Colors.orange),
          _durumChip('1-1', '1 gün çalış 1 istirahat', Colors.teal),
        ],
      ),
    );
  }

  Widget _durumChip(String deger, String etiket, Color renk) {
    bool aktifMi = seciliAraclar.isNotEmpty && operasyonModu == 'ekle';
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        label: Text(etiket, style: TextStyle(fontSize: 14, color: seciliDurum == deger ? Colors.white : (aktifMi ? renk : Colors.grey))),
        selected: seciliDurum == deger,
        selectedColor: renk,
        onSelected: aktifMi ? (s) => setState(() {
          if (s && deger == '1-1') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("1-1 Düzeni Hakkında"),
                content: const Text(
                  "Bu mod seçildiğinde:\n\n"
                  "• Seçtiğiniz araçlar o gün 'Çalış' başlar.\n"
                  "• SEÇMEDİĞİNİZ tüm araçlar 'İstirahat' başlar.\n"
                  "• Tüm ay bu düzene göre otomatik doldurulur.\n"
                  "• Nöbetçi (N) olan günler korunur.\n\n"
                  "Devam etmek istiyor musunuz?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Vazgeç"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => seciliDurum = '1-1');
                      Navigator.pop(context);
                    },
                    child: const Text("Devam Et"),
                  ),
                ],
              ),
            );
            return;
          }
          seciliDurum = s ? deger : null;
          if (!s && seciliGunler.isNotEmpty) {
            for (var gunKey in seciliGunler) {
              if (aylikVeri.containsKey(gunKey)) {
                final yeniMap = Map<String, dynamic>.from(aylikVeri[gunKey]!);
                bool degisti = false;
                for (var p in seciliAraclar) {
                  if (yeniMap.containsKey(p)) {
                    yeniMap.remove(p);
                    degisti = true;
                  }
                }
                if (degisti) {
                  if (yeniMap.isEmpty) {
                    aylikVeri.remove(gunKey);
                  } else {
                    aylikVeri[gunKey] = yeniMap;
                  }
                  String ayKey = gunKey.substring(0, 7);
                  degisenAylar.add(ayKey);
                }
              }
            }
          }
        }) : null,
      ),
    );
  }
}
