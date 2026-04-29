import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../widgets/ana_buton.dart';
import 'randevu_ekrani.dart';

import 'package:geolocator/geolocator.dart';

class EsnafDetayEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const EsnafDetayEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<EsnafDetayEkrani> createState() => _EsnafDetayEkraniState();
}

class _EsnafDetayEkraniState extends State<EsnafDetayEkrani> {
  static final FirestoreServisi _firestoreServisi = FirestoreServisi();
  late EsnafModeli _guncelEsnaf;

  @override
  void initState() {
    super.initState();
    _guncelEsnaf = widget.esnaf;
    _esnafCanliDinle();
  }

  void _esnafCanliDinle() {
    FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _guncelEsnaf = EsnafModeli.fromFirestore(doc);
        });
      }
    });
  }

  Future<void> _aramaYap(String tel) async {
    final Uri url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<int> _hesaplaTahminiSure() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)
        );

        double mesafeMetre = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.esnaf.konum.latitude,
          widget.esnaf.konum.longitude
        );

        // --- Dinamik Hesaplama ---
        // Şehir içi ortalama hız: 30 km/s = 500 metre/dakika
        // Yol kıvrımları ve trafik katsayısı: 1.3
        double tahminiDakika = (mesafeMetre * 1.3) / 500;
        int sonuc = tahminiDakika.round();

        // Duraktaki araç sayısına göre ek süre
        // Eğer durakta hiç araç (durakta: true) yoksa, dışarıdaki aracın gelmesi için +10 dk ekle
        int duraktakiAracSayisi = _guncelEsnaf.araclar?.where((a) => a['durakta'] == true).length ?? 0;
        if (duraktakiAracSayisi == 0) {
          sonuc += 12; // Araç yoksa bekleme süresini daha gerçekçi (12 dk) artırıyoruz
        }

        // Mantıklı sınırlar: min 3, max 45 dakika
        if (sonuc < 3) return 3;
        if (sonuc > 45) return 45;

        return sonuc;
      }
    } catch (e) {
      debugPrint("Mesafe hesaplama hatası: $e");
    }
    return 10; // Hata veya izin yoksa varsayılan
  }

  @override
  Widget build(BuildContext context) {
    final Marker esnafIsaretci = Marker(
      markerId: MarkerId(widget.esnaf.id),
      position: LatLng(widget.esnaf.konum.latitude, widget.esnaf.konum.longitude),
      infoWindow: InfoWindow(title: widget.esnaf.isletmeAdi, snippet: widget.esnaf.kategori),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esnaf.isletmeAdi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: GoogleMap(
                key: UniqueKey(),
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.esnaf.konum.latitude, widget.esnaf.konum.longitude),
                  zoom: 15,
                ),
                markers: {esnafIsaretci},
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
              ),
            ),
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
                            Text(widget.esnaf.isletmeAdi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(widget.esnaf.kategori, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 25,
                        child: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          onPressed: () => _aramaYap(widget.esnaf.telefon),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text("Adres Bilgileri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text("${widget.esnaf.ilce}, ${widget.esnaf.il}"),
                    subtitle: Text(widget.esnaf.adres),
                  ),
                  const SizedBox(height: 20),
                  const Text("Çalışma Programı & Hizmet Bilgisi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        _calismaGunuSatiri("Pazartesi"),
                        _calismaGunuSatiri("Salı"),
                        _calismaGunuSatiri("Çarşamba"),
                        _calismaGunuSatiri("Perşembe"),
                        _calismaGunuSatiri("Cuma"),
                        _calismaGunuSatiri("Cumartesi"),
                        _calismaGunuSatiri("Pazar", sonSatir: true),
                      ],
                    ),
                  ),
                  
                  // --- AKTİF ARAÇ FİLOSU (Derecik Taksi ve Diğerleri İçin) ---
                  if (_guncelEsnaf.araclar != null && _guncelEsnaf.araclar!.isNotEmpty) ...[
                    const SizedBox(height: 25),
                    const Text("Aktif Araç Filosu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _guncelEsnaf.araclar!.length,
                        itemBuilder: (context, index) {
                          final arac = _guncelEsnaf.araclar![index];
                          return Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade900,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(arac['plaka'] ?? "-", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(arac['soforAd'] ?? arac['sofor'] ?? "Şoför Belirtilmemiş",
                                  style: const TextStyle(color: Colors.white, fontSize: 12), 
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (arac['durakta'] == true)
                                  const Text("● Durakta", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // --- RANDEVU KANALLARI ---
                  if (_guncelEsnaf.kanallar != null && _guncelEsnaf.kanallar!.isNotEmpty) ...[
                    const SizedBox(height: 25),
                    const Text("Randevu & İletişim Kanalları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _guncelEsnaf.kanallar!.map((kanal) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(kanal.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text("İletişim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android, color: Colors.green),
                    title: Text(widget.esnaf.telefon),
                    subtitle: const Text("Randevu için arayabilirsiniz"),
                    trailing: ElevatedButton(
                      onPressed: () => _aramaYap(widget.esnaf.telefon),
                      child: const Text("ARA"),
                    ),
                  ),
                  const Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Yorumlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (widget.esnaf.yorumSayisi > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            Text(widget.esnaf.puan.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(" (${widget.esnaf.yorumSayisi} Değerlendirme)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (widget.esnaf.yorumSayisi > 5)
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TumYorumlarEkrani(esnafId: widget.esnaf.id, esnafAd: widget.esnaf.isletmeAdi),
                                    ),
                                  );
                                },
                                child: const Text("Tümünü Gör", style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _yorumYazAlani(),
                  const SizedBox(height: 20),
                  _yorumlarListesi(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.esnaf.kategori == 'Taksi')
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ElevatedButton.icon(
                  onPressed: () => _taksiCagirDialog(context),
                  icon: const Icon(Icons.local_taxi, color: Colors.black),
                  label: const Text("TAKSİ ÇAĞIR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            AnaButon(
              metin: "HEMEN RANDEVU AL",
              onPressed: () {
                bool ajandaVarMi = false;
                final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (widget.esnaf.aktifGunler != null && widget.esnaf.aktifGunler!.isNotEmpty) {
                  for (var gunStr in widget.esnaf.aktifGunler!) {
                    String tarihKismi = gunStr.toString().split('_')[0];
                    if (tarihKismi.compareTo(bugunStr) >= 0) {
                      ajandaVarMi = true;
                      break;
                    }
                  }
                }
                if (ajandaVarMi) {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => RandevuEkrani(esnaf: widget.esnaf, kullaniciTel: widget.kullaniciTel)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajanda bulunamadı!"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  final TextEditingController _yorumController = TextEditingController();
  double _secilenPuan = 0.0;
  bool _yorumGonderiliyor = false;

  Widget _yorumYazAlani() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Deneyiminizi Paylaşın", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) => IconButton(
              onPressed: () => setState(() => _secilenPuan = index + 1.0),
              icon: Icon(
                index < _secilenPuan ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 30,
              ),
            )),
          ),
          TextField(
            controller: _yorumController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Yorumunuzu buraya yazın...",
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _yorumGonderiliyor ? null : _yorumKaydet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: _yorumGonderiliyor
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Yorumu Gönder"),
          ),
        ],
      ),
    );
  }

  Future<void> _yorumKaydet() async {
    if (_secilenPuan == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir yıldız seçerek puan verin."), backgroundColor: Colors.orange));
      return;
    }

    if (_yorumController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir yorum yazın.")));
      return;
    }

    if (widget.kullaniciTel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum yapmak için giriş yapmalısınız.")));
      return;
    }

    setState(() => _yorumGonderiliyor = true);

    try {
      // Not: Normalde randevuId gereklidir ancak bağımsız yorum için 'genel' atıyoruz.
      // FirestoreServisi.yorumEkle metodunu bu senaryo için kullanıyoruz.
      await _firestoreServisi.yorumEkle(
        esnafId: widget.esnaf.id,
        randevuId: "genel_${DateTime.now().millisecondsSinceEpoch}",
        kullaniciAd: "Müşteri", // İleride kullanıcı adını profilden çekebilirsiniz
        kullaniciTel: widget.kullaniciTel!,
        puan: _secilenPuan,
        yorum: _yorumController.text.trim(),
      );

      _yorumController.clear();
      setState(() {
        _secilenPuan = 0.0;
        _yorumGonderiliyor = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorumunuz başarıyla gönderildi."), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _yorumGonderiliyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _yorumlarListesi() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreServisi.esnafYorumlariniGetir(widget.esnaf.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Yorumlar yüklenirken bir hata oluştu: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final yorumlar = snapshot.data ?? [];
        if (yorumlar.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
            child: const Column(
              children: [
                Icon(Icons.rate_review_outlined, color: Colors.grey, size: 40),
                SizedBox(height: 10),
                Text("Henüz değerlendirme yapılmamış.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: yorumlar.length > 5 ? 5 : yorumlar.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final y = yorumlar[i];
            final DateTime tarih = (y['tarih'] as Timestamp).toDate();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(y['kullaniciAd'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd.MM.yyyy').format(tarih), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    children: List.generate(5, (index) => Icon(
                      index < (y['puan'] ?? 0) ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(y['yorum'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _calismaGunuSatiri(String gun, {bool sonSatir = false}) {
    final Map<String, dynamic> gunler = _guncelEsnaf.calismaSaatleri?['gunler'] ?? {};
    final bool acik = gunler[gun] ?? true;
    
    // Veritabanından gelen saatleri al, yoksa varsayılanı kullan
    String acilis = _guncelEsnaf.calismaSaatleri?['acilis'] ?? "09:00";
    String kapanis = _guncelEsnaf.calismaSaatleri?['kapanis'] ?? "18:00";
    
    // Eğer Derecik Taksi ise ve veritabanı boşsa 7/24 göster
    if (_guncelEsnaf.isletmeAdi.contains("Derecik") && _guncelEsnaf.calismaSaatleri == null) {
      acilis = "00:00";
      kapanis = "23:59";
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(gun, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                acik ? "$acilis - $kapanis" : "KAPALI",
                style: TextStyle(color: acik ? Colors.black87 : Colors.red, fontWeight: acik ? FontWeight.normal : FontWeight.bold),
              ),
            ],
          ),
        ),
        if (!sonSatir) const Divider(height: 1),
      ],
    );
  }

  void _taksiCagirDialog(BuildContext context) async {
    // 1. Duraktaki araçları filtrele ve sırala
    List<Map<String, dynamic>> duraktakiAraclar = [];
    if (_guncelEsnaf.araclar != null) {
      duraktakiAraclar = _guncelEsnaf.araclar!
          .where((a) => a['durakta'] == true)
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
      
      duraktakiAraclar.sort((a, b) {
        var t1 = a['katilmaSaati'] ?? 0;
        var t2 = b['katilmaSaati'] ?? 0;
        return (t1 as num).compareTo(t2 as num);
      });
    }

    int beklemeSuresi = await _hesaplaTahminiSure();
    Map<String, dynamic>? siradakiArac = duraktakiAraclar.isNotEmpty ? duraktakiAraclar.first : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Üst Sarı Başlık Bölümü ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.yellow.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
              ),
              child: const Column(
                children: [
                  Icon(Icons.local_taxi, size: 50, color: Colors.black),
                  SizedBox(height: 10),
                  Text(
                    "TAKSİ ÇAĞIR",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // --- Sıradaki Araç Bilgisi ---
                    if (siradakiArac != null) ...[
                      const Text("SIRADAKİ ARAÇ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        siradakiArac['plaka'] ?? "PLAKA YOK",
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo),
                      ),
                      Text(
                        siradakiArac['sofor']?.toString().toUpperCase() ?? "ŞOFÖR BİLGİSİ YOK",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      const Divider(),
                    ],

                    // --- Bekleme Süresi ---
                    const SizedBox(height: 15),
                    const Text("TAHMİNİ VARALIK SÜRESİ", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        "$beklemeSuresi Dakika",
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo),
                      ),
                    ),
                    
                    // --- Diğer Bekleyen Araçlar ---
                    if (duraktakiAraclar.length > 1) ...[
                      const SizedBox(height: 25),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("DURAKTAKİ DİĞER ARAÇLAR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      const SizedBox(height: 8),
                      ...duraktakiAraclar.skip(1).map((arac) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(arac['plaka'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(arac['sofor'] ?? "-", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                    ],

                    if (duraktakiAraclar.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("Şu an tüm araçlar meşgul,\nen yakın araç yönlendirilecek.", 
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),

            // --- Alt Butonlar ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("VAZGEÇ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _taksiTalebiGonder(widget.esnaf, siradakiArac);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      child: const Text(
                        "ŞİMDİ ÇAĞIR",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _taksiTalebiGonder(EsnafModeli esnaf, Map<String, dynamic>? arac) async {
    final talepId = "talep_${DateTime.now().millisecondsSinceEpoch}";

    // 1. Talebi Firestore'a Kaydet (Durağın panelinde anlık görünmesi için)
    await FirebaseFirestore.instance.collection('taksi_talepleri').doc(talepId).set({
      'esnafId': esnaf.id,
      'musteriTel': widget.kullaniciTel ?? "Bilinmiyor",
      'musteriAd': "Müşteri", // Müşteri adını buradan gönderiyoruz
      'adres': "Seçilen Konum", // Müşterinin adresi
      'durum': 'bekliyor', // beklemede değil 'bekliyor' (panel 'bekliyor' olanları dinliyor)
      'tarih': FieldValue.serverTimestamp(),
      'plaka': arac?['plaka'],
      'sofor': arac?['soforAd'],
      'soforTel': arac?['soforTel'], // Kritik: Şoförün telefonu bildirim filtresi için şart
      'musteriKonum': widget.esnaf.konum,
    });

    // 2. Bildirimleri Gönder
    // Durağa bildirim (Yönetici)
    BildirimServisi.bildirimGonder(
      kullaniciTel: esnaf.telefon,
      baslik: "🚕 Yeni Taksi Talebi!",
      icerik: "Müşteri taksi bekliyor. Onaylamak için panele girin.",
    );

    // Sürücüye bildirim (Eğer şoförün telefonu varsa - soforTel alanını kullanıyoruz)
    final sTel = arac?['soforTel'] ?? arac?['telefon'];
    if (sTel != null && sTel.toString().isNotEmpty) {
      BildirimServisi.bildirimGonder(
        kullaniciTel: sTel.toString(),
        baslik: "🚕 Taksi: Sıra Sende!",
        icerik: "Müşteri seni bekliyor (${arac?['plaka']}). Lütfen hazır ol!",
      );
    }

    // 3. Onay Bekleme Ekranını Göster
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _TaksiOnayBeklemeDiyalog(esnaf: esnaf, talepId: talepId),
      );
    }
  }
}

class _TaksiOnayBeklemeDiyalog extends StatefulWidget {
  final EsnafModeli esnaf;
  final String talepId;
  const _TaksiOnayBeklemeDiyalog({required this.esnaf, required this.talepId});

  @override
  State<_TaksiOnayBeklemeDiyalog> createState() => _TaksiOnayBeklemeDiyalogState();
}

class _TaksiOnayBeklemeDiyalogState extends State<_TaksiOnayBeklemeDiyalog> {
  int _sayac = 30;
  Timer? _timer;
  StreamSubscription? _abonelik;
  bool _onaylandi = false;
  String? _plaka;
  String? _sofor;
  int _kalanDakika = 5;
  Timer? _yolTimer;

  @override
  void initState() {
    super.initState();

    // 1. İlk bekleme geri sayımı
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sayac > 0) {
        setState(() => _sayac--);
      } else if (!_onaylandi) {
        _iptalEt();
        _onayAlinamadiMesaji();
      }
    });

    // 2. Firestore'u dinle (Durak onayladı mı?)
    _abonelik = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .doc(widget.talepId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data?['durum'] == 'onaylandi') {
          _timer?.cancel();
          setState(() {
            _onaylandi = true;
            _plaka = data?['plaka'];
            _sofor = data?['sofor'];
            _kalanDakika = int.tryParse(data?['tahminiSure']?.toString() ?? "5") ?? 5;
          });
          _yolSayaciniBaslat();
        } else if (data?['durum'] == 'iptal') {
          _iptalEt();
        }
      }
    });
  }

  void _yolSayaciniBaslat() {
    _yolTimer?.cancel();
    _yolTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_kalanDakika > 1) {
        setState(() => _kalanDakika--);
      } else {
        timer.cancel();
      }
    });
  }

  void _iptalEt() {
    _timer?.cancel();
    _yolTimer?.cancel();
    _abonelik?.cancel();
    if (mounted) Navigator.pop(context);
    FirebaseFirestore.instance.collection('taksi_talepleri').doc(widget.talepId).update({'durum': 'iptal'});
  }

  void _onayAlinamadiMesaji() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Duraktan yanıt alınamadı. Lütfen telefonla arayınız."),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _yolTimer?.cancel();
    _abonelik?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _onaylandi ? Colors.yellow.shade50 : Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_onaylandi) ...[
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 70, height: 70,
                  child: CircularProgressIndicator(strokeWidth: 4, color: Colors.orange),
                ),
                Text("$_sayac", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 25),
            const Text("Talebiniz İletildi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Durağın onay vermesi bekleniyor...", textAlign: TextAlign.center),
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 15),
            const Text("TAKSİ YOLDA!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const Divider(height: 30),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.orange),
                      const SizedBox(width: 10),
                      Text("Plaka: ${_plaka ?? '---'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue),
                      const SizedBox(width: 10),
                      Text("Şoför: ${_sofor ?? '---'}", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text("Tahmini Varış: ", style: TextStyle(color: Colors.grey.shade700)),
                Text("$_kalanDakika Dakika", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent)),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (!_onaylandi)
          TextButton(
            onPressed: _iptalEt,
            child: const Text("İptal Et", style: TextStyle(color: Colors.red)),
          )
        else
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("TAMAM"),
            ),
          ),
      ],
    );
  }
}

class TumYorumlarEkrani extends StatelessWidget {
  final String esnafId;
  final String esnafAd;
  static final FirestoreServisi _firestoreServisi = FirestoreServisi();

  const TumYorumlarEkrani({super.key, required this.esnafId, required this.esnafAd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$esnafAd - Tüm Yorumlar")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreServisi.esnafYorumlariniGetir(esnafId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final yorumlar = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: yorumlar.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final y = yorumlar[i];
              final DateTime tarih = (y['tarih'] as Timestamp).toDate();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(y['kullaniciAd'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(DateFormat('dd.MM.yyyy').format(tarih), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) => Icon(
                        index < (y['puan'] ?? 0) ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      )),
                    ),
                    const SizedBox(height: 10),
                    Text(y['yorum'] ?? "", style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
