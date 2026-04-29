import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'servisler/bildirim_servisi.dart';
import 'ekranlar/giris_secim_ekrani.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Türkçe tarih formatlarını başlat
  await initializeDateFormatting('tr_TR', null);

  // Bildirim servisini başlat (Hata olsa bile uygulama açılmaya devam etsin)
  try {
    await BildirimServisi.initialize();
  } catch (e) {
    debugPrint("Bildirim servisi başlatılamadı: $e");
  }

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC55S5CY0E_WxTmwq-TvpF2Tp_yrBdrQb8",
          appId: "1:1013564598824:web:ae03d69dd700b7df86a31d",
          messagingSenderId: "1013564598824",
          projectId: "almely-randevu",
          storageBucket: "almely-randevu.firebasestorage.app",
          authDomain: "almely-randevu.firebaseapp.com",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase başlatma hatası: $e");
  }
  runApp(const AlmElyApp());
}

class AlmElyApp extends StatelessWidget {
  const AlmElyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
