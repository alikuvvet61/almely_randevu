import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Debug/profile build'lerde köşede aktif ekran dosya + sınıf adını gösterir.
/// Release'de hiç çizilmez (`kReleaseMode`).
class DebugEkranRozeti extends StatelessWidget {
  const DebugEkranRozeti({super.key, required this.child});

  final Widget? child;

  static final ValueNotifier<String> aktifEkran = ValueNotifier<String>('…');

  static final DebugNavigatorObserver observer = DebugNavigatorObserver();

  /// Sınıf adı → lib altındaki dosya yolu (rozet için).
  static const Map<String, String> _dosyaHaritasi = {
    'GirisSecimSayfasi': 'ekranlar/giris.dart',
    'AnaEkran': 'ekranlar/ana_ekran.dart',
    'MusteriEkrani': 'ekranlar/musteri_ekrani.dart',
    'RandevuEkrani': 'ekranlar/randevu_ekrani.dart',
    'EsnafPaneli': 'ekranlar/esnaf_paneli.dart',
    'EsnafAjandaEkrani': 'ekranlar/esnaf_ajanda_ekrani.dart',
    'EsnafParametreEkrani': 'ekranlar/esnaf_parametre_ekrani.dart',
    'AracParametreEkrani': 'ekranlar/arac_kiralama/arac_parametre_ekrani.dart',
    'EsnafRandevuYonetimEkrani': 'ekranlar/esnaf_randevu_onay_ekrani.dart',
    'AracKiralamaEsnafRandevuOnayEkrani': 'ekranlar/arac_kiralama/arac_kiralama_esnaf_randevu_onay_ekrani.dart',
    'KullaniciRandevuEkrani': 'ekranlar/kullanici_randevu_ekrani.dart',
    'RehberEkrani': 'ekranlar/rehber_ekrani.dart',
    'AracKiralamaRehberEkrani': 'ekranlar/arac_kiralama/arac_kiralama_rehber_ekrani.dart',
    'TumYorumlarEkrani': 'ekranlar/tum_yorumlar_ekrani.dart',
    'KazaBildirimEkrani': 'ekranlar/arac_kiralama/kaza_bildirim_ekrani.dart',
    'KiraTeslimatEkrani': 'ekranlar/arac_kiralama/kira_teslimat_ekrani.dart',
    'AdminEkrani': 'ekranlar/Admin_Paneli/admin_ekrani.dart',
    'AracKiralamaMusteriEkrani': 'ekranlar/arac_kiralama/arac_kiralama_musteri_ekrani.dart',
    'AracKiralamaRandevuEkrani': 'ekranlar/arac_kiralama/arac_kiralama_randevu_ekrani.dart',
    'AracKiralamaEsnafPaneli': 'ekranlar/arac_kiralama/arac_kiralama_esnaf_paneli.dart',
    'TaksiModSecimEkrani': 'ekranlar/taksi/taksi_mod_secim_ekrani.dart',
    'TaksiMusteriEkrani': 'ekranlar/taksi/taksi_musteri_ekrani.dart',
    'TaksiRandevuEkrani': 'ekranlar/taksi/taksi_randevu_ekrani.dart',
    'TaksiEsnafPaneli': 'ekranlar/taksi/taksi_esnaf_paneli.dart',
    'TaksiEsnafRandevuOnayEkrani': 'ekranlar/taksi/taksi_esnaf_randevu_onay_ekrani.dart',
    'TaksiParametreEkrani': 'ekranlar/taksi/taksi_parametre_ekrani.dart',
    'TaksiCizelgeEkrani': 'ekranlar/taksi/taksi_cizelge_ekrani.dart',
    'TaksiDurakTakipEkrani': 'ekranlar/taksi/taksi_durak_takip_ekrani.dart',
    'TaksiRehberEkrani': 'ekranlar/taksi/taksi_rehber_ekrani.dart',
    'TaksiSurucuDogrulamaEkrani': 'ekranlar/taksi/taksi_surucu_dogrulama_ekrani.dart',
    'TaksiSurucuProfilDetayEkrani': 'ekranlar/taksi/taksi_surucu_profil_detay_ekrani.dart',
  };

  static String etiketOlustur(String sinifAdi) {
    final dosya = _dosyaHaritasi[sinifAdi];
    if (dosya == null) return sinifAdi;
    final kisa = dosya.split('/').last;
    return '$kisa\n$sinifAdi';
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (child != null) child!,
        Positioned(
          left: 8,
          bottom: 8,
          child: IgnorePointer(
            child: SafeArea(
              child: ValueListenableBuilder<String>(
                valueListenable: aktifEkran,
                builder: (_, ad, __) => Material(
                  elevation: 3,
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      ad,
                      style: const TextStyle(
                        color: Color(0xFFB8FF4A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DebugNavigatorObserver extends NavigatorObserver {
  void _guncelle(Route<dynamic>? route) {
    if (kReleaseMode || route == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kReleaseMode) return;

      var ad = route.settings.name;
      if (ad == null || ad.isEmpty || ad == Navigator.defaultRouteName) {
        ad = _routeWidgetAdi(route);
      }
      if (ad != null && ad.isNotEmpty) {
        DebugEkranRozeti.aktifEkran.value = DebugEkranRozeti.etiketOlustur(ad);
      }
    });
  }

  String? _routeWidgetAdi(Route<dynamic> route) {
    final nav = navigator;
    if (nav == null) return route.runtimeType.toString();

    try {
      if (route is MaterialPageRoute) {
        return route.builder(nav.context).runtimeType.toString();
      }
      if (route is PageRouteBuilder) {
        return route
            .pageBuilder(
              nav.context,
              const AlwaysStoppedAnimation(1),
              const AlwaysStoppedAnimation(1),
            )
            .runtimeType
            .toString();
      }
    } catch (_) {
      // Builder henüz hazır değilse route tipine düş.
    }
    return route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _guncelle(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _guncelle(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _guncelle(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _guncelle(previousRoute);
}
