import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:almely_randevu/ekranlar/taksi/taksi_yonlendirme.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';
import 'package:almely_randevu/widgets/isletme_logosu.dart';
import 'package:almely_randevu/servisler/bildirim_servisi.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/servisler/konum_servisi.dart';
import 'package:almely_randevu/widgets/ana_buton.dart';
import 'package:almely_randevu/widgets/sos_butonu.dart';
import 'package:almely_randevu/widgets/yapay_zeka_kutusu.dart';
import 'package:almely_randevu/widgets/nereye_alani.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_yolculuk_karti.dart';
import 'package:almely_randevu/servisler/taksi/taksi_cagri_sirasi.dart';
import 'package:almely_randevu/servisler/taksi/taksi_iptal_bedeli.dart';
import 'package:almely_randevu/servisler/taksi/taksi_guven.dart';

/// Taksi için müşteri (yolcu) detay ekranı.
class TaksiMusteriEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;
  final bool cagriyiHazirla;

  const TaksiMusteriEkrani({super.key, required this.esnaf, this.kullaniciTel, this.cagriyiHazirla = false});

  @override
  State<TaksiMusteriEkrani> createState() => _TaksiMusteriEkraniState();
}

class _TaksiMusteriEkraniState extends State<TaksiMusteriEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  final KonumServisi _konumServisi = KonumServisi();
  late EsnafModeli _guncelEsnaf;
  GoogleMapController? _mapController;
  late CameraPosition _ilkKameraPozisyonu;
  final Set<Marker> _isaretciler = {};
  final Set<Circle> _daireler = {};
  final ScrollController _filoController = ScrollController();
  final TextEditingController _yorumController = TextEditingController();
  StreamSubscription? _esnafSub;
  StreamSubscription? _ajandaSub;
  StreamSubscription? _kullaniciSub;
  StreamSubscription? _talepSub;
  Map<String, dynamic>? _aktifTalep;
  Timer? _beklemeSayaci;
  bool _yolcuVazgecti = false;
  final Set<String> _ozetGosterilen = {};
  final Map<String, DateTime> _beklemeBaslangici = {};
  BitmapDescriptor? _taksiIkon;
  String? _taksiIkonPlaka;
  Map<String, dynamic> _gunlukAjanda = {};
  final Map<String, Map<String, dynamic>> _kullaniciProfilleri = {};
  double _secilenPuan = 0.0;
  bool _yorumGonderiliyor = false;
  bool _taksiYukleniyor = false;
  late Stream<List<Map<String, dynamic>>> _yorumlarStream;

  @override
  void initState() {
    super.initState();
    if (widget.kullaniciTel != null) {
      BildirimServisi.bildirimDinle(widget.kullaniciTel!);
    }

    _guncelEsnaf = widget.esnaf;
    _ilkKameraPozisyonu = CameraPosition(
      target: LatLng(_guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude),
      zoom: 15,
    );

    _durakMarkerEkle();
    _yorumlarStream = _firestoreServisi.yorumlariGetir(widget.esnaf.id);
    _esnafDinle();
    _ajandaDinle();
    _talepDinle();
    if (widget.cagriyiHazirla) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _taksiCagirDialog(context);
      });
    }
  }

  /// Her iki balonu da aynı anda açık tutmak için görsel marker üreten yardımcı metot
  Future<BitmapDescriptor> _balonluMarkerUret({
    required String baslik,
    required Color balonRenk,
    required Color igneRenk,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    const double width = 200.0;
    const double height = 100.0;

    // 1. Bilgi Balonu Arka Planı (Beyaz Kutu)
    final Paint boxPaint = Paint()..color = balonRenk;
    final RRect outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 0, width - 20, 46),
      const Radius.circular(8),
    );
    canvas.drawRRect(outerRect, boxPaint);

    // Balonun Altındaki Üçgen Uç
    final Path path = Path()
      ..moveTo(width / 2 - 8, 46)
      ..lineTo(width / 2 + 8, 46)
      ..lineTo(width / 2, 56)
      ..close();
    canvas.drawPath(path, boxPaint);

    // Balonun Etrafına İnce Gölge / Çerçeve
    final Paint borderPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(outerRect, borderPaint);

    // 2. Balon İçindeki Metin (ui.TextDirection.ltr ile düzeltildi)
    TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.text = TextSpan(
      text: baslik,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
    textPainter.layout(maxWidth: width - 30);
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, (46 - textPainter.height) / 2),
    );

    // 3. Konum İğnesi (Pin)
    final Paint pinPaint = Paint()..color = igneRenk;
    canvas.drawCircle(Offset(width / 2, 78), 16, pinPaint);

    final Paint innerCirclePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(width / 2, 78), 6, innerCirclePaint);

    final img = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    // Deprecated olan fromBytes yerine BitmapDescriptor.bytes kullanıldı
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Durak İşaretçisini Sarı Renkli ve Balonu Açık Şekilde Ekler
  Future<void> _durakMarkerEkle() async {
    final durakIcon = await _balonluMarkerUret(
      baslik: _guncelEsnaf.isletmeAdi,
      balonRenk: Colors.white,
      igneRenk: Colors.amber.shade700,
    );

    if (mounted) {
      setState(() {
        _isaretciler.add(Marker(
          markerId: MarkerId(_guncelEsnaf.id),
          position: LatLng(_guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude),
          icon: durakIcon,
          anchor: const Offset(0.5, 1.0),
        ));
      });
    }
  }

  /// Müşteri konumunu belirler, haritaya MAVİ işaretçi ekler ve balonu açık tutar.
  Future<void> _musteriKonumunaOdakla() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        LatLng musteriKonum = LatLng(position.latitude, position.longitude);
        LatLng durakKonum = LatLng(_guncelEsnaf.konum.latitude, _guncelEsnaf.konum.longitude);

        const String musteriMarkerId = "musteri_marker";

        final musteriIcon = await _balonluMarkerUret(
          baslik: "Konumunuz",
          balonRenk: Colors.white,
          igneRenk: Colors.blue.shade600,
        );

        setState(() {
          _daireler.removeWhere((c) => c.circleId.value.startsWith("user_dot"));
          _isaretciler.removeWhere((m) => m.markerId.value == musteriMarkerId);

          _daireler.add(Circle(
            circleId: const CircleId("user_dot"),
            center: musteriKonum,
            radius: 10,
            fillColor: Colors.blue.shade700,
            strokeColor: Colors.white,
            strokeWidth: 2,
            zIndex: 10,
          ));

          _isaretciler.add(Marker(
            markerId: const MarkerId(musteriMarkerId),
            position: musteriKonum,
            icon: musteriIcon,
            anchor: const Offset(0.5, 1.0),
          ));
        });

        if (_mapController != null) {
          _autoFitKamera(musteriKonum, durakKonum);
        }
      }
    } catch (_) {}
  }

  /// Durak ve Müşteri noktalarını kapsayacak Auto-fit kamera algoritması
  void _autoFitKamera(LatLng p1, LatLng p2) {
    double south = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double north = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double west = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double east = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;

    double distanceInMeters = Geolocator.distanceBetween(p1.latitude, p1.longitude, p2.latitude, p2.longitude);

    if (distanceInMeters < 30) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(p1, 16),
      );
    } else {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
    }
  }

  @override
  void dispose() {
    _esnafSub?.cancel();
    _ajandaSub?.cancel();
    _kullaniciSub?.cancel();
    _talepSub?.cancel();
    _beklemeSayaci?.cancel();
    _filoController.dispose();
    _yorumController.dispose();
    super.dispose();
  }

  void _esnafDinle() {
    _esnafSub = FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _guncelEsnaf = EsnafModeli.fromFirestore(snapshot);
          _kullanicilariDinle();
        });
      }
    });
  }

  void _ajandaDinle() {
    String ayKey = DateFormat('yyyy-MM').format(DateTime.now());
    String gunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _ajandaSub = FirebaseFirestore.instance.collection('esnaflar').doc(widget.esnaf.id).collection('taksi_ajanda').doc(ayKey).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() { _gunlukAjanda = Map<String, dynamic>.from(snapshot.data()?[gunKey] ?? {}); });
      }
    });
  }

  void _kullanicilariDinle() {
    _kullaniciSub?.cancel();
    final telefonlar = _guncelEsnaf.araclar.map((a) => a['soforTel']?.toString()).where((t) => t != null && t.isNotEmpty).toSet().toList();
    if (telefonlar.isEmpty) return;
    _kullaniciSub = FirebaseFirestore.instance.collection('kullanicilar').where(FieldPath.documentId, whereIn: telefonlar.take(30).toList()).snapshots().listen((snapshot) {
      if (mounted) {
        setState(() { for (var doc in snapshot.docs) { _kullaniciProfilleri[doc.id] = Map<String, dynamic>.from(doc.data()); } });
      }
    });
  }

  bool _istirahatKontrol(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    if (arac['durum'] == 'İstirahatte') return true;
    if (_gunlukAjanda.containsKey(plaka) && _gunlukAjanda[plaka]?.toString().contains('I') == true) return true;
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
    return !((arac['calismaGunleri'] ?? {})[gunAdi] ?? true);
  }

  bool _nobetciKontrol(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    if (_gunlukAjanda.containsKey(plaka) && _gunlukAjanda[plaka]?.toString().contains('N') == true) return true;
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
    return ((arac['nobetBilgileri'] ?? {})[gunAdi] ?? {})['nobetci'] ?? false;
  }

  Future<void> _aramaYap(String tel) async {
    final Uri url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsappAc(String tel) async {
    String formattedTel = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedTel.startsWith('0')) formattedTel = formattedTel.substring(1);
    if (!formattedTel.startsWith('90')) formattedTel = '90$formattedTel';

    final Uri url = Uri.parse("whatsapp://send?phone=$formattedTel");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri webUrl = Uri.parse("https://wa.me/$formattedTel");
      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
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
    } catch (e) { return true; }
  }

  Widget _durumRozeti() {
    bool acik = _suAnAcikMi();
    if (!acik) return _rozet("Şu An Kapalı", Colors.red);
    
    // [GÜNCELLEME] 1 tane bile 'Müsait' araç varsa durak Müsait görünür
    bool musaitAracVar = _guncelEsnaf.araclar.any((a) => a['durum'] == 'Müsait' && !_istirahatKontrol(a));
    
    if (musaitAracVar) {
      return _rozet("Müsait", Colors.green);
    } else {
      return _rozet("Meşgul", Colors.orange);
    }
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

  Widget _calismaGunuSatiri(String gun, {bool sonSatir = false}) {
    final cs = _guncelEsnaf.calismaSaatleri ?? {};
    final gunler = cs['gunler'] as Map<String, dynamic>? ?? {};
    final bool acik = gunler[gun] ?? true;
    final String acilis = cs['acilis'] ?? "09:00";
    final String kapanis = cs['kapanis'] ?? "18:00";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(gun, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Text(
                acik ? "$acilis - $kapanis" : "Kapalı",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: acik ? Colors.blue.shade900 : Colors.red,
                ),
              ),
            ],
          ),
        ),
        if (!sonSatir) Divider(height: 8, color: Colors.blue.shade100),
      ],
    );
  }

  Widget _harita() {
    return GoogleMap(
      key: const PageStorageKey('taksi_harita'),
      onMapCreated: (c) {
        _mapController = c;
        _musteriKonumunaOdakla();
      },
      initialCameraPosition: _ilkKameraPozisyonu,
      markers: _isaretciler,
      circles: _daireler,
      myLocationEnabled: false,
      myLocationButtonEnabled: true,
      mapType: MapType.normal,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
    );
  }

  Widget _yolculukSayfasi() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_guncelEsnaf.isletmeAdi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: const [SizedBox(width: 48)],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _harita()),
          Positioned(left: 12, right: 12, bottom: 88, child: _yolculukSeridi()),
        ],
      ),
      floatingActionButton: SosButonu(
        randevuId: "taksi_detay",
        esnafId: _guncelEsnaf.id,
        kullaniciTel: widget.kullaniciTel ?? "",
        baslatanRol: 'Yolcu',
        adminTel: _guncelEsnaf.telefon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_aktifTalep != null) return _yolculukSayfasi();
    return Scaffold(
      appBar: AppBar(
        title: Text(_guncelEsnaf.isletmeAdi),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: const [
          SizedBox(width: 48), // global ? için yer
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: _harita(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_guncelEsnaf.logoUrl.trim().isNotEmpty) ...[
                    Center(child: IsletmeLogosu(url: _guncelEsnaf.logoUrl, boyut: 88, yuvarlak: true, kenarBoslugu: false)),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_guncelEsnaf.isletmeAdi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(children: [const Text("Taksi", style: TextStyle(fontSize: 16, color: Colors.grey)), const SizedBox(width: 10), _durumRozeti()]),
                      ])),
                      CircleAvatar(backgroundColor: Colors.green, radius: 25, child: IconButton(icon: const Icon(Icons.phone, color: Colors.white), onPressed: () => _aramaYap(_guncelEsnaf.telefon))),
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
                  const Text("Gündüz Mesai Saatleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        if (_guncelEsnaf.calismaSaatleri?['is724'] == true || (_guncelEsnaf.calismaSaatleri?['acilis'] == "00:00" && _guncelEsnaf.calismaSaatleri?['kapanis'] == "00:00"))
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
                  const SizedBox(height: 25),
                  const Text("Bugün Çalışan Araçlarımız", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _calisanAraclarListesi(),
                  const SizedBox(height: 25),
                  const Text("İletişim ve Hızlı Randevu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_android, color: Colors.green),
                    title: Text(_guncelEsnaf.telefon),
                    subtitle: const Text("İşletme İletişim Hattı"),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _aramaYap(_guncelEsnaf.telefon),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text("Ara"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700, elevation: 0),
                    ),
                  ),
                  if (_guncelEsnaf.whatsapp != null && _guncelEsnaf.whatsapp!.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                      title: Text(_guncelEsnaf.whatsapp!),
                      subtitle: const Text("WhatsApp üzerinden yazabilirsiniz"),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _whatsappAc(_guncelEsnaf.whatsapp!),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text("WhatsApp"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700, elevation: 0),
                      ),
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
            YapayZekaKutusu(
              aktif: _guncelEsnaf.yapayZekaAktif,
              isletmeAdi: _guncelEsnaf.isletmeAdi,
              rehberAnahtar: 'TaksiMusteriEkrani',
              taksiIstiyorum: () => _taksiCagirDialog(context),
              randevuAl: !_guncelEsnaf.randevuAlinmasin
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => TaksiYonlendirme.randevuEkrani(esnaf: _guncelEsnaf, kullaniciTel: widget.kullaniciTel)),
                      )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: ElevatedButton.icon(
                onPressed: _taksiYukleniyor ? null : () => _taksiCagirDialog(context),
                icon: _taksiYukleniyor ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.local_taxi, color: Colors.black),
                label: const Text("Taksi İstiyorum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (!_guncelEsnaf.randevuAlinmasin)
              AnaButon(
                metin: "Hemen Randevu Al", 
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (c) => TaksiYonlendirme.randevuEkrani(esnaf: _guncelEsnaf, kullaniciTel: widget.kullaniciTel))
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      floatingActionButton: SosButonu(randevuId: "taksi_detay", esnafId: _guncelEsnaf.id, kullaniciTel: widget.kullaniciTel ?? "", baslatanRol: 'Yolcu', adminTel: _guncelEsnaf.telefon),
    );
  }

  Widget _calisanAraclarListesi() {
    List<Map<String, dynamic>> tumAraclar = List<Map<String, dynamic>>.from(_guncelEsnaf.araclar);

    // [GÜNCELLEME] İşletme ayarına göre istirahatli araçları filtrele veya göster
    final calisanAraclar = _guncelEsnaf.istirahatliAraclariGizle 
        ? tumAraclar.where((a) => !_istirahatKontrol(a)).toList() 
        : tumAraclar;

    calisanAraclar.sort((a, b) {
      bool aNob = _nobetciKontrol(a); bool bNob = _nobetciKontrol(b);
      if (aNob != bNob) return aNob ? -1 : 1;
      int t1 = a['siraZamani'] ?? 0; int t2 = b['siraZamani'] ?? 0;
      return t1.compareTo(t2);
    });

    if (calisanAraclar.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Şu an çalışan araç bulunmuyor.", style: TextStyle(color: Colors.grey))));
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 135,
          child: ListView.builder(
            controller: _filoController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            itemCount: calisanAraclar.length,
            itemBuilder: (context, index) {
              final arac = calisanAraclar[index];
              final bool nobetci = _nobetciKontrol(arac);
              final String durum = arac['durum'] ?? 'Müsait';

              final String tel = (arac['soforTel'] ?? "").toString();
              final userData = _kullaniciProfilleri[tel] ?? {};
              String? fotoUrl = userData['fotoUrl'];
              final belgeler = userData['belgeler'] ?? {};
              if (belgeler['selfie']?['status'] == 'Onaylandı') {
                fotoUrl = belgeler['selfie']['url'];
              }

              return Container(
                width: 155,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                  border: nobetci ? Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: Text(arac['plaka'] ?? "-", style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                        if (nobetci) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 0.5)), child: const Text("NÖBETÇİ", style: TextStyle(color: Colors.orange, fontSize: 7.5, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                          child: ClipOval(
                            child: fotoUrl != null
                                ? Image.network(
                              fotoUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 100,
                              errorBuilder: (c,e,s) => const Icon(Icons.person, size: 18, color: Colors.white54),
                            )
                                : const Icon(Icons.person, size: 18, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(arac['soforAd'] ?? "Şoför", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Builder(builder: (context) {
                          bool istirahatte = _istirahatKontrol(arac);
                          Color noktaRengi = istirahatte ? Colors.grey : (nobetci ? Colors.orange : (durum == 'Meşgul' ? Colors.blue : Colors.green));
                          String durumMetni = istirahatte ? "İstirahatte" : (nobetci ? "Nöbetçi" : (durum == 'Meşgul' ? "Meşgul" : "Müsait"));
                          
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 10, color: noktaRengi),
                              const SizedBox(width: 5),
                              Flexible(child: Text(durumMetni, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis)),
                              if (taksiBelgeli(belgeler))
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text('BELGELİ', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(left: 0, child: _kaydirmaButonu(Icons.arrow_back_ios_new, Alignment.centerLeft)),
        Positioned(right: 0, child: _kaydirmaButonu(Icons.arrow_forward_ios, Alignment.centerRight)),
      ],
    );
  }

  Widget _kaydirmaButonu(IconData icon, Alignment alignment) {
    bool isLeft = alignment == Alignment.centerLeft;
    return GestureDetector(
      onTap: () {
        if (_filoController.hasClients) {
          if (isLeft) {
            _filoController.animateTo(_filoController.offset - 167, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
          } else {
            _filoController.animateTo(_filoController.offset + 167, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
          }
        }
      },
      child: Container(
        height: 60, width: 35,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [isLeft ? Colors.white : Colors.white10, isLeft ? Colors.white10 : Colors.white],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
        ),
        child: Icon(icon, size: 14, color: Colors.indigo),
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
              children: List.generate(5, (i) => IconButton(onPressed: () => setState(() => _secilenPuan = i + 1.0), icon: Icon(i < _secilenPuan ? Icons.star : Icons.star_border, color: Colors.amber, size: 30)))),
          TextField(controller: _yorumController, maxLines: 3, decoration: InputDecoration(hintText: "Yorumunuzu buraya yazın...", fillColor: Colors.white, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
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
    if (_secilenPuan == 0 || _yorumController.text.trim().isEmpty || widget.kullaniciTel == null) return;
    setState(() => _yorumGonderiliyor = true);
    try {
      await _firestoreServisi.yorumEkle({'esnafId': widget.esnaf.id, 'kullaniciTel': widget.kullaniciTel!, 'puan': _secilenPuan, 'yorum': _yorumController.text.trim(), 'tarih': FieldValue.serverTimestamp()});
      if (mounted) setState(() { _secilenPuan = 0.0; _yorumGonderiliyor = false; _yorumController.clear(); });
    } catch (_) { if (mounted) setState(() => _yorumGonderiliyor = false); }
  }

  Widget _yorumlarSliverListesi() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _yorumlarStream,
      builder: (context, snapshot) {
        final yorumlar = snapshot.data ?? [];
        if (yorumlar.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) {
            final y = yorumlar[i];
            final DateTime tarih = (y['tarih'] as Timestamp).toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Müşteri", style: TextStyle(fontWeight: FontWeight.bold)), Text(DateFormat('dd.MM.yyyy').format(tarih), style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                Row(children: List.generate(5, (index) => Icon(index < (y['puan'] ?? 0) ? Icons.star : Icons.star_border, size: 14, color: Colors.amber))),
                const SizedBox(height: 6),
                Text(y['yorum'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ]),
            );
          }, childCount: yorumlar.length > 5 ? 5 : yorumlar.length)),
        );
      },
    );
  }

  void _talepDinle() {
    final anahtar = _firestoreServisi.musteriTelefonAnahtari(widget.kullaniciTel ?? '');
    if (anahtar.isEmpty) return;
    _talepSub = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('musteriAnahtar', isEqualTo: anahtar)
        .snapshots()
        .listen((snap) async {
      QueryDocumentSnapshot<Map<String, dynamic>>? secilen;
      for (final d in snap.docs) {
        final data = d.data();
        if (data['esnafId'] != widget.esnaf.id) continue;
        final durum = (data['durum'] ?? '').toString();
        if (!taksiSurenDurumlar.contains(durum)) continue;
        if (secilen == null) {
          secilen = d;
          continue;
        }
        final onceki = (secilen.data()['durum'] ?? '').toString();
        if (onceki == 'bekliyor' && durum != 'bekliyor') secilen = d;
      }
      if (!mounted) return;
      if (secilen == null) {
        final oncekiId = (_aktifTalep?['id'] ?? '').toString();
        final oncekiDurum = (_aktifTalep?['durum'] ?? '').toString();
        final oncekiBekliyordu = oncekiDurum == 'bekliyor';
        final vazgecti = _yolcuVazgecti;
        Map<String, dynamic>? ozet;
        if (oncekiId.isNotEmpty && !oncekiBekliyordu && !_ozetGosterilen.contains(oncekiId)) {
          for (final d in snap.docs) {
            if (d.id != oncekiId) continue;
            if ((d.data()['durum'] ?? '').toString() != 'indi') continue;
            ozet = Map<String, dynamic>.from(d.data());
            _ozetGosterilen.add(oncekiId);
          }
        }
        _yolcuVazgecti = false;
        _beklemeSayaci?.cancel();
        setState(() {
          _aktifTalep = null;
          _isaretciler.removeWhere((m) => m.markerId.value == 'taksi_yolda');
        });
        if (oncekiBekliyordu && !vazgecti) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Şu an araç çıkarılamadı. Biraz sonra tekrar deneyebilirsiniz.')),
          );
        }
        if (ozet != null) {
          final veri = ozet;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _yolculukOzeti(veri);
          });
        }
        return;
      }
      final data = Map<String, dynamic>.from(secilen.data());
      data['id'] = secilen.id;
      setState(() => _aktifTalep = data);
      _beklemeSayaciniKur(secilen.id, data);
      final konum = data['soforKonum'];
      final plaka = (data['plaka'] ?? '').toString();
      if (konum is! GeoPoint || (data['durum'] ?? '') == 'bekliyor') {
        setState(() => _isaretciler.removeWhere((m) => m.markerId.value == 'taksi_yolda'));
        return;
      }
      if (_taksiIkon == null || _taksiIkonPlaka != plaka) {
        _taksiIkon = await _balonluMarkerUret(
          baslik: plaka.isEmpty ? 'Taksi' : plaka,
          balonRenk: Colors.yellow.shade600,
          igneRenk: Colors.black,
        );
        _taksiIkonPlaka = plaka;
      }
      if (!mounted || _taksiIkon == null) return;
      final nokta = LatLng(konum.latitude, konum.longitude);
      setState(() {
        _isaretciler.removeWhere((m) => m.markerId.value == 'taksi_yolda');
        _isaretciler.add(Marker(
          markerId: const MarkerId('taksi_yolda'),
          position: nokta,
          icon: _taksiIkon!,
          anchor: const Offset(0.5, 1.0),
        ));
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(nokta));
    });
  }

  void _beklemeSayaciniKur(String id, Map<String, dynamic> data) {
    _beklemeSayaci?.cancel();
    if ((data['durum'] ?? '') != 'bekliyor') return;
    _beklemeBaslangici.putIfAbsent(id, () => DateTime.now());
    final toplam = taksiCagriKalani(data, yerelden: _beklemeBaslangici[id]);
    final soru = data['soruZamani'];
    var soruKalan = taksiSoruAraligi;
    if (soru is Timestamp) {
      soruKalan = taksiSoruAraligi - DateTime.now().difference(soru.toDate());
      if (soruKalan.isNegative) soruKalan = Duration.zero;
    }
    final bekle = soruKalan < toplam ? soruKalan : toplam;
    if (bekle == Duration.zero) {
      taksiSiradakiAracaSor(id);
      _beklemeSayaci = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        final guncel = _aktifTalep;
        if (guncel != null && (guncel['id'] ?? '') == id) _beklemeSayaciniKur(id, guncel);
      });
      return;
    }
    _beklemeSayaci = Timer(bekle, () => taksiSiradakiAracaSor(id));
  }

  Future<void> _yolcuVazgec(Map<String, dynamic> talep) async {
    final id = (talep['id'] ?? '').toString();
    final durum = (talep['durum'] ?? '').toString();
    if (id.isEmpty) return;
    if (durum == 'yolda' || durum == 'geldim') {
      final hesap = taksiIptalHesapla(
        talep: talep,
        taban: _guncelEsnaf.taksiIptalTabanUcret,
        kmUcret: _guncelEsnaf.taksiIptalKmUcret,
        dakikaUcret: _guncelEsnaf.taksiIptalDakikaUcret,
      );
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vazgeç'),
          content: Text(taksiIptalOnayMetni(hesap)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vazgeç', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (onay != true || !mounted) return;
      final bedel = await taksiBinmedenVazgec(talepId: id, esnafId: widget.esnaf.id);
      if (bedel == null) return;
      await BildirimServisi.taksiYolcuVazgecti(
        esnaf: _guncelEsnaf,
        soforTel: (talep['soforTel'] ?? '').toString(),
        iptalBedeli: bedel,
      );
      return;
    }
    _beklemeyiKapat(id, 'iptal');
  }

  Future<void> _beklemeyiKapat(String id, String durum) async {
    if (durum == 'iptal') _yolcuVazgecti = true;
    final kapandi = await taksiBekleyenCagriyiKapat(id, durum);
    if (!kapandi) {
      if (durum == 'iptal') _yolcuVazgecti = false;
      return;
    }
    if (durum != 'iptal') return;
    final sofor = (_aktifTalep?['soforTel'] ?? '').toString();
    await BildirimServisi.taksiYolcuVazgecti(esnaf: _guncelEsnaf, soforTel: sofor);
  }

  Widget _yolculukSeridi() {
    final talep = _aktifTalep;
    if (talep == null) return const SizedBox.shrink();
    final durum = (talep['durum'] ?? '').toString();
    final plaka = (talep['plaka'] ?? '').toString();
    final nereye = (talep['nereye'] ?? '').toString();
    String alt = 'Ücret taksimetrededir.';
    if (durum == 'yolda') {
      final arac = talep['soforKonum'];
      final yolcu = talep['musteriKonum'];
      if (arac is GeoPoint && yolcu is GeoPoint) {
        alt = 'Yaklaşık ${taksiDakika(arac, yolcu)} dk. Ücret taksimetrededir.';
      } else {
        alt = 'Konum birazdan görünecek. Ücret taksimetrededir.';
      }
    } else if (durum == 'bekliyor') {
      alt = 'Durağın onayı bekleniyor. 25 saniye cevap yoksa sıradaki araca geçilir. 2 dakika dolunca çağrı kapanır.';
    }
    final soforTel = (talep['soforTel'] ?? '').toString();
    final belgeli = taksiBelgeli((_kullaniciProfilleri[soforTel] ?? {})['belgeler']);
    final yolda = durum == 'yolda' || durum == 'geldim' || durum == 'bindi';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.yellow.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.yellow.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plaka.isEmpty ? taksiDurumBasligi(durum) : '$plaka · ${taksiDurumBasligi(durum)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (belgeli)
            const Text('Belgeli', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w800)),
          Text(alt),
          if (nereye.isNotEmpty) Text('Varış: $nereye'),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (durum == 'bekliyor' || durum == 'yolda' || durum == 'geldim' || durum == 'bindi')
                TextButton.icon(
                  onPressed: () {
                    final sofor = (talep['soforTel'] ?? '').toString().trim();
                    final tel = durum == 'bekliyor' || sofor.isEmpty ? _guncelEsnaf.telefon : sofor;
                    _aramaYap(tel);
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text(durum == 'bekliyor' ? 'Durağı ara' : 'Şoförü ara'),
                ),
              if (yolda)
                TextButton.icon(
                  onPressed: () => _yakinaGonder(talep),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Yakınıma gönder'),
                ),
              if (durum == 'bekliyor' || durum == 'yolda' || durum == 'geldim')
                TextButton(
                  onPressed: () => _yolcuVazgec(talep),
                  child: const Text('Vazgeç', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _yakinaGonder(Map<String, dynamic> talep) async {
    final konum = talep['soforKonum'];
    final durum = (talep['durum'] ?? '').toString();
    final metin = taksiYakinaMetin(
      durak: _guncelEsnaf.isletmeAdi,
      plaka: (talep['plaka'] ?? '').toString(),
      durum: taksiDurumBasligi(durum),
      durakTel: _guncelEsnaf.telefon,
      adres: (talep['adres'] ?? '').toString(),
      nereye: (talep['nereye'] ?? '').toString(),
      enlem: konum is GeoPoint ? konum.latitude : null,
      boylam: konum is GeoPoint ? konum.longitude : null,
    );
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _yolculukOzeti(Map<String, dynamic> talep) {
    final plaka = (talep['plaka'] ?? '').toString();
    final adres = (talep['adres'] ?? '').toString();
    final nereye = (talep['nereye'] ?? '').toString();
    final kabul = taksiSaatYazi(talep['kabulZamani']);
    final inis = taksiSaatYazi(talep['indimZamani']);
    final satirlar = <String>[
      _guncelEsnaf.isletmeAdi,
      if (plaka.isNotEmpty) 'Plaka: $plaka',
      if (adres.isNotEmpty) 'Alış: $adres',
      if (nereye.isNotEmpty) 'Varış: $nereye',
      if (kabul.isNotEmpty) 'Kabul: $kabul',
      if (inis.isNotEmpty) 'İniş: $inis',
      'Ücret taksimetrededir.',
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yolculuk kaydı'),
        content: Text(satirlar.join('\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _taksiCagirDialog(BuildContext context) async {
    if (_taksiYukleniyor) return;
    setState(() => _taksiYukleniyor = true);

    final konumBilgisi = await _konumServisi.konumuVeAdresiGetir();
    String musteriAdresi = "Konum Alınamadı";
    GeoPoint musteriKonumu = widget.esnaf.konum;

    if (konumBilgisi != null && !konumBilgisi.containsKey('hata')) {
      musteriAdresi = konumBilgisi['tamAdres'] ?? "Adres Belirlenemedi";
      musteriKonumu = GeoPoint(double.parse(konumBilgisi['enlem']!), double.parse(konumBilgisi['boylam']!));
    }

    final duraktakiAraclar = widget.esnaf.araclar
        .where((a) => a['durakta'] == true && a['durum'] != 'İstirahatte')
        .toList();

    duraktakiAraclar.sort((a, b) {
      bool aNob = _nobetciKontrol(a); bool bNob = _nobetciKontrol(b);
      if (aNob != bNob) return aNob ? -1 : 1;
      int t1 = a['siraZamani'] ?? 0; int t2 = b['siraZamani'] ?? 0;
      return t1.compareTo(t2);
    });

    double mesafeMetre = Geolocator.distanceBetween(musteriKonumu.latitude, musteriKonumu.longitude, widget.esnaf.konum.latitude, widget.esnaf.konum.longitude);
    double tahminiDakika = (mesafeMetre * 1.3) / 500;
    int beklemeSuresi = tahminiDakika.round();
    if (duraktakiAraclar.isEmpty) beklemeSuresi += 12;
    if (beklemeSuresi < 3) beklemeSuresi = 3;
    if (beklemeSuresi > 45) beklemeSuresi = 45;

    Map<String, dynamic>? siradakiArac = duraktakiAraclar.isNotEmpty ? duraktakiAraclar.first : null;

    if (mounted) setState(() => _taksiYukleniyor = false);
    if (!context.mounted) return;

    final secilen = await showDialog<String>(
      context: context,
      builder: (context) => _TaksiCagriDialog(
        isletmeAdi: _guncelEsnaf.isletmeAdi,
        musteriAdresi: musteriAdresi,
        enlem: musteriKonumu.latitude,
        boylam: musteriKonumu.longitude,
        il: widget.esnaf.il,
        ilce: widget.esnaf.ilce,
        esnafEnlem: widget.esnaf.konum.latitude,
        esnafBoylam: widget.esnaf.konum.longitude,
        beklemeSuresi: beklemeSuresi,
        mesafeMetre: mesafeMetre,
      ),
    );
    if (secilen == null || !mounted) return;
    _taksiCagriOnayla(musteriKonumu, musteriAdresi, secilen, beklemeSuresi, siradakiArac);
  }

  void _taksiCagriOnayla(GeoPoint musteriKonumu, String musteriAdresi, String nereye, int beklemeSuresi, Map<String, dynamic>? siradakiArac) async {
    try {
      final mesafe = Geolocator.distanceBetween(
        musteriKonumu.latitude,
        musteriKonumu.longitude,
        widget.esnaf.konum.latitude,
        widget.esnaf.konum.longitude,
      );
      final plaka = siradakiArac?['plaka'];
      final kayit = await FirebaseFirestore.instance.collection('taksi_talepleri').add({
        'esnafId': widget.esnaf.id,
        'kullaniciTel': widget.kullaniciTel ?? '',
        'musteriTel': widget.kullaniciTel ?? '',
        'musteriAd': 'Yolcu',
        'adres': musteriAdresi,
        'nereye': nereye,
        'musteriKonum': musteriKonumu,
        'musteriAnahtar': _firestoreServisi.musteriTelefonAnahtari(widget.kullaniciTel ?? ''),
        'tarih': FieldValue.serverTimestamp(),
        'olusturulmaTarihi': FieldValue.serverTimestamp(),
        'soruZamani': FieldValue.serverTimestamp(),
        'sorulanPlakalar': [if (plaka != null) plaka],
        'durum': 'bekliyor',
        'plaka': plaka,
        'soforTel': siradakiArac?['soforTel'],
        'tahminiSure': beklemeSuresi,
        'mesafe': mesafe,
      });

      await BildirimServisi.taksiCagriDustu(
        esnaf: widget.esnaf,
        soforTel: siradakiArac?['soforTel']?.toString(),
        adres: musteriAdresi,
        talepId: kayit.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Taksi çağrınız durağa iletildi. Sürücü onayladığında bilgilendirileceksiniz."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Taksi çağrısı oluşturulamadı: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _TaksiCagriDialog extends StatefulWidget {
  final String isletmeAdi;
  final String musteriAdresi;
  final double enlem;
  final double boylam;
  final String il;
  final String ilce;
  final double esnafEnlem;
  final double esnafBoylam;
  final int beklemeSuresi;
  final double mesafeMetre;

  const _TaksiCagriDialog({
    required this.isletmeAdi,
    required this.musteriAdresi,
    required this.enlem,
    required this.boylam,
    required this.il,
    required this.ilce,
    required this.esnafEnlem,
    required this.esnafBoylam,
    required this.beklemeSuresi,
    required this.mesafeMetre,
  });

  @override
  State<_TaksiCagriDialog> createState() => _TaksiCagriDialogState();
}

class _TaksiCagriDialogState extends State<_TaksiCagriDialog> {
  final TextEditingController _nereye = TextEditingController();

  @override
  void dispose() {
    _nereye.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesafeMetre = widget.mesafeMetre;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: Colors.yellow.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  const Icon(Icons.local_taxi, size: 50, color: Colors.black),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.isletmeAdi,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("MÜŞTERİ ADRESİ", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.musteriAdresi, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  NereyeAlani(
                    controller: _nereye,
                    enlem: widget.enlem,
                    boylam: widget.boylam,
                    il: widget.il,
                    ilce: widget.ilce,
                    esnafEnlem: widget.esnafEnlem,
                    esnafBoylam: widget.esnafBoylam,
                  ),
                  const SizedBox(height: 8),
                  const Text('Ücret taksimetrededir.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const Divider(height: 32),
                  const Text('TAHMİNİ GELİŞ', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(children: [Text("${widget.beklemeSuresi} dk", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo)), const Text("Süre", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                      Column(children: [Text(mesafeMetre < 1000 ? "${mesafeMetre.toStringAsFixed(0)} m" : "${(mesafeMetre / 1000).toStringAsFixed(1)} km", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.orange)), const Text("Mesafe", style: TextStyle(fontSize: 10, color: Colors.grey))]),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, _nereye.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow.shade700,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 4,
                          ),
                          child: const Text("Taksi İstiyorum", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}