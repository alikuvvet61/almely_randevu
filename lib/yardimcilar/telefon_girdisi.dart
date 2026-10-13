import 'package:flutter/services.dart';

/// Telefon alanları yalnızca rakam alır. Cep ve sabit hat kabul edilir.
class TelefonGirdisi {
  static final List<TextInputFormatter> bicim = [_TelefonRakamlari()];

  static String rakamlar(String ham) {
    var t = ham.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.startsWith('90') && t.length >= 12) t = t.substring(2);
    return t;
  }

  static bool harfVar(String ham) =>
      RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(ham);

  static bool gecerli(String ham, {bool bosOlabilir = false}) {
    if (harfVar(ham)) return false;
    final t = rakamlar(ham);
    if (t.isEmpty) return bosOlabilir;
    if (t.length == 10 && !t.startsWith('0')) return true;
    if (t.length == 11 && t.startsWith('0') && t[1] != '0') return true;
    return false;
  }

  static String? hata(String ham, {bool bosOlabilir = false}) {
    if (harfVar(ham)) return 'Telefon numarasında harf olamaz.';
    if (gecerli(ham, bosOlabilir: bosOlabilir)) return null;
    if (ham.trim().isEmpty) return 'Telefon numarası yazın.';
    return 'Geçerli bir telefon yazın. Örnek: 05xx xxx xx xx';
  }
}

class _TelefonRakamlari extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.startsWith('90') && t.length >= 12) t = t.substring(2);
    if (t.length > 11) t = t.substring(0, 11);
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
