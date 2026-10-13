import 'package:flutter/material.dart';

/// Telefonda işletme penceresi ekran genişliğine yayılır. Geniş ekranda 440 kalır.
double isletmeFormGenisligi(BuildContext context) {
  final ekran = MediaQuery.sizeOf(context).width;
  if (ekran >= 520) return 440;
  return (ekran - 56).clamp(260.0, ekran);
}

EdgeInsets isletmeFormKenar(BuildContext context) {
  final dar = MediaQuery.sizeOf(context).width < 520;
  return EdgeInsets.symmetric(horizontal: dar ? 8 : 40, vertical: dar ? 12 : 24);
}

/// Uzun formda kaydırma çubuğunu ve “aşağı kaydırın” yazısını açık tutar.
class BelirginKaydirma extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;

  const BelirginKaydirma({
    super.key,
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  State<BelirginKaydirma> createState() => _BelirginKaydirmaState();
}

class _BelirginKaydirmaState extends State<BelirginKaydirma> {
  final _kaydirma = ScrollController();
  bool _asagidaVar = false;

  @override
  void initState() {
    super.initState();
    _kaydirma.addListener(_guncelle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guncelle();
      WidgetsBinding.instance.addPostFrameCallback((_) => _guncelle());
    });
  }

  void _guncelle() {
    if (!_kaydirma.hasClients || !mounted) return;
    final konum = _kaydirma.position;
    final varMi = konum.maxScrollExtent > 12 && konum.pixels < konum.maxScrollExtent - 12;
    if (varMi != _asagidaVar) setState(() => _asagidaVar = varMi);
  }

  @override
  void dispose() {
    _kaydirma.removeListener(_guncelle);
    _kaydirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zemin = Theme.of(context).colorScheme.surface;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          RawScrollbar(
            controller: _kaydirma,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10,
            radius: const Radius.circular(8),
            thumbColor: Colors.indigo,
            trackColor: Colors.indigo.withValues(alpha: 0.18),
            trackBorderColor: Colors.transparent,
            child: SingleChildScrollView(
              controller: _kaydirma,
              primary: false,
              padding: const EdgeInsets.only(right: 16, bottom: 28),
              child: widget.child,
            ),
          ),
          if (_asagidaVar)
            Positioned(
              left: 0,
              right: 18,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        zemin.withValues(alpha: 0),
                        zemin,
                      ],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard_arrow_down, color: Colors.indigo),
                        SizedBox(width: 4),
                        Text(
                          'Aşağı kaydırın',
                          style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
