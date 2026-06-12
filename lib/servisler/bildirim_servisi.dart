import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb için gerekli
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("ARKA PLAN BİLDİRİMİ GELDİ: ${message.messageId}");
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

    // 2. Bildirim izinlerini iste
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Bildirim izni verildi.');
    }

    // 3. Arka plan mesaj dinleyicisini kaydet
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Yerel bildirimleri ayarla
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    // V18+ DÜZELTMESİ: İsimlendirilmiş parametre kullanımı
    await _localNotifications.initialize(settings: initializationSettings);

    // Kanalları oluştur (V3 - Kesinlik ve Görünürlük için)
    const AndroidNotificationChannel smartTrackChannel = AndroidNotificationChannel(
      'akilli_takip_kanali_v3',
      'KRİTİK UYARILAR',
      description: 'Kiralama süresi bitimine yakın kritik uyarılar.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(smartTrackChannel);

    // 5. Ön planda bildirim yakalama
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: "ÖN PLAN: ${notification.title}",
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'akilli_takip_kanali_v3',
              'KRİTİK UYARILAR',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
      }
    });
  }

  static Future<void> tokenKaydet(String telefon, {BuildContext? context}) async {
    if (kIsWeb) return;
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('kullanici_tokenlar').doc(telefon).set({
          'token': token,
          'sonGuncelleme': FieldValue.serverTimestamp(),
          'cihaz': kIsWeb ? "Web" : "Mobil",
        });
        
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("BİLDİRİM KİMLİĞİ KAYDEDİLDİ: Bildirim almaya hazırsınız."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      }
    } catch (e) {
      debugPrint("Token Hatası: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("KİMLİK HATASI: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  static Future<void> bildirimGonder({
    required String kullaniciTel,
    required String baslik,
    required String icerik,
  }) async {
    await FirebaseFirestore.instance.collection('bildirimler').add({
      'aliciTel': kullaniciTel,
      'baslik': baslik,
      'icerik': icerik,
      'okundu': false,
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  // HATA TESPİT SİSTEMİ: Bildirim kurulurken hata olursa kullanıcıya bildir
  static Future<void> saatliBildirimKur({
    required int id,
    required String baslik,
    required String icerik,
    required DateTime zaman,
    BuildContext? context,
  }) async {
    if (kIsWeb) return;
    
    if (zaman.isBefore(DateTime.now())) {
      String msg = "HATA: Bildirim zamanı geçmişte (${DateFormat('HH:mm').format(zaman)}).";
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
      return;
    }

    try {
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      if (await Permission.scheduleExactAlarm.isDenied) {
        debugPrint("UYARI: Tam zamanlı alarm izni yok, yaklaşık mod kullanılıyor.");
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }

      // V18+ DÜZELTMESİ: zonedSchedule parametreleri isimlendirilmiş hale getirildi
      await _localNotifications.zonedSchedule(
        id: id,
        title: baslik,
        body: icerik,
        scheduledDate: tz.TZDateTime.from(zaman, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'akilli_takip_kanali_v3',
            'KRİTİK UYARILAR',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
        ),
        androidScheduleMode: scheduleMode,
      );
      debugPrint("BAŞARILI: Bildirim kuruldu: $zaman");
    } catch (e) {
      String msg = "BİLDİRİM KURULAMADI: $e";
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 8)));
      }
    }
  }

  static Future<void> syncAkilliTakipBildirimleri(String telefon, BuildContext context) async {
    if (kIsWeb) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('randevular')
          .where('kullaniciTel', isEqualTo: telefon)
          .where('akilliTakipAktif', isEqualTo: true)
          .where('durum', isEqualTo: 'Onaylandı')
          .get();

      int count = 0;
      String alarmZamani = "";
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? bZamanTs = data['bildirimZamani'] as Timestamp?;
        
        if (bZamanTs != null) {
          final DateTime bZaman = bZamanTs.toDate();
          if (bZaman.isAfter(DateTime.now())) {
            // Her kurma işleminden önce context hala geçerli mi kontrol et
            if (context.mounted) {
              await saatliBildirimKur(
                id: doc.id.hashCode.remainder(100000),
                baslik: "Kiralama Süreniz Doluyor",
                icerik: "Aktif araç kiralamanızın süresi yakında doluyor.",
                zaman: bZaman,
                context: context,
              );
              alarmZamani = DateFormat('HH:mm').format(bZaman);
              count++;
            }
          }
        }
      }
      if (count > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$count bildirim telefonunuza kuruldu. Saat: $alarmZamani"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      debugPrint("Senkronizasyon Hatası: $e");
    }
  }

  static void bildirimDinle(String telefon, {BuildContext? context}) {
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
            _localNotifications.show(
              id: change.doc.id.hashCode,
              title: data['baslik'] ?? 'Yeni Bildirim',
              body: data['icerik'] ?? '',
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'akilli_takip_kanali_v3',
                  'KRİTİK UYARILAR',
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: true,
                ),
              ),
            );
            
            if (context != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("BİLDİRİM GELDİ: ${data['baslik']}"),
                  backgroundColor: Colors.indigo,
                ),
              );
            }
            change.doc.reference.update({'okundu': true});
          }
        }
      }
    });
  }
}
