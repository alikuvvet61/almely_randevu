import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/widgets/ana_buton.dart';
import 'package:almely_randevu/ekranlar/arac_kiralama/arac_kiralama_randevu_ekrani.dart';

class AracKiralamaDetayEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const AracKiralamaDetayEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<AracKiralamaDetayEkrani> createState() => _AracKiralamaDetayEkraniState();
}

class _AracKiralamaDetayEkraniState extends State<AracKiralamaDetayEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  late EsnafModeli _guncelEsnaf;
  late CameraPosition _ilkKameraPozisyonu;
  final Set<Marker> _isaretciler = {};
  StreamSubscription? _esnafSub;

  @override
  void initState() {
    super.initState();
    
    _guncelEsnaf = widget.esnaf;
    _ilkKameraPozisyonu = CameraPosition(
      target: LatLng(_guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude),
      zoom: 15,
    );
    _isaretciler.add(Marker(
      markerId: MarkerId(_guncelEsnaf.id),
      position: LatLng(_guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude),
      infoWindow: InfoWindow(title: _guncelEsnaf.isletmeAdi),
    ));
    _esnafDinle();
  }

  @override
  void dispose() {
    _esnafSub?.cancel();
    super.dispose();
  }

  void _esnafDinle() {
    _esnafSub = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _guncelEsnaf = EsnafModeli.fromFirestore(snapshot);
        });
      }
    });
  }

  Future<void> _aramaYap(String tel) async {
    final Uri url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _resimGoster(BuildContext context, String url, String baslik) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(url, fit: BoxFit.contain))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_guncelEsnaf.isletmeAdi), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 250,
              child: GoogleMap(
                initialCameraPosition: _ilkKameraPozisyonu,
                markers: _isaretciler,
                myLocationButtonEnabled: true,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_guncelEsnaf.isletmeAdi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(_guncelEsnaf.kategori, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ])),
                      CircleAvatar(backgroundColor: Colors.green, child: IconButton(icon: const Icon(Icons.phone, color: Colors.white), onPressed: () => _aramaYap(_guncelEsnaf.telefon))),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text("Araç Filomuz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  StreamBuilder<List<RandevuModeli>>(
                    stream: _firestoreServisi.randevulariGetir(_guncelEsnaf.id, DateTime.now()),
                    builder: (context, randevuSnapshot) {
                      final randevular = randevuSnapshot.data ?? [];
                      final kanallar = _guncelEsnaf.kanallar ?? [];

                      return Column(
                        children: kanallar.map((k) {
                          String ad = ""; String resim = ""; String plaka = "";
                          if (k is Map) {
                            ad = k['ad']?.toString() ?? "İsimsiz Araç";
                            resim = k['resim']?.toString() ?? "";
                            plaka = k['plaka']?.toString() ?? "";
                          } else { ad = k.toString(); }

                          RandevuModeli? aktifRandevu;
                          String durumEtiketi = "";
                          try {
                            aktifRandevu = randevular.firstWhere((r) {
                              if (r.durum != 'Onaylandı' && r.durum != 'Kullanımda') return false;
                              return r.randevuKanali == ad || r.randevuKanali == plaka;
                            });
                            durumEtiketi = "KİRADA";
                          } catch (_) {}

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: aktifRandevu != null ? Colors.red.shade200 : Colors.grey.shade200)),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: resim.isNotEmpty ? () => _resimGoster(context, resim, ad) : null,
                                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: resim.isNotEmpty ? Image.network(resim, width: 90, height: 60, fit: BoxFit.cover) : Container(width: 90, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.directions_car))),
                                ),
                                const SizedBox(width: 15),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(plaka, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                                ])),
                                if (aktifRandevu != null) Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)), child: Text(durumEtiketi, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }
                  ),
                  const SizedBox(height: 25),
                  const Text("İletişim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone, color: Colors.green), title: Text(_guncelEsnaf.telefon), subtitle: const Text("İşletme İletişim Hattı")),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(10), child: AnaButon(metin: "Araç Kirala", onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AracKiralamaRandevuEkrani(esnaf: _guncelEsnaf, kullaniciTel: widget.kullaniciTel)))))),
    );
  }
}
