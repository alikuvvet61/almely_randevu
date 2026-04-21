import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';

class FirestoreServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Koleksiyon Referansları
  CollectionReference get _esnaflarRef => _db.collection('esnaflar');
  CollectionReference get _randevularRef => _db.collection('randevular');
  CollectionReference get _ayarlarRef => _db.collection('ayarlar');
  CollectionReference get _kategorilerRef => _db.collection('kategoriler');
  CollectionReference get _hizmetTanimRef => _db.collection('hizmet_tanimlari');

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

  // --- KATEGORİ İŞLEMLERİ ---
  Stream<List<Map<String, dynamic>>> kategorileriGetir() {
    return _kategorilerRef.orderBy('ad').snapshots().map((snap) => 
      snap.docs.map((doc) => {'id': doc.id, 'ad': doc['ad']}).toList());
  }

  Future<void> kategoriEkle(String ad) async => await _kategorilerRef.add({'ad': ad});
  Future<void> kategoriGuncelle(String id, String yeniAd) async => await _kategorilerRef.doc(id).update({'ad': yeniAd});
  Future<void> kategoriSil(String id) async => await _kategorilerRef.doc(id).delete();

  // --- HİZMET TANIMLARI ---
  Stream<List<Map<String, dynamic>>> hizmetTanimlariniGetir(String kategori) {
    return _hizmetTanimRef.where('kategori', isEqualTo: kategori).snapshots().map((snap) => 
      snap.docs.map((doc) => {'id': doc.id, 'ad': doc['ad'], 'kategori': doc['kategori']}).toList());
  }

  Future<void> hizmetTanimEkle(String ad, String kategori) async => await _hizmetTanimRef.add({'ad': ad, 'kategori': kategori, 'tarih': FieldValue.serverTimestamp()});

  // --- AJANDA İŞLEMLERİ ---
  Stream<DocumentSnapshot> gunlukAjandaGetir(String esnafId, DateTime tarih, String? kanal) {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    return _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).snapshots();
  }

  Future<void> ajandaOlustur({
    required String esnafId,
    required List<DateTime> tarihler,
    required String acilis,
    required String kapanis,
    required int slotDakika,
    String? ogleBaslangic,
    String? ogleBitis,
    String? kanal,
  }) async {
    final String kTemiz = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    List<String> yeniAktifler = tarihler.map((t) {
      String tStr = DateFormat('yyyy-MM-dd').format(t);
      return kTemiz.isNotEmpty ? "${tStr}_$kTemiz" : tStr;
    }).toList();

    await _esnaflarRef.doc(esnafId).update({
      'aktifGunler': FieldValue.arrayUnion(yeniAktifler),
      'calismaSaatleri.acilis': acilis,
      'calismaSaatleri.kapanis': kapanis,
      'calismaSaatleri.slotDakika': slotDakika,
      'calismaSaatleri.slotAraligi': slotDakika,
    }).timeout(const Duration(seconds: 30));

    const int batchSize = 50;
    for (var i = 0; i < tarihler.length; i += batchSize) {
      final batch = _db.batch();
      final end = (i + batchSize < tarihler.length) ? i + batchSize : tarihler.length;
      final chunk = tarihler.sublist(i, end);

      for (var tarih in chunk) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        String docId = kTemiz.isNotEmpty ? "${tarihStr}_$kTemiz" : tarihStr;
        DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);
        batch.set(docRef, {
          'tarih': tarihStr,
          'kanal': kTemiz,
          'acilis': acilis,
          'kapanis': kapanis,
          'slotDakika': slotDakika,
          'ogleBaslangic': ogleBaslangic,
          'ogleBitis': ogleBitis,
          'olusturulmaTarihi': FieldValue.serverTimestamp(),
          'kapaliSlotlar': {}, // Map olarak tutulacak: { 'saat': 'neden' }
        }, SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 60));
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> ajandaSil(String esnafId, DateTime tarih, String? kanal) async {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    await _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).delete();
    await _esnaflarRef.doc(esnafId).update({'aktifGunler': FieldValue.arrayRemove([docId])});
  }

  Future<void> slotKapatAc(String esnafId, DateTime tarih, String? kanal, String saat, {String? neden}) async {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);
    
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      Map<String, dynamic> kapaliSlotlar = {};
      
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        var rawKapali = data['kapaliSlotlar'];
        if (rawKapali is Map) {
          kapaliSlotlar = Map<String, dynamic>.from(rawKapali);
        } else if (rawKapali is List) {
          // Eski liste formatını map'e çevir (Geriye dönük uyumluluk)
          for (var s in rawKapali) {
            kapaliSlotlar[s.toString()] = "Belirtilmedi";
          }
        }

        if (kapaliSlotlar.containsKey(saat)) {
          kapaliSlotlar.remove(saat);
        } else {
          kapaliSlotlar[saat] = neden ?? "Belirtilmedi";
        }
        transaction.update(docRef, {'kapaliSlotlar': kapaliSlotlar});
      } else {
        kapaliSlotlar = {saat: neden ?? "Belirtilmedi"};
        transaction.set(docRef, {
          'tarih': tarihStr,
          'kanal': k,
          'kapaliSlotlar': kapaliSlotlar,
          'olusturulmaTarihi': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> gunuKapatAc(String esnafId, DateTime tarih, String? kanal, List<String> slotlar, bool kapat, {String? neden}) async {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);
    
    if (kapat) {
      Map<String, String> map = {};
      for (var s in slotlar) {
        map[s] = neden ?? "Belirtilmedi";
      }
      await docRef.set({'kapaliSlotlar': map}, SetOptions(merge: true));
    } else {
      await docRef.set({'kapaliSlotlar': {}}, SetOptions(merge: true));
    }
  }

  // --- RANDEVU İŞLEMLERİ ---
  Stream<List<RandevuModeli>> randevulariGetir(String esnafId, DateTime tarih) {
    DateTime bas = DateTime(tarih.year, tarih.month, tarih.day);
    DateTime bit = bas.add(const Duration(days: 1));
    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(bas))
        .where('tarih', isLessThan: Timestamp.fromDate(bit))
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RandevuModeli.fromFirestore(doc))
            .where((r) => r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
            .toList());
  }

  Stream<List<RandevuModeli>> esnafTumRandevulariGetir(String esnafId) {
    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          list.sort((a, b) {
            int d = a.tarih.compareTo(b.tarih);
            if (d != 0) return d;
            return a.saat.compareTo(b.saat);
          });
          return list;
        });
  }

  Stream<List<RandevuModeli>> kullaniciRandevulariniGetir(String telefon) {
    return _randevularRef
        .where('kullaniciTel', isEqualTo: telefon)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          list.sort((a, b) {
            int d = a.tarih.compareTo(b.tarih);
            if (d != 0) return d;
            return a.saat.compareTo(b.saat);
          });
          return list;
        });
  }

  Future<void> randevuEkle(RandevuModeli randevu) async => await _randevularRef.add(randevu.toMap());
  Future<void> randevuSil(String id) async => await _randevularRef.doc(id).delete();
  
  Future<void> randevuDurumGuncelle(String id, String yeniDurum) async {
    await _randevularRef.doc(id).update({'durum': yeniDurum, 'guncellemeTarihi': FieldValue.serverTimestamp()});
  }

  Future<void> randevuIptalEt(String id, String neden) async {
    await _randevularRef.doc(id).update({'durum': 'İptal Edildi', 'iptalNedeni': neden, 'iptalTarihi': FieldValue.serverTimestamp()});
  }

  // --- YÖNETİCİ AYARLARI ---
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
    await _db.runTransaction((transaction) async {
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

  Future<void> tumAjandalariTemizle() async {
    try {
      var esnaflar = await _esnaflarRef.get();
      for (var esnafDoc in esnaflar.docs) {
        await esnafDoc.reference.update({
          'aktifGunler': [],
          'calismaSaatleri': FieldValue.delete()
        });
        var ajandaDocs = await esnafDoc.reference.collection('ajanda').get();
        if (ajandaDocs.docs.isNotEmpty) {
          for (var i = 0; i < ajandaDocs.docs.length; i += 500) {
            final batch = _db.batch();
            final end = (i + 500 < ajandaDocs.docs.length) ? i + 500 : ajandaDocs.docs.length;
            for (var j = i; j < end; j++) {
              batch.delete(ajandaDocs.docs[j].reference);
            }
            await batch.commit();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Ajanda temizleme hatası: $e");
      }
      rethrow;
    }
  }
}
