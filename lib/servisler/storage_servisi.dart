import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageServisi {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// [randevuId] ile ilişkili bir dosya (foto/video) yükler ve URL döner.
  /// [isTeslimat] true ise 'teslimatlar' klasörüne, false ise 'iadeler' klasörüne yükler.
  Future<String?> dosyaYukle(String randevuId, File dosya, bool isTeslimat) async {
    try {
      final String klasor = isTeslimat ? 'teslimatlar' : 'iadeler';
      final String dosyaAdi = "${DateTime.now().millisecondsSinceEpoch}_${dosya.path.split('/').last}";
      final String path = "$klasor/$randevuId/$dosyaAdi";

      final ref = _storage.ref().child(path);
      
      // Video veya Fotoğraf tespiti
      String contentType = 'image/jpeg';
      if (dosya.path.endsWith('.mp4') || dosya.path.endsWith('.mov')) {
        contentType = 'video/mp4';
      }

      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putFile(dosya, metadata);
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage yükleme hatası: $e");
      return null;
    }
  }

  /// Bir dosyayı Storage'dan siler
  Future<void> dosyaSil(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint("Storage silme hatası: $e");
    }
  }
}
