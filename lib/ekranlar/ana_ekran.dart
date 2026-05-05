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

  IconData _getKategoriIkon(String ad) {
    switch (ad.trim()) {
      case 'Kuaför': return Icons.content_cut;
      case 'Taksi': return Icons.local_taxi;
      case 'Halı Saha': return Icons.sports_soccer;
      case 'Oto Yıkama': return Icons.local_car_wash;
      case 'Restoran': return Icons.restaurant;
      case 'Düğün Salonu': return Icons.celebration;
      case 'Araç Kiralama': return Icons.car_rental;
      case 'Diyetisyen': return Icons.apple;
      case 'Fizyoterapi ve Rehabilitasyon': return Icons.healing;
      case 'Pet Kuaför': return Icons.pets;
      case 'Veteriner': return Icons.pets;
      case 'Psikolog': return Icons.psychology;
      case 'Özel Ders': return Icons.school;
      default: return Icons.business;
    }
  }

  Widget _buildKategoriIcon(String ad, int? ikonKod, {double size = 45, Color color = Colors.white}) {
    if (ikonKod != null) {
      // Dinamik ikonlar için Text widget'ı kullanarak tree-shake hatasını baypas ediyoruz
      return Text(
        String.fromCharCode(ikonKod),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: size,
          color: color,
          inherit: false,
        ),
      );
    }
    return Icon(_getKategoriIkon(ad), size: size, color: color);
  }

  Color _getKategoriRenk(String ad, int? renkKod) {
    if (renkKod != null) {
      return Color(renkKod);
    }
    switch (ad.trim()) {
      case 'Kuaför': return Colors.orange;
      case 'Taksi': return Colors.amber;
      case 'Halı Saha': return Colors.green;
      case 'Oto Yıkama': return Colors.blue;
      case 'Restoran': return Colors.redAccent;
      case 'Düğün Salonu': return Colors.purple;
      case 'Araç Kiralama': return Colors.blueGrey;
      case 'Diyetisyen': return Colors.lightGreen;
      case 'Fizyoterapi ve Rehabilitasyon': return Colors.teal;
      case 'Pet Kuaför': return Colors.brown;
      case 'Veteriner': return Colors.redAccent;
      case 'Psikolog': return Colors.indigo;
      case 'Özel Ders': return Colors.deepOrange;
      default: return Colors.blueAccent;
    }
  }

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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _siralamaChip(
                          label: "Puan", 
                          icon: Icons.star, 
                          secili: siralamaKriteri == 'puan',
                          onTap: () => setModalState(() => siralamaKriteri = 'puan')
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
                ),
              ),
              if (_currentPosition == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
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
                      } else if (siralamaKriteri == 'puan') {
                        return esnafB.puan.compareTo(esnafA.puan);
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
                          title: Row(
                            children: [
                              Expanded(child: Text(esnaf.isletmeAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              if (esnaf.puan > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    Text(esnaf.puan.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    Text(" (${esnaf.yorumSayisi})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                            ],
                          ),
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
      body: CustomScrollView(
        slivers: [
          if (widget.kullaniciTel != null)
            SliverToBoxAdapter(
              child: Padding(
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
            ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreServisi.kategorileriGetir(),
            builder: (context, snapshot) {
              final kats = snapshot.data ?? [];
              
              // Veri henüz yoksa ve bağlantı bekleniyorsa loading göster
              if (snapshot.connectionState == ConnectionState.waiting && kats.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              // Veri boşsa (gerçekten veri yoksa) uyarı göster
              if (kats.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Henüz kategori eklenmemiş.")),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(15),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final kat = kats[i];
                      final ad = kat['ad'] as String;
                      final ikonKod = kat['ikon'] as int?;
                      final renkKod = kat['renk'] as int?;
                      
                      return InkWell(
                        onTap: () => _esnafListesiAc(context, ad),
                        borderRadius: BorderRadius.circular(15),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          color: _getKategoriRenk(ad, renkKod),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildKategoriIcon(ad, ikonKod),
                              const SizedBox(height: 10),
                              Text(
                                ad,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: kats.length,
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}
