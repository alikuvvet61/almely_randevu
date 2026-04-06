import 'package:flutter/material.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import 'esnaf_detay_ekrani.dart';

class AnaEkran extends StatelessWidget {
  const AnaEkran({super.key});

  final List<Map<String, dynamic>> kategoriler = const [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.amber},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.redAccent},
    {'ad': 'Düğün Salonu', 'ikon': Icons.celebration, 'renk': Colors.purple},
  ];

  void _esnafListesiAc(BuildContext context, String katAd) {
    final firestoreServisi = FirestoreServisi();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 15),
          Text("$katAd Esnafları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<EsnafModeli>>(
              stream: firestoreServisi.kategoriyeGoreGetir(katAd),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final esnaflar = snapshot.data ?? [];
                if (esnaflar.isEmpty) {
                  return const Center(child: Text("Henüz esnaf bulunamadı."));
                }

                return ListView.builder(
                  itemCount: esnaflar.length,
                  itemBuilder: (context, i) {
                    final esnaf = esnaflar[i];
                    return ListTile(
                      title: Text(esnaf.isletmeAdi),
                      subtitle: Text("${esnaf.ilce} - ${esnaf.telefon}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Detay sayfasına geçiş yapıyoruz
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EsnafDetayEkrani(esnaf: esnaf),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AlmEly - Trabzon"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          crossAxisSpacing: 12, 
          mainAxisSpacing: 12,
        ),
        itemCount: kategoriler.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => _esnafListesiAc(context, kategoriler[i]['ad']),
          child: Card(
            color: kategoriler[i]['renk'],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(kategoriler[i]['ikon'], size: 50, color: Colors.white),
                Text(
                  kategoriler[i]['ad'], 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
