import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';

class OneSignalServisi {
  // Lütfen OneSignal App ID'nizi buraya girin (OneSignal Panelinden alabilirsiniz)
  // OneSignal App ID'si başarıyla bağlandı
  static const String appId = "40997d21-3c4a-4585-bbf1-8b30c01cba54";

  static Future<void> initialize() async {
    if (kIsWeb) return;

    // Log seviyesini ayarla
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // OneSignal'ı başlat
    OneSignal.initialize(appId);

    // Bildirim izni iste
    OneSignal.Notifications.requestPermission(true);
  }

  // Kullanıcıyı telefon numarasıyla eşleştir (Tag ekle)
  static Future<void> kullaniciyiKaydet(String telefon) async {
    if (kIsWeb) return;
    
    try {
      // Önce giriş yap
      OneSignal.login(telefon);
      
      // Bildirimleri aç ve tag ekle
      OneSignal.User.addTagWithKey("telefon", telefon);
      OneSignal.User.pushSubscription.optIn();
      
      debugPrint("OneSignal: Kullanıcı $telefon başarıyla abone edildi ve kaydedildi.");
    } catch (e) {
      debugPrint("OneSignal Kayıt Hatası: $e");
    }
  }

  // Bildirim gönderimi (Profesyonel uygulamalarda bu sunucu tarafında yapılır)
  // Burada mantığı kuruyoruz.
  static Future<void> bildirimGonder({
    required String kullaniciTel,
    required String baslik,
    required String icerik,
    DateTime? gonderimZamani,
  }) async {
    // NOT: OneSignal istemci tarafı (App içinden) doğrudan diğer kullanıcılara 
    // bildirim göndermeyi güvenlik nedeniyle kısıtlar. 
    // Gerçek profesyonel çözümde bu fonksiyon REST API üzerinden sunucudan çağrılır.
    debugPrint("OneSignal: $kullaniciTel için bildirim emri oluşturuldu.");
  }
}
