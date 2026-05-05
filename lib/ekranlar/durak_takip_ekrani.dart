import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../modeller/esnaf_modeli.dart';

class DurakTakipEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const DurakTakipEkrani({super.key, required this.esnaf, this.soforTel});

  @override
  State<DurakTakipEkrani> createState() => _DurakTakipEkraniState();
}

class _DurakTakipEkraniState extends State<DurakTakipEkrani> {
  List<Map<String, dynamic>> araclar = [];
  StreamSubscription? _aracSubscription;

  @override
  void initState() {
    super.initState();
    _araclariDinle();
  }

  @override
  void dispose() {
    _aracSubscription?.cancel();
    super.dispose();
  }

  void _araclariDinle() {
    _aracSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          List<Map<String, dynamic>> hamListe = List<Map<String, dynamic>>.from(data['araclar'] ?? []);
          
          // Kesin Sıralama Mantığı:
          hamListe.sort((a, b) {
            // 1. Durakta olanları (true) en başa al
            bool aDurakta = a['durakta'] == true;
            bool bDurakta = b['durakta'] == true;

            if (aDurakta != bDurakta) {
              return aDurakta ? -1 : 1;
            }

            // 2. Her ikisi de duraktaysa, siraZamani'na göre (en eski giren 1. olur)
            if (aDurakta && bDurakta) {
              int aZaman = a['siraZamani'] ?? 0;
              int bZaman = b['siraZamani'] ?? 0;
              if (aZaman != bZaman) return aZaman.compareTo(bZaman);
            }
            
            // 3. Her ikisi de dışarıdaysa veya zamanlar eşitse plakaya göre
            String aPlaka = a['plaka'] ?? "";
            String bPlaka = b['plaka'] ?? "";
            return aPlaka.compareTo(bPlaka);
          });

          if (mounted) {
            setState(() {
              araclar = hamListe;
            });
          }
        }
      }
    });
  }

  Future<void> _kaydet() async {
    try {
      await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).update({
        'araclar': araclar,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  bool get _isSofor => widget.soforTel != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Canlı Durak Takip", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: CustomScrollView(
        slivers: [
          if (araclar.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text("Henüz kayıtlı araç bulunmuyor.", style: TextStyle(color: Colors.grey))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    var arac = araclar[idx];
                    bool durakta = arac['durakta'] ?? false;
                    String durum = arac['durum'] ?? 'Müsait';
                    bool kendiAraci = _isSofor && arac['soforTel'] == widget.soforTel;

                    Color durumRengi = Colors.green;
                    IconData durumIkonu = Icons.local_taxi;

                    if (durum == 'Meşgul') {
                      durumRengi = Colors.red;
                      durumIkonu = Icons.not_interested;
                    } else if (durum == 'Mola') {
                      durumRengi = Colors.orange;
                      durumIkonu = Icons.coffee_rounded;
                    }

                    int siraNo = 0;
                    if (durakta) {
                      var duraktakiler = araclar.where((a) => a['durakta'] == true).toList();
                      siraNo = duraktakiler.indexOf(arac) + 1;
                    }

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: durakta ? Colors.blue.shade700 : durumRengi.withValues(alpha: 0.1),
                            child: durakta
                                ? Text(siraNo.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                : Icon(durumIkonu, color: durumRengi),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  arac['plaka'] ?? "Plaka Yok",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (durakta)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    siraNo == 1 ? "SIRADAKİ" : "$siraNo. SIRA",
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (kendiAraci)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("Siz", style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            "${arac['soforAd'] ?? 'Şoför Belirtilmemiş'} - $durum ${durakta ? '(Durakta)' : ''}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: (widget.soforTel == null || kendiAraci)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: () => _sirayaGirCik(idx, durakta),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: durakta ? Colors.orange.shade50 : Colors.green.shade50,
                                          foregroundColor: durakta ? Colors.orange : Colors.green,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        child: Text(
                                          kendiAraci
                                              ? (durakta ? "Sıradan Çık" : "Sıraya Gir")
                                              : (durakta ? "Sıradan Çıkar" : "Sıraya Al"),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (String yeniDurum) async {
                                        setState(() => araclar[idx]['durum'] = yeniDurum);
                                        await _kaydet();
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
                        ),
                        if (idx < araclar.length - 1) const Divider(),
                      ],
                    );
                  },
                  childCount: araclar.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sirayaGirCik(int idx, bool durakta) async {
    if (!durakta) {
      try {
        var esDoc = await FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).get();
        GeoPoint guncelDurakKonumu = widget.esnaf.konum;

        if (esDoc.exists && esDoc.data()?['konum'] != null) {
          guncelDurakKonumu = esDoc.data()?['konum'];
        }

        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
        );
        double hamMesafe = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          guncelDurakKonumu.latitude,
          guncelDurakKonumu.longitude,
        );

        // GPS hata payını düşerek net mesafeyi buluyoruz.
        double netMesafe = hamMesafe - pos.accuracy;
        if (netMesafe < 0) netMesafe = 0;

        if (netMesafe > 5) { // 5 metre net sınır
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Icon(Icons.location_off, color: Colors.red, size: 40),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Durakta Değilsiniz",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Sıraya girmek için durağın 5 metre yakınında olmalısınız.\n\n"
                      "Ölçülen: ${hamMesafe < 1000 ? "${hamMesafe.toStringAsFixed(1)} m" : "${(hamMesafe / 1000).toStringAsFixed(2)} km"}\n"
                      "Hata Payı: ±${pos.accuracy < 1000 ? "${pos.accuracy.toStringAsFixed(1)} m" : "${(pos.accuracy / 1000).toStringAsFixed(2)} km"}\n"
                      "Net Mesafe: ${netMesafe < 1000 ? "${netMesafe.toStringAsFixed(1)} m" : "${(netMesafe / 1000).toStringAsFixed(2)} km"}",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Tamam", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konum doğrulanırken bir hata oluştu."), backgroundColor: Colors.orange),
          );
        }
        return;
      }
    }

    setState(() {
      araclar[idx]['durakta'] = !durakta;
      if (araclar[idx]['durakta']) {
        araclar[idx]['siraZamani'] = DateTime.now().millisecondsSinceEpoch;
        araclar[idx]['durum'] = 'Müsait';
      }
    });
    await _kaydet();
  }
}
