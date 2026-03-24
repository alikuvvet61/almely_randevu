import 'package:flutter/material.dart';

void main() => runApp(AlmElyApp());

class AlmElyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AlmEly Türkiye',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatelessWidget {
  // Sektör listemiz (İleride buraya yenilerini eklemek çok kolay)
  final List<Map<String, dynamic>> kategoriler = [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.yellow[700]},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.red},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Düğün Salonu', 'ikon': Icons.event, 'renk': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AlmEly Randevu Portalı"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Yan yana 2 kutu
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: kategoriler.length,
          itemBuilder: (context, index) {
            final kat = kategoriler[index];
            return InkWell(
              onTap: () {
                // Tıklandığında o sektöre gidecek
                print("${kat['ad']} seçildi!");
              },
              child: Card(
                elevation: 4,
                color: kat['renk'],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(kat['ikon'], size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text(kat['ad'], style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}