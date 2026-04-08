import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modeller/esnaf_modeli.dart';
import '../widgets/ana_buton.dart';

class EsnafDetayEkrani extends StatelessWidget {
  final EsnafModeli esnaf;

  const EsnafDetayEkrani({super.key, required this.esnaf});

  // Telefon araması başlatma fonksiyonu
  Future<void> _aramaYap(String tel) async {
    final Uri url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Haritadaki işaretçi (Marker) ayarı
    final Marker esnafIsaretci = Marker(
      markerId: MarkerId(esnaf.id),
      position: LatLng(esnaf.konum.latitude, esnaf.konum.longitude),
      infoWindow: InfoWindow(title: esnaf.isletmeAdi, snippet: esnaf.kategori),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(esnaf.isletmeAdi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HARİTA BÖLÜMÜ
            SizedBox(
              height: 300,
              child: GoogleMap(
                key: UniqueKey(), // Haritayı tazeleyen ve beyaz ekranı çözen anahtar
                initialCameraPosition: CameraPosition(
                  target: LatLng(esnaf.konum.latitude, esnaf.konum.longitude),
                  zoom: 15,
                ),
                markers: {esnafIsaretci},
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
              ),
            ),

            // 2. BİLGİ BÖLÜMÜ
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded( // Taşkınlıkları önlemek için eklendi
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esnaf.isletmeAdi,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              esnaf.kategori,
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Hızlı Arama Butonu
                      CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 25,
                        child: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          onPressed: () => _aramaYap(esnaf.telefon),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),

                  // Adres Detayı
                  const Text(
                    "Adres Bilgileri",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text("${esnaf.ilce}, ${esnaf.il}"),
                    subtitle: Text(esnaf.adres),
                  ),

                  const SizedBox(height: 20),

                  // İletişim Detayı
                  const Text(
                    "İletişim",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android, color: Colors.green),
                    title: Text(esnaf.telefon),
                    subtitle: const Text("Randevu için arayabilirsiniz"),
                    trailing: ElevatedButton(
                      onPressed: () => _aramaYap(esnaf.telefon),
                      child: const Text("ARA"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnaButon(
        metin: "HEMEN RANDEVU AL",
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Randevu sistemi çok yakında eklenecek!"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}