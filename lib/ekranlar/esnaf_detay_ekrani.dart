import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modeller/esnaf_modeli.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/konum_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../widgets/ana_buton.dart';
import 'randevu_ekrani.dart';
import 'tum_yorumlar_ekrani.dart';

class EsnafDetayEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const EsnafDetayEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<EsnafDetayEkrani> createState() => _EsnafDetayEkraniState();
}

class _EsnafDetayEkraniState extends State<EsnafDetayEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  final KonumServisi _konumServisi = KonumServisi();
  late EsnafModeli _guncelEsnaf;
  late CameraPosition _ilkKameraPozisyonu;
  final Set<Marker> _isaretciler = {};
  final ScrollController _filoController = ScrollController();
  final TextEditingController _yorumController = TextEditingController();
  StreamSubscription? _esnafSub;
  double _secilenPuan = 0.0;
  bool _yorumGonderiliyor = false;
  bool _taksiYukleniyor = false;
  late Stream<List<Map<String, dynamic>>> _yorumlarStream;

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
    _yorumlarStream = _firestoreServisi.yorumlariGetir(widget.esnaf.id);
    _esnafDinle();
  }

  @override
  void dispose() {
    _esnafSub?.cancel();
    _filoController.dispose();
    _yorumController.dispose();
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
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  bool _suAnAcikMi() {
    final cs = _guncelEsnaf.calismaSaatleri;
    if (cs == null) return true;
    if (cs['acilis'] == "00:00" && cs['kapanis'] == "00:00") return true;
    final simdi = DateTime.now();
    final gunAdlari = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
    String bugun = gunAdlari[simdi.weekday - 1];
    final gunler = cs['gunler'] as Map<String, dynamic>? ?? {};
    if (gunler[bugun] == false) return false;
    try {
      final acilisStr = cs['acilis'] ?? "09:00";
      final kapanisStr = cs['kapanis'] ?? "18:00";
      final simdiDakika = simdi.hour * 60 + simdi.minute;
      final aParca = acilisStr.split(":");
      final kParca = kapanisStr.split(":");
      final acilisDakika = int.parse(aParca[0]) * 60 + int.parse(aParca[1]);
      final kapanisDakika = int.parse(kParca[0]) * 60 + int.parse(kParca[1]);
      return simdiDakika >= acilisDakika && simdiDakika <= kapanisDakika;
    } catch (e) {
      return true;
    }
  }

  Widget _durumRozeti() {
    bool isTaksi = _guncelEsnaf.kategori == 'Taksi';
    bool acik = _suAnAcikMi();
    if (!acik) return _rozet("Şu An Kapalı", Colors.red);
    if (isTaksi) {
      int duraktakiAracSayisi = _guncelEsnaf.araclar?.where((a) => a['durakta'] == true).length ?? 0;
      if (duraktakiAracSayisi > 0) {
        return _rozet("Müsait", Colors.green);
      } else {
        return _rozet("Meşgul", Colors.orange);
      }
    }
    return _rozet("Açık", Colors.green);
  }

  Widget _rozet(String metin, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(metin, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_guncelEsnaf.isletmeAdi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: GoogleMap(
                key: const PageStorageKey('esnaf_harita'),
                initialCameraPosition: _ilkKameraPozisyonu,
                markers: _isaretciler,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_guncelEsnaf.isletmeAdi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(_guncelEsnaf.kategori, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                                const SizedBox(width: 10),
                                _durumRozeti(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 25,
                        child: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.white),
                          onPressed: () => _aramaYap(_guncelEsnaf.telefon),
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
                    title: Text("${_guncelEsnaf.ilce}, ${_guncelEsnaf.il}"),
                    subtitle: Text(_guncelEsnaf.adres),
                  ),
                  const SizedBox(height: 20),
                  const Text("Çalışma Programı ve Hizmet Bilgisi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        if (_guncelEsnaf.calismaSaatleri?['acilis'] == "00:00" && _guncelEsnaf.calismaSaatleri?['kapanis'] == "00:00")
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_mode, color: Colors.blue),
                                SizedBox(width: 10),
                                Text("7/24 Kesintisiz Hizmet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                              ],
                            ),
                          )
                        else ...[
                          _calismaGunuSatiri("Pazartesi"),
                          _calismaGunuSatiri("Salı"),
                          _calismaGunuSatiri("Çarşamba"),
                          _calismaGunuSatiri("Perşembe"),
                          _calismaGunuSatiri("Cuma"),
                          _calismaGunuSatiri("Cumartesi"),
                          _calismaGunuSatiri("Pazar", sonSatir: true),
                        ],
                      ],
                    ),
                  ),
                  if (_guncelEsnaf.araclar != null && _guncelEsnaf.araclar!.isNotEmpty) ...[
                    const SizedBox(height: 25),
                    const Text("Aktif Araç Filosu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 100,
                          child: Builder(builder: (context) {
                            final duraktakiAraclar = _guncelEsnaf.araclar!.where((a) => a['durakta'] == true).toList();
                            final digerAraclar = _guncelEsnaf.araclar!.where((a) => a['durakta'] != true).toList();
                            duraktakiAraclar.sort((a, b) {
                              int t1 = a['siraZamani'] ?? 0;
                              int t2 = b['siraZamani'] ?? 0;
                              if (t1 != t2) return t1.compareTo(t2);
                              return (a['plaka'] ?? "").compareTo(b['plaka'] ?? "");
                            });
                            final tumAraclar = [...duraktakiAraclar, ...digerAraclar];
                            return ListView.builder(
                              controller: _filoController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                              itemCount: tumAraclar.length,
                              itemBuilder: (context, index) {
                                final arac = tumAraclar[index];
                                final bool durakta = arac['durakta'] == true;
                                int siraNo = -1;
                                if (durakta) siraNo = duraktakiAraclar.indexWhere((a) => a['plaka'] == arac['plaka']) + 1;
                                return Container(
                                  width: 155,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade900,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(arac['plaka'] ?? "-", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                          if (durakta) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)), child: Text(siraNo.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(arac['soforAd'] ?? arac['sofor'] ?? "Şoför belirtilmemiş", style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const Spacer(),
                                      if (durakta)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.circle, size: 6, color: Colors.greenAccent),
                                            const SizedBox(width: 4),
                                            Flexible(child: Text(siraNo == 1 ? "Sıradaki Araç" : "$siraNo. Sırada", style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                          ],
                                        )
                                      else
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle, size: 6, color: (arac['durum'] == 'Meşgul' ? Colors.redAccent : (arac['durum'] == 'Mola' ? Colors.purpleAccent : Colors.white54))),
                                            const SizedBox(width: 4),
                                            Text(arac['durum'] ?? "Müsait Değil", style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                        Positioned(
                          left: 0,
                          child: GestureDetector(
                            onTap: () {
                              if (_filoController.hasClients) {
                                if (_filoController.offset <= 50) {
                                  _filoController.animateTo(_filoController.position.maxScrollExtent, duration: const Duration(milliseconds: 800), curve: Curves.easeOutBack);
                                } else {
                                  _filoController.animateTo(_filoController.offset - 167, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                }
                              }
                            },
                            child: _kaydirmaButonu(Icons.arrow_back_ios_new, Alignment.centerLeft),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              if (_filoController.hasClients) {
                                if (_filoController.offset >= _filoController.position.maxScrollExtent - 50) {
                                  _filoController.animateTo(0, duration: const Duration(milliseconds: 800), curve: Curves.easeOutBack);
                                } else {
                                  _filoController.animateTo(_filoController.offset + 167, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                }
                              }
                            },
                            child: _kaydirmaButonu(Icons.arrow_forward_ios, Alignment.centerRight),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_guncelEsnaf.kanallar != null && _guncelEsnaf.kanallar!.isNotEmpty) ...[
                    const SizedBox(height: 25),
                    const Text("Randevu ve İletişim Kanalları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _guncelEsnaf.kanallar!.map((kanal) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
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
                    title: Text(_guncelEsnaf.telefon),
                    subtitle: const Text("Randevu için arayabilirsiniz"),
                    trailing: ElevatedButton(onPressed: () => _aramaYap(_guncelEsnaf.telefon), child: const Text("Ara")),
                  ),
                  const Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Yorumlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (_guncelEsnaf.yorumSayisi > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            Text(_guncelEsnaf.puan.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(" (${_guncelEsnaf.yorumSayisi} değerlendirme)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (_guncelEsnaf.yorumSayisi > 5)
                              TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => TumYorumlarEkrani(esnafId: _guncelEsnaf.id, esnafAd: _guncelEsnaf.isletmeAdi)));
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
                ],
              ),
            ),
          ),
          _yorumlarSliverListesi(),
          const SliverToBoxAdapter(child: SizedBox(height: 180)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_guncelEsnaf.kategori == 'Taksi')
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ElevatedButton.icon(
                  onPressed: _taksiYukleniyor ? null : () => _taksiCagirDialog(context),
                  icon: _taksiYukleniyor ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.local_taxi, color: Colors.black),
                  label: Text(_taksiYukleniyor ? "Tahmini Süre Hesaplanıyor..." : "Taksi Çağır", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            AnaButon(
              metin: "Hemen Randevu Al",
              onPressed: () {
                bool ajandaVarMi = false;
                final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (_guncelEsnaf.aktifGunler != null && _guncelEsnaf.aktifGunler!.isNotEmpty) {
                  for (var gunStr in _guncelEsnaf.aktifGunler!) {
                    String tarihKismi = gunStr.toString().split('_')[0];
                    if (tarihKismi.compareTo(bugunStr) >= 0) {
                      ajandaVarMi = true;
                      break;
                    }
                  }
                }
                if (ajandaVarMi) {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => RandevuEkrani(esnaf: _guncelEsnaf, kullaniciTel: widget.kullaniciTel)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bu işletmenin henüz yayında olan bir ajandası bulunmuyor."), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _kaydirmaButonu(IconData icon, Alignment alignment) {
    bool isLeft = alignment == Alignment.centerLeft;
    return Container(
      height: 60,
      width: 35,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isLeft ? Colors.white : Colors.white.withValues(alpha: 0),
            isLeft ? Colors.white.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
            isLeft ? Colors.white.withValues(alpha: 0) : Colors.white,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.only(left: isLeft ? 6 : 0, right: isLeft ? 0 : 6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.8), shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _yorumYazAlani() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Deneyiminizi paylaşın...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
                5,
                (index) => IconButton(
                      onPressed: () => setState(() => _secilenPuan = index + 1.0),
                      icon: Icon(index < _secilenPuan ? Icons.star : Icons.star_border, color: Colors.amber, size: 30),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
            child: _yorumGonderiliyor ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Yorumu Gönder"),
          ),
        ],
      ),
    );
  }

  Future<void> _yorumKaydet() async {
    if (_secilenPuan == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir puan seçin!"), backgroundColor: Colors.orange));
      return;
    }
    if (_yorumController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir yorum yazın!")));
      return;
    }
    if (widget.kullaniciTel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorum yapmak için giriş yapmalısınız!")));
      return;
    }
    setState(() => _yorumGonderiliyor = true);
    try {
      await _firestoreServisi.yorumEkle({
        'esnafId': widget.esnaf.id,
        'randevuId': "genel_${DateTime.now().millisecondsSinceEpoch}",
        'kullaniciAd': "Müşteri",
        'kullaniciTel': widget.kullaniciTel!,
        'puan': _secilenPuan,
        'yorum': _yorumController.text.trim(),
        'tarih': FieldValue.serverTimestamp(),
      });
      _yorumController.clear();
      setState(() {
        _secilenPuan = 0.0;
        _yorumGonderiliyor = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorumunuz başarıyla gönderildi!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _yorumGonderiliyor = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _yorumlarSliverListesi() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _yorumlarStream,
      builder: (context, snapshot) {
        final yorumlar = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting && yorumlar.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
        }
        if (yorumlar.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
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
              ),
            ),
          );
        }
        final gosterilecekYorumlar = yorumlar.length > 5 ? yorumlar.take(5).toList() : yorumlar;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final y = gosterilecekYorumlar[i];
                final DateTime tarih = (y['tarih'] as Timestamp).toDate();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                        Row(children: List.generate(5, (index) => Icon(index < (y['puan'] ?? 0) ? Icons.star : Icons.star_border, size: 14, color: Colors.amber))),
                        const SizedBox(height: 6),
                        Text(y['yorum'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                );
              },
              childCount: gosterilecekYorumlar.length,
            ),
          ),
        );
      },
    );
  }

  Widget _calismaGunuSatiri(String gun, {bool sonSatir = false}) {
    final Map<String, dynamic> gunler = _guncelEsnaf.calismaSaatleri?['gunler'] ?? {};
    final bool acikGunu = gunler[gun] ?? true;
    String acilis = _guncelEsnaf.calismaSaatleri?['acilis'] ?? "09:00";
    String kapanis = _guncelEsnaf.calismaSaatleri?['kapanis'] ?? "18:00";
    if (acilis == "00:00" && kapanis == "00:00") {
      acilis = "00:00";
      kapanis = "24:00";
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(gun, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(acikGunu ? "$acilis - $kapanis" : "Kapalı", style: TextStyle(color: acikGunu ? Colors.black87 : Colors.red, fontWeight: acikGunu ? FontWeight.normal : FontWeight.bold)),
            ],
          ),
        ),
        if (!sonSatir) const Divider(height: 1),
      ],
    );
  }

  void _taksiCagirDialog(BuildContext context) async {
    if (_taksiYukleniyor) return;
    setState(() => _taksiYukleniyor = true);
    final konumBilgisi = await _konumServisi.konumuVeAdresiGetir();
    String musteriAdresi = "Konum Alınamadı";
    GeoPoint musteriKonumu = _guncelEsnaf.konum;
    if (konumBilgisi != null && !konumBilgisi.containsKey('hata')) {
      musteriAdresi = konumBilgisi['tamAdres'] ?? "Adres Belirlenemedi";
      musteriKonumu = GeoPoint(double.parse(konumBilgisi['enlem']!), double.parse(konumBilgisi['boylam']!));
    }
    List<Map<String, dynamic>> duraktakiAraclar = [];
    if (_guncelEsnaf.araclar != null) {
      duraktakiAraclar = _guncelEsnaf.araclar!.where((a) => a['durakta'] == true).map((a) => Map<String, dynamic>.from(a as Map)).toList();
      duraktakiAraclar.sort((a, b) {
        // 1. siraZamani'na göre (en eski giren 1. olur)
        int t1 = a['siraZamani'] ?? 0;
        int t2 = b['siraZamani'] ?? 0;
        if (t1 != t2) return t1.compareTo(t2);
        
        // 2. Zamanlar eşitse plakaya göre (tutarlılık için)
        String p1 = a['plaka'] ?? "";
        String p2 = b['plaka'] ?? "";
        return p1.compareTo(p2);
      });
    }
    double mesafeMetre = Geolocator.distanceBetween(musteriKonumu.latitude, musteriKonumu.longitude, _guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude);
    double tahminiDakika = (mesafeMetre * 1.3) / 500;
    int beklemeSuresi = tahminiDakika.round();
    int duraktakiAracSayisi = duraktakiAraclar.length;
    if (duraktakiAracSayisi == 0) beklemeSuresi += 12;
    if (beklemeSuresi < 3) beklemeSuresi = 3;
    if (beklemeSuresi > 45) beklemeSuresi = 45;
    Map<String, dynamic>? siradakiArac = duraktakiAraclar.isNotEmpty ? duraktakiAraclar.first : null;
    if (mounted) setState(() => _taksiYukleniyor = false);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: Colors.yellow.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
              child: const Column(
                children: [
                  Icon(Icons.local_taxi, size: 50, color: Colors.black),
                  SizedBox(height: 10),
                  Text("Taksi Çağır", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.2)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (siradakiArac != null) ...[
                      const Text("SIRADAKİ ARAÇ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(siradakiArac['plaka'] ?? "PLAKA YOK", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.indigo)),
                      Text((siradakiArac['soforAd'] ?? siradakiArac['sofor'] ?? "Şoför bilgisi yok").toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      const Divider(),
                    ],
                    const SizedBox(height: 15),
                    const Text("MÜŞTERİ ADRESİ", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(musteriAdresi, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 15),
                    const Text("TAHMİNİ VARIŞ VE MESAFE", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text("$beklemeSuresi dk", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo)),
                            const Text("Süre", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        if (mesafeMetre > 0)
                          Column(
                            children: [
                              Text(mesafeMetre < 1000 ? "${mesafeMetre.toStringAsFixed(0)} m" : "${(mesafeMetre / 1000).toStringAsFixed(1)} km", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.orange)),
                              const Text("Mesafe", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _taksiTalebiGonder(_guncelEsnaf, siradakiArac, musteriAdresi, musteriKonumu, beklemeSuresi, mesafeMetre);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("ŞİMDİ ÇAĞIR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

  void _taksiTalebiGonder(EsnafModeli esnaf, Map<String, dynamic>? arac, String adres, GeoPoint konum, int beklemeSuresi, double mesafe) async {
    try {
      await FirebaseFirestore.instance.collection('taksi_talepleri').add({
        'esnafId': esnaf.id,
        'esnafAd': esnaf.isletmeAdi,
        'musteriTel': widget.kullaniciTel,
        'musteriAd': 'Müşteri',
        'adres': adres,
        'talepZamani': FieldValue.serverTimestamp(),
        'durum': 'bekliyor',
        'plaka': arac?['plaka'],
        'soforAd': arac?['soforAd'] ?? arac?['sofor'],
        'soforTel': arac?['soforTel'],
        'musteriKonum': konum,
        'tahminiSure': beklemeSuresi,
        'mesafe': mesafe,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Taksi talebiniz başarıyla iletildi."), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }

      if (arac?['soforTel'] != null) {
        BildirimServisi.bildirimGonder(
          baslik: "Yeni Taksi Talebi",
          icerik: "$adres adresinden bir taksi talebi var.",
          kullaniciTel: arac!['soforTel'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Talep gönderilirken hata oluştu: $e"), backgroundColor: Colors.red));
      }
    }
  }
}
