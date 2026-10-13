/// Kategoriye göre çalışan görevi. Yeni kategori buraya eklenir.
class CalisanGorevleri {
  static const String taksiSoforu = 'Taksi Şoförü';

  static List<String> gorevler(String kategori) {
    if (kategori == 'Taksi') return const [taksiSoforu];
    return const [];
  }

  static bool plakaGerekli(String gorev) => gorev == taksiSoforu;
}
