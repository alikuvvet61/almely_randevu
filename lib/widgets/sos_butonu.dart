import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../servisler/konum_servisi.dart';

class SosButonu extends StatefulWidget {
  final String randevuId;
  final String esnafId;
  final String kullaniciTel;
  final String baslatanRol; // 'Yolcu' veya 'Sürücü'
  final String adminTel; // Acil durum bildiriminin gideceği telefon (Admin/Merkez)

  const SosButonu({
    super.key,
    required this.randevuId,
    required this.esnafId,
    required this.kullaniciTel,
    required this.baslatanRol,
    required this.adminTel,
  });

  @override
  State<SosButonu> createState() => _SosButonuState();
}

class _SosButonuState extends State<SosButonu> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  double _progress = 0.0;
  Timer? _timer;
  final _firestoreServisi = FirestoreServisi();
  final _konumServisi = KonumServisi();

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          _progress = _animationController.value;
        });
      });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startPress() {
    setState(() {
      _isPressed = true;
      _progress = 0.0;
    });
    _animationController.forward(from: 0.0);
    
    _timer = Timer(const Duration(seconds: 3), () {
      if (_isPressed) {
        _triggerSos();
      }
    });
  }

  void _stopPress() {
    setState(() {
      _isPressed = false;
      _progress = 0.0;
    });
    _animationController.stop();
    _timer?.cancel();
  }

  Future<void> _triggerSos() async {
    _stopPress();
    
    // Konum al
    final konumData = await _konumServisi.konumuVeAdresiGetir();
    GeoPoint konum = const GeoPoint(0, 0);
    String adres = "Konum alınamadı";
    bool isMocked = false;
    
    if (konumData != null && konumData['hata'] == null) {
      konum = GeoPoint(
        double.parse(konumData['enlem']!),
        double.parse(konumData['boylam']!),
      );
      adres = konumData['tamAdres'] ?? "Adres alınamadı";
      isMocked = konumData['isMocked'] ?? false;
    }

    try {
      // 1. Firestore'a kaydet
      await _firestoreServisi.acilDurumTalebiOlustur(
        randevuId: widget.randevuId,
        esnafId: widget.esnafId,
        kullaniciTel: widget.kullaniciTel,
        konum: konum,
        baslatanRol: widget.baslatanRol,
        isMockedLocation: isMocked,
      );

      // 2. Admin'e bildirim gönder
      await BildirimServisi.acilDurumBildirimiGonder(
        baslik: "ACİL DURUM SİNYALİ!",
        icerik: "${widget.baslatanRol} (${widget.kullaniciTel}) acil durum sinyali gönderdi! Konum: $adres",
        hedefTel: widget.adminTel,
        ekVeri: {
          'randevuId': widget.randevuId,
          'lat': konum.latitude,
          'lng': konum.longitude,
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.emergency, color: Colors.red, size: 60),
            title: const Text("SOS Gönderildi", textAlign: TextAlign.center),
            content: const Text(
              "Acil durum sinyaliniz merkeze ve yetkililere iletildi. Lütfen sakin olun, konumunuz takip ediliyor.",
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("TAMAM"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("SOS gönderilemedi: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startPress(),
      onLongPressEnd: (_) => _stopPress(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 8,
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _isPressed ? Colors.red.shade900 : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                  Text(
                    "SOS",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
