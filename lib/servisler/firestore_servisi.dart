import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';

class FirestoreServisi {
  FirestoreServisi();
  final CollectionReference _esnaflarRef = FirebaseFirestore.instance.collection('esnaflar');
  final CollectionReference _hizmetTanimRef = FirebaseFirestore.instance.collection('hizmet_tanimlari');
  final CollectionReference _randevularRef = FirebaseFirestore.instance.collection('randevular');
  final CollectionReference _kategorilerRef = FirebaseFirestore.instance.collection('kategoriler');
  final CollectionReference _ayarlarRef = FirebaseFirestore.instance.collection('ayarlar');

  // --- ESNAF İŞLEMLERİ ---
  Stream<List<EsnafModeli>> esnaflariGetir() {
    return _esnaflarRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  Stream<EsnafModeli> esnafGetir(String id) {
    return _esnaflarRef.doc(id).snapshots().map((doc) => EsnafModeli.fromFirestore(doc));
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

  // --- KATEGORİ İŞLEMLERİ ---
  Stream<List<Map<String, dynamic>>> kategorileriGetir() {
    return _kategorilerRef.orderBy('ad').snapshots().map((snap) => 
      snap.docs.map((doc) => {'id': doc.id, 'ad': doc['ad']}).toList());
  }

  Future<void> kategoriEkle(String ad) async {
    await _kategorilerRef.add({'ad': ad});
  }

  Future<void> kategoriGuncelle(String id, String yeniAd) async {
    await _kategorilerRef.doc(id).update({'ad': yeniAd});
  }

  Future<void> kategoriSil(String id) async {
    await _kategorilerRef.doc(id).delete();
  }

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

  Stream<List<RandevuModeli>> esnafTumRandevulariGetir(String esnafId) {
    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          list.sort((a, b) => b.tarih.compareTo(a.tarih)); 
          return list;
        });
  }

  Future<void> randevuEkle(RandevuModeli randevu) async => await _randevularRef.add(randevu.toMap());
  Future<void> randevuSil(String id) async => await _randevularRef.doc(id).delete();
  
  Future<void> randevuIptalEt(String id, String neden) async {
    await _randevularRef.doc(id).update({
      'durum': 'İptal Edildi',
      'iptalNedeni': neden,
      'iptalTarihi': FieldValue.serverTimestamp()
    });
  }

  Future<void> randevuDurumGuncelle(String id, String yeniDurum) async {
    await _randevularRef.doc(id).update({
      'durum': yeniDurum,
      'guncellemeTarihi': FieldValue.serverTimestamp()
    });
  }

  Stream<List<RandevuModeli>> kullaniciRandevulariniGetir(String telefon) {
    return _randevularRef
        .where('kullaniciTel', isEqualTo: telefon)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          list.sort((a, b) => b.tarih.compareTo(a.tarih)); // Tarihe göre azalan
          return list;
        });
  }

  // --- YÖNETİCİ AYARLARI (İptal Nedenleri vb.) ---
  Stream<List<String>> iptalNedenleriniGetir(String tip) {
    return _ayarlarRef.doc('randevu_iptal_nedenleri').snapshots().map((doc) {
      if (!doc.exists) return tip == 'kullanici' ? ['Planlarım değişti', 'Yanlışlıkla aldım'] : ['Hizmet veremeyeceğim', 'Personel eksikliği'];
      return List<String>.from(doc.get(tip == 'kullanici' ? 'kullanici_nedenler' : 'esnaf_nedenler') ?? []);
    });
  }

  Future<void> iptalNedeniEkle(String tip, String neden) async {
    String alan = tip == 'kullanici' ? 'kullanici_nedenler' : 'esnaf_nedenler';
    await _ayarlarRef.doc('randevu_iptal_nedenleri').set({
      alan: FieldValue.arrayUnion([neden])
    }, SetOptions(merge: true));
  }

  Future<void> iptalNedeniGuncelle(String tip, String eskiNeden, String yeniNeden) async {
    String alan = tip == 'kullanici' ? 'kullanici_nedenler' : 'esnaf_nedenler';
    DocumentReference docRef = _ayarlarRef.doc('randevu_iptal_nedenleri');
    
    // İşlem sırası: Önce eskiyi sil, sonra yeniyi ekle
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        List<dynamic> liste = List.from(snapshot.get(alan) ?? []);
        int index = liste.indexOf(eskiNeden);
        if (index != -1) {
          liste[index] = yeniNeden;
          transaction.update(docRef, {alan: liste});
        }
      }
    });
  }

  Future<void> iptalNedeniSil(String tip, String neden) async {
    String alan = tip == 'kullanici' ? 'kullanici_nedenler' : 'esnaf_nedenler';
    await _ayarlarRef.doc('randevu_iptal_nedenleri').update({
      alan: FieldValue.arrayRemove([neden])
    });
  }

  // Toplu randevu silme (tarih ve kanal bazlı)
  Future<void> topluRandevuSil(String esnafId, DateTime tarih, String? kanal) async {
    DateTime baslangic = DateTime(tarih.year, tarih.month, tarih.day);
    DateTime bitis = baslangic.add(const Duration(days: 1));

    var snapshot = await _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
        .where('tarih', isLessThan: Timestamp.fromDate(bitis))
        .get();
    
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (kanal == null || data['randevu_kanali'] == kanal) {
        await doc.reference.delete();
      }
    }
  }

  // Tüm esnafların ajanda verilerini kökten temizle (Aktif, Kapalı ve Randevular)
  Future<void> tumAjandalariTemizle() async {
    // 1. Tüm esnafların aktifGunler alanlarını temizle
    var esnaflar = await _esnaflarRef.get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in esnaflar.docs) {
      batch.update(doc.reference, {
        'aktifGunler': [],
        'kapaliGunler': FieldValue.delete(), // Bu alanı tamamen siliyoruz
      });
    }
    await batch.commit();

    // 2. TÜM RANDEVULARI SİL (Temiz bir başlangıç için)
    var randevular = await _randevularRef.get();
    WriteBatch rBatch = FirebaseFirestore.instance.batch();
    for (var doc in randevular.docs) {
      rBatch.delete(doc.reference);
    }
    await rBatch.commit();
  }

  // Kapalı günleri güncelle
  Future<void> kapaliGunGuncelle(String esnafId, List<dynamic> kapaliGunler) async {
    await _esnaflarRef.doc(esnafId).update({'kapaliGunler': kapaliGunler});
  }

  Future<void> ajandaOlustur({
    required String esnafId,
    required DateTime tarih,
    required String acilis,
    required String kapanis,
    required int slotDakika,
    String? ogleBaslangic,
    String? ogleBitis,
    String? kanal,
  }) async {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String anahtar = kanal != null ? "${tarihStr}_$kanal" : tarihStr;
    
    await _esnaflarRef.doc(esnafId).update({
      'aktifGunler': FieldValue.arrayUnion([anahtar]),
      'calismaSaatleri': {
        'acilis': acilis,
        'kapanis': kapanis,
        'slotDakika': slotDakika,
        'ogleBaslangic': ogleBaslangic,
        'ogleBitis': ogleBitis,
      }
    });
  }
}
