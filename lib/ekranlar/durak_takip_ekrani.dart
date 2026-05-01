import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _araclariDinle();
  }

  void _araclariDinle() {
    FirebaseFirestore.instance
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
      body: araclar.isEmpty
          ? const Center(child: Text("Henüz kayıtlı araç bulunmuyor.", style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: araclar.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, idx) {
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
                  // Sadece durakta olanlar arasında kaçıncı sırada olduğunu bul
                  var duraktakiler = araclar.where((a) => a['durakta'] == true).toList();
                  siraNo = duraktakiler.indexOf(arac) + 1;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: durakta ? Colors.blue.shade700 : durumRengi.withValues(alpha: 0.1),
                    child: durakta 
                      ? Text(siraNo.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      : Icon(durumIkonu, color: durumRengi),
                  ),
                  title: Row(
                    children: [
                      Text(arac['plaka'] ?? "Plaka Yok", style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (durakta)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(4)),
                          child: Text(siraNo == 1 ? "SIRADAKİ ARAÇ" : "$siraNo. SIRADA", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
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
                  trailing: (widget.soforTel == null || kendiAraci) 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                araclar[idx]['durakta'] = !durakta;
                                if (araclar[idx]['durakta']) {
                                  araclar[idx]['siraZamani'] = DateTime.now().millisecondsSinceEpoch;
                                  araclar[idx]['durum'] = 'Müsait';
                                }
                              });
                              await _kaydet();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: durakta ? Colors.orange.shade50 : Colors.green.shade50,
                              foregroundColor: durakta ? Colors.orange : Colors.green,
                              elevation: 0,
                            ),
                            child: Text(
                              kendiAraci 
                                ? (durakta ? "Sıradan Çık" : "Sıraya Gir")
                                : (durakta ? "Sıradan Çıkar" : "Sıraya Al"), 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
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
                    : null, // Şoför ise ve kendi aracı değilse butonları gösterme
                );
              },
            ),
    );
  }
}
