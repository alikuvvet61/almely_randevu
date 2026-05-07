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
  List<Map<String, dynamic>> araclar = [];
  bool yukleniyor = true;
  bool degisiklikVar = false;
  DateTime seciliAy = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, Map<String, dynamic>> aylikVeri = {};
  Set<String> yuklenenAylar = {};

  DateTime? baslangicTarihi;
  Set<String> seciliAraclar = {};
  String? seciliDurum;
  Set<String> seciliGunler = {};

  int periyotDeger = 1;
  String periyotBirim = "Ay";
  late TextEditingController periyotController;

  final List<String> gunler = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];

  @override
  void initState() {
    super.initState();
    baslangicTarihi = seciliAy;
    periyotController = TextEditingController(text: periyotDeger.toString());
    _verileriGetir();
  }

  @override
  void dispose() {
    periyotController.dispose();
    super.dispose();
  }

  Future<void> _verileriGetir({bool temizle = true}) async {
    if (temizle) setState(() => yukleniyor = true);

    final esnafDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
    String ayKey = DateFormat('yyyy-MM').format(seciliAy);
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
          // Tamamen sıfırla ve Firebase'den geleni al
          aylikVeri = Map<String, Map<String, dynamic>>.from(gelenVeri);
        } else {
          // Mevcut yerel verileri (değişiklikleri) koru,
          // sadece bu ayın henüz yerelde olmayan verilerini Firebase'den çek
          gelenVeri.forEach((key, value) {
            if (!aylikVeri.containsKey(key)) {
              aylikVeri[key] = Map<String, dynamic>.from(value);
            }
          });
        }
        // degisiklikVar = false; // BU SATIRI KALDIRIYORUZ
        yukleniyor = false;
      });
    }
  }

  Future<void> _ajandaKaydet() async {
    final batch = FirebaseFirestore.instance.batch();

    // Yüklenen/işlem gören her ay için güncel veriyi gönder
    for (String ayKey in yuklenenAylar) {
      Map<String, Map<String, dynamic>> ayData = {};

      // aylikVeri içinden bu aya ait olanları (ve içi dolu olanları) topla
      aylikVeri.forEach((tarih, data) {
        if (tarih.startsWith(ayKey) && data.isNotEmpty) {
          ayData[tarih] = data;
        }
      });

      // merge: false kullanarak dökümanı tamamen güncelliyoruz.
      // Eğer ayData boşsa, Firebase dökümanı da temizlenmiş olur.
      batch.set(
        FirebaseFirestore.instance
            .collection('esnaflar')
            .doc(widget.esnaf.id)
            .collection('taksi_ajanda')
            .doc(ayKey),
        ayData,
        SetOptions(merge: false)
      );
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() => degisiklikVar = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Tüm değişiklikler başarıyla Firebase'e kaydedildi"),
          backgroundColor: Colors.green,
        ));
        // Kayıt sonrası verileri tazeleyelim (mevcut yerel durumu koruyarak)
        _verileriGetir(temizle: false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kaydetme Hatası: $e"), backgroundColor: Colors.red));
    }
  }

  void _topluSil() {
    setState(() {
      for (var gunKey in seciliGunler) {
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
      degisiklikVar = true;
    });
  }

  void _gunDetayGoster(DateTime tarih) {
    String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
      Map<String, dynamic> currentGunData = aylikVeri[tarihKey] ?? {};
      return AlertDialog(
        title: Text("${DateFormat('dd MMMM yyyy', 'tr_TR').format(tarih)} Detayı"),
        content: SizedBox(width: double.maxFinite, child: currentGunData.isEmpty ? const Text("Kayıt yok.") : ListView(shrinkWrap: true, children: currentGunData.entries.map((e) => ListTile(title: Text(e.key), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { currentGunData.remove(e.key); if (currentGunData.isEmpty) aylikVeri.remove(tarihKey); degisiklikVar = true; }); setDialogState(() {}); }))).toList())),
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
              onPressed: () {
                setState(() {
                  seciliGunler.clear();
                  _verileriGetir(temizle: true);
                  degisiklikVar = false;
                });
              },
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
                seciliGunler.clear();
                _verileriGetir(temizle: false);
              }),
            ),
            Column(
              children: [
                Text(DateFormat('MMMM yyyy', 'tr_TR').format(seciliAy), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Değişiklikler yereldir, kaydetmeyi unutmayın", style: TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                seciliAy = DateTime(seciliAy.year, seciliAy.month + 1, 1);
                seciliGunler.clear();
                _verileriGetir(temizle: false);
              }),
            ),
          ],
        ),
      ),
  // 2. Araç Seçimi
  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Araç Seçin", style: TextStyle(fontWeight: FontWeight.bold))),
  _aracSecici(),

  // 3. Durum / Patern Seçimi
  const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text("Uygulanacak Durum / Patern", style: TextStyle(fontWeight: FontWeight.bold))),
  _durumSecici(),
  
  const Divider(),
      Expanded(child: SingleChildScrollView(child: Column(children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: gunSayisi + baslangicBosluk,
          itemBuilder: (context, index) {
            if (index < baslangicBosluk) return const SizedBox.shrink();
            int gun = index - baslangicBosluk + 1;
            DateTime tarih = DateTime(seciliAy.year, seciliAy.month, gun);
            String tarihKey = DateFormat('yyyy-MM-dd').format(tarih);
            final gunData = aylikVeri[tarihKey] ?? {};

            return InkWell(
              onTap: () {
                setState(() {
                  if (seciliGunler.contains(tarihKey)) {
                    seciliGunler.remove(tarihKey);
                  } else {
                    seciliGunler.add(tarihKey);
                  }
                });

                if (seciliAraclar.isEmpty || seciliDurum == null) return;

                setState(() {
                  if (seciliDurum == '1-1') {
                    int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
                    for (int i = gun; i <= gunSayisi; i++) {
                      String k = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
                      if ((i - gun) % 2 == 0) {
                        if (!aylikVeri.containsKey(k)) aylikVeri[k] = {};
                        for (var p in seciliAraclar) {
                          aylikVeri[k]![p] = 'C';
                        }
                      }
                    }
                  } else {
                    if (!aylikVeri.containsKey(tarihKey)) aylikVeri[tarihKey] = {};
                    for (var p in seciliAraclar) {
                      aylikVeri[tarihKey]![p] = seciliDurum!;
                    }
                  }
                  degisiklikVar = true;
                });
              },
              onLongPress: () => _gunDetayGoster(tarih),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: seciliGunler.contains(tarihKey) ? Colors.black : Colors.grey, width: seciliGunler.contains(tarihKey) ? 2.0 : 1.0)
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gun.toString(), style: TextStyle(color: Colors.black, fontWeight: seciliGunler.contains(tarihKey) ? FontWeight.bold : FontWeight.normal)),
                      if (gunData.isNotEmpty)
                        ...gunData.entries.map((e) {
                          Color plakaRengi = Colors.black;
                          if (e.value == 'N') plakaRengi = Colors.orange.shade900;
                          if (e.value == 'I') plakaRengi = Colors.purple;
                          if (e.value == 'C') plakaRengi = Colors.blue;

                          return Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 8,
                              color: plakaRengi,
                              fontWeight: FontWeight.bold
                            )
                          );
                        }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ]))),
      Container(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: _ajandaKaydet, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white), child: const Text("Tüm Değişiklikleri Kaydet"))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: () {
            setState(() {
              int gunSayisi = DateTime(seciliAy.year, seciliAy.month + 1, 0).day;
              for (int i = 1; i <= gunSayisi; i++) {
                String tarihKey = DateFormat('yyyy-MM-dd').format(DateTime(seciliAy.year, seciliAy.month, i));
                seciliGunler.add(tarihKey);
              }
              degisiklikVar = true;
            });
          }, child: const Text("Tüm Ayı Seç"))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(onPressed: seciliGunler.isEmpty ? null : _topluSil, child: const Text("Seçiliyi Sil"))),
        ]),
      ]))
    ]);
  }

  Widget _aracSecici() {
    final benzersizPlakalar = araclar.map((a) => (a['plaka'] ?? "").toString()).where((p) => p.isNotEmpty).toSet();
    bool hepsiSecili = benzersizPlakalar.isNotEmpty && seciliAraclar.length >= benzersizPlakalar.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: hepsiSecili ? Colors.blue.shade100 : null,
              label: Text(hepsiSecili ? "Seçimi Kaldır" : "Tümünü Seç"),
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
            String sofor = arac['soforAd'] ?? arac['sofor'] ?? "";
            if (plaka.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (sofor.isNotEmpty) Text(sofor, style: const TextStyle(fontSize: 10)),
                  ],
                ),
                selected: seciliAraclar.contains(plaka),
                onSelected: (selected) => setState(() => selected ? seciliAraclar.add(plaka) : seciliAraclar.remove(plaka)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _durumChip('C', 'Çalışıyor', Colors.blue),
          _durumChip('I', 'İstirahat', Colors.purple),
          _durumChip('N', 'Nöbetçi', Colors.orange),
          _durumChip('1-1', '1/1 Düzen', Colors.orange),
        ],
      ),
    );
  }

  Widget _durumChip(String deger, String etiket, Color renk) {
    bool aracSeciliMi = seciliAraclar.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(etiket, style: TextStyle(color: seciliDurum == deger ? Colors.white : (aracSeciliMi ? renk : Colors.grey))),
        selected: seciliDurum == deger,
        selectedColor: renk,
        onSelected: aracSeciliMi ? (s) => setState(() => seciliDurum = s ? deger : null) : null,
      ),
    );
  }
}
