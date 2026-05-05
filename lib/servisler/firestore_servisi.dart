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
  CollectionReference get _yorumlarRef => _db.collection('yorumlar');

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
      // 1. Önce doğrudan esnaf telefonu olarak ara
      var sonuc = await _esnaflarRef.where('telefon', isEqualTo: telefon).limit(1).get();
      if (sonuc.docs.isNotEmpty) return EsnafModeli.fromFirestore(sonuc.docs.first);

      // 2. Esnaf bulunamadıysa, araçlardaki şoför telefonları arasında ara
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

    // Eğer isim değiştiyse bu kategorideki esnafların kategori adını da güncelle
    if (eskiAd != null && eskiAd != yeniAd) {
      final esnaflar = await _esnaflarRef.where('kategori', isEqualTo: eskiAd).get();
      for (var doc in esnaflar.docs) {
        await doc.reference.update({'kategori': yeniAd});
      }
      
      // Ayrıca hizmet tanımlarını da güncelle
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
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    
    var doc = await _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<DocumentSnapshot> gunlukAjandaSnapStream(String esnafId, DateTime tarih, String? kanal) {
    String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
    String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
    String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
    
    return _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId).snapshots();
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
    final batch = _db.batch();
    List<String> aktifGunIds = [];

    for (var tarih in tarihler) {
      String tarihStr = DateFormat('yyyy-MM-dd').format(tarih);
      String docId = kanal.isNotEmpty ? "${tarihStr}_$kanal" : tarihStr;
      aktifGunIds.add(docId);

      DocumentReference docRef = _esnaflarRef.doc(esnafId).collection('ajanda').doc(docId);
      batch.set(docRef, {
        'tarih': tarihStr,
        'kanal': kanal,
        'acilis': acilis,
        'kapanis': kapanis,
        'ogleBaslangic': ogleBaslangic,
        'ogleBitis': ogleBitis,
        'slotAraligi': slotAraligi,
        'kapaliSlotlar': {},
        'olusturulmaTarihi': FieldValue.serverTimestamp(),
      });
    }

    // Esnaf belgesindeki aktif günleri güncelle
    batch.update(_esnaflarRef.doc(esnafId), {
      'aktifGunler': FieldValue.arrayUnion(aktifGunIds)
    });

    await batch.commit();
  }

  Future<void> ajandaSil(String esnafId, DateTime tarih, String? kanal) async {
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
    int gunSayisi = bitis.difference(baslangic).inDays;
    final batch = _db.batch();
    List<String> silinecekIds = [];

    for (int i = 0; i <= gunSayisi; i++) {
      DateTime gun = baslangic.add(Duration(days: i));
      String tarihStr = DateFormat('yyyy-MM-dd').format(gun);
      String k = (kanal != null && kanal.trim().isNotEmpty) ? kanal.trim() : "";
      String docId = k.isNotEmpty ? "${tarihStr}_$k" : tarihStr;
      
      silinecekIds.add(docId);
      batch.delete(_esnaflarRef.doc(esnafId).collection('ajanda').doc(docId));
    }

    batch.update(_esnaflarRef.doc(esnafId), {
      'aktifGunler': FieldValue.arrayRemove(silinecekIds)
    });

    await batch.commit();
  }

  Future<void> slotKapatAc(String esnafId, DateTime tarih, String? kanal, String saat, bool kapat, {String? neden}) async {
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
            .where((r) => r.durum == 'Beklemede' || r.durum == 'Onaylandı' || r.durum == 'Onay bekliyor')
            .toList());
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

  Future<void> randevuEkle(RandevuModeli randevu) async => await _randevularRef.add(randevu.toMap());
  
  Future<bool> randevuCakisiyorMu({
    required String esnafId,
    required DateTime tarih,
    required String saat,
    required int sure,
    String? kanal,
    String? haricRandevuId,
  }) async {
    DateTime bas = DateTime(tarih.year, tarih.month, tarih.day);
    DateTime bit = bas.add(const Duration(days: 1));

    var query = _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(bas))
        .where('tarih', isLessThan: Timestamp.fromDate(bit));

    var snap = await query.get();
    
    int yeniBas = _saatiDakikayaCevir(saat);
    int yeniBit = yeniBas + sure;

    for (var doc in snap.docs) {
      if (doc.id == haricRandevuId) continue;
      
      final data = doc.data() as Map<String, dynamic>;
      if (data['durum'] == 'Reddedildi' || data['durum'] == 'İptal Edildi') continue;
      
      // Kanal kontrolü (Eğer kanal belirtilmişse sadece o kanaldaki çakışmalara bak)
      if (kanal != null && kanal.isNotEmpty && data['randevuKanali'] != kanal) continue;

      int mevcutBas = _saatiDakikayaCevir(data['saat']);
      int mevcutSure = data['sure'] ?? 30;
      int mevcutBit = mevcutBas + mevcutSure;

      // Çakışma mantığı: (yeniBas < mevcutBit) && (yeniBit > mevcutBas)
      if (yeniBas < mevcutBit && yeniBit > mevcutBas) {
        return true;
      }
    }
    return false;
  }

  int _saatiDakikayaCevir(String saat) {
    try {
      final parcalar = saat.split(':');
      return int.parse(parcalar[0]) * 60 + int.parse(parcalar[1]);
    } catch (e) {
      return 0;
    }
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
  
  Future<void> randevuDurumGuncelle(
    String id, 
    String yeniDurum, {
    String? iptalNedeni, 
    String? aliciTel, 
    String? esnafAdi, 
    String? tarihSaat
  }) async {
    Map<String, dynamic> veri = {
      'durum': yeniDurum,
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    };
    if (iptalNedeni != null) veri['iptalNedeni'] = iptalNedeni;
    await _randevularRef.doc(id).update(veri);

    // Bildirim gönder
    if (aliciTel != null && esnafAdi != null && tarihSaat != null) {
      String baslik = "";
      String icerik = "";

      if (yeniDurum == 'Onaylandı') {
        baslik = "Randevu Onaylandı ✅";
        icerik = "Sayın müşterimiz, $esnafAdi bünyesindeki $tarihSaat tarihli randevunuz onaylanmıştır. Sizi bekliyoruz.";
      } else if (yeniDurum == 'Reddedildi') {
        baslik = "Randevu Durumu Hakkında ℹ️";
        icerik = "$esnafAdi işletmesindeki $tarihSaat randevunuz maalesef onaylanamadı.${iptalNedeni != null ? ' Not: $iptalNedeni' : ''}";
      } else if (yeniDurum == 'İptal Edildi') {
        baslik = "Randevu İptal Bilgisi ⚠️";
        icerik = "$esnafAdi işletmesindeki $tarihSaat tarihli randevunuz iptal edilmiştir.";
      }

      if (baslik.isNotEmpty) {
        await FirebaseFirestore.instance.collection('bildirimler').add({
          'aliciTel': aliciTel,
          'baslik': baslik,
          'icerik': icerik,
          'okundu': false,
          'tarih': FieldValue.serverTimestamp(),
        });
      }
    }
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
    
    var query = _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(bas))
        .where('tarih', isLessThan: Timestamp.fromDate(bit));

    var snap = await query.get();
    
    return snap.docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final bool durumOnayli = data['durum'] == 'Onaylandı';
      
      if (kanal != null && kanal.isNotEmpty) {
        return durumOnayli && data['randevu_kanali'] == kanal;
      }
      return durumOnayli;
    });
  }

  // --- YORUM İŞLEMLERİ ---
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
    
    // Esnaf puanını ve yorum sayısını güncelle
    var esnafDoc = await _esnaflarRef.doc(yorum['esnafId']).get();
    if (esnafDoc.exists) {
      var data = esnafDoc.data() as Map<String, dynamic>;
      int eskiSayi = data['yorumSayisi'] ?? 0;
      double eskiPuan = (data['puan'] ?? 0).toDouble();
      
      int yeniSayi = eskiSayi + 1;
      double yeniPuan = ((eskiPuan * eskiSayi) + yorum['puan']) / yeniSayi;
      
      await _esnaflarRef.doc(yorum['esnafId']).update({
        'yorumSayisi': yeniSayi,
        'puan': yeniPuan
      });
    }
  }

  // --- TAKSİ ÇAĞRI İŞLEMLERİ ---
  Future<void> taksiCagir(Map<String, dynamic> talep) async {
    await _db.collection('taksi_talepleri').add({
      ...talep,
      'durum': 'Bekliyor',
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<DocumentSnapshot>> aktifTaksiTalepleriniDinle(String esnafId) {
    return _db.collection('taksi_talepleri')
        .where('esnafId', isEqualTo: esnafId)
        .where('durum', isEqualTo: 'Bekliyor')
        .snapshots()
        .map((snap) => snap.docs);
  }

  Future<void> taksiTalebiGuncelle(String talepId, Map<String, dynamic> veri) async {
    await _db.collection('taksi_talepleri').doc(talepId).update(veri);
  }
}
