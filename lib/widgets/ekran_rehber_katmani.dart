import 'package:flutter/material.dart';
import '../ekranlar/ekran_rehber_detay_ekrani.dart';
import '../navigator_key.dart';
import '../yardimcilar/ekran_rehber_katalogu.dart';

/// Aktif route sınıf adını tutar (rehber + debug rozet).
class AktifEkranTakibi {
  AktifEkranTakibi._();

  /// Yalnızca sınıf adı (örn. AnaEkran).
  static final ValueNotifier<String> sinifAdi = ValueNotifier<String>('GirisSecimSayfasi');
}

/// Her ekranda AppBar sağ üstte ? (help_outline).
/// Not: MaterialApp.builder Overlay'in dışında olduğu için Tooltip kullanılamaz
/// (No Overlay → kırmızı hata şeridi oluşuyordu).
class EkranRehberKatmani extends StatelessWidget {
  final Widget? child;

  const EkranRehberKatmani({super.key, required this.child});

  void _ac(String sinif) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => EkranRehberDetayEkrani(sinifAdi: sinif),
      ),
    );
  }

  static bool _maviAppBarMi(String sinif) {
    return sinif == 'AracKiralamaMusteriEkrani' ||
        sinif == 'TaksiMusteriEkrani' ||
        sinif == 'TaksiRandevuEkrani' ||
        sinif == 'MusteriEkrani' ||
        sinif == 'TumYorumlarEkrani';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (child != null) child!,
        Positioned(
          top: 0,
          right: 4,
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<String>(
              valueListenable: AktifEkranTakibi.sinifAdi,
              builder: (context, sinif, _) {
                if (EkranRehberKatalogu.gizlensinMi(sinif)) {
                  return const SizedBox.shrink();
                }
                return Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 48,
                    height: kToolbarHeight,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _ac(sinif),
                      child: Icon(
                        Icons.help_outline,
                        size: 26,
                        color: _maviAppBarMi(sinif)
                            ? Colors.white
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Route değişince [AktifEkranTakibi] günceller (release dahil).
class RehberNavigatorObserver extends NavigatorObserver {
  void _guncelle(Route<dynamic>? route) {
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ad = _routeWidgetAdi(route);
      if (ad != null && ad.isNotEmpty) {
        AktifEkranTakibi.sinifAdi.value = ad;
      }
    });
  }

  String? _routeWidgetAdi(Route<dynamic> route) {
    final nav = navigator;
    if (nav == null) return null;
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
    } catch (_) {}
    final name = route.settings.name;
    if (name != null && name.isNotEmpty && name != Navigator.defaultRouteName) {
      return name;
    }
    return null;
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
