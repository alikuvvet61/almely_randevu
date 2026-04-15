import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modeller/esnaf_modeli.dart';
import '../widgets/ana_buton.dart';
import 'randevu_ekrani.dart';

class EsnafDetayEkrani extends StatelessWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const EsnafDetayEkrani({super.key, required this.esnaf, this.kullaniciTel});

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
                key: UniqueKey(),
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
                      Expanded(
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
          // Ajanda Kontrolü
          bool ajandaVarMi = false;
          final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          
          if (esnaf.aktifGunler != null && esnaf.aktifGunler!.isNotEmpty) {
            for (var gunStr in esnaf.aktifGunler!) {
              // gunStr formatı: "2024-05-20_Kanal"
              String tarihKismi = gunStr.toString().split('_')[0];
              if (tarihKismi.compareTo(bugunStr) >= 0) {
                ajandaVarMi = true;
                break;
              }
            }
          }

          if (ajandaVarMi) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RandevuEkrani(
                  esnaf: esnaf, 
                  kullaniciTel: kullaniciTel
                )
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Ajanda bulunamadı!"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}
