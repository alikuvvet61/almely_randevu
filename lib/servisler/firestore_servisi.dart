import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/mac_ilani.dart';
import '../modeller/randevu_modeli.dart';
import '../modeller/bekleme_listesi_modeli.dart';
import '../modeller/musteri_ceza_kaydi.dart';
import '../yardimcilar/calisan_gorevleri.dart';
import '../yardimcilar/hizmet_paketi.dart';
import '../yardimcilar/telefon_girdisi.dart';
import 'taksi/taksi_guven.dart';
import 'onesignal_servisi.dart';
import 'bildirim_servisi.dart';

class FirestoreServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Koleksiyon Referansları
  CollectionReference get _esnaflarRef => _db.collection('esnaflar');
  CollectionReference get _randevularRef => _db.collection('randevular');
  CollectionReference get _kategorilerRef => _db.collection('kategoriler');
  CollectionReference get _hizmetTanimRef => _db.collection('hizmet_tanimlari');
  CollectionReference get _yorumlarRef => _db.collection('yorumlar');
  CollectionReference get _beklemeListesiRef => _db.collection('bekleme_listesi');
  CollectionReference get _musteriCezaRef => _db.collection('musteri_ceza');
  final Set<String> _paketYaziliyor = {};
  CollectionReference get _musteriPaketRef => _db.collection('musteri_paketleri');
  CollectionReference get _kullanicilarRef => _db.collection('kullanicilar');
  CollectionReference get _ayarlarRef => _db.collection('ayarlar');
  CollectionReference get _esnafBasvuruRef => _db.collection('esnaf_basvurulari');
  CollectionReference get _calisanBasvuruRef => _db.collection('calisan_basvurulari');
  CollectionReference get _macIlanRef => _db.collection('mac_ilanlari');

  String musteriTelefonAnahtari(String telefon) {
    var t = telefon.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.startsWith('90') && t.length > 10) t = t.substring(t.length - 10);
    if (t.startsWith('0')) t = t.substring(1);
    return t;
  }

  /// 505… ile 0505… aynı numaradır. İkisi de bu kümede durur.
  Set<String> telefonYazimlari(String telefon) {
    final rakam = TelefonGirdisi.rakamlar(telefon);
    final anahtar = musteriTelefonAnahtari(telefon);
    return {
      if (anahtar.isNotEmpty) anahtar,
      if (anahtar.length == 10) '0$anahtar',
      telefon.trim(),
      rakam,
    };
  }

  CollectionReference<Map<String, dynamic>> _musteriNotRef(String esnafId) =>
      _esnaflarRef.doc(esnafId).collection('musteri_notlari');

  Stream<Map<String, String>> musteriNotlariDinle(String esnafId) {
    return _musteriNotRef(esnafId).snapshots().map((snap) {
      final map = <String, String>{};
      for (final d in snap.docs) {
        final not = (d.data()['not'] as String?)?.trim() ?? '';
        if (not.isNotEmpty) map[d.id] = not;
      }
      return map;
    });
  }

  Future<void> musteriNotuKaydet(String esnafId, String telefon, String not) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return;
    final ref = _musteriNotRef(esnafId).doc(id);
    final temiz = not.trim();
    if (temiz.isEmpty) {
      await ref.delete();
      return;
    }
    await ref.set({
      'not': temiz,
      'telefon': id,
      'guncelleme': FieldValue.serverTimestamp(),
    });
  }

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

  // --- RANDEVU GÖRSEL YÖNETİMİ ---
  /// Randevuya yeni bir fotoğraf veya video URL'si ekler
  Future<void> randevuGorselEkle(String randevuId, String url, bool isTeslimat) async {
    final String alan = isTeslimat ? 'teslimatGorselleri' : 'iadeGorselleri';
    await _randevularRef.doc(randevuId).update({
      alan: FieldValue.arrayUnion([url]),
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    });
  }

  /// Randevudan bir görseli siler
  Future<void> randevuGorselSil(String randevuId, String url, bool isTeslimat) async {
    final String alan = isTeslimat ? 'teslimatGorselleri' : 'iadeGorselleri';
    await _randevularRef.doc(randevuId).update({
      alan: FieldValue.arrayRemove([url]),
      'guncellemeTarihi': FieldValue.serverTimestamp(),
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

  Stream<Map<String, dynamic>?> kullaniciGetir(String tel) {
    return _kullanicilarRef.doc(tel).snapshots().map((doc) {
      if (!doc.exists) return null;
      try {
        return Map<String, dynamic>.from(doc.data() as Map);
      } catch (e) {
        return doc.data() as Map<String, dynamic>?;
      }
    });
  }

  Future<Map<String, dynamic>?> kullaniciKaydiBul(String telefon) async {
    Map<String, dynamic>? birlesik;
    for (final id in telefonYazimlari(telefon)) {
      if (id.isEmpty) continue;
      final doc = await _kullanicilarRef.doc(id).get();
      if (!doc.exists || doc.data() == null) continue;
      final veri = Map<String, dynamic>.from(doc.data() as Map);
      if (birlesik == null) {
        birlesik = veri;
        continue;
      }
      for (final e in veri.entries) {
        final eski = birlesik[e.key];
        if (_profilAlaniBos(eski) && !_profilAlaniBos(e.value)) {
          birlesik[e.key] = e.value;
        }
      }
    }
    return birlesik;
  }

  bool _profilAlaniBos(dynamic deger) {
    if (deger == null) return true;
    if (deger is String) return deger.trim().isEmpty;
    if (deger is List) return deger.isEmpty;
    if (deger is Map) return deger.isEmpty;
    return false;
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
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return null;
    try {
      bool ayni(String? kayitli) => musteriTelefonAnahtari(kayitli ?? '') == anahtar;

      var sonuc = await _esnaflarRef.where('telefon', isEqualTo: telefon.trim()).limit(1).get();
      if (sonuc.docs.isEmpty) {
        sonuc = await _esnaflarRef.where('telefon', isEqualTo: TelefonGirdisi.rakamlar(telefon)).limit(1).get();
      }
      if (sonuc.docs.isNotEmpty) return EsnafModeli.fromFirestore(sonuc.docs.first);

      var tumEsnaflar = await _esnaflarRef.get();
      for (var doc in tumEsnaflar.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (ayni('${data['telefon'] ?? ''}')) return EsnafModeli.fromFirestore(doc);
        var araclar = data['araclar'] as List?;
        if (araclar != null) {
          for (var arac in araclar) {
            if (arac is Map && (ayni('${arac['soforTel'] ?? ''}') || ayni('${arac['telefon'] ?? ''}'))) {
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

  Future<Map<String, dynamic>?> esnafBasvurusuGetir(String telefon) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return null;
    final doc = await _esnafBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return {'id': doc.id, ...Map<String, dynamic>.from(doc.data() as Map)};
  }

  Future<Map<String, dynamic>?> calisanBasvurusuGetir(String telefon) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return null;
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return {'id': doc.id, ...Map<String, dynamic>.from(doc.data() as Map)};
  }

  Stream<List<Map<String, dynamic>>> calisanBasvurulariDinle(String esnafId) {
    return _calisanBasvuruAkisi(esnafId, sadeceBekleyen: true);
  }

  Stream<List<Map<String, dynamic>>> calisanBasvurulariTumunuDinle(String esnafId) {
    return _calisanBasvuruAkisi(esnafId, sadeceBekleyen: false);
  }

  /// Bu durağın kabul ettiği taksi şoförleri. Telefon anahtarı bir kez durur.
  List<Map<String, dynamic>> durakKabulSoforleri(List<Map<String, dynamic>> basvurular) {
    final gorulen = <String>{};
    final liste = <Map<String, dynamic>>[];
    for (final b in basvurular) {
      if (b['durum']?.toString() != 'Kabul') continue;
      if (!CalisanGorevleri.plakaGerekli((b['gorev'] ?? '').toString())) continue;
      final plaka = (b['plaka'] ?? '').toString().trim();
      if (plaka.isEmpty) continue;
      final hamTel = (b['telefon'] ?? '').toString();
      final anahtar = musteriTelefonAnahtari(hamTel);
      if (anahtar.isEmpty || !gorulen.add(anahtar)) continue;
      liste.add({
        'tel': hamTel,
        'anahtar': anahtar,
        'adSoyad': (b['adSoyad'] ?? '').toString(),
        'plaka': plaka,
      });
    }
    liste.sort((a, b) => (a['adSoyad'] ?? '').toString().compareTo((b['adSoyad'] ?? '').toString()));
    return liste;
  }

  Stream<List<Map<String, dynamic>>> _calisanBasvuruAkisi(String esnafId, {required bool sadeceBekleyen}) {
    return _calisanBasvuruRef.where('esnafId', isEqualTo: esnafId).snapshots().map((snap) {
      final liste = snap.docs
          .map((d) => {'id': d.id, ...Map<String, dynamic>.from(d.data() as Map)})
          .where((d) {
            if (!sadeceBekleyen) return true;
            final durum = d['durum']?.toString();
            return durum == 'Bekliyor' || durum == 'İptal bekliyor';
          })
          .toList();
      liste.sort((a, b) => (a['adSoyad'] ?? '').toString().compareTo((b['adSoyad'] ?? '').toString()));
      return liste;
    });
  }

  Future<String?> calisanBasvurusuGonder({
    required String telefon,
    required String adSoyad,
    required String kategori,
    required String gorev,
    required String esnafId,
    required String isletmeAdi,
    String plaka = '',
    Map<String, String> belgeler = const {},
  }) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return 'Telefon geçersiz.';
    if (adSoyad.trim().isEmpty) return 'Ad soyad yazın.';
    if (!CalisanGorevleri.gorevler(kategori).contains(gorev)) return 'Görevinizi seçin.';
    final plakaYazi = plaka.trim().toUpperCase();
    if (CalisanGorevleri.plakaGerekli(gorev) && plakaYazi.isEmpty) return 'Plaka yazın.';
    final taksiBasvurusu = CalisanGorevleri.plakaGerekli(gorev);
    if (esnafId.trim().isEmpty || isletmeAdi.trim().isEmpty) return 'İşletme seçin.';
    final esnaf = await esnafGetirDoc(esnafId);
    if (esnaf == null || esnaf.kategori != kategori) return 'İşletme bu kategoride değil.';
    final bagli = await telefonIleEsnafGetir(telefon);
    final kendiDuragi = bagli != null &&
        bagli.id == esnaf.id &&
        musteriTelefonAnahtari(bagli.telefon) == id;
    if (bagli != null && !kendiDuragi) return 'Bu telefon zaten bir işletmeye bağlı.';
    if (taksiBasvurusu && !kendiDuragi) {
      for (final tur in taksiZorunluBelgeler) {
        if ((belgeler[tur] ?? '').trim().isEmpty) {
          return 'Ehliyet, ruhsat, sigorta ve taksimetre fotoğrafı gerekli.';
        }
      }
    }
    final mevcut = await _calisanBasvuruRef.doc(id).get();
    final veri = mevcut.data();
    final durum = veri is Map ? veri['durum']?.toString() : null;
    if (durum == 'Bekliyor') return 'Başvurunuz inceleniyor.';
    if (durum == 'Kabul') return 'Başvurunuz kabul edilmiş.';
    if (durum == 'İptal bekliyor') return 'İptal onayınız bekleniyor.';
    await _calisanBasvuruRef.doc(id).set({
      'telefon': TelefonGirdisi.rakamlar(telefon),
      'adSoyad': adSoyad.trim(),
      'kategori': kategori.trim(),
      'gorev': gorev.trim(),
      'esnafId': esnafId.trim(),
      'isletmeAdi': isletmeAdi.trim(),
      'plaka': plakaYazi,
      'durum': 'Bekliyor',
      if (taksiBasvurusu && !kendiDuragi) 'belgeler': {
        for (final tur in taksiZorunluBelgeler) tur: belgeler[tur]!.trim(),
      },
      'guncelleme': FieldValue.serverTimestamp(),
      if (!mevcut.exists) 'olusturma': FieldValue.serverTimestamp(),
    });
    final yoneticiTel = esnaf.telefon.trim();
    if (kendiDuragi) {
      final hata = await calisanBasvurusuKabul(id);
      if (hata != null) {
        if (mevcut.exists && durum != null) {
          await _calisanBasvuruRef.doc(id).update({'durum': durum});
        } else {
          await _calisanBasvuruRef.doc(id).delete();
        }
        return hata;
      }
      return null;
    }
    if (yoneticiTel.isNotEmpty && musteriTelefonAnahtari(yoneticiTel) != id) {
      final plakaSatir = plakaYazi.isEmpty ? '' : ' Plaka: $plakaYazi.';
      await BildirimServisi.bildirimGonder(
        baslik: 'Yeni çalışan başvurusu',
        icerik: '${adSoyad.trim()} $gorev olarak başvurdu.$plakaSatir',
        kullaniciTel: yoneticiTel,
      );
    }
    return null;
  }

  Future<String?> calisanBasvurusuKabul(String id) async {
    final ref = _calisanBasvuruRef.doc(id);
    String? plakaYaz;
    String? telYaz;
    try {
      await _db.runTransaction((tx) async {
        final bSnap = await tx.get(ref);
        if (!bSnap.exists || bSnap.data() == null) throw 'Başvuru bulunamadı.';
        final d = Map<String, dynamic>.from(bSnap.data() as Map);
        if (d['durum']?.toString() != 'Bekliyor') throw 'Bu başvuru zaten işlenmiş.';
        final esnafId = (d['esnafId'] ?? '').toString();
        final eRef = _esnaflarRef.doc(esnafId);
        final eSnap = await tx.get(eRef);
        if (!eSnap.exists || eSnap.data() == null) throw 'İşletme bulunamadı.';
        final e = Map<String, dynamic>.from(eSnap.data() as Map);
        final tel = (d['telefon'] ?? '').toString();
        final ad = (d['adSoyad'] ?? '').toString();
        final gorev = (d['gorev'] ?? '').toString();
        final plaka = (d['plaka'] ?? '').toString().trim().toUpperCase();
        final calisanlar = List<Map<String, dynamic>>.from(e['calisanlar'] ?? []);
        final zatenCalisan = calisanlar.any((c) => musteriTelefonAnahtari('${c['telefon'] ?? ''}') == musteriTelefonAnahtari(tel));
        if (!zatenCalisan) {
          calisanlar.add({'telefon': tel, 'adSoyad': ad, 'gorev': gorev, 'plaka': plaka});
        }
        final guncel = <String, dynamic>{'calisanlar': calisanlar};
        if (CalisanGorevleri.plakaGerekli(gorev)) {
          final araclar = List<Map<String, dynamic>>.from(e['araclar'] ?? []);
          final ayniPlaka = araclar.any((a) => (a['plaka'] ?? '').toString().trim().toUpperCase() == plaka &&
              musteriTelefonAnahtari('${a['soforTel'] ?? ''}') != musteriTelefonAnahtari(tel));
          if (ayniPlaka) throw 'Bu plaka işletmede başka bir araçta kayıtlı.';
          final ayniTel = araclar.any((a) => musteriTelefonAnahtari('${a['soforTel'] ?? ''}') == musteriTelefonAnahtari(tel));
          if (!ayniTel) {
            araclar.add({
              'plaka': plaka,
              'soforAd': ad,
              'soforTel': tel,
              'nobetSirasi': null,
              'durum': 'Aktif',
              'durakta': false,
            });
          }
          guncel['araclar'] = araclar;
          plakaYaz = plaka;
          telYaz = tel;
        }
        tx.update(eRef, guncel);
        tx.update(ref, {'durum': 'Kabul', 'guncelleme': FieldValue.serverTimestamp()});
      });
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    if (telYaz != null && plakaYaz != null && plakaYaz!.isNotEmpty) {
      await kullaniciProfiliniGuncelle(telYaz!, {'plaka': plakaYaz});
    }
    return null;
  }

  Future<String?> calisanBasvurusuReddet(String id) async {
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'Bekliyor') return 'Bu başvuru zaten işlenmiş.';
    await doc.reference.update({'durum': 'Reddedildi', 'guncelleme': FieldValue.serverTimestamp()});
    return null;
  }

  Future<String?> calisanBasvurusuSil(String telefon) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return 'Telefon geçersiz.';
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'Bekliyor') return 'Yalnızca bekleyen başvuru silinir.';
    await doc.reference.update({'durum': 'İptal', 'guncelleme': FieldValue.serverTimestamp()});
    return null;
  }

  Future<String?> calisanIptalIste(String telefon) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return 'Telefon geçersiz.';
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'Kabul') return 'Yalnızca onaylı çalışma için iptal istenir.';
    await doc.reference.update({'durum': 'İptal bekliyor', 'guncelleme': FieldValue.serverTimestamp()});
    final esnaf = await esnafGetirDoc((d['esnafId'] ?? '').toString());
    final yoneticiTel = esnaf?.telefon.trim() ?? '';
    if (yoneticiTel.isNotEmpty && musteriTelefonAnahtari(yoneticiTel) != id) {
      await BildirimServisi.bildirimGonder(
        baslik: 'Çalışan iptal istiyor',
        icerik: '${(d['adSoyad'] ?? '').toString().trim()} çalışmayı bırakmak istiyor. İptali siz onaylarsınız.',
        kullaniciTel: yoneticiTel,
      );
    }
    return null;
  }

  Future<String?> calisanIptalGeriAl(String telefon) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return 'Telefon geçersiz.';
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'İptal bekliyor') return 'Geri alınacak iptal talebi yok.';
    await doc.reference.update({'durum': 'Kabul', 'guncelleme': FieldValue.serverTimestamp()});
    return null;
  }

  Future<String?> calisanIptalOnayla(String id) async {
    final ref = _calisanBasvuruRef.doc(id);
    String tel = '';
    try {
      await _db.runTransaction((tx) async {
        final bSnap = await tx.get(ref);
        if (!bSnap.exists || bSnap.data() == null) throw 'Başvuru bulunamadı.';
        final d = Map<String, dynamic>.from(bSnap.data() as Map);
        if (d['durum']?.toString() != 'İptal bekliyor') throw 'İptal talebi yok.';
        tel = (d['telefon'] ?? '').toString();
        final esnafId = (d['esnafId'] ?? '').toString();
        final eRef = _esnaflarRef.doc(esnafId);
        final eSnap = await tx.get(eRef);
        if (!eSnap.exists || eSnap.data() == null) throw 'İşletme bulunamadı.';
        final e = Map<String, dynamic>.from(eSnap.data() as Map);
        final anahtar = musteriTelefonAnahtari(tel);
        final calisanlar = List<Map<String, dynamic>>.from(e['calisanlar'] ?? [])
            .where((c) => musteriTelefonAnahtari('${c['telefon'] ?? ''}') != anahtar)
            .toList();
        final guncel = <String, dynamic>{'calisanlar': calisanlar};
        if (CalisanGorevleri.plakaGerekli((d['gorev'] ?? '').toString())) {
          final araclar = List<Map<String, dynamic>>.from(e['araclar'] ?? [])
              .where((a) => musteriTelefonAnahtari('${a['soforTel'] ?? ''}') != anahtar)
              .toList();
          guncel['araclar'] = araclar;
        }
        tx.update(eRef, guncel);
        tx.update(ref, {'durum': 'İptal', 'guncelleme': FieldValue.serverTimestamp()});
      });
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    if (tel.trim().isNotEmpty) {
      await BildirimServisi.bildirimGonder(
        baslik: 'İptal onaylandı',
        icerik: 'Çalışmayı bırakma talebiniz onaylandı.',
        kullaniciTel: tel,
      );
    }
    return null;
  }

  Future<String?> calisanIptalReddet(String id) async {
    final doc = await _calisanBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'İptal bekliyor') return 'İptal talebi yok.';
    await doc.reference.update({'durum': 'Kabul', 'guncelleme': FieldValue.serverTimestamp()});
    final tel = (d['telefon'] ?? '').toString();
    if (tel.trim().isNotEmpty) {
      await BildirimServisi.bildirimGonder(
        baslik: 'İptal onaylanmadı',
        icerik: 'Çalışmayı bırakma talebiniz reddedildi. Kayıt duruyor.',
        kullaniciTel: tel,
      );
    }
    return null;
  }

  Stream<List<Map<String, dynamic>>> esnafBasvurulariDinle() {
    return _esnafBasvuruAkisi(sadeceBekleyen: true);
  }

  Stream<List<Map<String, dynamic>>> esnafBasvurulariTumunuDinle() {
    return _esnafBasvuruAkisi(sadeceBekleyen: false);
  }

  Stream<List<Map<String, dynamic>>> _esnafBasvuruAkisi({required bool sadeceBekleyen}) {
    final sorgu = sadeceBekleyen
        ? _esnafBasvuruRef.where('durum', isEqualTo: 'Bekliyor')
        : _esnafBasvuruRef;
    return sorgu.snapshots().map((snap) {
      final liste = snap.docs
          .map((d) => {'id': d.id, ...Map<String, dynamic>.from(d.data() as Map)})
          .toList();
      liste.sort((a, b) =>
          (a['isletmeAdi'] ?? '').toString().compareTo((b['isletmeAdi'] ?? '').toString()));
      return liste;
    });
  }

  /// null = alındı. Dolu metin, kişiye gösterilecek engel.
  Future<String?> esnafBasvurusuGonder({
    required String telefon,
    required String adSoyad,
    required String isletmeAdi,
    required String isletmeTuru,
    required String kategori,
    required String email,
    required String vergiNo,
    required String vergiLevhaUrl,
    required String acilis,
    required String kapanis,
    required String kapaliGun,
    required bool sozlesmeOnay,
    required bool kvkkOnay,
    double enlem = 0,
    double boylam = 0,
    String sabitTel = '',
    String web = '',
    String instagram = '',
    String tanitim = '',
    String mersisNo = '',
    String ticaretSicilNo = '',
    String il = '',
    String ilce = '',
    String mahalle = '',
    String cadde = '',
    String adres = '',
    List<String> olanaklar = const [],
    String logoUrl = '',
  }) async {
    final id = musteriTelefonAnahtari(telefon);
    if (id.isEmpty) return 'Telefon geçersiz.';
    final tur = isletmeTuru.trim();
    if (tur != 'Şahıs' && tur != 'Şirket') return 'İşletme türünü seçin.';
    final vergi = vergiNo.trim();
    final beklenen = tur == 'Şirket' ? 10 : 11;
    if (vergi.length != beklenen) {
      return tur == 'Şirket'
          ? 'Şirket için vergi kimlik numarası 10 hane olmalı.'
          : 'Şahıs işletmesi için T.C. kimlik numarası 11 hane olmalı.';
    }
    if (vergiLevhaUrl.trim().isEmpty) return 'Vergi levhası olmadan başvuru olmaz.';
    if (!email.contains('@') || !email.contains('.')) return 'E-posta yazın.';
    if (!sozlesmeOnay || !kvkkOnay) return 'Sözleşme ve aydınlatma onayı gerekli.';
    final saat = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!saat.hasMatch(acilis.trim()) || !saat.hasMatch(kapanis.trim())) {
      return 'Açılış ve kapanış saatini 09:00 biçiminde yazın.';
    }
    if (isletmeAdi.trim().isEmpty || kategori.trim().isEmpty || il.trim().isEmpty || ilce.trim().isEmpty || adres.trim().isEmpty) {
      return 'Unvan, kategori ve adres gerekli.';
    }
    if (await telefonIleEsnafGetir(telefon) != null) {
      return 'Bu telefon zaten bir işletmeye bağlı.';
    }
    final mevcut = await _esnafBasvuruRef.doc(id).get();
    final veri = mevcut.data();
    final durum = veri is Map ? veri['durum']?.toString() : null;
    if (durum == 'Bekliyor') return 'Başvurunuz inceleniyor.';
    await _esnafBasvuruRef.doc(id).set({
      'telefon': TelefonGirdisi.rakamlar(telefon),
      'adSoyad': adSoyad.trim(),
      'isletmeAdi': isletmeAdi.trim(),
      'isletmeTuru': tur,
      'kategori': kategori.trim(),
      'il': il.trim(),
      'ilce': ilce.trim(),
      'mahalle': mahalle.trim(),
      'cadde': cadde.trim(),
      'adres': adres.trim(),
      'email': email.trim(),
      'vergiNo': vergi,
      'vergiLevhaUrl': vergiLevhaUrl.trim(),
      'logoUrl': logoUrl.trim(),
      'acilis': acilis.trim(),
      'kapanis': kapanis.trim(),
      'kapaliGun': kapaliGun.trim(),
      'sozlesmeOnay': true,
      'kvkkOnay': true,
      'enlem': enlem,
      'boylam': boylam,
      'sabitTel': TelefonGirdisi.rakamlar(sabitTel),
      'web': web.trim(),
      'instagram': instagram.trim(),
      'tanitim': tanitim.trim(),
      'mersisNo': mersisNo.trim(),
      'ticaretSicilNo': ticaretSicilNo.trim(),
      'olanaklar': olanaklar,
      'durum': 'Bekliyor',
      'redNotu': '',
      'esnafId': '',
      'guncelleme': FieldValue.serverTimestamp(),
      if (!mevcut.exists) 'olusturma': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return null;
  }

  /// null = esnaf kaydı açıldı.
  Future<String?> esnafBasvurusuOnayla(String id) async {
    final doc = await _esnafBasvuruRef.doc(id).get();
    if (!doc.exists || doc.data() == null) return 'Başvuru bulunamadı.';
    final d = Map<String, dynamic>.from(doc.data() as Map);
    if (d['durum']?.toString() != 'Bekliyor') return 'Bu başvuru zaten işlenmiş.';
    final tel = (d['telefon'] ?? '').toString();
    if (await telefonIleEsnafGetir(tel) != null) {
      await doc.reference.set({
        'durum': 'Onaylandı',
        'guncelleme': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return 'Bu telefon zaten bir işletmede. Başvuru kapatıldı.';
    }
    const gunAdlari = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final kapali = (d['kapaliGun'] ?? '').toString();
    final gunler = {for (final g in gunAdlari) g: kapali != g};
    final acilis = (d['acilis'] ?? '09:00').toString();
    final kapanis = (d['kapanis'] ?? '19:00').toString();
    final yeni = await _esnaflarRef.add(EsnafModeli(
      id: '',
      isletmeAdi: (d['isletmeAdi'] ?? '').toString(),
      kategori: (d['kategori'] ?? '').toString(),
      telefon: tel,
      email: (d['email'] ?? '').toString(),
      il: (d['il'] ?? '').toString(),
      ilce: (d['ilce'] ?? '').toString(),
      adres: (d['adres'] ?? '').toString(),
      tanitim: (d['tanitim'] ?? '').toString(),
      konum: GeoPoint(
        (d['enlem'] as num?)?.toDouble() ?? 0,
        (d['boylam'] as num?)?.toDouble() ?? 0,
      ),
      calismaSaatleri: {
        'gunler': gunler,
        'acilis': acilis,
        'kapanis': kapanis,
        'is724': false,
        'slotDakika': 30,
      },
    ).toMap());
    await yeni.update({
      'vergiNo': (d['vergiNo'] ?? '').toString(),
      'vergiLevhaUrl': (d['vergiLevhaUrl'] ?? '').toString(),
      'isletmeTuru': (d['isletmeTuru'] ?? '').toString(),
      'mahalle': (d['mahalle'] ?? '').toString(),
      'cadde': (d['cadde'] ?? '').toString(),
      'sabitTel': (d['sabitTel'] ?? '').toString(),
      'web': (d['web'] ?? '').toString(),
      'instagram': (d['instagram'] ?? '').toString(),
      'mersisNo': (d['mersisNo'] ?? '').toString(),
      'ticaretSicilNo': (d['ticaretSicilNo'] ?? '').toString(),
      'olanaklar': d['olanaklar'] ?? [],
      'yetkiliAd': (d['adSoyad'] ?? '').toString(),
      'logoUrl': (d['logoUrl'] ?? '').toString(),
    });
    await doc.reference.set({
      'durum': 'Onaylandı',
      'esnafId': yeni.id,
      'guncelleme': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return null;
  }

  Future<void> esnafBasvurusuReddet(String id, String not) async {
    await _esnafBasvuruRef.doc(id).set({
      'durum': 'Reddedildi',
      'redNotu': not.trim(),
      'guncelleme': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> vergiGuncellemeleriDinle() {
    return _esnaflarRef.where('vergiGuncelleme.durum', isEqualTo: 'Bekliyor').snapshots().map((snap) {
      final liste = snap.docs
          .map((d) => {'id': d.id, ...Map<String, dynamic>.from(d.data() as Map)})
          .toList();
      liste.sort((a, b) =>
          (a['isletmeAdi'] ?? '').toString().compareTo((b['isletmeAdi'] ?? '').toString()));
      return liste;
    });
  }

  Future<String?> vergiGuncellemesiniOnayla(String esnafId) async {
    final doc = await _esnaflarRef.doc(esnafId).get();
    final data = doc.data();
    if (data is! Map) return 'İşletme bulunamadı.';
    final g = data['vergiGuncelleme'];
    if (g is! Map || g['durum']?.toString() != 'Bekliyor') return 'Bekleyen vergi güncellemesi yok.';
    await doc.reference.update({
      'isletmeTuru': (g['isletmeTuru'] ?? '').toString(),
      'vergiNo': (g['vergiNo'] ?? '').toString(),
      'vergiLevhaUrl': (g['vergiLevhaUrl'] ?? '').toString(),
      'vergiGuncelleme.durum': 'Onaylandı',
      'vergiGuncelleme.onayTarihi': FieldValue.serverTimestamp(),
    });
    return null;
  }

  Future<void> vergiGuncellemesiniReddet(String esnafId, String not) async {
    await _esnaflarRef.doc(esnafId).update({
      'vergiGuncelleme.durum': 'Reddedildi',
      'vergiGuncelleme.redNotu': not.trim(),
    });
  }

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
          'slotDakika': slotAraligi,
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

  Stream<RandevuModeli> randevuyuGetir(String id) {
    return _randevularRef.doc(id).snapshots().map((doc) => RandevuModeli.fromFirestore(doc));
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

  Future<int> onayliRandevuSayisi(String esnafId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (esnafId.isEmpty || anahtar.isEmpty) return 0;
    final snap = await _randevularRef.where('esnafId', isEqualTo: esnafId).get();
    var sayi = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final durum = data['durum'];
      if (durum != 'Onaylandı' && durum != 'Tamamlandı') continue;
      if (musteriTelefonAnahtari('${data['kullaniciTel'] ?? ''}') != anahtar) continue;
      sayi++;
    }
    return sayi;
  }

  /// Onaylı kayıt sırası kurala denk gelirse indirim notunu yazar. Paket hakkını değiştirmez.
  Future<void> sadakatIsle(RandevuModeli r, EsnafModeli esnaf) async {
    if (!esnaf.sadakatAktif || esnaf.sadakatAdet < 2 || esnaf.sadakatYuzde <= 0) return;
    if (esnaf.kategori == 'Taksi' || esnaf.kategori == 'Araç Kiralama') return;
    if (r.id.isEmpty || r.sadakatYuzde > 0) return;
    if (r.durum != 'Onaylandı' && r.durum != 'Tamamlandı') return;
    final sira = await onayliRandevuSayisi(esnaf.id, r.kullaniciTel);
    if (sira <= 0 || sira % esnaf.sadakatAdet != 0) return;
    await _randevularRef.doc(r.id).update({
      'sadakatYuzde': esnaf.sadakatYuzde,
      'sadakatSira': sira,
    });
  }

  Future<List<RandevuModeli>> esnafRandevulariBirKez(String esnafId) async {
    final snap = await _randevularRef.where('esnafId', isEqualTo: esnafId).get();
    return snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
  }

  Future<List<({DateTime baslangic, double ucret, String durum})>> esnafPaketOzetleri(String esnafId) async {
    final snap = await _musteriPaketRef.where('esnafId', isEqualTo: esnafId).get();
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final ham = data['baslangic'] ?? data['olusturmaTarihi'];
      final bas = ham is Timestamp ? ham.toDate() : DateTime.now();
      return (
        baslangic: bas,
        ucret: (data['ucret'] as num?)?.toDouble() ?? 0,
        durum: (data['durum'] ?? '').toString(),
      );
    }).toList();
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

  Future<List<RandevuModeli>> kullaniciRandevulariniBirKezGetir(String telefon) async {
    final snap = await _randevularRef.where('kullaniciTel', isEqualTo: telefon).get();
    final list = snap.docs.map((doc) => RandevuModeli.fromFirestore(doc)).toList();
    list.sort((a, b) {
      final d = b.tarih.compareTo(a.tarih);
      if (d != 0) return d;
      return b.saat.compareTo(a.saat);
    });
    return list;
  }

  Future<String?> randevuEkle(RandevuModeli randevu, {bool onayBildir = true}) async {
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

    // Genel randevu hatırlatmaları (otomatik onaylı kayıtlar)
    if (randevu.durum == 'Onaylandı') {
      try {
        final esnaf = await esnafGetirDoc(randevu.esnafId);
        if (esnaf != null && esnaf.hatirlatmaAktif) {
          final rKayit = randevu.copyWith(id: docRef.id);
          final hat = await BildirimServisi.randevuHatirlatmalariniKur(
            r: rKayit,
            esnaf: esnaf,
            randevuId: docRef.id,
          );
          if (hat['hata'] == 'ALICI_YOK' && sonucHata == null) {
            sonucHata = 'ALICI_YOK';
          }
        }
      } catch (e) {
        debugPrint('❌ Randevu ekleme hatırlatma planlama hatası: $e');
      }
      if (onayBildir) {
        try {
          final esnafBildir = await esnafGetirDoc(randevu.esnafId);
          if (esnafBildir != null) {
            await BildirimServisi.onayVeyaRedBildir(
              r: randevu.copyWith(id: docRef.id),
              esnaf: esnafBildir,
              onay: true,
            );
          }
        } catch (e) {
          debugPrint('❌ Onay bildirimi: $e');
        }
      }
      try {
        final esnafSadakat = await esnafGetirDoc(randevu.esnafId);
        if (esnafSadakat != null) {
          await sadakatIsle(randevu.copyWith(id: docRef.id), esnafSadakat);
        }
      } catch (e) {
        debugPrint('❌ Sadakat: $e');
      }
    }

    if (randevu.durum == 'Onaylandı') {
      try {
        final esnafHat = await esnafGetirDoc(randevu.esnafId);
        if (esnafHat != null && esnafHat.kategori == 'Taksi') {
          final p = randevu.saat.split(':');
          final bas = DateTime(
            randevu.tarih.year,
            randevu.tarih.month,
            randevu.tarih.day,
            int.parse(p[0]),
            int.parse(p.length > 1 ? p[1] : '0'),
          );
          await BildirimServisi.taksiHatirlatmaPlanla(
            randevuId: docRef.id,
            esnaf: esnafHat,
            musteriTel: randevu.kullaniciTel,
            baslangic: bas,
          );
        }
      } catch (e) {
        debugPrint('❌ Taksi rezervasyon hatırlatması: $e');
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

  /// Gelecekteki (henüz başlamamış) seri randevularını iptal eder; geçmiş kayıtlar kalır.
  Future<int> randevuSerisiniIptalEt(String seriId, String neden) async {
    final snap = await _randevularRef.where('seriId', isEqualTo: seriId).get();
    final now = DateTime.now();
    int iptalSayisi = 0;

    for (var doc in snap.docs) {
      final r = RandevuModeli.fromFirestore(doc);
      if (r.durum == 'İptal Edildi' ||
          r.durum == 'Reddedildi' ||
          r.durum == 'Tamamlandı' ||
          r.durum == 'Kullanımda') {
        continue;
      }

      final parts = r.saat.split(':');
      final baslangic = DateTime(
        r.tarih.year,
        r.tarih.month,
        r.tarih.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      if (!baslangic.isAfter(now)) continue;

      await randevuIptalEt(r.id, neden);
      iptalSayisi++;
    }
    return iptalSayisi;
  }

  /// Aynı pakete veya aynı seriye bağlı, henüz kapanmamış randevular.
  Future<List<RandevuModeli>> bagliRandevulariGetir(RandevuModeli r) async {
    const kapali = {'İptal Edildi', 'Reddedildi', 'Tamamlandı', 'Gelmedi', 'Kullanımda'};
    final gorulen = <String>{};
    final liste = <RandevuModeli>[];

    void ekle(RandevuModeli kayit) {
      if (kayit.id.isEmpty || gorulen.contains(kayit.id) || kapali.contains(kayit.durum)) return;
      if (kayit.esnafId != r.esnafId) return;
      final buOn = HizmetPaketi.randevuOnGorusmeMi(r.hizmetAdi);
      final oOn = HizmetPaketi.randevuOnGorusmeMi(kayit.hizmetAdi);
      if (buOn != oOn) return;
      if (!buOn && kayit.hizmetAdi.toLowerCase() != r.hizmetAdi.toLowerCase()) return;
      gorulen.add(kayit.id);
      liste.add(kayit);
    }

    ekle(r);
    if (r.paketKayitId != null && r.paketKayitId!.isNotEmpty) {
      final snap = await _randevularRef.where('paketKayitId', isEqualTo: r.paketKayitId).get();
      for (final doc in snap.docs) {
        ekle(RandevuModeli.fromFirestore(doc));
      }
    }
    if (r.seriId != null && r.seriId!.isNotEmpty) {
      final snap = await _randevularRef.where('seriId', isEqualTo: r.seriId).get();
      for (final doc in snap.docs) {
        ekle(RandevuModeli.fromFirestore(doc));
      }
    }
    liste.sort((a, b) {
      final gun = a.tarih.compareTo(b.tarih);
      if (gun != 0) return gun;
      return a.saat.compareTo(b.saat);
    });
    return liste;
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
    bool durumBildir = false,
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

        if (esnaf.kategori == 'Taksi') {
          final p = r.saat.split(':');
          final bas = DateTime(
            r.tarih.year, r.tarih.month, r.tarih.day,
            int.parse(p[0]), int.parse(p.length > 1 ? p[1] : '0'),
          );
          await BildirimServisi.taksiHatirlatmaPlanla(
            randevuId: id,
            esnaf: esnaf,
            musteriTel: r.kullaniciTel,
            baslangic: bas,
          );
        }

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

          // [PROFESYONEL]: Sıradaki bekleyen müşteriyi tespit et
          RandevuModeli? siradaki;
          try {
            final bugunSifir = DateTime(r.tarih.year, r.tarih.month, r.tarih.day);
            final yarinaKadar = bugunSifir.add(const Duration(days: 1));
            final tumSnap = await _randevularRef
                .where('esnafId', isEqualTo: r.esnafId)
                .where('randevu_kanali', isEqualTo: r.randevuKanali)
                .where('tarih', isGreaterThanOrEqualTo: bugunSifir)
                .where('tarih', isLessThan: yarinaKadar)
                .where('durum', whereIn: ['Onaylandı', 'Onay bekliyor'])
                .get();

            final tumRandevular = tumSnap.docs.map((d) => RandevuModeli.fromFirestore(d)).toList();
            siradaki = tumRandevular.firstWhere((sr) {
              final srBas = DateTime(sr.tarih.year, sr.tarih.month, sr.tarih.day,
                  int.parse(sr.saat.split(':')[0]), int.parse(sr.saat.split(':')[1]));
              return srBas.isAfter(bitisZamani) && srBas.isBefore(bitisZamani.add(const Duration(hours: 2)));
            });
          } catch (_) {}

          // [PROFESYONEL RETRY]: Hızlı girişlerde OneSignal aboneliğinin tamamlanması için 3 kez deneme yapıyoruz.
          String? newGecikmeId;
          int denemeSayisi = 0;
          
          if (siradaki != null) {
            while (denemeSayisi < 3) {
              newGecikmeId = await OneSignalServisi.bildirimPlanla(
                baslik: "🔴 KRİTİK GECİKME: ${siradaki.kullaniciAd} (${siradaki.saat}) BEKLİYOR!",
                icerik: "${r.randevuKanali} plakalı aracın iade saati ($bitisSaati) geçti! Lütfen aracı teslim alınız.",
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
                break;
              }
              if (newGecikmeId == "ALICI_YOK") {
                denemeSayisi++;
                await Future.delayed(const Duration(seconds: 1));
              } else {
                break;
              }
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

        // Genel öncesi/sonrası hatırlatmalar
        if (esnaf.hatirlatmaAktif) {
          final hat = await BildirimServisi.randevuHatirlatmalariniKur(
            r: r,
            esnaf: esnaf,
            randevuId: id,
          );
          if (hat['oncesi'] == true || hat['sonrasi'] == true) {
            sonuc['hatirlatmaKuruldu'] = true;
          }
          if (hat['hata'] == 'ALICI_YOK' && sonuc['hata'] == null) {
            sonuc['hata'] = 'ALICI_YOK';
          }
        }
        try {
          await BildirimServisi.onayVeyaRedBildir(r: r, esnaf: esnaf, onay: true);
        } catch (e) {
          debugPrint('❌ Onay bildirimi: $e');
        }
        try {
          await sadakatIsle(r, esnaf);
        } catch (e) {
          debugPrint('❌ Sadakat: $e');
        }
      } catch (e) {
        debugPrint("❌ Onay sonrası OneSignal hatası: $e");
        sonuc['basarili'] = false;
      }
      try {
        final yazSnap = await _randevularRef.doc(id).get();
        if (yazSnap.exists) {
          final eksikAjanda = await paketSonrakiGunleriniYaz(RandevuModeli.fromFirestore(yazSnap));
        if (eksikAjanda != null && eksikAjanda.isNotEmpty) {
          sonuc['eksikAjanda'] = eksikAjanda.map((g) => g.millisecondsSinceEpoch).toList();
        }
        }
      } catch (e) {
        debugPrint('❌ Paket günleri yazılamadı: $e');
      }
    }
else if (yeniDurum == 'Reddedildi' || yeniDurum == 'İptal Edildi' || yeniDurum == 'Tamamlandı' || yeniDurum == 'Gelmedi') {
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

          // Öncesi/sonrası hatırlatmalar yalnızca iptal/redde düşsün (Tamamlandı'da teşekkür gidebilsin)
          if (yeniDurum == 'Reddedildi' || yeniDurum == 'İptal Edildi' || yeniDurum == 'Gelmedi') {
            await BildirimServisi.randevuHatirlatmalariniIptal(r);
            await BildirimServisi.taksiHatirlatmaIptal(id);
            // Slot boşaldı → bekleme listesine haber ver
            await beklemeListesiSlotBosaldiBildir(r);
          }
          if (yeniDurum == 'Reddedildi' && durumBildir) {
            try {
              final esnafSnap = await _esnaflarRef.doc(r.esnafId).get();
              if (esnafSnap.exists) {
                await BildirimServisi.onayVeyaRedBildir(
                  r: r,
                  esnaf: EsnafModeli.fromFirestore(esnafSnap),
                  onay: false,
                  neden: iptalNedeni ?? r.iptalNedeni,
                );
              }
            } catch (e) {
              debugPrint('❌ Red bildirimi: $e');
            }
          }
          final raw = rSnap.data();
          final iadeEdildi = raw is Map && raw['paketIadeEdildi'] == true;
          if ((yeniDurum == 'Reddedildi' || yeniDurum == 'İptal Edildi') &&
              r.paketKayitId != null &&
              r.paketKayitId!.isNotEmpty &&
              !iadeEdildi) {
            await paketSeansIade(r.paketKayitId!);
            await _randevularRef.doc(id).update({'paketIadeEdildi': true});
          }
        }
      } catch (e) {
        debugPrint('❌ İptal sırasında bildirim işaretleme hatası: $e');
      }
    }
    return sonuc;
  }

  String _telTemizle(String tel) {
    String temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (temiz.length >= 10) temiz = temiz.substring(temiz.length - 10);
    return temiz;
  }

  /// Dolu saate yazılma. Dönüş: null = OK, aksi hata kodu.
  Future<String?> beklemeListesineEkle(BeklemeListesiModeli kayit) async {
    try {
      final temizTel = _telTemizle(kayit.kullaniciTel);
      final gun = DateTime(kayit.tarih.year, kayit.tarih.month, kayit.tarih.day);

      final mevcut = await _beklemeListesiRef
          .where('esnafId', isEqualTo: kayit.esnafId)
          .where('kullaniciTel', isEqualTo: temizTel)
          .where('saat', isEqualTo: kayit.saat)
          .where('durum', whereIn: ['bekliyor', 'bildirildi'])
          .get();

      for (final doc in mevcut.docs) {
        final d = BeklemeListesiModeli.fromFirestore(doc);
        final ayniGun = d.tarih.year == gun.year && d.tarih.month == gun.month && d.tarih.day == gun.day;
        final ayniKanal = (kayit.randevuKanali ?? '') == (d.randevuKanali ?? '');
        if (ayniGun && ayniKanal) {
          return 'ZATEN_VAR';
        }
      }

      final temizKayit = kayit.copyWith(kullaniciTel: temizTel);
      await _beklemeListesiRef.add(temizKayit.toMap());
      debugPrint('✅ Bekleme listesine eklendi: ${kayit.esnafAdi} ${kayit.saat}');
      return null;
    } catch (e) {
      debugPrint('❌ beklemeListesineEkle: $e');
      return 'HATA';
    }
  }

  Stream<List<BeklemeListesiModeli>> kullaniciBeklemeListesiniGetir(String telefon) {
    final temiz = _telTemizle(telefon);
    return _beklemeListesiRef
        .where('kullaniciTel', isEqualTo: temiz)
        .where('durum', whereIn: ['bekliyor', 'bildirildi'])
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => BeklemeListesiModeli.fromFirestore(d)).toList();
          list.sort((a, b) {
            final t = a.tarih.compareTo(b.tarih);
            if (t != 0) return t;
            return a.saat.compareTo(b.saat);
          });
          return list;
        });
  }

  Future<void> beklemeListesiIptalEt(String id) async {
    await _beklemeListesiRef.doc(id).update({
      'durum': 'iptal',
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    });
  }

  /// Randevu iptal/red sonrası aynı slot bekleyenlere anlık push.
  Future<int> beklemeListesiSlotBosaldiBildir(RandevuModeli r) async {
    try {
      final gun = DateTime(r.tarih.year, r.tarih.month, r.tarih.day);
      final snap = await _beklemeListesiRef
          .where('esnafId', isEqualTo: r.esnafId)
          .where('saat', isEqualTo: r.saat)
          .where('durum', whereIn: ['bekliyor', 'bildirildi'])
          .get();

      final adaylar = snap.docs
          .map((d) => BeklemeListesiModeli.fromFirestore(d))
          .where((b) {
            final ayniGun = b.tarih.year == gun.year && b.tarih.month == gun.month && b.tarih.day == gun.day;
            if (!ayniGun) return false;
            final kanal = r.randevuKanali ?? '';
            if (kanal.isNotEmpty && (b.randevuKanali ?? '').isNotEmpty && b.randevuKanali != kanal) {
              return false;
            }
            return true;
          })
          .toList()
        ..sort((a, b) {
          final aa = a.olusturmaTarihi ?? DateTime(2000);
          final bb = b.olusturmaTarihi ?? DateTime(2000);
          return aa.compareTo(bb);
        });

      int sayi = 0;
      final tarihStr = DateFormat('dd.MM.yyyy').format(gun);
      for (final b in adaylar) {
        await OneSignalServisi.bildirimGonderAnlik(
          baslik: 'Slot boşaldı!',
          icerik: '${b.esnafAdi} · $tarihStr saat ${b.saat} müsait. Hemen randevu alabilirsiniz.',
          telefon: b.kullaniciTel,
          ekVeri: {
            'action': 'bekleme_slot',
            'esnafId': b.esnafId,
            'beklemeId': b.id,
            'tel': b.kullaniciTel,
          },
        );
        await _beklemeListesiRef.doc(b.id).update({
          'durum': 'bildirildi',
          'bildirimTarihi': FieldValue.serverTimestamp(),
        });
        sayi++;
      }
      if (sayi > 0) debugPrint('📢 Bekleme listesi bildirimi: $sayi kişi');
      return sayi;
    } catch (e) {
      debugPrint('❌ beklemeListesiSlotBosaldiBildir: $e');
      return 0;
    }
  }

  Future<MusteriPaketKaydi?> paketKaydiGetir(String id) async {
    if (id.isEmpty) return null;
    final doc = await _musteriPaketRef.doc(id).get();
    if (!doc.exists) return null;
    return MusteriPaketKaydi.fromFirestore(doc);
  }

  Stream<List<MusteriPaketKaydi>> musteriPaketleri(String telefon) {
    final tel = _telTemizle(telefon);
    if (tel.isEmpty) return Stream.value(const []);
    return _musteriPaketRef.where('kullaniciTel', isEqualTo: tel).snapshots().map((snap) {
      final liste = snap.docs.map(MusteriPaketKaydi.fromFirestore).toList();
      liste.sort((a, b) => b.bitis.compareTo(a.bitis));
      return liste;
    });
  }

  /// Paketi açar ve bu randevu için 1 seans düşer. Kayıt id döner.
  Future<String> paketSatinAl({
    required String esnafId,
    required String esnafAdi,
    required String kullaniciTel,
    required String hizmetAdi,
    required HizmetPaketTanimi tanim,
    int kullanilanSeans = 1,
  }) async {
    final tel = _telTemizle(kullaniciTel);
    final simdi = DateTime.now();
    final sonGun = simdi.add(Duration(days: tanim.gecerlilikGun));
    final bitis = DateTime(sonGun.year, sonGun.month, sonGun.day, 23, 59, 59);
    final kullanilan = kullanilanSeans.clamp(0, tanim.seans);
    final kalan = tanim.seans - kullanilan;
    final ref = _musteriPaketRef.doc();
    await ref.set({
      'esnafId': esnafId,
      'esnafAdi': esnafAdi,
      'kullaniciTel': tel,
      'hizmetAdi': hizmetAdi,
      'paketTanimId': tanim.id,
      'paketAdi': tanim.ad,
      'toplamSeans': tanim.seans,
      'kalanSeans': kalan,
      'ucret': tanim.ucret,
      'baslangic': Timestamp.fromDate(simdi),
      'bitis': Timestamp.fromDate(bitis),
      'durum': kalan > 0 ? 'aktif' : 'bitti',
      'olusturmaTarihi': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> paketKaydiSil(String id) async {
    if (id.isEmpty) return;
    await _musteriPaketRef.doc(id).delete();
  }

  /// true: 1 hak düştü. false: hak yok veya süre dolmuş.
  Future<bool> paketSeansDus(String id) async {
    if (id.isEmpty) return false;
    return _db.runTransaction<bool>((tx) async {
      final ref = _musteriPaketRef.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final kalan = (data['kalanSeans'] as num?)?.toInt() ?? 0;
      final bitis = data['bitis'] is Timestamp ? (data['bitis'] as Timestamp).toDate() : DateTime.now();
      if (bitis.isBefore(DateTime.now()) || kalan <= 0 || data['durum'] == 'bitti') {
        tx.update(ref, {'durum': bitis.isBefore(DateTime.now()) ? 'suresi_doldu' : 'bitti'});
        return false;
      }
      final yeni = kalan - 1;
      tx.update(ref, {
        'kalanSeans': yeni,
        'durum': yeni > 0 ? 'aktif' : 'bitti',
      });
      return true;
    });
  }

  /// Onaylı paketin sonraki haftalık günlerine aynı isim ve saati yazar.
  /// Ajandası olmayan günleri döner; o günlerin ajandası da açılır.
  Future<List<DateTime>?> paketSonrakiGunleriniYaz(RandevuModeli r) async {
    final paketId = r.paketKayitId;
    if (paketId == null || paketId.isEmpty || r.durum != 'Onaylandı') return const [];
    if (!_paketYaziliyor.add(paketId)) return const [];
    try {
      final paket = await paketKaydiGetir(paketId);
      if (paket == null || paket.toplamSeans <= 1) return const [];

      final bagli = await _randevularRef.where('paketKayitId', isEqualTo: paketId).get();
      DateTime? ilkTarih;
      for (final doc in bagli.docs) {
        final kayit = RandevuModeli.fromFirestore(doc);
        if (kayit.durum == 'Reddedildi' || kayit.durum == 'İptal Edildi') continue;
        final gun = DateTime(kayit.tarih.year, kayit.tarih.month, kayit.tarih.day);
        if (ilkTarih == null || gun.isBefore(ilkTarih)) ilkTarih = gun;
      }
      final buGun = DateTime(r.tarih.year, r.tarih.month, r.tarih.day);
      var kaynak = r;
      if (ilkTarih != null && buGun != ilkTarih) {
        for (final doc in bagli.docs) {
          final kayit = RandevuModeli.fromFirestore(doc);
          if (kayit.durum == 'Reddedildi' || kayit.durum == 'İptal Edildi') continue;
          final gun = DateTime(kayit.tarih.year, kayit.tarih.month, kayit.tarih.day);
          if (gun == ilkTarih) {
            kaynak = kayit;
            break;
          }
        }
      }

      final esnaf = await esnafGetirDoc(kaynak.esnafId);
      if (esnaf == null) return const [];
      final kanal = (kaynak.randevuKanali ?? '').trim();
      final yazilan = <DateTime>[];

      if (paket.durum == 'aktif' && paket.kalanSeans > 0 && paket.toplamSeans - paket.kalanSeans == 1) {
        final sonrakiler = HizmetPaketi.haftalikPlan(kaynak.tarih, paket.toplamSeans, bitis: paket.bitis).skip(1).toList();
        for (final gun in sonrakiler) {
          final guncel = await paketKaydiGetir(paketId);
          if (guncel == null || guncel.kalanSeans <= 0) break;
          final dolu = await randevuCakisiyorMu(
            esnafId: kaynak.esnafId,
            tarih: gun,
            saat: kaynak.saat,
            sure: kaynak.sure,
            kanal: kanal.isEmpty ? null : kanal,
          );
          if (dolu) continue;
          final dustu = await paketSeansDus(paketId);
          if (!dustu) break;
          try {
            await randevuEkle(RandevuModeli(
              id: '',
              esnafId: kaynak.esnafId,
              esnafAdi: kaynak.esnafAdi,
              esnafTel: kaynak.esnafTel,
              kullaniciAd: kaynak.kullaniciAd,
              kullaniciTel: kaynak.kullaniciTel,
              tarih: gun,
              saat: kaynak.saat,
              sure: kaynak.sure,
              hizmetAdi: kaynak.hizmetAdi,
              durum: 'Onaylandı',
              randevuKanali: kaynak.randevuKanali,
              calisanPersonel: kaynak.calisanPersonel,
              paketKayitId: paketId,
              paketAdi: kaynak.paketAdi,
            ), onayBildir: false);
            yazilan.add(gun);
          } catch (e) {
            await paketSeansIade(paketId);
            debugPrint('❌ Paket günü kaydedilemedi: $e');
          }
        }
      }

      final plan = HizmetPaketi.haftalikPlan(kaynak.tarih, paket.toplamSeans, bitis: paket.bitis);
      if (plan.isEmpty) return const [];
      final aralik = HizmetPaketi.ardisikGunler(plan.first, plan.last);
      final slot = HizmetPaketi.idealSlot(esnaf.hizmetler);
      final cs = esnaf.calismaSaatleri ?? {};
      final acilis = (cs['acilis'] ?? '09:00').toString();
      final kapanis = (cs['kapanis'] ?? '18:00').toString();
      final eksik = <DateTime>[];
      for (final gun in aralik) {
        final tarihStr = DateFormat('yyyy-MM-dd').format(gun);
        final docId = kanal.isNotEmpty ? '${tarihStr}_$kanal' : tarihStr;
        final ref = _esnaflarRef.doc(kaynak.esnafId).collection('ajanda').doc(docId);
        final doc = await ref.get();
        if (!doc.exists) {
          eksik.add(gun);
          continue;
        }
        final data = doc.data();
        if (data == null) continue;
        final mevcutHam = data['slotDakika'] ?? data['slotAraligi'];
        final mevcut = mevcutHam is num ? mevcutHam.toInt() : int.tryParse('$mevcutHam') ?? 0;
        if (mevcut != slot) {
          await ref.update({'slotAraligi': slot, 'slotDakika': slot});
        }
      }
      if (eksik.isNotEmpty) {
        await ajandaOlustur(
          esnafId: kaynak.esnafId,
          tarihler: eksik,
          kanal: kanal,
          acilis: acilis,
          kapanis: kapanis,
          ogleBaslangic: cs['ogleBaslangic']?.toString(),
          ogleBitis: cs['ogleBitis']?.toString(),
          slotAraligi: slot,
        );
      }
      if (yazilan.isEmpty && eksik.isEmpty) return const [];
      return eksik.isNotEmpty ? eksik : yazilan;
    } finally {
      _paketYaziliyor.remove(paketId);
    }
  }

  Future<void> paketSeansIade(String id) async {
    if (id.isEmpty) return;
    await _db.runTransaction((tx) async {
      final ref = _musteriPaketRef.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final kalan = (data['kalanSeans'] as num?)?.toInt() ?? 0;
      final toplam = (data['toplamSeans'] as num?)?.toInt() ?? kalan;
      final bitis = data['bitis'] is Timestamp ? (data['bitis'] as Timestamp).toDate() : DateTime.now();
      final yeni = (kalan + 1).clamp(0, toplam);
      final suresiGecti = bitis.isBefore(DateTime.now());
      final tamamenIade = toplam > 0 && yeni >= toplam;
      tx.update(ref, {
        'kalanSeans': yeni,
        'durum': tamamenIade ? 'iptal' : (suresiGecti ? 'suresi_doldu' : (yeni > 0 ? 'aktif' : 'bitti')),
      });
    });
  }

  Future<void> randevuIptalEt(String id, String neden, {String? aliciTel, String? esnafAdi, String? tarihSaat, bool durumBildir = false}) async {
    await randevuDurumGuncelle(id, 'Reddedildi', iptalNedeni: neden, aliciTel: aliciTel, esnafAdi: esnafAdi, tarihSaat: tarihSaat, durumBildir: durumBildir);
  }

  Future<MusteriCezaKaydi?> musteriCezaGetir(String esnafId, String telefon) async {
    final tel = _telTemizle(telefon);
    if (esnafId.isEmpty || tel.isEmpty) return null;
    final doc = await _musteriCezaRef.doc('${esnafId}_$tel').get();
    if (!doc.exists) return null;
    return MusteriCezaKaydi.fromFirestore(doc);
  }

  Stream<List<MusteriCezaKaydi>> musteriCezaKayitlari(String esnafId) {
    return _musteriCezaRef.where('esnafId', isEqualTo: esnafId).snapshots().map((snap) {
      final liste = snap.docs.map(MusteriCezaKaydi.fromFirestore).toList();
      liste.sort((a, b) => b.toplam.compareTo(a.toplam));
      return liste;
    });
  }

  /// tip: gec_iptal | gelmedi. Eşik 0 ise sayaç artar, kara listeye alınmaz.
  Future<MusteriCezaKaydi> musteriCezaNotuIsle({
    required String esnafId,
    required String telefon,
    required String ad,
    required String tip,
    required int esik,
  }) async {
    final tel = _telTemizle(telefon);
    final ref = _musteriCezaRef.doc('${esnafId}_$tel');
    final snap = await ref.get();
    int gec = 0;
    int gel = 0;
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      gec = (data['gecIptal'] as num?)?.toInt() ?? 0;
      gel = (data['gelmedi'] as num?)?.toInt() ?? 0;
    }
    if (tip == 'gelmedi') {
      gel++;
    } else {
      gec++;
    }
    final toplam = gec + gel;
    final kara = esik > 0 && toplam >= esik;
    final sonNot = tip == 'gelmedi' ? 'Gelmedi' : 'Geç iptal';
    await ref.set({
      'esnafId': esnafId,
      'telefon': tel,
      'ad': ad,
      'gecIptal': gec,
      'gelmedi': gel,
      'karaListede': kara,
      'sonNot': sonNot,
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final guncel = await ref.get();
    return MusteriCezaKaydi.fromFirestore(guncel);
  }

  Future<void> musteriKaraListedenCikar(String esnafId, String telefon) async {
    final tel = _telTemizle(telefon);
    await _musteriCezaRef.doc('${esnafId}_$tel').set({
      'karaListede': false,
      'gecIptal': 0,
      'gelmedi': 0,
      'sonNot': 'Esnaf listeden çıkardı',
      'guncellemeTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> randevuGuncelle(String randevuId, Map<String, dynamic> veri) async {
    await _randevularRef.doc(randevuId).update(veri);
  }

  // --- SÜRÜCÜ VE SOS İŞLEMLERİ ---
  Future<void> surucuBelgeleriniGuncelle(String esnafId, Map<String, String> belgeler) async {
    await _esnaflarRef.doc(esnafId).update({
      'surucuBelgeleri': belgeler,
      'surucuOnayDurumu': 'Beklemede',
      'surucuBelgeleriYuklenmeTarihi': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acilDurumTalebiOlustur({
    required String randevuId,
    required String esnafId,
    required String kullaniciTel,
    required GeoPoint konum,
    required String baslatanRol,
    bool isMockedLocation = false,
  }) async {
    await _db.collection('acil_durumlar').add({
      'randevuId': randevuId,
      'esnafId': esnafId,
      'kullaniciTel': kullaniciTel,
      'konum': konum,
      'baslatanRol': baslatanRol,
      'isMockedLocation': isMockedLocation,
      'durum': 'Aktif',
      'olusturulmaTarihi': FieldValue.serverTimestamp(),
    });

    // Eğer sahte konum ise esnaf profilini de işaretle
    if (isMockedLocation) {
      await _esnaflarRef.doc(esnafId).update({
        'isMockedLocation': true,
        'sonSahteKonumTarihi': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> sahteKonumGuncelle(String esnafId, bool isMocked) async {
    await _esnaflarRef.doc(esnafId).update({
      'isMockedLocation': isMocked,
      'sonKonumKontrolTarihi': FieldValue.serverTimestamp(),
    });
  }

  // --- RANDEVU EKRANI İÇİN YARDIMCI STREAM'LER ---
  Stream<Map<String, dynamic>?> ajandaGetir(String esnafId, DateTime tarih, {String? kanal}) {
    return gunlukAjandaSnapStream(esnafId, tarih, kanal).map((snap) {
      if (!snap.exists) return null;
      try {
        return Map<String, dynamic>.from(snap.data() as Map);
      } catch (e) {
        return snap.data() as Map<String, dynamic>?;
      }
    });
  }

  Stream<Map<String, dynamic>?> taksiCizelgesiGetir(String esnafId) {
    return taksiAjandasiSnapStream(esnafId, DateTime.now()).map((snap) {
      if (!snap.exists) return null;
      try {
        return Map<String, dynamic>.from(snap.data() as Map);
      } catch (e) {
        return snap.data() as Map<String, dynamic>?;
      }
    });
  }

  Stream<List<Map<String, dynamic>>> tumKullanicilariGetir() {
    return _kullanicilarRef.snapshots().map((snap) => snap.docs.map((doc) => {
      'tel': doc.id,
      ...doc.data() as Map<String, dynamic>
    }).toList());
  }

  Future<void> globalPlakaGuncelle({
    required String esnafId,
    required String eskiPlaka,
    required String yeniPlaka,
  }) async {
    final ajandaRef = _esnaflarRef.doc(esnafId).collection('taksi_ajanda');
    final querySnapshot = await ajandaRef.get();

    final batch = _db.batch();
    bool degisiklikVar = false;

    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      bool docDegisti = false;

      data.forEach((tarih, gunlukVeri) {
        if (gunlukVeri is Map && gunlukVeri.containsKey(eskiPlaka)) {
          Map<String, dynamic> yeniGunlukVeri = Map<String, dynamic>.from(gunlukVeri);
          final durum = yeniGunlukVeri.remove(eskiPlaka);
          yeniGunlukVeri[yeniPlaka] = durum;
          data[tarih] = yeniGunlukVeri;
          docDegisti = true;
          degisiklikVar = true;
        }
      });

      if (docDegisti) {
        batch.set(doc.reference, data, SetOptions(merge: false));
      }
    }

    if (degisiklikVar) {
      await batch.commit();
    }
  }

  /// Sürücü plaka, ad veya telefonunu değiştirince bu bilginin durduğu
  /// kopyaları da aynı değere çeker: kullanıcı profili (fotoğraf ve belgeler),
  /// nöbet çizelgesi, rezervasyon kanalı, personel listesi ve bekleyen çağrı.
  Future<void> soforKimliginiYay({
    required String esnafId,
    required String eskiTel,
    required String yeniTel,
    required String eskiPlaka,
    required String yeniPlaka,
    required String yeniAd,
  }) async {
    final telEski = eskiTel.trim();
    final telYeni = yeniTel.trim();
    final plakaEski = eskiPlaka.trim().toUpperCase();
    final plakaYeni = yeniPlaka.trim().toUpperCase();
    final ad = yeniAd.trim();

    if (telYeni.isNotEmpty) {
      final veri = <String, dynamic>{
        'plaka': plakaYeni,
        'adSoyad': ad,
        'ad': ad,
      };
      if (telEski.isNotEmpty && telEski != telYeni) {
        final eskiDoc = await _kullanicilarRef.doc(telEski).get();
        if (eskiDoc.exists && eskiDoc.data() != null) {
          final eski = Map<String, dynamic>.from(eskiDoc.data()! as Map);
          if (eski['fotoUrl'] != null) veri['fotoUrl'] = eski['fotoUrl'];
          if (eski['belgeler'] != null) veri['belgeler'] = eski['belgeler'];
        }
      }
      await _kullanicilarRef.doc(telYeni).set(veri, SetOptions(merge: true));
    }

    if (plakaEski.isNotEmpty && plakaYeni.isNotEmpty && plakaEski != plakaYeni) {
      await globalPlakaGuncelle(
        esnafId: esnafId,
        eskiPlaka: plakaEski,
        yeniPlaka: plakaYeni,
      );
      await _plakaliRandevulariTasi(esnafId, plakaEski, plakaYeni);
    }

    await _personelKaydiniHizala(
      esnafId: esnafId,
      eskiPlaka: plakaEski,
      yeniPlaka: plakaYeni,
      yeniAd: ad,
    );
    await _bekleyenCagrilariHizala(
      esnafId: esnafId,
      eskiTel: telEski,
      yeniTel: telYeni,
      eskiPlaka: plakaEski,
      yeniPlaka: plakaYeni,
    );
  }

  Future<void> _plakaliRandevulariTasi(String esnafId, String eskiPlaka, String yeniPlaka) async {
    final snap = await _randevularRef
        .where('esnafId', isEqualTo: esnafId)
        .where('randevu_kanali', isEqualTo: eskiPlaka)
        .get();
    WriteBatch batch = _db.batch();
    var sayac = 0;
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'randevu_kanali': yeniPlaka,
        'guncellemeTarihi': FieldValue.serverTimestamp(),
      });
      sayac++;
      if (sayac == 400) {
        await batch.commit();
        batch = _db.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();
  }

  Future<void> _personelKaydiniHizala({
    required String esnafId,
    required String eskiPlaka,
    required String yeniPlaka,
    required String yeniAd,
  }) async {
    if (eskiPlaka.isEmpty && yeniPlaka.isEmpty) return;
    final doc = await _esnaflarRef.doc(esnafId).get();
    if (!doc.exists || doc.data() == null) return;
    final data = Map<String, dynamic>.from(doc.data()! as Map);
    final ham = data['personeller'];
    if (ham is! List) return;
    var degisti = false;
    final yeniListe = ham.map((p) {
      final kayit = Map<String, dynamic>.from(p as Map);
      final isim = (kayit['isim'] ?? '').toString().trim().toUpperCase();
      if (isim == eskiPlaka || (yeniPlaka.isNotEmpty && isim == yeniPlaka)) {
        kayit['isim'] = yeniPlaka;
        kayit['kanal'] = yeniAd;
        degisti = true;
      }
      return kayit;
    }).toList();
    if (degisti) {
      await _esnaflarRef.doc(esnafId).update({'personeller': yeniListe});
    }
  }

  Future<void> _bekleyenCagrilariHizala({
    required String esnafId,
    required String eskiTel,
    required String yeniTel,
    required String eskiPlaka,
    required String yeniPlaka,
  }) async {
    final snap = await _db.collection('taksi_talepleri').where('esnafId', isEqualTo: esnafId).get();
    const bekleyen = {'bekliyor', 'Bekliyor', 'Beklemede'};
    WriteBatch batch = _db.batch();
    var sayac = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final durum = (data['durum'] ?? '').toString();
      if (!bekleyen.contains(durum)) continue;
      final plaka = (data['plaka'] ?? '').toString().trim().toUpperCase();
      final tel = (data['soforTel'] ?? '').toString().trim();
      final plakaEslesir = eskiPlaka.isNotEmpty && plaka == eskiPlaka;
      final telEslesir = eskiTel.isNotEmpty && tel == eskiTel;
      if (!plakaEslesir && !telEslesir) continue;
      final guncel = <String, dynamic>{};
      if (plakaEslesir && yeniPlaka.isNotEmpty) guncel['plaka'] = yeniPlaka;
      if (telEslesir && yeniTel.isNotEmpty) guncel['soforTel'] = yeniTel;
      if (guncel.isEmpty) continue;
      batch.update(doc.reference, guncel);
      sayac++;
      if (sayac == 400) {
        await batch.commit();
        batch = _db.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();
  }

  Future<void> kullaniciProfiliniGuncelle(String tel, Map<String, dynamic> veri) async {
    for (final id in telefonYazimlari(tel)) {
      if (id.isEmpty) continue;
      await _kullanicilarRef.doc(id).set(veri, SetOptions(merge: true));
    }
  }

  Future<void> kullaniciKaydiSil(String telefon) async {
    for (final id in telefonYazimlari(telefon)) {
      if (id.isEmpty) continue;
      await _kullanicilarRef.doc(id).delete();
    }
    final basvuruId = musteriTelefonAnahtari(telefon);
    if (basvuruId.isNotEmpty) {
      final basvuru = await _esnafBasvuruRef.doc(basvuruId).get();
      final veri = basvuru.data();
      if (basvuru.exists && veri is Map && veri['durum']?.toString() == 'Bekliyor') {
        await basvuru.reference.set({
          'durum': 'İptal',
          'guncelleme': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await _calisanBasvuruRef.doc(basvuruId).delete();
    }
  }

  Future<void> belgeYukle(String tel, String belgeTuru, String url) async {
    await _kullanicilarRef.doc(tel).set({
      'belgeler': {
        belgeTuru: {
          'url': url,
          'status': 'Bekliyor',
          'tarih': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));
  }

  Future<void> belgeOnayla(String tel, String belgeTuru, bool onay) async {
    await _kullanicilarRef.doc(tel).set({
      'belgeler': {
        belgeTuru: {
          'status': onay ? 'Onaylandı' : 'Reddedildi',
          'onayTarihi': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));
  }

  Future<void> belgeSil(String tel, String belgeTuru) async {
    await _kullanicilarRef.doc(tel).update({
      'belgeler.$belgeTuru': FieldValue.delete(),
    });
  }

  // --- STORAGE İŞLEMLERİ ---
  Future<String?> dosyaYukle(dynamic dosyaVerisi, String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);
      UploadTask uploadTask;
      
      if (dosyaVerisi is File) {
        uploadTask = storageRef.putFile(dosyaVerisi);
      } else if (dosyaVerisi is Uint8List) {
        uploadTask = storageRef.putData(dosyaVerisi);
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Storage Yükleme Hatası: $e");
      return null;
    }
  }

  /// Taksi randevu ekranı için yerel mekan araması.
  /// İlk kelimeyle geniş prefix sorgusu yapıp, tüm kelimeleri istemci tarafında
  /// büyük/küçük harf duyarsız önek eşleşmesiyle süzüyoruz ("hayal vad" → "Hayal Vadisi").
  Future<List<String>> mekanArama(String sorgu) async {
    try {
      String q = sorgu.trim();
      if (q.isEmpty) return [];
      
      final kelimeler = q
          .toLowerCase()
          .replaceAll('İ', 'i')
          .replaceAll('I', 'ı')
          .split(RegExp(r'\s+'))
          .where((k) => k.isNotEmpty)
          .toList();
      if (kelimeler.isEmpty) return [];

      // Firestore case-sensitive: ilk kelimenin birden fazla yazımını dene
      final ilk = kelimeler.first;
      final varyantlar = <String>{
        ilk,
        ilk[0].toUpperCase() + ilk.substring(1),
        ilk.toUpperCase(),
        // Türkçe İ/I ayrımı
        ilk.replaceAll('i', 'İ').replaceAll('ı', 'I'),
        (ilk[0].toUpperCase() + ilk.substring(1))
            .replaceAll('i', 'İ')
            .replaceAll('ı', 'I'),
      }.toList();

      final results = await Future.wait(
        varyantlar.map((v) => _esnaflarRef
            .where('isletmeAdi', isGreaterThanOrEqualTo: v)
            .where('isletmeAdi', isLessThanOrEqualTo: '$v\u{f8ff}')
            .limit(15)
            .get()),
      );

      String normalize(String s) {
        var t = s
            .replaceAll('İ', 'i')
            .replaceAll('I', 'ı')
            .toLowerCase()
            .replaceAll('ş', 's')
            .replaceAll('ğ', 'g')
            .replaceAll('ü', 'u')
            .replaceAll('ö', 'o')
            .replaceAll('ç', 'c')
            .replaceAll('\u0307', '');
        return t;
      }

      bool eslesiyor(String ad) {
        final adNorm = normalize(ad);
        final adKelimeler = adNorm.split(RegExp(r'[\s,./\-]+')).where((k) => k.isNotEmpty).toList();
        // Her sorgu kelimesi, işletme adındaki bir kelimenin öneki veya parçası olmalı
        for (final sk in kelimeler.map(normalize)) {
          if (sk.isEmpty) continue;
          final ok = adKelimeler.any((ak) => ak.startsWith(sk) || ak.contains(sk)) || adNorm.contains(sk);
          if (!ok) return false;
        }
        return true;
      }
      
      Set<String> sonuclar = {};
      for (var snap in results) {
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ad = (data['isletmeAdi'] ?? "").toString();
          if (ad.isEmpty || !eslesiyor(ad)) continue;
          final ilce = data['ilce'] ?? "";
          sonuclar.add("$ad, $ilce, Trabzon");
          if (sonuclar.length >= 8) break;
        }
        if (sonuclar.length >= 8) break;
      }
      return sonuclar.toList();
    } catch (e) {
      debugPrint("Mekan Arama Hatası: $e");
      return [];
    }
  }

  Stream<List<MacIlani>> macIlanlariDinle() {
    return _macIlanRef.snapshots().map((snap) {
      return snap.docs
          .map((d) => MacIlani.fromMap(d.id, Map<String, dynamic>.from(d.data() as Map)))
          .toList();
    });
  }

  Future<String> _macAdi(String telefon) async {
    final veri = await kullaniciKaydiBul(telefon) ?? {};
    final ad = (veri['adSoyad'] ?? veri['ad'] ?? '').toString().trim();
    return ad.isEmpty ? 'İsimsiz' : ad;
  }

  Future<void> _macBildir(String telefon, String metin) async {
    if (telefon.trim().isEmpty || metin.trim().isEmpty) return;
    try {
      await BildirimServisi.bildirimGonder(
        baslik: 'Oyuncu veya Rakip Bul',
        icerik: metin,
        kullaniciTel: telefon,
      );
    } catch (e) {
      debugPrint('Maç bildirimi gitmedi: $e');
    }
  }

  List<Map<String, dynamic>> _macKatilanlar(dynamic ham) {
    if (ham is! List) return [];
    final liste = <Map<String, dynamic>>[];
    for (final e in ham) {
      if (e is! Map) continue;
      final kayit = Map<String, dynamic>.from(e);
      if ((kayit['tel'] ?? '').toString().isEmpty) continue;
      liste.add(kayit);
    }
    return liste;
  }

  Future<String?> macIlaniAc({
    required String telefon,
    required String esnafId,
    required String isletmeAdi,
    required String tur,
    required String tarih,
    required String saat,
    String saha = '',
    int kacKisi = 0,
    String takimAdi = '',
    int oyuncuSayisi = 0,
    String notu = '',
  }) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    if (esnafId.trim().isEmpty) return 'Saha seçin.';
    if (tur != 'eksik' && tur != 'takim' && tur != 'oyuncu' && tur != 'rakip' && tur != 'kaleci' && tur != 'kaleci_ara') {
      return 'Ne aradığınızı seçin.';
    }
    if (tarih.trim().isEmpty || saat.trim().isEmpty) return 'Tarih ve saat seçin.';
    final an = DateTime.tryParse('$tarih $saat');
    if (an == null) return 'Tarih geçersiz.';
    if (an.isBefore(DateTime.now())) return 'Geçmiş saate istek yazılmaz.';
    if (tur == 'eksik' && (kacKisi < 1 || kacKisi > 21)) return 'Kaç kişi lazım, 1 ile 21 arasında olsun.';
    if (tur == 'takim' || tur == 'rakip') {
      if (takimAdi.trim().length < 2) return 'Takım adını yazın.';
      if (oyuncuSayisi < 5 || oyuncuSayisi > 14) return 'Oyuncu sayısı 5 ile 14 arasında olsun.';
    }
    final ad = await _macAdi(telefon);
    try {
      await _macIlanRef.add({
        'tur': tur,
        'durum': 'Açık',
        'esnafId': esnafId,
        'isletmeAdi': isletmeAdi.trim(),
        'saha': saha.trim(),
        'tarih': tarih,
        'saat': saat,
        'acanTel': anahtar,
        'acanAd': ad,
        'kacKisi': tur == 'eksik' ? kacKisi : (tur == 'kaleci_ara' ? 1 : 0),
        'katilanlar': <Map<String, dynamic>>[],
        'takimAdi': (tur == 'takim' || tur == 'rakip') ? takimAdi.trim() : '',
        'oyuncuSayisi': (tur == 'takim' || tur == 'rakip') ? oyuncuSayisi : 0,
        'rakipTakimAdi': '',
        'rakipTel': '',
        'rakipTelYazi': '',
        'rakipAd': '',
        'cagiranTel': '',
        'cagiranTelYazi': '',
        'cagiranAd': '',
        'cagiranTakim': '',
        'not': notu.trim(),
        'olusturma': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('Maç ilanı açılamadı: $e');
      return 'İstek yazılamadı.';
    }
  }

  Future<String?> macIlaninaKatil(String ilanId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    final ad = await _macAdi(telefon);
    try {
      final bilgi = await _db.runTransaction<({String? hata, String acan, bool doldu, bool kaleci})>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return (hata: 'İstek yok.', acan: '', doldu: false, kaleci: false);
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        final tur = (veri['tur'] ?? '').toString();
        if (tur != 'eksik' && tur != 'kaleci_ara') return (hata: 'Bu istek katılım beklemiyor.', acan: '', doldu: false, kaleci: false);
        if (veri['durum'] != 'Açık') return (hata: 'İstek kapandı.', acan: '', doldu: false, kaleci: false);
        if (veri['acanTel'] == anahtar) return (hata: 'Kendi isteğinize katılamazsınız.', acan: '', doldu: false, kaleci: false);
        final katilan = _macKatilanlar(veri['katilanlar']);
        if (katilan.any((k) => k['tel'] == anahtar)) return (hata: 'Zaten katıldınız.', acan: '', doldu: false, kaleci: false);
        final kac = (veri['kacKisi'] as num?)?.toInt() ?? 0;
        if (katilan.length >= kac) return (hata: 'Yer kalmadı.', acan: '', doldu: false, kaleci: false);
        katilan.add({'tel': anahtar, 'telYazi': telefon.trim(), 'ad': ad});
        final doldu = katilan.length >= kac;
        tx.update(ref, {'katilanlar': katilan, 'durum': doldu ? 'Doldu' : 'Açık'});
        return (hata: null, acan: (veri['acanTel'] ?? '').toString(), doldu: doldu, kaleci: tur == 'kaleci_ara');
      });
      if (bilgi.hata != null) return bilgi.hata;
      await _macBildir(
        bilgi.acan,
        bilgi.kaleci ? '$ad kaleci olarak katıldı.' : (bilgi.doldu ? '$ad katıldı. Yer kalmadı.' : '$ad isteğinize katıldı.'),
      );
      return null;
    } catch (e) {
      debugPrint('Maça katılınamadı: $e');
      return 'Katılınamadı.';
    }
  }

  Future<String?> macIlanindanAyril(String ilanId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    final ad = await _macAdi(telefon);
    try {
      final acan = await _db.runTransaction<String>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return '';
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        if (veri['tur'] != 'eksik' && veri['tur'] != 'kaleci_ara') return '';
        if (veri['durum'] != 'Açık' && veri['durum'] != 'Doldu') return '';
        final katilan = _macKatilanlar(veri['katilanlar']);
        final once = katilan.length;
        katilan.removeWhere((k) => k['tel'] == anahtar);
        if (katilan.length == once) return '';
        tx.update(ref, {'katilanlar': katilan, 'durum': 'Açık'});
        return (veri['acanTel'] ?? '').toString();
      });
      if (acan.isEmpty) return 'Bu istekten ayrılamazsınız.';
      await _macBildir(acan, '$ad istekten ayrıldı.');
      return null;
    } catch (e) {
      debugPrint('Maçtan ayrılınamadı: $e');
      return 'Ayrılınamadı.';
    }
  }

  Future<String?> macRakipKabul(String ilanId, String telefon, String takimAdi) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    final rakipAdi = takimAdi.trim();
    if (rakipAdi.length < 2) return 'Takım adını yazın.';
    final ad = await _macAdi(telefon);
    try {
      final acan = await _db.runTransaction<String>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return 'yok';
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        if (veri['tur'] != 'takim') return 'tur';
        if (veri['durum'] != 'Açık') return 'kapali';
        if (veri['acanTel'] == anahtar) return 'kendi';
        if ((veri['rakipTel'] ?? '').toString().isNotEmpty) return 'dolu';
        tx.update(ref, {
          'rakipTakimAdi': rakipAdi,
          'rakipTel': anahtar,
          'rakipTelYazi': telefon.trim(),
          'rakipAd': ad,
          'durum': 'Eşleşti',
        });
        return (veri['acanTel'] ?? '').toString();
      });
      if (acan == 'yok') return 'İstek yok.';
      if (acan == 'tur') return 'Bu kişi rakip aramıyor.';
      if (acan == 'kapali') return 'İstek kapandı.';
      if (acan == 'kendi') return 'Kendi isteğinize rakip olamazsınız.';
      if (acan == 'dolu') return 'Rakip belli oldu.';
      await _macBildir(acan, '$rakipAdi rakip olarak kabul etti.');
      return null;
    } catch (e) {
      debugPrint('Rakip kabul edilemedi: $e');
      return 'Kabul edilemedi.';
    }
  }

  Future<String?> macRakipVazgec(String ilanId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    try {
      final acan = await _db.runTransaction<String>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return '';
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        if (veri['durum'] != 'Eşleşti') return '';
        if (veri['rakipTel'] != anahtar) return '';
        tx.update(ref, {
          'rakipTakimAdi': '',
          'rakipTel': '',
          'rakipTelYazi': '',
          'rakipAd': '',
          'durum': 'Açık',
        });
        return (veri['acanTel'] ?? '').toString();
      });
      if (acan.isEmpty) return 'Bu eşleşmeden vazgeçemezsiniz.';
      await _macBildir(acan, 'Rakip takım vazgeçti. İstek yeniden açık.');
      return null;
    } catch (e) {
      debugPrint('Rakip vazgeçemedi: $e');
      return 'Vazgeçilemedi.';
    }
  }

  Future<String?> macIlaniIptal(String ilanId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    try {
      final hedefler = await _db.runTransaction<List<String>>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return [];
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        if (veri['acanTel'] != anahtar) return [];
        if (veri['durum'] == 'İptal') return [];
        final kisiler = <String>[];
        final rakip = (veri['rakipTel'] ?? '').toString();
        if (rakip.isNotEmpty) kisiler.add(rakip);
        final cagiran = (veri['cagiranTel'] ?? '').toString();
        if (cagiran.isNotEmpty) kisiler.add(cagiran);
        for (final k in _macKatilanlar(veri['katilanlar'])) {
          final tel = (k['tel'] ?? '').toString();
          if (tel.isNotEmpty) kisiler.add(tel);
        }
        tx.update(ref, {'durum': 'İptal'});
        return kisiler;
      });
      if (hedefler.isEmpty) {
        final snap = await _macIlanRef.doc(ilanId).get();
        final veri = snap.data();
        if (veri is Map && veri['durum'] == 'İptal' && veri['acanTel'] == anahtar) return null;
        return 'İsteği yalnızca yazan kişi kaldırır.';
      }
      for (final tel in hedefler) {
        await _macBildir(tel, 'Maç isteği kaldırıldı.');
      }
      return null;
    } catch (e) {
      debugPrint('Maç ilanı kapanmadı: $e');
      return 'İstek kaldırılamadı.';
    }
  }

  Future<String?> macCagir(String ilanId, String telefon, {String takimAdi = ''}) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    final cagiranTakim = takimAdi.trim();
    final ad = await _macAdi(telefon);
    try {
      final sonuc = await _db.runTransaction<String>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return 'yok';
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        final tur = (veri['tur'] ?? '').toString();
        if (tur != 'oyuncu' && tur != 'rakip' && tur != 'kaleci') return 'tur';
        if (veri['durum'] != 'Açık') return 'kapali';
        if (veri['acanTel'] == anahtar) return 'kendi';
        if ((veri['cagiranTel'] ?? '').toString().isNotEmpty) return 'dolu';
        if ((tur == 'rakip' || tur == 'oyuncu') && cagiranTakim.length < 2) return 'takim';
        tx.update(ref, {
          'cagiranTel': anahtar,
          'cagiranTelYazi': telefon.trim(),
          'cagiranAd': ad,
          'cagiranTakim': (tur == 'rakip' || tur == 'oyuncu') ? cagiranTakim : '',
          'durum': 'Çağrıldı',
        });
        return '${veri['acanTel'] ?? ''}|$tur';
      });
      if (sonuc == 'yok') return 'İstek yok.';
      if (sonuc == 'tur') return 'Bu kişi çağrı beklemiyor.';
      if (sonuc == 'kapali') return 'İstek kapandı.';
      if (sonuc == 'kendi') return 'Kendinizi çağıramazsınız.';
      if (sonuc == 'dolu') return 'Bu kişi çağrıldı.';
      if (sonuc == 'takim') return 'Takım adını yazın.';
      final parca = sonuc.split('|');
      final acan = parca.first;
      final tur = parca.length > 1 ? parca[1] : '';
      final metin = tur == 'rakip'
          ? '$cagiranTakim sizi rakip olarak çağırdı.'
          : tur == 'oyuncu'
              ? '$cagiranTakim sizi takımına çağırdı.'
              : '$ad sizi kaleci olarak çağırdı.';
      await _macBildir(acan, metin);
      return null;
    } catch (e) {
      debugPrint('Çağrı gitmedi: $e');
      return 'Çağrılamadı.';
    }
  }

  Future<String?> macCagriVazgec(String ilanId, String telefon) async {
    final anahtar = musteriTelefonAnahtari(telefon);
    if (anahtar.isEmpty) return 'Giriş yapın.';
    try {
      final acan = await _db.runTransaction<String>((tx) async {
        final ref = _macIlanRef.doc(ilanId);
        final snap = await tx.get(ref);
        if (!snap.exists) return '';
        final veri = Map<String, dynamic>.from(snap.data() as Map);
        if (veri['durum'] != 'Çağrıldı') return '';
        if (veri['cagiranTel'] != anahtar) return '';
        tx.update(ref, {
          'cagiranTel': '',
          'cagiranTelYazi': '',
          'cagiranAd': '',
          'cagiranTakim': '',
          'durum': 'Açık',
        });
        return (veri['acanTel'] ?? '').toString();
      });
      if (acan.isEmpty) return 'Bu çağrıdan vazgeçemezsiniz.';
      await _macBildir(acan, 'Çağrı kalktı. İstek yeniden açık.');
      return null;
    } catch (e) {
      debugPrint('Çağrıdan vazgeçilemedi: $e');
      return 'Vazgeçilemedi.';
    }
  }
}
