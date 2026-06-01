import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class VersiyonServisi {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  static Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Varsayılan değerler
    await _remoteConfig.setDefaults({
      "guncel_versiyon": "1.0.0",
      "zorunlu_guncelleme": false,
      "market_url": "https://play.google.com/store/apps/details?id=com.example.almely_randevu",
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint("Remote Config çekilemedi: $e");
    }
  }

  static Future<void> versiyonKontrol(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String mevcutVersiyon = packageInfo.version;
    
    String guncelVersiyon = _remoteConfig.getString("guncel_versiyon");
    bool zorunluMu = _remoteConfig.getBool("zorunlu_guncelleme");
    String marketUrl = _remoteConfig.getString("market_url");

    if (_versiyonKarsilastir(mevcutVersiyon, guncelVersiyon)) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: !zorunluMu,
        builder: (ctx) => AlertDialog(
          title: const Text("Güncelleme Mevcut"),
          content: Text(zorunluMu 
            ? "Uygulamayı kullanmaya devam edebilmek için lütfen güncelleyin." 
            : "Yeni bir versiyon mevcut. Güncellemek ister misiniz?"),
          actions: [
            if (!zorunluMu)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Daha Sonra")),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse(marketUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text("Şimdi Güncelle"),
            ),
          ],
        ),
      );
    }
  }

  // Eğer mevcut versiyon güncel versiyondan küçükse true döner
  static bool _versiyonKarsilastir(String mevcut, String guncel) {
    try {
      // Build numaralarını (+1) temizle, sadece 1.0.0 kısmını al
      String temizMevcut = mevcut.split('+')[0];
      String temizGuncel = guncel.split('+')[0];

      List<int> mList = temizMevcut.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> gList = temizGuncel.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Uzunlukları eşitle (Örn: 1.0 ile 1.0.1 kıyaslanırken)
      int maxLen = mList.length > gList.length ? mList.length : gList.length;
      while (mList.length < maxLen) {
        mList.add(0);
      }
      while (gList.length < maxLen) {
        gList.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (gList[i] > mList[i]) {
          return true;
        }
        if (gList[i] < mList[i]) {
          return false;
        }
      }
    } catch (e) {
      debugPrint("Versiyon kıyaslama hatası: $e");
    }
    return false;
  }
}
