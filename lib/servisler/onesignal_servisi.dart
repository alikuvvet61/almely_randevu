import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OneSignalServisi {
  static const String appId = "40997d21-3c4a-4585-bbf1-8b30c01cba54"; 
  static const String restApiKey = "os_v2_app_icmx2ij4jjcylo7rrmymahf2kqjqvqbgm3xupemwmzb5kj7zsfumguxl4gnaeggtxc7bmlxvvubke6lmijcjsv6ooqefyig6ele2cqq"; 

  // Kesin kalıcı veri saklama (Global Bellek)
  static Map<String, dynamic>? sonTiklananVeri;

  static Future<void> initialize({BuildContext? context}) async {
    if (kIsWeb) return;

    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.User.pushSubscription.optIn();
      
      // BİLDİRİM TIKLAMA DİNLEYİCİSİ (Uygulama kapalıyken bile çalışır)
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null && data.containsKey("action")) {
          // Veriyi en tepe statik değişkene yaz
          sonTiklananVeri = Map<String, dynamic>.from(data);
          debugPrint("OneSignal: Bildirim verisi belleğe alındı: ${data['action']}");
        }
      });
    } catch (e) {
      debugPrint("OneSignal Başlatma Hatası: $e");
    }
  }

  static Future<void> kullaniciyiKaydet(String telefon, {BuildContext? context}) async {
    if (kIsWeb) return;
    try {
      OneSignal.login(telefon);
      OneSignal.User.addTagWithKey("telefon", telefon);
      OneSignal.User.pushSubscription.optIn();
    } catch (e) {
      debugPrint("OneSignal Kayıt Hatası: $e");
    }
  }

  static Future<bool> bildirimPlanla({
    required String baslik,
    required String icerik,
    required DateTime zaman,
    required String telefon,
  }) async {
    if (kIsWeb) return false;

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_external_user_ids': [telefon],
          'headings': {'en': baslik},
          'contents': {'en': icerik},
          'send_after': zaman.toUtc().toIso8601String(),
          'data': {
            'action': 'uzatma_ekrani',
            'tel': telefon,
          },
          'android_accent_color': 'FF0000FF',
          'priority': 10,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
