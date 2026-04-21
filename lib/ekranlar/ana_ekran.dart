import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import 'esnaf_detay_ekrani.dart';
import 'kullanici_randevu_ekrani.dart';

class AnaEkran extends StatefulWidget {
  final String? kullaniciTel;
  const AnaEkran({super.key, this.kullaniciTel});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final FirestoreServisi firestoreServisi = FirestoreServisi();
  Position? _currentPosition;

  final List<Map<String, dynamic>> kategoriler = const [
    {'ad': 'Kuaför', 'ikon': Icons.content_cut, 'renk': Colors.orange},
    {'ad': 'Taksi', 'ikon': Icons.local_taxi, 'renk': Colors.amber},
    {'ad': 'Halı Saha', 'ikon': Icons.sports_soccer, 'renk': Colors.green},
    {'ad': 'Oto Yıkama', 'ikon': Icons.local_car_wash, 'renk': Colors.blue},
    {'ad': 'Restoran', 'ikon': Icons.restaurant, 'renk': Colors.redAccent},
    {'ad': 'Düğün Salonu', 'ikon': Icons.celebration, 'renk': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Konum alma hatası: $e");
    }
  }

  double _mesafeHesapla(EsnafModeli esnaf) {
    if (_currentPosition == null) return -1;
    if (esnaf.konum.latitude == 0 && esnaf.konum.longitude == 0) return -1;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      esnaf.konum.latitude,
      esnaf.konum.longitude,
    );
  }

  String _formatMesafe(double metre) {
    if (metre < 1000) return "${metre.toStringAsFixed(0)} m";
    return "${(metre / 1000).toStringAsFixed(1)} km";
  }

  void _esnafListesiAc(BuildContext context, String katAd) {
    // Konum yoksa varsayılan sıralama 'isim' olsun
    String siralamaKriteri = _currentPosition == null ? 'isim' : 'mesafe';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              Text("$katAd Esnafları", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              
              // SIRALAMA SEÇENEKLERİ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text("Sıralama:", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                        const SizedBox(width: 10),
                        if (_currentPosition != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _siralamaChip(
                              label: "Mesafe", 
                              icon: Icons.near_me, 
                              secili: siralamaKriteri == 'mesafe',
                              onTap: () => setModalState(() => siralamaKriteri = 'mesafe')
                            ),
                          ),
                        _siralamaChip(
                          label: "İsim", 
                          icon: Icons.sort_by_alpha, 
                          secili: siralamaKriteri == 'isim',
                          onTap: () => setModalState(() => siralamaKriteri = 'isim')
                        ),
                      ],
                    ),
                    if (_currentPosition == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.location_off, size: 18, color: Colors.amber),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "En yakın esnafları görebilmek için konum izni verebilirsiniz.",
                                  style: TextStyle(fontSize: 12, color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: StreamBuilder<List<EsnafModeli>>(
                  stream: firestoreServisi.kategoriyeGoreGetir(katAd),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    List<EsnafModeli> esnaflar = snapshot.data ?? [];
                    if (esnaflar.isEmpty) return const Center(child: Text("Bu kategoride henüz esnaf bulunamadı."));

                    // Verileri hazırla
                    final List<Map<String, dynamic>> liste = esnaflar.map((e) {
                      return {'data': e, 'mesafe': _mesafeHesapla(e)};
                    }).toList();

                    // KRİTERE GÖRE SIRALA
                    liste.sort((a, b) {
                      final esnafA = a['data'] as EsnafModeli;
                      final esnafB = b['data'] as EsnafModeli;

                      if (siralamaKriteri == 'mesafe' && _currentPosition != null) {
                        double dA = a['mesafe'] as double;
                        double dB = b['mesafe'] as double;
                        if (dA == -1 && dB != -1) return 1;
                        if (dA != -1 && dB == -1) return -1;
                        if (dA != -1 && dB != -1) return dA.compareTo(dB);
                      }
                      
                      // İsim sıralaması veya Fallback
                      return esnafA.isletmeAdi.toLowerCase().compareTo(esnafB.isletmeAdi.toLowerCase());
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: liste.length,
                      separatorBuilder: (context, i) => const Divider(height: 1, indent: 70),
                      itemBuilder: (context, i) {
                        final esnaf = liste[i]['data'] as EsnafModeli;
                        final mesafe = liste[i]['mesafe'] as double;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blue.shade50,
                            child: const Icon(Icons.store, color: Colors.blue, size: 28),
                          ),
                          title: Text(esnaf.isletmeAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("${esnaf.ilce} - ${esnaf.telefon}", style: TextStyle(color: Colors.grey.shade700)),
                              if (mesafe != -1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatMesafe(mesafe),
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EsnafDetayEkrani(esnaf: esnaf, kullaniciTel: widget.kullaniciTel))),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _siralamaChip({required String label, required IconData icon, required bool secili, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: secili ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secili ? Colors.blue : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: secili ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: secili ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AlmEly - Trabzon"),
        centerTitle: true,
        actions: [
          if (widget.kullaniciTel != null)
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.blue),
              tooltip: "Randevularım",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => KullaniciRandevuEkrani(telefon: widget.kullaniciTel!))
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.kullaniciTel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => KullaniciRandevuEkrani(telefon: widget.kullaniciTel!))
                ),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "Randevularım",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: kategoriler.length,
              itemBuilder: (context, i) => InkWell(
                onTap: () => _esnafListesiAc(context, kategoriler[i]['ad']),
                borderRadius: BorderRadius.circular(15),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: kategoriler[i]['renk'],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(kategoriler[i]['ikon'], size: 45, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        kategoriler[i]['ad'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
