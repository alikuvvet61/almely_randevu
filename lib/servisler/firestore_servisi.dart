import 'package:cloud_firestore/cloud_firestore.dart';
import '../modeller/esnaf_modeli.dart';

class FirestoreServisi {
  final CollectionReference _esnaflarRef = FirebaseFirestore.instance.collection('esnaflar');

  // Tüm esnafları anlık dinler (Stream)
  Stream<List<EsnafModeli>> esnaflariGetir() {
    return _esnaflarRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  // Kategoriye göre esnafları getirir
  Stream<List<EsnafModeli>> kategoriyeGoreGetir(String kategori) {
    return _esnaflarRef
        .where('kategori', isEqualTo: kategori)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  // Yeni esnaf ekler
  Future<void> esnafEkle(EsnafModeli esnaf) async {
    await _esnaflarRef.add(esnaf.toMap());
  }

  // Esnaf günceller
  Future<void> esnafGuncelle(String id, EsnafModeli esnaf) async {
    await _esnaflarRef.doc(id).update(esnaf.toMap());
  }

  // Esnaf siler
  Future<void> esnafSil(String id) async {
    await _esnaflarRef.doc(id).delete();
  }
}
