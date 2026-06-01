import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'servisler/bildirim_servisi.dart';
import 'servisler/versiyon_servisi.dart';
import 'ekranlar/giris_secim_ekrani.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  // Bildirim servisini başlat
  try {
    await BildirimServisi.initialize();
  } catch (e) {
    debugPrint("Bildirim servisi başlatılamadı: $e");
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
