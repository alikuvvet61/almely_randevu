import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'servisler/bildirim_servisi.dart';
import 'servisler/onesignal_servisi.dart';
import 'servisler/versiyon_servisi.dart';
import 'ekranlar/giris_secim_ekrani.dart';

// Global Navigator Key (Her yerden navigasyon için)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Çevresel değişkenleri yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(".env dosyası yüklenemedi: $e");
  }

  // Türkçe tarih formatlarını başlat
  await initializeDateFormatting('tr_TR', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firebase başlatıldıktan sonra Remote Config'i başlat
    await VersiyonServisi.initialize();
  } catch (e) {
    debugPrint("Firebase başlatma hatası: $e");
  }

  // Bildirim servislerini başlat (Birbirinden bağımsız hata yakalamalı)
  try {
    await BildirimServisi.initialize();
  } catch (e) {
    debugPrint("BildirimServisi başlatılamadı: $e");
  }

  try {
    // OneSignal profesyonel bildirimleri başlat
    await OneSignalServisi.initialize();
  } catch (e) {
    debugPrint("OneSignalServisi başlatılamadı: $e");
  }

  runApp(const AlmElyApp());
}

class AlmElyApp extends StatelessWidget {
  const AlmElyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AlmEly Randevu Portalı',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Türkçe Dil Desteği
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      home: const GirisSecimSayfasi(),
    );
  }
}
