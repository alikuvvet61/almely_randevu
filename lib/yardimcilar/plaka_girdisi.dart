import 'package:flutter/services.dart';

/// Türk plakası: 01–81, 1–3 harf, sonra sayı. İki rakamdan sonra boşluk gelir.
class PlakaGirdisi {
  static final List<TextInputFormatter> bicim = [_PlakaBicimleyici()];

  static const String ornek = '61 SH 063';

  static String yaz(String ham) {
    final il = StringBuffer();
    final harf = StringBuffer();
    final sayi = StringBuffer();
    var asama = 0;

    for (final birim in ham.toUpperCase().split('')) {
      if (asama == 0) {
        if (!_rakam(birim)) continue;
        if (il.isEmpty) {
          if (birim.codeUnitAt(0) <= 56) il.write(birim);
          continue;
        }
        final ilk = il.toString()[0];
        final ikinci = (ilk == '0' && birim != '0') ||
            (ilk == '8' && (birim == '0' || birim == '1')) ||
            (ilk != '0' && ilk != '8');
        if (!ikinci) continue;
        il.write(birim);
        asama = 1;
        continue;
      }
      if (asama == 1) {
        if (_harf(birim) && harf.length < 3) {
          harf.write(birim);
          continue;
        }
        if (_rakam(birim) && harf.isNotEmpty) {
          asama = 2;
        } else {
          continue;
        }
      }
      if (asama == 2 && _rakam(birim)) {
        final sinir = harf.length == 1 ? 5 : (harf.length == 2 ? 4 : 3);
        if (sayi.length < sinir) sayi.write(birim);
      }
    }

    final parca = <String>[
      if (il.isNotEmpty) il.toString(),
      if (harf.isNotEmpty) harf.toString(),
      if (sayi.isNotEmpty) sayi.toString(),
    ];
    var sonuc = parca.join(' ');
    if (il.length == 2 && harf.isEmpty) sonuc = '$sonuc ';
    if (harf.length == 3 && sayi.isEmpty) sonuc = '$sonuc ';
    return sonuc;
  }

  static bool _rakam(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _harf(String c) => RegExp(r'[A-PR-VYZ]').hasMatch(c);
}

class _PlakaBicimleyici extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final eski = oldValue.text;
    final yeni = newValue.text;
    if (yeni.length < eski.length && PlakaGirdisi.yaz(yeni) == eski) {
      final imlec = oldValue.selection.extentOffset.clamp(0, eski.length);
      var kes = imlec - 1;
      while (kes >= 0 && eski[kes] == ' ') {
        kes--;
      }
      final kaynak = kes < 0 ? eski.substring(imlec) : eski.substring(0, kes) + eski.substring(imlec);
      final yazili = PlakaGirdisi.yaz(kaynak);
      final once = PlakaGirdisi.yaz(kes < 0 ? '' : eski.substring(0, kes));
      return TextEditingValue(
        text: yazili,
        selection: TextSelection.collapsed(offset: once.length.clamp(0, yazili.length)),
      );
    }
    final imlec = newValue.selection.extentOffset.clamp(0, yeni.length);
    final yazili = PlakaGirdisi.yaz(yeni);
    final once = PlakaGirdisi.yaz(yeni.substring(0, imlec));
    return TextEditingValue(
      text: yazili,
      selection: TextSelection.collapsed(offset: once.length.clamp(0, yazili.length)),
    );
  }
}
