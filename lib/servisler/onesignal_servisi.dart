import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' show pow;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bildirim_servisi.dart';

class OneSignalServisi {
  static const String appId = "40997d21-3c4a-4585-bbf1-8b30c01cba54";
  static String get restApiKey => dotenv.env['ONESIGNAL_REST_API_KEY'] ?? "";

  static Map<String, dynamic>? sonTiklananVeri;

  static Future<void> initialize({BuildContext? context}) async {
    if (kIsWeb) return;
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(appId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.User.pushSubscription.optIn();
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData;
        if (data != null && data.containsKey("action")) {
          sonTiklananVeri = Map<String, dynamic>.from(data);
        }
      });
    } catch (e) {
      debugPrint("OneSignal Başlatma Hatası: $e");
    }
  }

  static String _numaraTemizle(String tel) {
    // Temizle: +90, +, -, (), boşluk vb. kaldır
    String temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
    // Başında 0 varsa kaldır (0532 -> 532)
    if (temiz.startsWith('0')) {
      temiz = temiz.substring(1);
    }
    // Son 10 rakam (ulusal formatta 10 rakam = XXXXXXXXXX)
    if (temiz.length > 10) {
      temiz = temiz.substring(temiz.length - 10);
    }
    // Kontrol: en az 10 karakter olmalı (doğru format için)
    if (temiz.length != 10) {
      debugPrint("Uyarı: Telefon numarası şüpheli ($tel -> $temiz, ${temiz.length} kar)");
    }
    return temiz;
  }

  static Future<void> oturumuKapat() async {
    if (kIsWeb) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint("OneSignal Logout Hatası: $e");
    }
  }

  static Future<void> kullaniciyiKaydet(String telefon, {String? role, BuildContext? context}) async {
    String temizTel = _numaraTemizle(telefon);
    if (temizTel.length != 10) {
      debugPrint("HATA: Geçersiz telefon formatı - $telefon -> $temizTel");
      return;
    }

    if (kIsWeb) {
      // Web'de: Push notification yok, ama Firestore listener başlat
      debugPrint("Web cihazda: OneSignal kaydetme (tarayıcı push yok), listener başlatılıyor: $temizTel");
      BildirimServisi.bildirimDinle(temizTel, context: context);
      return;
    }

    try {
      await OneSignal.login(temizTel);
      OneSignal.User.pushSubscription.optIn();
      
      // [OPTİMİZASYON] Etiketleri toplu olarak (batch) gönderiyoruz
      Map<String, String> tags = {"telefon": temizTel};
      if (role != null && role.isNotEmpty) {
        tags["telefon_$role"] = temizTel;
      }
      OneSignal.User.addTags(tags);
      
      debugPrint("✅ OneSignal: Cihaz mühürlendi (Batch Tags): $temizTel (role: $role)");
    } catch (e) {
      debugPrint("❌ OneSignal Kayıt Hatası: $e (telefon: $temizTel)");
      // Retry: 1 saniye sonra tekrar dene
      await Future.delayed(const Duration(seconds: 1));
      try {
        await OneSignal.login(temizTel);
        Map<String, String> tags = {"telefon": temizTel};
        if (role != null && role.isNotEmpty) {
          tags["telefon_$role"] = temizTel;
        }
        OneSignal.User.addTags(tags);
        debugPrint("✅ OneSignal: Retry başarılı: $temizTel");
      } catch (e2) {
        debugPrint("❌ OneSignal Retry Hatası: $e2");
      }
    }
  }

  /// Dinamik timezone offset hesapla (işletmenin bulunduğu bölge)
  static String _getTimezoneOffset() {
    // OneSignal standardı: "GMT+0300" veya "GMT-0700"
    // Türkiye şu an kalıcı olarak UTC+3 (GMT+0300) kullanıyor.
    return "GMT+0300";
  }

  /// REST API Key ve uygulaması kontrol et (v3 Bearer format)
  static void _checkApiKey() {
    String key = restApiKey;
    if (key.isEmpty || key == "" || key == "null") {
      debugPrint("🚨 KRITIK HATA: ONESIGNAL_REST_API_KEY yüklenmemiş! .env dosyasını kontrol et.");
      debugPrint("   Beklenen: ONESIGNAL_REST_API_KEY=os_v2_... veya api_v3_key (.env'de)");
    } else if (!key.startsWith('os_v2_') && !key.startsWith('api_')) {
      debugPrint("⚠️  UYARI: REST API Key bilinmeyen format: ${key.substring(0, 10)}...");
    } else {
      debugPrint("✅ OneSignal REST API Key yüklü (format: ${key.substring(0, 10)})");
    }
  }

  /// Exponential backoff retry ile bildirim planla
  static Future<String?> bildirimPlanla({
    required String baslik,
    required String icerik,
    required DateTime zaman,
    required String telefon,
    Map<String, dynamic>? ekVeri,
    String? randevuId,
    BuildContext? context,
    int retryCount = 0,
    String tagKey = 'telefon',
  }) async {
    // [GÜNCELLEME] Web üzerinden OneSignal REST API çağrısına izin veriyoruz.
    // Bu sayede web panelinden yapılan onaylar mobil cihazlara bildirim olarak düşebilecek.

    try {
      String temizTel = _numaraTemizle(telefon);
      if (temizTel.length != 10) {
        debugPrint("❌ bildirimPlanla: Geçersiz telefon formatı - $telefon -> $temizTel");
        return null;
      }

      // Zaman kontrolü: minimum 3 dakika ilerisi
      DateTime planZamani = zaman;
      if (planZamani.isBefore(DateTime.now().add(const Duration(minutes: 3)))) {
        planZamani = DateTime.now().add(const Duration(minutes: 3));
        debugPrint("⚠️  Planlama zamanı çok yakın, 3 dakika ilerisine alındı: $zaman -> $planZamani");
      }

      String formatliZaman = DateFormat('yyyy-MM-dd HH:mm:ss').format(planZamani);
      String timezone = _getTimezoneOffset();

      // [PROFESYONEL HEDEFLEME]: Tags (Etiketler) üzerinden hedefleme.
      // OneSignal Dashboard'da yeşil kutu içinde gördüğünüz "telefon" etiketini kullanır.
      final Map<String, dynamic> notificationBody = {
        'app_id': appId,
        'filters': [
          {'field': 'tag', 'key': 'telefon', 'relation': '=', 'value': temizTel}
        ],
        'headings': {'en': baslik, 'tr': baslik}, // 'en' (English) zorunludur
        'contents': {'en': icerik, 'tr': icerik}, // 'en' (English) zorunludur
        'send_after': "$formatliZaman $timezone",
        'data': ekVeri ?? {
          'action': 'uzatma_ekrani',
          'tel': temizTel,
          'randevuId': randevuId,
        },
        'priority': 10,
        'android_visibility': 1,
      };

       // API Key kontrol
       _checkApiKey();

       debugPrint("📤 OneSignal Planlanıyor (Tag Bazlı): $baslik (tel: $temizTel)");
       debugPrint("📋 OneSignal Payload: ${jsonEncode(notificationBody)}");

       final Map<String, String> headers = {
         'Content-Type': 'application/json; charset=utf-8',
         'Authorization': 'Basic $restApiKey',
       };

       final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: headers,
        body: jsonEncode(notificationBody),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("OneSignal API timeout (10s)");
      });

       debugPrint("📡 OneSignal Response Status: ${response.statusCode}");
       debugPrint("📄 OneSignal Response Body: ${response.body}");

      bool basarili = response.statusCode >= 200 && response.statusCode < 300;
      final responseData = jsonDecode(response.body);
      String? notificationId = responseData['id'];

       if (basarili && notificationId != null && notificationId.isNotEmpty) {
        debugPrint("✅ OneSignal Bildirim Planlandı: ID=$notificationId");
        return notificationId;
      } else {
        if (responseData.containsKey('errors')) {
          final List errors = responseData['errors'];
          if (errors.contains("All included players are not subscribed")) {
             debugPrint("❌ OneSignal Hata: Bu numaraya bağlı aktif cihaz bulunamadı!");
             
             // [AKILLI SABIR]: Alıcı yoksa 2 saniye bekle ve bir kez daha dene (Senkronizasyon gecikmesi için)
             if (retryCount < 1) {
               debugPrint("🔄 Alıcı henüz senkronize olmamış olabilir, 2s sonra tekrar deneniyor...");
               await Future.delayed(const Duration(seconds: 2));
               return await bildirimPlanla(
                 baslik: baslik,
                 icerik: icerik,
                 zaman: zaman,
                 telefon: temizTel,
                 ekVeri: ekVeri,
                 randevuId: randevuId,
                 context: null,
                 retryCount: retryCount + 1,
                 tagKey: tagKey,
               );
             }
             return "ALICI_YOK"; // İkinci denemede de yoksa hata dön
          }
          debugPrint("❌ OneSignal Bildirim Oluşturulamadı: ${responseData['errors']}");
        }
        
        // Eğer 400 veya alıcı yok hatası varsa retry mantıklı olmayabilir (alıcı gerçekten yoksa)
        // Ancak ağ hatası veya sunucu hatası için retry devam eder.
        if (retryCount < 2 && response.statusCode != 400) {
          final waitTime = Duration(seconds: pow(2, retryCount).toInt());
          debugPrint("🔄 Retry $retryCount/2...");
          await Future.delayed(waitTime);
          return await bildirimPlanla(
            baslik: baslik,
            icerik: icerik,
            zaman: zaman,
            telefon: temizTel,
            ekVeri: ekVeri,
            randevuId: randevuId,
            context: null,
            retryCount: retryCount + 1,
            tagKey: tagKey,
          );
        }
        return null;
      }
    } catch (e) {
      debugPrint("❌ OneSignal Planlama İstisnası: $e");
      return null;
    }
  }

  static Future<bool> bildirimIptalEt(String notificationId, {int retryCount = 0}) async {
    try {
      debugPrint("🗑️  OneSignal Bildirim İptal Ediliyor: $notificationId");

      final Map<String, String> headers = {};
      if (restApiKey.startsWith('os_v2_')) {
        headers['Authorization'] = 'Basic $restApiKey';
      } else {
        headers['Authorization'] = 'Bearer $restApiKey';
      }

      final response = await http.delete(
        Uri.parse('https://onesignal.com/api/v1/notifications/$notificationId?app_id=$appId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("OneSignal cancel timeout");
      });

      if (response.statusCode == 200) {
        debugPrint("✅ OneSignal Bildirim İptal Edildi: $notificationId");
        return true;
      } else {
        debugPrint("⚠️  OneSignal İptal Yanıtı (${response.statusCode}): ${response.body}");
        // 404 (not found) kabul edilebilir (zaten iptal edilmiş)
        if (response.statusCode == 404) {
          debugPrint("ℹ️  Bildirim zaten silinmiş: $notificationId");
          return true;
        }

        // Retry: diğer hatalar için
        if (retryCount < 2) {
          await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
          return await bildirimIptalEt(notificationId, retryCount: retryCount + 1);
        }
        return false;
      }
    } catch (e) {
      debugPrint("❌ OneSignal İptal Hatası: $e");
      if (retryCount < 2 && e is TimeoutException) {
        await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
        return await bildirimIptalEt(notificationId, retryCount: retryCount + 1);
      }
      return false;
    }
  }

  static Future<bool> bildirimGonderAnlik({
    required String baslik,
    required String icerik,
    required String telefon,
    Map<String, dynamic>? ekVeri,
    BuildContext? context,
    int retryCount = 0,
    String tagKey = 'telefon',
  }) async {
    // [GÜNCELLEME] Web üzerinden OneSignal REST API çağrısına izin veriyoruz.

    try {
      String temizTel = _numaraTemizle(telefon);
      if (temizTel.length != 10) {
        debugPrint("❌ bildirimGonderAnlik: Geçersiz telefon - $telefon -> $temizTel");
        return false;
      }

      final Map<String, dynamic> notificationBody = {
        'app_id': appId,
        'filters': [
          {'field': 'tag', 'key': 'telefon', 'relation': '=', 'value': temizTel}
        ],
        'target_channel': 'push',
        'name': "Anlık: $baslik ($temizTel)",
        'headings': {'en': baslik, 'tr': baslik}, // 'en' zorunludur
        'contents': {'en': icerik, 'tr': icerik}, // 'en' zorunludur
        'data': ekVeri ?? {'type': 'bilgi'},
        'priority': 10,
      };

      // API Key kontrol
      _checkApiKey();

      debugPrint("📨 OneSignal Anlık Gönderiliyor: $baslik (tel: $temizTel)");
      debugPrint("📋 OneSignal Payload: ${jsonEncode(notificationBody)}");

      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic $restApiKey',
      };

       final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: headers,
        body: jsonEncode(notificationBody),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("OneSignal instant timeout");
      });

      debugPrint("📡 OneSignal Response Status: ${response.statusCode}");
      debugPrint("📄 OneSignal Response Body: ${response.body}");

      bool basarili = response.statusCode >= 200 && response.statusCode < 300;
      if (basarili) {
        debugPrint("✅ OneSignal Anlık Gönderildi: $temizTel");
      } else {
        debugPrint("❌ OneSignal Anlık Hata (${response.statusCode}): ${response.body}");
        
        // Retry
        if (retryCount < 2) {
          final waitTime = Duration(seconds: pow(2, retryCount).toInt());
          debugPrint("🔄 Anlık Retry $retryCount/2 (${waitTime.inSeconds}s sonra)");
          await Future.delayed(waitTime);
          return await bildirimGonderAnlik(
            baslik: baslik,
            icerik: icerik,
            telefon: temizTel,
            ekVeri: ekVeri,
            context: null,
            retryCount: retryCount + 1,
            tagKey: tagKey,
          );
        }
      }
      return basarili;
    } catch (e) {
      debugPrint("❌ OneSignal Anlık İstisna: $e");
      if (retryCount < 2 && e is TimeoutException) {
        final waitTime = Duration(seconds: pow(2, retryCount).toInt());
        debugPrint("🔄 Network Retry $retryCount/2 (${waitTime.inSeconds}s sonra)");
        await Future.delayed(waitTime);
        return await bildirimGonderAnlik(
          baslik: baslik,
          icerik: icerik,
          telefon: telefon,
          ekVeri: ekVeri,
          context: null,
          retryCount: retryCount + 1,
          tagKey: tagKey,
        );
      }
      return false;
    }
  }
}
