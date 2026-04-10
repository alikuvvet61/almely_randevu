import 'package:cloud_firestore/cloud_firestore.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';

class FirestoreServisi {
  FirestoreServisi();
  final CollectionReference _esnaflarRef = FirebaseFirestore.instance.collection('esnaflar');
  final CollectionReference _hizmetTanimRef = FirebaseFirestore.instance.collection('hizmet_tanimlari');
  final CollectionReference _randevularRef = FirebaseFirestore.instance.collection('randevular');

  // --- ESNAF İŞLEMLERİ ---
  Stream<List<EsnafModeli>> esnaflariGetir() {
    return _esnaflarRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  Stream<List<EsnafModeli>> kategoriyeGoreGetir(String kategori) {
    return _esnaflarRef
        .where('kategori', isEqualTo: kategori)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  Future<EsnafModeli?> telefonIleEsnafGetir(String telefon) async {
    try {
      var sonuc = await _esnaflarRef.where('telefon', isEqualTo: telefon).limit(1).get();
      if (sonuc.docs.isNotEmpty) return EsnafModeli.fromFirestore(sonuc.docs.first);
    } catch (e) { return null; }
    return null;
  }

  Future<void> esnafEkle(EsnafModeli esnaf) async => await _esnaflarRef.add(esnaf.toMap());
  Future<void> esnafGuncelle(String id, Map<String, dynamic> veri) async => await _esnaflarRef.doc(id).update(veri);
  Future<void> esnafSil(String id) async => await _esnaflarRef.doc(id).delete();

  // --- HİZMET TANIMLARI ---
  Stream<List<Map<String, dynamic>>> hizmetTanimlariniGetir(String kategori) {
    return _hizmetTanimRef.where('kategori', isEqualTo: kategori).snapshots().map((snap) => 
      snap.docs.map((doc) => {'id': doc.id, 'ad': doc['ad'], 'kategori': doc['kategori']}).toList());
  }

  Future<void> hizmetTanimEkle(String ad, String kategori) async => await _hizmetTanimRef.add({'ad': ad, 'kategori': kategori, 'tarih': FieldValue.serverTimestamp()});
  Future<void> hizmetTanimGuncelle(String id, String yeniAd) async => await _hizmetTanimRef.doc(id).update({'ad': yeniAd, 'guncellemeTarihi': FieldValue.serverTimestamp()});
  Future<void> hizmetTanimSil(String id) async => await _hizmetTanimRef.doc(id).delete();

  // --- RANDEVU İŞLEMLERİ ---
  Stream<List<RandevuModeli>> randevulariGetir(String esnafId, DateTime tarih) {
    DateTime baslangic = DateTime(tarih.year, tarih.month, tarih.day);
    DateTime bitis = baslangic.add(const Duration(days: 1));

    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
        .where('tarih', isLessThan: Timestamp.fromDate(bitis))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList());
  }

  Future<void> randevuEkle(RandevuModeli randevu) async => await _randevularRef.add(randevu.toMap());
  Future<void> randevuSil(String id) async => await _randevularRef.doc(id).delete();
}