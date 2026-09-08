class TaksiKurallari {
  static bool kategoriTaksiMi(String? kategori) => kategori == 'Taksi';

  static bool rotaGecerliMi(String? nereden, String? nereye) {
    final start = (nereden ?? '').trim();
    final end = (nereye ?? '').trim();
    return start.isNotEmpty && end.isNotEmpty && start != end;
  }

  static String telefonTemizle(String telefon) {
    final clean = telefon.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length > 10 && clean.startsWith('90')) {
      return clean;
    }
    return clean.startsWith('0') ? clean.substring(1) : clean;
  }
}
