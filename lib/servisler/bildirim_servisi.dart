import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BildirimServisi {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return; // Web üzerinde FCM ve yerel bildirimler şu an devre dışı
    // 1. Bildirim izinlerini iste (iOS ve Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Bildirim izni verildi.');
    }

    // 2. Yerel bildirimleri ayarla (Ön planda bildirim göstermek için)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _localNotifications.initialize(initializationSettings);

    // Taksi kanalı oluştur (Özel sesli)
    const AndroidNotificationChannel taxiChannel = AndroidNotificationChannel(
      'taksi_cagrisi_kanali',
      'Taksi Çağrıları',
      description: 'Yeni taksi çağrısı bildirimi.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('taxi_horn'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(taxiChannel);

    // 3. Ön planda (app açıkken) bildirim gelirse yakala ve yerel olarak göster
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'randevu_kanal_id',
              'Randevu Bildirimleri',
              channelDescription: 'Randevu durumu değişiklikleri bildirilir.',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
      }
    });
  }

  // FCM Token al ve Firestore'a telefon numarasıyla eşleştirerek kaydet
  static Future<void> tokenKaydet(String telefon) async {
    if (kIsWeb) return;
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('kullanici_tokenlar').doc(telefon).set({
          'token': token,
          'sonGuncelleme': FieldValue.serverTimestamp(),
        });
        debugPrint("Token başarıyla kaydedildi.");
      }
    } catch (e) {
      debugPrint("Token kaydedilemedi: $e");
    }
  }

  // Firestore üzerinden bildirim gönderimi
  static Future<void> bildirimGonder({
    required String kullaniciTel,
    required String baslik,
    required String icerik,
  }) async {
    final docRef = await FirebaseFirestore.instance.collection('bildirimler').add({
      'aliciTel': kullaniciTel,
      'baslik': baslik,
      'icerik': icerik,
      'okundu': false,
      'tarih': FieldValue.serverTimestamp(),
    });
    debugPrint("Bildirim Firestore'a eklendi: ${docRef.id}");
  }

  // Firestore'daki bildirimleri dinle ve telefona bildirim olarak bas
  static void bildirimDinle(String telefon) {
    if (kIsWeb) return;
    FirebaseFirestore.instance
        .collection('bildirimler')
        .where('aliciTel', isEqualTo: telefon)
        .where('okundu', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data();
          if (data != null) {
            final bool isTaxi = data['baslik']?.toString().contains('Taksi') ?? false;
            
            _localNotifications.show(
              change.doc.id.hashCode,
              data['baslik'] ?? 'Yeni Bildirim',
              data['icerik'] ?? '',
              NotificationDetails(
                android: AndroidNotificationDetails(
                  isTaxi ? 'taksi_cagrisi_kanali' : 'randevu_kanal_id',
                  isTaxi ? 'Taksi Çağrıları' : 'Randevu Bildirimleri',
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: true,
                  sound: isTaxi ? const RawResourceAndroidNotificationSound('taxi_horn') : null,
                ),
              ),
            );
            // Bildirimi okundu olarak işaretle ki tekrar tetiklenmesin
            change.doc.reference.update({'okundu': true});
          }
        }
      }
    });
  }
}
