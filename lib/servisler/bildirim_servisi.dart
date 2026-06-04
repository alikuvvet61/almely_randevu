import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Arka plan bildirimi geldi: ${message.messageId}");
}

class BildirimServisi {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    // 1. Timezone ayarlarını yap
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));

    // 2. Bildirim izinlerini iste (Android 13+ desteği ile)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Bildirim izni verildi.');
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Bildirim izni reddedildi.');
    }

    // 3. Arka plan mesaj dinleyicisini kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Yerel bildirimleri ayarla (Ön planda bildirim göstermek için)
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
    final docRef =
        await FirebaseFirestore.instance.collection('bildirimler').add({
      'aliciTel': kullaniciTel,
      'baslik': baslik,
      'icerik': icerik,
      'okundu': false,
      'tarih': FieldValue.serverTimestamp(),
    });
    debugPrint("Bildirim Firestore'a eklendi: ${docRef.id}");
  }

  // Akıllı Takip Modu için yerel saatli bildirim kur (App kapalıyken çalışır)
  static Future<void> saatliBildirimKur({
    required int id,
    required String baslik,
    required String icerik,
    required DateTime zaman,
  }) async {
    if (kIsWeb) return;
    
    // Eğer zaman geçmişteyse hemen gönder veya iptal et
    if (zaman.isBefore(DateTime.now())) return;

    await _localNotifications.zonedSchedule(
      id,
      baslik,
      icerik,
      tz.TZDateTime.from(zaman, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'akilli_takip_kanali',
          'Akıllı Takip Bildirimleri',
          channelDescription: 'Kiralama süresi bitimine yakın uyarılar.',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint("Saatli bildirim kuruldu: $zaman");
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

  // Cihazlar arası senkronizasyon (Web'den alınan randevuyu telefona kurma)
  static Future<void> syncAkilliTakipBildirimleri(String telefon) async {
    if (kIsWeb) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('randevular')
        .where('kullaniciTel', isEqualTo: telefon)
        .where('akilliTakipAktif', isEqualTo: true)
        .where('durum', isEqualTo: 'Onaylandı')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final Timestamp? bZamanTs = data['bildirimZamani'] as Timestamp?;
      
      if (bZamanTs != null) {
        final DateTime bZaman = bZamanTs.toDate();
        if (bZaman.isAfter(DateTime.now())) {
          await saatliBildirimKur(
            id: doc.id.hashCode.remainder(100000),
            baslik: "Kiralama Süreniz Doluyor",
            icerik: "Aktif araç kiralamanızın süresi yakında doluyor. Detaylar için uygulamayı açın.",
            zaman: bZaman,
          );
        }
      }
    }
  }
}
