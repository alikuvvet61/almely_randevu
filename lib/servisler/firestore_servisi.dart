import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import 'onesignal_servisi.dart';

class FirestoreServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Koleksiyon Referansları
  CollectionReference get _esnaflarRef => _db.collection('esnaflar');
  CollectionReference get _randevularRef => _db.collection('randevular');
  CollectionReference get _kategorilerRef => _db.collection('kategoriler');
  CollectionReference get _hizmetTanimRef => _db.collection('hizmet_tanimlari');
  CollectionReference get _yorumlarRef => _db.collection('yorumlar');
  CollectionReference get _kullanicilarRef => _db.collection('kullanicilar');
  CollectionReference get _ayarlarRef => _db.collection('ayarlar');

  // --- AYARLAR VE TANIMLAMALAR ---
  List<String> get _varsayilanAracTurleri => ["Binek", "SUV", "Minibüs", "Panelvan", "Kamyonet"];
  List<String> get _varsayilanAracSiniflari => ["Ekonomik", "Orta", "Üst Sınıf", "Lüks", "VIP"];

  Stream<List<String>> aracTurleriniGetir() {
    return _ayarlarRef.doc('arac_tanimlari').snapshots().map((doc) {
      if (!doc.exists) return _varsayilanAracTurleri;
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['turler'] ?? _varsayilanAracTurleri);
    });
  }

  Future<void> aracTuruEkle(String tur) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> turler;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['turler'] == null) {
        turler = List.from(_varsayilanAracTurleri);
      } else {
        turler = List<String>.from((snapshot.data() as Map<String, dynamic>)['turler']);
      }

      if (!turler.contains(tur)) {
        turler.add(tur);
        transaction.set(docRef, {'turler': turler}, SetOptions(merge: true));
      }
    });
  }

  Future<void> aracTuruSil(String tur) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> turler;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['turler'] == null) {
        turler = List.from(_varsayilanAracTurleri);
      } else {
        turler = List<String>.from((snapshot.data() as Map<String, dynamic>)['turler']);
      }

      if (turler.contains(tur)) {
        turler.remove(tur);
        transaction.set(docRef, {'turler': turler}, SetOptions(merge: true));
      }
    });
  }

  Future<void> aracTuruGuncelle(String eskiTur, String yeniTur) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> turler;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['turler'] == null) {
        turler = List.from(_varsayilanAracTurleri);
      } else {
        turler = List<String>.from((snapshot.data() as Map<String, dynamic>)['turler']);
      }

      int index = turler.indexOf(eskiTur);
      if (index != -1) {
        turler[index] = yeniTur;
        transaction.set(docRef, {'turler': turler}, SetOptions(merge: true));
      }
    });
  }

  Stream<List<String>> aracSiniflariniGetir() {
    return _ayarlarRef.doc('arac_tanimlari').snapshots().map((doc) {
      if (!doc.exists) return _varsayilanAracSiniflari;
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['siniflar'] ?? _varsayilanAracSiniflari);
    });
  }

  Future<void> aracSinifiEkle(String sinif) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> siniflar;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['siniflar'] == null) {
        siniflar = List.from(_varsayilanAracSiniflari);
      } else {
        siniflar = List<String>.from((snapshot.data() as Map<String, dynamic>)['siniflar']);
      }

      if (!siniflar.contains(sinif)) {
        siniflar.add(sinif);
        transaction.set(docRef, {'siniflar': siniflar}, SetOptions(merge: true));
      }
    });
  }

  Future<void> aracSinifiSil(String sinif) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> siniflar;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['siniflar'] == null) {
        siniflar = List.from(_varsayilanAracSiniflari);
      } else {
        siniflar = List<String>.from((snapshot.data() as Map<String, dynamic>)['siniflar']);
      }

      if (siniflar.contains(sinif)) {
        siniflar.remove(sinif);
        transaction.set(docRef, {'siniflar': siniflar}, SetOptions(merge: true));
      }
    });
  }

  Future<void> aracSinifiGuncelle(String eskiSinif, String yeniSinif) async {
    DocumentReference docRef = _ayarlarRef.doc('arac_tanimlari');
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      List<String> siniflar;
      if (!snapshot.exists || (snapshot.data() as Map<String, dynamic>)['siniflar'] == null) {
        siniflar = List.from(_varsayilanAracSiniflari);
      } else {
        siniflar = List<String>.from((snapshot.data() as Map<String, dynamic>)['siniflar']);
      }

      int index = siniflar.indexOf(eskiSinif);
      if (index != -1) {
        siniflar[index] = yeniSinif;
        transaction.set(docRef, {'siniflar': siniflar}, SetOptions(merge: true));
      }
    });
  }

  // --- KULLANICI İŞLEMLERİ ---
  Stream<List<String>> favorileriGetir(String tel) {
    return _kullanicilarRef.doc(tel).snapshots().map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['favoriKategoriler'] ?? []);
    });
  }

  Future<void> favoriGuncelle(String tel, String kategoriId, bool favoriMi) async {
    if (favoriMi) {
      await _kullanicilarRef.doc(tel).set({
        'favoriKategoriler': FieldValue.arrayUnion([kategoriId])
      }, SetOptions(merge: true));
    } else {
      await _kullanicilarRef.doc(tel).update({
        'favoriKategoriler': FieldValue.arrayRemove([kategoriId])
      });
    }
  }

  // --- ESNAF İŞLEMLERİ ---
  Stream<List<EsnafModeli>> esnaflariGetir() {
    return _esnaflarRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EsnafModeli.fromFirestore(doc)).toList();
    });
  }

  Stream<EsnafModeli> esnafGetir(String id) {
    if (id.trim().isEmpty) return const Stream.empty();
    try {
      return _esnaflarRef.doc(id).snapshots().map((doc) => EsnafModeli.fromFirestore(doc));
    } catch (e) {
      debugPrint("Esnaf getir stream hatası: $e");
      return const Stream.empty();
    }
  }

  Future<EsnafModeli?> esnafGetirDoc(String id) async {
    var doc = await _esnaflarRef.doc(id).get();
    return doc.exists ? EsnafModeli.fromFirestore(doc) : null;
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

      var tumEsnaflar = await _esnaflarRef.get();
      for (var doc in tumEsnaflar.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var araclar = data['araclar'] as List?;
        if (araclar != null) {
          for (var arac in araclar) {
            if (arac is Map && (arac['soforTel'] == telefon || arac['telefon'] == telefon)) {
              return EsnafModeli.fromFirestore(doc);
            }
          }
        }
      }
    } catch (e) { return null; }
    return null;
  }

  Future<void> esnafEkle(EsnafModeli esnaf) async => await _esnaflarRef.add(esnaf.toMap());
  Future<void> esnafGuncelle(String id, Map<String, dynamic> veri) async => await _esnaflarRef.doc(id).update(veri);
  Future<void> esnafSil(String id) async => await _esnaflarRef.doc(id).delete();

  // --- KATEGORİ İŞLEMLERİ ---
  Stream<List<Map<String, dynamic>>> kategorileriGetir() {
    return _kategorilerRef.orderBy('ad').snapshots().map((snap) => 
      snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id, 
          'ad': data['ad'],
          'ikon': data['ikon'],
          'renk': data['renk']
        };
      }).toList());
  }

  Future<void> kategoriEkle(String ad, {int? ikon, int? renk}) async => 
      await _kategorilerRef.add({'ad': ad, 'ikon': ikon, 'renk': renk});

  Future<void> kategoriGuncelle(String id, String yeniAd, {String? eskiAd, int? ikon, int? renk}) async {
    Map<String, dynamic> veri = {'ad': yeniAd};
    if (ikon != null) veri['ikon'] = ikon;
    if (renk != null) veri['renk'] = renk;
    await _kategorilerRef.doc(id).update(veri);

    if (eskiAd != null && eskiAd != yeniAd) {
      final esnaflar = await _esnaflarRef.where('kategori', isEqualTo: eskiAd).get();
      for (var doc in esnaflar.docs) {
        await doc.reference.update({'kategori': yeniAd});
      }
      
      final hizmetler = await _hizmetTanimRef.where('kategori', isEqualTo: eskiAd).get();
      for (var doc in hizmetler.docs) {
        await doc.reference.update({'kategori': yeniAd});
      }
    }
  }

  Future<void> kategoriSil(String id) async => await _kategorilerRef.doc(id).delete();

  // --- HİZMET TANIMLARI ---
  Stream<List<Map<String, dynamic>>> hizmetTanimlariniGetir(String kategori) {
    return _hizmetTanimRef.where('kategori', isEqualTo: kategori).snapshots().map((snap) => 
      snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'isim': data['isim'],
          'sure': data['sure'],
          'kategori': data['kategori']
        };
      }).toList());
  }

  Future<void> hizmetTanimEkle(String kategori, String isim, int sure) async => 
      await _hizmetTanimRef.add({'kategori': kategori, 'isim': isim, 'sure': sure});

  Future<void> hizmetTanimSil(String id) async => await _hizmetTanimRef.doc(id).delete();

  // --- AJANDA İŞLEMLERİ ---
  Future<Map<String, dynamic>?> gunlukAjandaGetir(String esnafId, DateTime tarih, String? kanal) async {
    if (esnafId.isEmpty) return null;
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    
    var doc = await _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<DocumentSnapshot> gunlukAjandaSnapStream(String esnafId, DateTime tarih, String? kanal) {
    if (esnafId.trim().isEmpty) return const Stream.empty();
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    
    try {
      return _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).snapshots();
    } catch (e) {
      debugPrint("Ajanda stream hatası: $e");
      return const Stream.empty();
    }
  }

  Stream<DocumentSnapshot> taksiAjandasiSnapStream(String esnafId, DateTime tarih) {
    if (esnafId.trim().isEmpty) return const Stream.empty();
    String ayKey = DateFormat('yyyy-MM').format(tarih);
    try {
      return _esnaflarRef.doc(esnafId).collection('taksi_ajanda').doc(ayKey).snapshots();
    } catch (e) {
      debugPrint("Taksi ajanda stream hatası: $e");
      return const Stream.empty();
    }
  }

  Future<void> ajandaMuhurle(String esnafId, DateTime tarih, String? kanal, Map<String, dynamic> veri) async {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    await _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).set(veri, SetOptions(merge: true));

    await _esnaflarRef.doc(esnafId).get().then((doc) {
      if (doc.exists) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> aktifler = data['aktifGunler'] ?? [];
        if (!aktifler.contains(docId)) {
          aktifler.add(docId);
          _esnaflarRef.doc(esnafId).update({'aktifGunler': aktifler});
        }
      }
    });
  }

  Future<void> ajandaOlustur({
    required String esnafId,
    required List<DateTime> tarihler,
    required String kanal,
    required String acilis,
    required String kapanis,
    String? ogleBaslangic,
    String? ogleBitis,
    required int slotAraligi,
  }) async {
    if (esnafId.isEmpty) return;
    const int chunkLimit = 400;
    for (var i = 0; i < tarihler.length; i += chunkLimit) {
      final batch = _db.batch();
      final chunk = tarihler.sublist(i, i + chunkLimit > tarihler.length ? tarihler.length : i + chunkLimit);
      List<String> aktifGunIds = [];

      for (var tarih in chunk) {
        String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
        String temizKanal = kanal.trim();
        String docId = temizKanal.isNotEmpty ? "${tarihStr}_$temizKanal" : tarihStr;
        aktifGunIds.add(docId);

        DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);
        batch.set(docRef, {
          'tarih': tarihStr,
          'kanal': temizKanal,
          'acilis': acilis,
          'kapanis': kapanis,
          'ogleBaslangic': ogleBaslangic,
          'ogleBitis': ogleBitis,
          'slotAraligi': slotAraligi,
          'kapaliSlotlar': {},
          'olusturulmaTarihi': FieldValue.serverTimestamp(),
        });
      }

      batch.update(_esnaflarRef.doc(esnafId), {
        'aktifGunler': FieldValue.arrayUnion(aktifGunIds)
      });

      await batch.commit();
    }
  }

  Future<void> ajandaSil(String esnafId, DateTime tarih, String? kanal) async {
    if (esnafId.isEmpty) return;
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;

    await _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).delete();
    await _esnaflarRef.doc(esnafId).update({
      'aktifGunler': FieldValue.arrayRemove([docId])
    });
  }

  Future<void> topluAjandaSil({
    required String esnafId,
    required DateTime baslangic,
    required DateTime bitis,
    String? kanal,
  }) async {
    if (esnafId.isEmpty) return;
    int gunSayisi = bitis.difference(baslangic).inDays;
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    const int chunkLimit = 400;
    
    for (int i = 0; i <= gunSayisi; i += chunkLimit) {
      final batch = _db.batch();
      List<String> silinecekIds = [];
      int max = (i + chunkLimit > gunSayisi + 1) ? gunSayisi + 1 : i + chunkLimit;
      
      for (int j = i; j < max; j++) {
        DateTime gun = baslangic.add(Duration(days: j));
        String tarihStr = DateFormat('yyyy-MM-dd').format(gun);
        String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
        silinecekIds.add(docId);
        batch.delete(_esnaflarRef.doc(esnafId).collection('ajanda').doc(docId));
      }

      batch.update(_esnaflarRef.doc(esnafId), {
        'aktifGunler': FieldValue.arrayRemove(silinecekIds)
      });

      await batch.commit();
    }
  }

  Future<void> slotKapatAc(String esnafId, DateTime tarih, String? kanal, String saat, bool kapat, {String? neden}) async {
    if (esnafId.isEmpty) return;
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);

    await _db.runTransaction((transaction) async {
      var snapshot = await transaction.get(docRef);
      Map<String, dynamic> kapaliSlotlar = {};
      
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('kapaliSlotlar')) {
          kapaliSlotlar = Map<String, dynamic>.from(data['kapaliSlotlar']);
        }
        
        if (kapat) {
          kapaliSlotlar[saat] = neden ?? "Belirtilmedi";
        } else {
          kapaliSlotlar.remove(saat);
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
    if (esnafId.isEmpty) return;
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

  Future<void> tumAjandalariTemizle() async {
    final esnaflar = await _esnaflarRef.get();
    for (var esnafDoc in esnaflar.docs) {
      final ajandaSnap = await esnafDoc.reference.collection('ajanda').get();
      final batch = _db.batch();
      for (var doc in ajandaSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // --- RANDEVU İŞLEMLERİ ---
  Stream<List<RandevuModeli>> randevulariGetir(String esnafId, DateTime tarih, {int pencereGun = 30}) {
    DateTime bas = DateTime(tarih.year, tarih.month, tarih.day).subtract(Duration(days: pencereGun));
    DateTime bit = DateTime(tarih.year, tarih.month, tarih.day).add(const Duration(days: 2));
    
    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .snapshots()
        .map((snap) {
          final hepsi = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          
          return hepsi.where((r) {
            if (!(r.durum == 'Beklemede' || r.durum == 'Onaylandı' || r.durum == 'Onay bekliyor')) return false;
            return r.tarih.isAfter(bas.subtract(const Duration(seconds: 1))) && 
                   r.tarih.isBefore(bit.add(const Duration(seconds: 1)));
          }).toList();
        });
  }

  Stream<List<RandevuModeli>> esnafTumRandevulariGetir(String esnafId) {
    return _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .snapshots()
        .map((snap) {
          var list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
          list.sort((a, b) {
            int d = b.tarih.compareTo(a.tarih);
            if (d != 0) return d;
            return b.saat.compareTo(a.saat);
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
            int d = b.tarih.compareTo(a.tarih);
            if (d != 0) return d;
            return b.saat.compareTo(a.saat);
          });
          return list;
        });
  }

  Future<String?> randevuEkle(RandevuModeli randevu) async {
    debugPrint('📝 Randevu Ekleme Başlatıldı: ${randevu.kullaniciTel} -> ${randevu.esnafAdi}');
    final docRef = await _randevularRef.add(randevu.toMap());
    debugPrint('✅ Randevu Firestore\'a Kaydedildi: ID=${docRef.id}');
    
    String? sonucHata;

    // [YENİ REDESIGN] Müşteri randevu alır almaz bildirim planla
    if (randevu.akilliTakipAktif && randevu.bildirimZamani != null) {
      try {
        final esnaf = await esnafGetirDoc(randevu.esnafId);
        if (esnaf != null && esnaf.akilliTakipModu) {
          final String? uzatmaId = await OneSignalServisi.bildirimPlanla(
            baslik: "Kiralama Süreniz Doluyor",
            icerik: "${randevu.randevuKanali} için kiralama süreniz ${esnaf.akilliTakipSuresi} dakika sonra bitiyor. Uzatmak ister misiniz?",
            zaman: randevu.bildirimZamani!,
            telefon: randevu.kullaniciTel,
            tagKey: 'telefon',
            randevuId: docRef.id,
            ekVeri: {
              'action': 'uzatma_ekrani',
              'tel': randevu.kullaniciTel,
              'randevuId': docRef.id,
            },
          );

          if (uzatmaId != null && uzatmaId != "ALICI_YOK") {
            await docRef.update({
              'uzatmaBildirimId': uzatmaId,
              'uzatmaZamaniTs': randevu.bildirimZamani,
              'uzatmaZamaniStr': DateFormat('yyyy-MM-dd HH:mm:ss').format(randevu.bildirimZamani!),
            });
          } else if (uzatmaId == "ALICI_YOK") {
            sonucHata = "ALICI_YOK";
          }
        }
      } catch (e) {
        debugPrint('❌ Randevu ekleme sırasında bildirim planlama hatası: $e');
      }
    }
    return sonucHata;
  }
  
  Future<bool> randevuCakisiyorMu({
    required String esnafId,
    required DateTime tarih,
    required String saat,
    required int sure,
    String? kanal,
    String? haricRandevuId,
  }) async {
    final parcalar = saat.split(':');
    DateTime reqStart = DateTime(tarih.year, tarih.month, tarih.day, 
        int.parse(parcalar[0]), int.parse(parcalar[1]));
    DateTime reqEnd = reqStart.add(Duration(minutes: sure));

    DateTime queryStart = reqStart.subtract(const Duration(days: 30));
    DateTime queryEnd = reqEnd.add(const Duration(days: 1));

    var query = _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart))
        .where('tarih', isLessThan: Timestamp.fromDate(queryEnd));

    var snap = await query.get();
    
    for (var doc in snap.docs) {
      if (doc.id == haricRandevuId) continue;
      final data = doc.data() as Map<String, dynamic>;
      if (data['durum'] == 'Reddedildi' || data['durum'] == 'İptal Edildi') continue;
      if (kanal != null && kanal.isNotEmpty && data['randevu_kanali'] != kanal) continue;

      DateTime mTarih = (data['tarih'] as Timestamp).toDate();
      String mSaat = data['saat'] ?? "00:00";
      final mParcalar = mSaat.split(':');
      DateTime mStart = DateTime(mTarih.year, mTarih.month, mTarih.day, 
          int.parse(mParcalar[0]), int.parse(mParcalar[1]));
      int mSure = data['sure'] ?? 30;
      DateTime mEnd = mStart.add(Duration(minutes: mSure));

      if (reqStart.isBefore(mEnd) && reqEnd.isAfter(mStart)) return true;
    }
    return false;
  }

  Future<void> randevuSerisiniSil(String seriId) async {
    final snap = await _randevularRef.where('seriId', isEqualTo: seriId).get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> randevuSil(String id) async => await _randevularRef.doc(id).delete();
  
  Future<Map<String, dynamic>> randevuDurumGuncelle(
    String id, 
    String yeniDurum, {
    String? iptalNedeni, 
    String? aliciTel, 
    String? esnafAdi, 
    String? tarihSaat,
    BuildContext? context,
  }) async {
    Map<String, dynamic> sonuc = {'basarili': true, 'alarmKuruldu': false, 'alarmSaati': ''};
    
    Map<String, dynamic> veri = {
      'durum': yeniDurum,
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    };
    if (iptalNedeni != null) veri['iptalNedeni'] = iptalNedeni;
    await _randevularRef.doc(id).update(veri);

    if (yeniDurum == 'Onaylandı') {
      try {
        final rSnap = await _randevularRef.doc(id).get();
        final r = RandevuModeli.fromFirestore(rSnap);
        final esnafSnap = await _esnaflarRef.doc(r.esnafId).get();
        final esnaf = EsnafModeli.fromFirestore(esnafSnap);

        // Akıllı takip modu aktif ise KRİTİK bildirim planla
        if (esnaf.akilliTakipModu) {
          final DateTime baslangicZamani = DateTime(
            r.tarih.year, r.tarih.month, r.tarih.day,
            int.parse(r.saat.split(':')[0]),
            int.parse(r.saat.split(':')[1]),
          );
          final DateTime bitisZamani = baslangicZamani.add(Duration(minutes: r.sure));
          final String bitisSaati = DateFormat('HH:mm').format(bitisZamani);
          final DateTime gecikmeAlarmZamani = bitisZamani.add(const Duration(minutes: 1));

          debugPrint('📋 Onay Sonrası KRİTİK Bildirim Planlanıyor: randevuId=$id, zaman=$gecikmeAlarmZamani');

          // [PROFESYONEL RETRY]: Hızlı girişlerde OneSignal aboneliğinin tamamlanması için 3 kez deneme yapıyoruz.
          String? newGecikmeId;
          int denemeSayisi = 0;
          
          while (denemeSayisi < 3) {
            newGecikmeId = await OneSignalServisi.bildirimPlanla(
              baslik: "🔴 KRİTİK GECİKME ALARMI",
              icerik: "${r.randevuKanali} plakalı aracın iade saati ($bitisSaati) geçti! Henüz teslim almadınız.",
              zaman: gecikmeAlarmZamani,
              telefon: esnaf.telefon,
              tagKey: 'telefon',
              randevuId: id,
              ekVeri: {
                'action': 'kritik_gecikme',
                'tel': esnaf.telefon,
                'randevuId': id,
              },
            );

            if (newGecikmeId != null && newGecikmeId != "ALICI_YOK") {
              // Başarılı kurulum
              break;
            }

            if (newGecikmeId == "ALICI_YOK") {
              denemeSayisi++;
              debugPrint("🔄 OneSignal aboneliği henüz hazır değil, deneme $denemeSayisi/3 bekleniyor...");
              await Future.delayed(const Duration(seconds: 1));
            } else {
              // Diğer hatalarda (ağ hatası vb.) döngüden çık
              break;
            }
          }

          if (newGecikmeId != null && newGecikmeId != "ALICI_YOK") {
            await _randevularRef.doc(id).update({
              'gecikmeBildirimId': newGecikmeId,
              'gecikmeZamaniTs': gecikmeAlarmZamani,
              'gecikmeZamaniStr': DateFormat('yyyy-MM-dd HH:mm:ss').format(gecikmeAlarmZamani),
            });
            debugPrint('✅ Esnaf Kritik Bildirimi Planlandı (Onay Anı): $newGecikmeId');
            
            sonuc['alarmKuruldu'] = true;
            sonuc['alarmSaati'] = bitisSaati;
          } else if (newGecikmeId == "ALICI_YOK") {
             sonuc['basarili'] = false;
             sonuc['hata'] = "ALICI_YOK";
          }
        }
      } catch (e) {
        debugPrint("❌ Onay sonrası OneSignal hatası: $e");
        sonuc['basarili'] = false;
      }
    } else if (yeniDurum == 'Reddedildi' || yeniDurum == 'İptal Edildi' || yeniDurum == 'Tamamlandı') {
      // [GÜNCELLEME] Bildirimleri tamamen silmek yerine İPTAL EDİLDİ olarak arşivleyelim
      try {
        final rSnap = await _randevularRef.doc(id).get();
        if (rSnap.exists) {
          final r = RandevuModeli.fromFirestore(rSnap);
          Map<String, dynamic> updateData = {};
          
          if (r.uzatmaBildirimId != null && r.uzatmaBildirimId!.isNotEmpty && !r.uzatmaBildirimId!.contains("İPTAL")) {
            await OneSignalServisi.bildirimIptalEt(r.uzatmaBildirimId!);
            updateData['uzatmaBildirimId'] = "${r.uzatmaBildirimId} [İPTAL EDİLDİ]";
            debugPrint('🗑️ Müşteri bildirimi iptal edildi: ${r.uzatmaBildirimId}');
          }
          
          if (r.gecikmeBildirimId != null && r.gecikmeBildirimId!.isNotEmpty && !r.gecikmeBildirimId!.contains("İPTAL")) {
            await OneSignalServisi.bildirimIptalEt(r.gecikmeBildirimId!);
            updateData['gecikmeBildirimId'] = "${r.gecikmeBildirimId} [İPTAL EDİLDİ]";
            debugPrint('🗑️ Esnaf bildirimi iptal edildi: ${r.gecikmeBildirimId}');
          }

          if (updateData.isNotEmpty) {
            await _randevularRef.doc(id).update(updateData);
          }
        }
      } catch (e) {
        debugPrint('❌ İptal sırasında bildirim işaretleme hatası: $e');
      }
    }
    return sonuc;
  }

  Future<void> randevuIptalEt(String id, String neden, {String? aliciTel, String? esnafAdi, String? tarihSaat}) async {
    await randevuDurumGuncelle(id, 'Reddedildi', iptalNedeni: neden, aliciTel: aliciTel, esnafAdi: esnafAdi, tarihSaat: tarihSaat);
  }

  Future<void> iptalNedeniEkle(String tip, String neden) async {
    await _db.collection('iptal_nedenleri').add({
      'tip': tip,
      'neden': neden,
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  Future<void> iptalNedeniSil(String tip, String neden) async {
    final query = await _db.collection('iptal_nedenleri')
        .where('tip', isEqualTo: tip)
        .where('neden', isEqualTo: neden)
        .limit(1)
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> iptalNedeniGuncelle(String tip, String eskiNeden, String yeniNeden) async {
    final query = await _db.collection('iptal_nedenleri')
        .where('tip', isEqualTo: tip)
        .where('neden', isEqualTo: eskiNeden)
        .limit(1)
        .get();
    for (var doc in query.docs) {
      await doc.reference.update({'neden': yeniNeden});
    }
  }

  Stream<List<String>> iptalNedenleriniGetir(String tip) {
    return _db.collection('iptal_nedenleri')
        .where('tip', isEqualTo: tip)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) {
            return tip == 'esnaf' 
              ? ["Yoğunluk nedeniyle", "Hizmet veremiyoruz", "Personel eksikliği", "Sistem hatası"]
              : ["Planım değişti", "Yanlış saat seçimi", "Acil işim çıktı", "Fiyat yüksek geldi"];
          }
          return snap.docs.map((doc) => (doc.data())['neden'] as String).toList();
        });
  }
  
  Future<bool> onayliRandevuVarMi(String esnafId, DateTime tarih, String? kanal) async {
    DateTime bas = DateTime(tarih.year, tarih.month, tarih.day);
    DateTime bit = bas.add(const Duration(days: 1));
    var snap = await _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(bas))
        .where('tarih', isLessThan: Timestamp.fromDate(bit))
        .get();
    
    return snap.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final bool durumOnayli = data['durum'] == 'Onaylandı';
      if (kanal != null && kanal.isNotEmpty) return durumOnayli && data['randevu_kanali'] == kanal;
      return durumOnayli;
    });
  }

  Stream<List<Map<String, dynamic>>> yorumlariGetir(String esnafId) {
    return _yorumlarRef
        .where('esnafId', isEqualTo: esnafId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>
        }).toList());
  }

  Future<void> yorumEkle(Map<String, dynamic> yorum) async {
    await _yorumlarRef.add(yorum);
    var esnafDoc = await _esnaflarRef.doc(yorum['esnafId']).get();
    if (esnafDoc.exists) {
      var data = esnafDoc.data() as Map<String, dynamic>;
      int eskiSayi = data['yorumSayisi'] ?? 0;
      double eskiPuan = (data['puan'] ?? 0).toDouble();
      int yeniSayi = eskiSayi + 1;
      double yeniPuan = ((eskiPuan * eskiSayi) + yorum['puan']) / yeniSayi;
      await _esnaflarRef.doc(yorum['esnafId']).update({'yorumSayisi': yeniSayi, 'puan': yeniPuan});
    }
  }

  Future<void> taksiCagir(Map<String, dynamic> talep) async {
    await _db.collection('taksi_talepleri').add({
      ...talep,
      'durum': 'Bekiyor',
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<DocumentSnapshot>> aktifTaksiTalepleriniDinle(String esnafId) {
    return _db.collection('taksi_talepleri')
        .where('esnafId', isEqualTo: esnafId)
        .where('durum', isEqualTo: 'Beklemede')
        .snapshots()
        .map((snap) => snap.docs);
  }

  Future<void> taksiTalebiGuncelle(String talepId, Map<String, dynamic> veri) async {
    await _db.collection('taksi_talepleri').doc(talepId).update(veri);
  }

  Future<int> randevuMaksimumUzatmaDk(RandevuModeli r) async {
    try {
      final parcalar = r.saat.split(':');
      DateTime rBaslangic = DateTime(r.tarih.year, r.tarih.month, r.tarih.day, int.parse(parcalar[0]), int.parse(parcalar[1]));
      DateTime rBitis = rBaslangic.add(Duration(minutes: r.sure));
      var snap = await _randevularRef.where('esnafId', isEqualTo: r.esnafId).where('randevu_kanali', isEqualTo: r.randevuKanali).get();
      DateTime? enYakinBaslangic;
      for (var doc in snap.docs) {
        if (doc.id == r.id) continue;
        final data = doc.data() as Map<String, dynamic>;
        if (data['durum'] == 'Reddedildi' || data['durum'] == 'İptal Edildi') continue;
        DateTime mTarih = (data['tarih'] as Timestamp).toDate();
        final mParcalar = (data['saat'] as String).split(':');
        DateTime mStart = DateTime(mTarih.year, mTarih.month, mTarih.day, int.parse(mParcalar[0]), int.parse(mParcalar[1]));
        if (mStart.isAfter(rBitis.subtract(const Duration(minutes: 1)))) {
          if (enYakinBaslangic == null || mStart.isBefore(enYakinBaslangic)) enYakinBaslangic = mStart;
        }
      }
      if (enYakinBaslangic == null) return 1440;
      return enYakinBaslangic.difference(rBitis).inMinutes;
    } catch (e) { return 0; }
  }

  Future<bool> randevuUzatmaMusaitMi(RandevuModeli r, int ekDakika) async {
    int maks = await randevuMaksimumUzatmaDk(r);
    return maks >= ekDakika;
  }

  Future<void> randevuUzat(String randevuId, int ekDakika) async {
    final doc = await _randevularRef.doc(randevuId).get();
    if (!doc.exists) return;
    final r = RandevuModeli.fromFirestore(doc);
    final int yeniSure = r.sure + ekDakika;
    final int yeniUzatma = r.uzatmaSuresi + ekDakika;
    await _randevularRef.doc(randevuId).update({'sure': yeniSure, 'uzatmaSuresi': yeniUzatma, 'guncellemeTarihi': FieldValue.serverTimestamp()});
  }

  Future<void> randevuyuMuadilAracaKaydir(String randevuId, String yeniPlaka) async {
    await _randevularRef.doc(randevuId).update({'randevu_kanali': yeniPlaka, 'guncellemeTarihi': FieldValue.serverTimestamp()});
  }
}
