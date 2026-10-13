import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../ekranlar/taksi/taksi_yolculuk_karti.dart';
import '../bildirim_servisi.dart';
import '../firestore_servisi.dart';

/// Yolculuk konumunu ekran kapansa da yazar. Telefon uygulamasında kilitliyken
/// bildirim durur. Tarayıcı sekmesi kapanırsa akış durur.
class TaksiKonumAkisi {
  static final FirestoreServisi _db = FirestoreServisi();
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _talepler;
  static StreamSubscription<Position>? _konum;
  static String? _esnafId;
  static String _tel = '';
  static String _plaka = '';
  static final Set<String> _geldi = {};
  static bool _yaziyor = false;
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _aktif = [];

  static void baslat({required String esnafId, String? soforTel, String? plaka}) {
    final tel = soforTel ?? '';
    final p = (plaka ?? '').trim();
    if (_talepler != null && _esnafId == esnafId && _tel == tel && _plaka == p) return;
    _esnafId = esnafId;
    _tel = tel;
    _plaka = p;
    _talepler?.cancel();
    _konum?.cancel();
    _konum = null;
    _talepler = FirebaseFirestore.instance
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: esnafId)
        .snapshots()
        .listen(_gelen, onError: (e) => debugPrint('Yolculuk dinlenemedi: $e'));
  }

  static bool _benim(Map<String, dynamic> data) {
    if (_tel.isEmpty && _plaka.isEmpty) return false;
    final kayitTel = _db.musteriTelefonAnahtari('${data['soforTel'] ?? ''}');
    final benimTel = _db.musteriTelefonAnahtari(_tel);
    if (benimTel.isNotEmpty && kayitTel == benimTel) return true;
    final kayitPlaka = (data['plaka'] ?? '').toString().trim();
    return _plaka.isNotEmpty && kayitPlaka == _plaka;
  }

  static void _gelen(QuerySnapshot<Map<String, dynamic>> snap) {
    _aktif = snap.docs.where((d) {
      final durum = (d.data()['durum'] ?? '').toString();
      if (durum != 'yolda' && durum != 'geldim' && durum != 'bindi') return false;
      return _benim(d.data());
    }).toList();
    if (_aktif.isEmpty) {
      _konum?.cancel();
      _konum = null;
      return;
    }
    if (_konum != null) return;
    _konumAc();
  }

  static Future<void> _konumAc() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final herZaman = await Permission.locationAlways.status;
        if (!herZaman.isGranted) await Permission.locationAlways.request();
      }
      final ayar = _ayar();
      _konum = Geolocator.getPositionStream(locationSettings: ayar).listen((pos) {
        _yaz(pos);
      }, onError: (e) => debugPrint('Konum akışı: $e'));
    } catch (e) {
      debugPrint('Konum akışı açılmadı: $e');
    }
  }

  static LocationSettings _ayar() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Taksi yolda',
          notificationText: 'Konumunuz yolcunun haritasına gidiyor.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 15,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15);
  }

  static Future<void> _yaz(Position pos) async {
    if (_yaziyor || _esnafId == null) return;
    _yaziyor = true;
    final nokta = GeoPoint(pos.latitude, pos.longitude);
    final liste = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(_aktif);
    try {
      for (final d in liste) {
        final data = d.data();
        final durum = (data['durum'] ?? '').toString();
        if (durum != 'yolda' && durum != 'geldim' && durum != 'bindi') continue;
        if (!_benim(data)) continue;
        var gidilen = (data['gidilenMetre'] is num) ? (data['gidilenMetre'] as num).toDouble() : 0.0;
        final onceki = data['soforKonum'];
        if (onceki is GeoPoint) {
          gidilen += Geolocator.distanceBetween(onceki.latitude, onceki.longitude, pos.latitude, pos.longitude);
        }
        await d.reference.update({
          'soforKonum': nokta,
          'gidilenMetre': gidilen,
          'sahteKonum': pos.isMocked,
          'konumZamani': FieldValue.serverTimestamp(),
        });
        final yolcu = data['musteriKonum'];
        if (durum != 'yolda' || yolcu is! GeoPoint || _geldi.contains(d.id)) continue;
        final metre = Geolocator.distanceBetween(pos.latitude, pos.longitude, yolcu.latitude, yolcu.longitude);
        if (metre > taksiGeldimMetre) continue;
        _geldi.add(d.id);
        try {
          await d.reference.update({
            'durum': 'geldim',
            'geldimZamani': FieldValue.serverTimestamp(),
          });
          final tel = (data['musteriTel'] ?? data['kullaniciTel'] ?? '').toString();
          final plaka = (data['plaka'] ?? '').toString();
          if (tel.isNotEmpty) {
            await BildirimServisi.bildirimGonder(
              kullaniciTel: tel,
              baslik: 'Taksiniz geldi',
              icerik: plaka.isEmpty ? 'Aracınız kapıda.' : '$plaka plakalı aracınız kapıda.',
            );
          }
        } catch (e) {
          _geldi.remove(d.id);
          debugPrint('Geldim yazılamadı: $e');
        }
      }
    } catch (e) {
      debugPrint('Yolculuk konumu yazılamadı: $e');
    } finally {
      _yaziyor = false;
    }
  }
}
