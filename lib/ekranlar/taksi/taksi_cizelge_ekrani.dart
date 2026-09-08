import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../modeller/esnaf_modeli.dart';
// import '../esnaf_paneli.dart'; // not used here

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
  final TextEditingController _aracAramaController = TextEditingController();


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


  // Minimal build to keep analyzer happy. Replace with full UI later if needed.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taksi Çizelge'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seçili Ay: ${DateFormat('MMMM yyyy', 'tr_TR').format(seciliAy)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: araclar.length,
                      itemBuilder: (context, i) {
                        final a = araclar[i];
                        return ListTile(
                          title: Text(a['plaka'] ?? 'Araç ${i+1}'),
                          subtitle: Text(a['soforAd'] ?? ''),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton(onPressed: _ajandaKaydet, child: kaydediliyor ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kaydet')),
                      const SizedBox(width: 12),
                      OutlinedButton(onPressed: () => _verileriGetir(temizle: true), child: const Text('Yenile')),
                    ],
                  )
                ],
              ),
            ),
    );
  }
}
