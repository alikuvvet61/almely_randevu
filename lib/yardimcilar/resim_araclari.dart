import 'dart:io';
import 'package:image/image.dart' as img;

class ResimAraclari {
  /// [DEVRE DISI]: Resim uzerine piksel mühürleme yerine MedyaGoruntuleyici overlay kullanılacaktır.
  /// Sadece boyut optimizasyonu yapar.
  static Future<File> zamanDamgasiEkle(File resimDosyasi, {String rol = "", String tel = ""}) async {
    try {
      final bytes = await resimDosyasi.readAsBytes();
      img.Image? resim = img.decodeImage(bytes);
      if (resim == null) return resimDosyasi;

      if (resim.width > 1200) {
        resim = img.copyResize(resim, width: 1200);
      }

      final islenmisBytes = img.encodeJpg(resim, quality: 75);
      final islenmisDosya = File(resimDosyasi.path)..writeAsBytesSync(islenmisBytes);
      return islenmisDosya;
    } catch (e) {
      return resimDosyasi;
    }
  }
}
