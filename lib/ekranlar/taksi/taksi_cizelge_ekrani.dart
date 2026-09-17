import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'taksi_rehber_ekrani.dart';

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
  String? operasyonModu;
  Set<String> seciliGunler = {};
  DateTime seciliGun = DateTime.now();
  String _seciliKapsam = "AY";

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

    setState(() {
      seciliGunler.clear();
      if (seciliGun.year != seciliAy.year || seciliGun.month != seciliAy.month) {
        DateTime simdi = DateTime.now();
        if (simdi.year == seciliAy.year && simdi.month == seciliAy.month) {
          seciliGun = simdi;
        } else {
          seciliGun = DateTime(seciliAy.year, seciliAy.month, 1);
        }
      }
      if (!yuklenenAylar.contains(ayKey)) {
        yukleniyor = true;
      }
    });

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

      for (var i = 0; i < aylarList.length; i += 500) {
        final end = (i + 500 < aylarList.length) ? i + 500 : aylarList.length;
        final chunk = aylarList.sublist(i, end);

        final batch = firestore.batch();

        for (String ayKey in chunk) {
          Map<String, Map<String, dynamic>> ayData = {};

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

  void _gunuTemizle(DateTime tarih) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String zamanMetni = "bugün";
          if (_seciliKapsam == "HAFTA") {
            zamanMetni = "1 hafta boyunca";
          } else if (_seciliKapsam == "AY") {
            zamanMetni = "ay sonuna kadar";
          } else if (_seciliKapsam == "YIL") {
            zamanMetni = "yıl sonuna kadar";
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(child: Text("Kayıtları Temizle", style: TextStyle(fontWeight: FontWeight.bold))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _kapsamSeciciWidget(setDialogState),
                const SizedBox(height: 20),
                Text(
                  _seciliKapsam == "GÜN"
                      ? "${DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(tarih)} gününe ait tüm kayıtları silmek istediğinizden emin misiniz?"
                      : "Seçili günden itibaren $zamanMetni tüm kayıtları silmek istediğinizden emin misiniz?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal", style: TextStyle(fontSize: 15))),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _executePlanLoop((t, ayKey) {
                      String tKey = DateFormat('yyyy-MM-dd').format(t);
                      if (aylikVeri.containsKey(tKey)) {
                        aylikVeri.remove(tKey);
                        degisenAylar.add(ayKey);
                      }
                    });
                  });
                },
                child: const Text("Evet, Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          );
        },
      ),
    );
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
          if (seciliDurum == '1-1') {
            int gunFarki = tarih.difference(DateTime(seciliGun.year, seciliGun.month, seciliGun.day)).inDays;
            final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
            final baslangicGunData = aylikVeri[gunKey] ?? {};

            final bugunCalisanlar = baslangicGunData.entries
                .where((e) => e.value?.toString().contains('C') == true)
                .map((e) => e.key)
                .toSet();

            for (var a in araclar) {
              String plaka = a['plaka'].toString();
              bool bugunCalisiyor = bugunCalisanlar.contains(plaka);
              bool oGunCalisacak = (gunFarki % 2 == 0) ? bugunCalisiyor : !bugunCalisiyor;

              String mevcut = gunMap[plaka]?.toString() ?? "";
              String yeni;

              if (oGunCalisacak) {
                if (mevcut == 'I') {
                  yeni = 'C';
                } else if (!mevcut.contains('C')) {
                  yeni = '${mevcut}C';
                } else {
                  yeni = mevcut;
                }
              } else {
                if (mevcut == 'C') {
                  yeni = 'I';
                } else {
                  yeni = mevcut.replaceAll('C', '');
                  if (yeni.isEmpty) yeni = 'I';
                }
              }

              List<String> chars = yeni.split('');
              chars.sort();
              String siraliYeni = chars.join('');

              if (mevcut != siraliYeni) {
                gunMap[plaka] = siraliYeni;
                degisti = true;
              }
            }
          } else {
            for (var p in seciliAraclar) {
              String mevcut = gunMap[p]?.toString() ?? "";
              if (seciliDurum == 'I') {
                if (mevcut != 'I') {
                  gunMap[p] = 'I';
                  degisti = true;
                }
              } else {
                String yeni = mevcut;
                if (mevcut == 'I') {
                  yeni = seciliDurum!;
                } else {
                  for (var char in seciliDurum!.split('')) {
                    if (!yeni.contains(char)) yeni += char;
                  }
                }

                List<String> chars = yeni.split('');
                chars.sort();
                String siraliYeni = chars.join('');

                if (mevcut != siraliYeni) {
                  gunMap[p] = siraliYeni;
                  degisti = true;
                }
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
        if (context.mounted && shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Nöbet Çizelgesi & Ajanda Defteri"),
          actions: [
            IconButton(
              tooltip: "Kullanım Rehberi",
              icon: const Icon(Icons.help_outline, color: Colors.blue),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TaksiRehberEkrani(mod: 'yonetici', bolum: 'cizelge'))),
            ),
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
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        color: Colors.grey.shade50,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: () => setState(() {
                    seciliAy = DateTime(seciliAy.year, seciliAy.month - 1, 1);
                    _verileriGetir(temizle: false);
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'tr_TR').format(seciliAy),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: () => setState(() {
                    seciliAy = DateTime(seciliAy.year, seciliAy.month + 1, 1);
                    _verileriGetir(temizle: false);
                  }),
                ),
              ],
            ),
            if (degisiklikVar)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 14, color: Colors.orange.shade900),
                    const SizedBox(width: 4),
                    Text(
                      "KAYDEDİLMEMİŞ DEĞİŞİKLİKLER",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: gunler.map((g) => Expanded(
            child: Center(child: Text(g, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600))),
          )).toList(),
        ),
      ),

      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.5,
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
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.lightBlue.shade50 : Colors.white,
                border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 0.5
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      gun.toString(),
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      )
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _ozetGostergeleriOlustur(gunData),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      Expanded(
        child: _seciliGunDetayPaneli(DateFormat('yyyy-MM-dd').format(seciliGun)),
      ),

      _altAksiyonlar(),
    ]);
  }

  List<Widget> _ozetGostergeleriOlustur(Map<String, dynamic> gunData) {
    bool calisanVar = gunData.values.any((v) => v.toString().contains('C'));
    bool nobetciVar = gunData.values.any((v) => v.toString().contains('N'));
    bool istirahatVar = gunData.values.any((v) => v.toString().contains('I'));

    List<Widget> noktaListesi = [];
    if (calisanVar) noktaListesi.add(_noktaWidget(Colors.blue));
    if (nobetciVar) noktaListesi.add(_noktaWidget(Colors.orange));
    if (istirahatVar) noktaListesi.add(_noktaWidget(Colors.purple));

    return noktaListesi;
  }

  Widget _noktaWidget(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _seciliGunDetayPaneli(String gunKey) {
    final gunData = aylikVeri[gunKey] ?? {};

    List<Map<String, dynamic>> filtrelenmisAraclar = araclar.where((a) {
      if (_aracAramaFiltresi.isEmpty) return true;
      final plaka = (a['plaka'] ?? "").toString().toLowerCase();
      final sofor = (a['soforAd'] ?? a['sofor'] ?? "").toString().toLowerCase();
      return plaka.contains(_aracAramaFiltresi.toLowerCase()) || sofor.contains(_aracAramaFiltresi.toLowerCase());
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.lightBlue.shade50.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(seciliGun),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                  ),
                  const Spacer(),
                  if (gunData.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _gunuTemizle(seciliGun),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text("Kayıt Sil", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    "${filtrelenmisAraclar.length}/${araclar.length} Araç",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _aracAramaController,
                  onChanged: (v) => setState(() => _aracAramaFiltresi = v),
                  decoration: InputDecoration(
                    hintText: "Plaka veya Şoför Ara...",
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.blue),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtrelenmisAraclar.length,
            itemBuilder: (context, index) {
              final a = filtrelenmisAraclar[index];
              String plaka = a['plaka'] ?? "";
              String sofor = a['soforAd'] ?? a['sofor'] ?? "";
              int? nobetSira = a['nobetSirasi'];
              String durum = gunData[plaka]?.toString() ?? "";

              bool calisiyor = durum.contains('C');
              bool nobetci = durum.contains('N');
              bool istirahatte = durum.contains('I');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(plaka, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                if (nobetSira != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Text("№ $nobetSira", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                                  ),
                                ]
                              ],
                            ),
                            if (sofor.isNotEmpty)
                              Text(sofor, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      _durumButonu("Çalış", calisiyor, Colors.blue, () => _durumDegistir(plaka, 'C', gunKey)),
                      const SizedBox(width: 4),
                      _durumButonu("Nöbet", nobetci, Colors.orange, () => _durumDegistir(plaka, 'N', gunKey)),
                      const SizedBox(width: 4),
                      _durumButonu("İst.", istirahatte, Colors.purple, () => _durumDegistir(plaka, 'I', gunKey)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.double_arrow, size: 16, color: Colors.blue),
                        onPressed: () {
                          setState(() {
                            seciliAraclar = {plaka};
                            seciliDurum = durum.isNotEmpty ? durum : 'C';
                            operasyonModu = 'ekle';
                          });
                          _planOlusturOnayiAl(1);
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _durumButonu(String etiket, bool aktif, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: aktif ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: aktif ? color : Colors.grey.shade300),
        ),
        child: Text(
          etiket,
          style: TextStyle(
            color: aktif ? Colors.white : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _durumDegistir(String plaka, String kod, String gunKey) {
    setState(() {
      final gunMap = Map<String, dynamic>.from(aylikVeri[gunKey] ?? {});
      String mevcut = gunMap[plaka]?.toString() ?? "";

      if (kod == 'I') {
        if (mevcut == 'I') {
          gunMap.remove(plaka);
        } else {
          gunMap[plaka] = 'I';
        }
      } else {
        if (mevcut == 'I') mevcut = "";
        if (mevcut.contains(kod)) {
          mevcut = mevcut.replaceAll(kod, '');
        } else {
          mevcut = '$mevcut$kod';
        }

        List<String> chars = mevcut.split('');
        chars.sort();
        mevcut = chars.join('');

        if (mevcut.isEmpty) {
          gunMap.remove(plaka);
        } else {
          gunMap[plaka] = mevcut;
        }
      }

      if (gunMap.isEmpty) {
        aylikVeri.remove(gunKey);
      } else {
        aylikVeri[gunKey] = gunMap;
      }

      String ayKey = gunKey.substring(0, 7);
      degisenAylar.add(ayKey);
    });
  }

  Widget _altAksiyonlar() {
    final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
    final gunData = aylikVeri[gunKey] ?? {};

    final nobetliPlakalar = gunData.entries
        .where((e) => e.value?.toString().contains('N') == true)
        .map((e) => e.key)
        .toList();

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

  Widget _kapsamSeciciWidget(StateSetter setDialogState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ["GÜN", "HAFTA", "AY", "YIL"].map((kapsam) {
          bool secili = _seciliKapsam == kapsam;
          String etiket = kapsam == "GÜN" ? "Gün" : (kapsam == "HAFTA" ? "Hafta" : (kapsam == "AY" ? "Ay" : "Yıl"));
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _seciliKapsam = kapsam);
                setDialogState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: secili ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: secili ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                ),
                child: Text(
                  etiket,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                    color: secili ? Colors.blue : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _planOlusturOnayiAl(int aracSayisi) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String eylemMetni = "çalıştırılmasını";
          if (seciliDurum == 'I') {
            eylemMetni = "istirahat ettirilmesini";
          } else if (seciliDurum == 'N') {
            eylemMetni = "nöbetçi olmasını";
          }

          String zamanMetni = "bugün";
          if (_seciliKapsam == "HAFTA") {
            zamanMetni = "1 hafta boyunca";
          } else if (_seciliKapsam == "AY") {
            zamanMetni = "ay sonuna kadar";
          } else if (_seciliKapsam == "YIL") {
            zamanMetni = "yıl sonuna kadar";
          }

          String dinamikMesaj = _seciliKapsam == "GÜN"
              ? "Seçili $aracSayisi aracın bugün $eylemMetni uygun görüyor musunuz?"
              : "Seçili $aracSayisi aracın seçili günden itibaren $zamanMetni $eylemMetni uygun görüyor musunuz?";

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Center(child: Text("Plan oluştur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _kapsamSeciciWidget(setDialogState),
                const SizedBox(height: 20),
                Text(
                  dinamikMesaj,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Vazgeç", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _topluIslemUygula();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text("Uygula", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          );
        },
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
            String kapsamText = _seciliKapsam == "GÜN"
                ? "sadece bugün"
                : (_seciliKapsam == "HAFTA"
                ? "1 hafta boyunca"
                : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar"));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Nöbet Planı Oluştur"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kapsamSeciciWidget(setDialogState),
                  const SizedBox(height: 20),
                  Text("${DateFormat('dd MMMM', 'tr_TR').format(seciliGun)} için nöbetçi seçildi.", style: const TextStyle(fontWeight: FontWeight.bold)),
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
        List<Map<String, dynamic>> tumu = List.from(araclar);
        tumu.sort((a, b) {
          int siraA = a['nobetSirasi'] ?? 999;
          int siraB = b['nobetSirasi'] ?? 999;
          return siraA.compareTo(siraB);
        });

        List<String> siraliPlakalar = tumu.map((a) => a['plaka'].toString()).toList();

        int startIndex = siraliPlakalar.indexOf(plakalar.first);
        if (startIndex == -1) startIndex = 0;

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

        Map<String, dynamic> yeniGunMap = {};
        gunMap.forEach((plaka, durum) {
          String s = durum.toString().replaceAll('N', '');
          if (s.isNotEmpty) yeniGunMap[plaka] = s;
        });

        String atanacakPlaka = havuz[dayIndex % havuz.length];
        String mevcut = yeniGunMap[atanacakPlaka]?.toString() ?? "";
        if (!mevcut.contains('N')) {
          String birlesik = '${mevcut}N';
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

  void _topluIslemOnayiAl() async {
    if (seciliDurum == '1-1') {
      final gunKey = DateFormat('yyyy-MM-dd').format(seciliGun);
      final gunData = aylikVeri[gunKey] ?? {};

      final calisanPlakalar = gunData.entries
          .where((e) => e.value?.toString().contains('C') == true)
          .map((e) => e.key)
          .toList();

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String kapsamText = _seciliKapsam == "HAFTA"
                ? "1 hafta boyunca"
                : (_seciliKapsam == "AY" ? "ay sonuna kadar" : "yıl sonuna kadar");
            String mesaj;

            if (calisanPlakalar.isEmpty) {
              mesaj = "Bugün için hiçbir araç 'Çalış' (Mavi) olarak seçilmemiş. Lütfen önce bugünkü çalışma düzenini belirleyin.";
            } else {
              mesaj = "Seçili ${calisanPlakalar.length} aracın bugün çalışacağı, diğer tüm araçların istirahat edeceği şekilde $kapsamText 1 gün çalış / 1 gün yat düzeni uygulansın mı?";
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Center(child: Text("Plan oluştur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _kapsamSeciciWidget(setDialogState),
                  const SizedBox(height: 20),
                  Text(
                    mesaj,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Vazgeç", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (calisanPlakalar.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        _topluIslemUygula();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: const Text("Uygula", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
              ],
            );
          },
        ),
      );
    }
  }
}