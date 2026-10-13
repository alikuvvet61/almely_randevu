import 'package:cloud_firestore/cloud_firestore.dart';

/// Kanal veya hizmet adı değişince bugünü ve geleceği yeni ada taşır.
/// Bitmiş randevu ile geçmiş ajanda eski adıyla kalır.
class AdDegisimi {
  static String? yeni(Map<String, String> harita, String eski) {
    final temiz = eski.trim();
    if (temiz.isEmpty) return null;
    final dogrudan = harita[temiz];
    if (dogrudan != null && dogrudan.trim().isNotEmpty) return dogrudan.trim();
    final alt = temiz.toLowerCase();
    for (final kayit in harita.entries) {
      if (kayit.key.trim().toLowerCase() == alt && kayit.value.trim().isNotEmpty) {
        return kayit.value.trim();
      }
    }
    return null;
  }

  static String? hizmetMetniniGuncelle(Map<String, String> harita, String mevcut) {
    final tam = yeni(harita, mevcut);
    if (tam != null) return tam;
    if (!mevcut.contains(' + ')) return null;
    var degisti = false;
    final parcalar = mevcut.split(' + ').map((parca) {
      final ad = yeni(harita, parca);
      if (ad == null) return parca.trim();
      degisti = true;
      return ad;
    }).toList();
    if (!degisti) return null;
    return parcalar.join(' + ');
  }

  static bool bugunVeyaSonrasi(DateTime tarih) {
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final gun = DateTime(tarih.year, tarih.month, tarih.day);
    return !gun.isBefore(bugun);
  }

  static Future<void> kanaliYay({
    required String esnafId,
    required Map<String, String> degisimler,
  }) async {
    if (esnafId.isEmpty || degisimler.isEmpty) return;
    await _ajandayiTasi(esnafId, degisimler);
    await _randevuKanaliniYaz(esnafId, degisimler);
    await _beklemeKanaliniYaz(esnafId, degisimler);
  }

  static Future<void> hizmetiYay({
    required String esnafId,
    required Map<String, String> degisimler,
  }) async {
    if (esnafId.isEmpty || degisimler.isEmpty) return;
    await _randevuHizmetiniYaz(esnafId, degisimler);
    await _beklemeHizmetiniYaz(esnafId, degisimler);
    await _paketHizmetiniYaz(esnafId, degisimler);
  }

  static Future<void> _ajandayiTasi(String esnafId, Map<String, String> degisimler) async {
    final db = FirebaseFirestore.instance;
    final esnafRef = db.collection('esnaflar').doc(esnafId);
    final esnafSnap = await esnafRef.get();
    final aktifHam = esnafSnap.data()?['aktifGunler'];
    final aktif = aktifHam is List ? aktifHam.map((e) => e.toString()).toList() : <String>[];

    final ajandaSnap = await esnafRef.collection('ajanda').get();
    final bellek = <String, Map<String, dynamic>>{};
    final silinecek = <String>[];

    for (final doc in ajandaSnap.docs) {
      final veri = Map<String, dynamic>.from(doc.data());
      final parca = _parcala(doc.id);
      final tarihYazi = parca?.tarih ?? veri['tarih']?.toString();
      final tarih = tarihYazi == null ? null : DateTime.tryParse(tarihYazi);
      if (tarih == null || !bugunVeyaSonrasi(tarih)) continue;

      final kendi = (parca?.kanal ?? veri['kanal'] ?? '').toString();
      final yeniKanal = yeni(degisimler, kendi);
      _listeleriUygula(veri, degisimler);
      if (yeniKanal != null) veri['kanal'] = yeniKanal;

      final hedefId = (parca != null && yeniKanal != null) ? '${parca.tarih}_$yeniKanal' : doc.id;
      if (hedefId != doc.id) silinecek.add(doc.id);
      bellek[hedefId] = _birlestir(bellek[hedefId], veri);
    }

    final yigin = _Yigin();
    for (final kayit in bellek.entries) {
      final ref = esnafRef.collection('ajanda').doc(kayit.key);
      await yigin.yaz((b) => b.set(ref, kayit.value, SetOptions(merge: true)));
    }
    final hedefler = bellek.keys.toSet();
    for (final id in silinecek.toSet()) {
      if (hedefler.contains(id)) continue;
      await yigin.yaz((b) => b.delete(esnafRef.collection('ajanda').doc(id)));
    }

    final yeniAktif = <String>[];
    final gorulen = <String>{};
    for (final id in aktif) {
      final hedef = _aktifHedef(id, degisimler);
      if (gorulen.add(hedef)) yeniAktif.add(hedef);
    }
    final ayni = aktif.length == yeniAktif.length &&
        aktif.asMap().entries.every((e) => e.value == yeniAktif[e.key]);
    if (!ayni) {
      await yigin.yaz((b) => b.update(esnafRef, {'aktifGunler': yeniAktif}));
    }
    await yigin.bitir();
  }

  static Future<void> _randevuKanaliniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('randevular').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_canliKayit(data)) continue;
      final mevcut = (data['randevu_kanali'] ?? data['kanal'] ?? '').toString();
      final ad = yeni(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'randevu_kanali': ad}));
    }
    await yigin.bitir();
  }

  static Future<void> _beklemeKanaliniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('bekleme_listesi').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_canliBekleme(data)) continue;
      final mevcut = (data['randevuKanali'] ?? '').toString();
      final ad = yeni(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'randevuKanali': ad}));
    }
    await yigin.bitir();
  }

  static Future<void> personeliYay({
    required String esnafId,
    required Map<String, String> degisimler,
  }) async {
    if (esnafId.isEmpty || degisimler.isEmpty) return;
    await _alanYaz(
      koleksiyon: 'randevular',
      esnafId: esnafId,
      degisimler: degisimler,
      alan: 'calisan_personel',
      canli: _canliKayit,
    );
    await _alanYaz(
      koleksiyon: 'bekleme_listesi',
      esnafId: esnafId,
      degisimler: degisimler,
      alan: 'calisanPersonel',
      canli: _canliBekleme,
    );
    await _ajandaPersoneliniYaz(esnafId, degisimler);
  }

  static Future<void> isletmeAdiniYay({
    required String esnafId,
    required String eski,
    required String yeniAd,
  }) async {
    final ad = yeniAd.trim();
    if (esnafId.isEmpty || eski.trim().isEmpty || ad.isEmpty || eski.trim() == ad) return;
    final harita = {eski.trim(): ad};
    await _alanYaz(
      koleksiyon: 'randevular',
      esnafId: esnafId,
      degisimler: harita,
      alan: 'esnafAdi',
      canli: _canliKayit,
    );
    await _alanYaz(
      koleksiyon: 'bekleme_listesi',
      esnafId: esnafId,
      degisimler: harita,
      alan: 'esnafAdi',
      canli: _canliBekleme,
    );
    await _paketEsnafAdiniYaz(esnafId, harita);
  }

  static Future<void> _alanYaz({
    required String koleksiyon,
    required String esnafId,
    required Map<String, String> degisimler,
    required String alan,
    required bool Function(Map<String, dynamic>) canli,
  }) async {
    final snap = await FirebaseFirestore.instance.collection(koleksiyon).where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!canli(data)) continue;
      final mevcut = (data[alan] ?? '').toString();
      final ad = yeni(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {alan: ad}));
    }
    await yigin.bitir();
  }

  static Future<void> _ajandaPersoneliniYaz(String esnafId, Map<String, String> degisimler) async {
    final esnafRef = FirebaseFirestore.instance.collection('esnaflar').doc(esnafId);
    final snap = await esnafRef.collection('ajanda').get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final veri = Map<String, dynamic>.from(doc.data());
      final parca = _parcala(doc.id);
      final tarihYazi = parca?.tarih ?? veri['tarih']?.toString();
      final tarih = tarihYazi == null ? null : DateTime.tryParse(tarihYazi);
      if (tarih == null || !bugunVeyaSonrasi(tarih)) continue;
      final personeller = veri['personeller'];
      if (personeller is! List) continue;
      var degisti = false;
      final yeniListe = personeller.map((p) {
        if (p is! Map) return p;
        final kayit = Map<String, dynamic>.from(p);
        final ad = yeni(degisimler, (kayit['isim'] ?? '').toString());
        if (ad == null) return kayit;
        kayit['isim'] = ad;
        degisti = true;
        return kayit;
      }).toList();
      if (!degisti) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'personeller': yeniListe}));
    }
    await yigin.bitir();
  }

  static Future<void> _paketEsnafAdiniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('musteri_paketleri').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['durum'] ?? '').toString() != 'aktif') continue;
      final kalan = (data['kalanSeans'] as num?)?.toInt() ?? 0;
      if (kalan <= 0) continue;
      final bitis = data['bitis'];
      if (bitis is Timestamp && bitis.toDate().isBefore(DateTime.now())) continue;
      final mevcut = (data['esnafAdi'] ?? '').toString();
      final ad = yeni(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'esnafAdi': ad}));
    }
    await yigin.bitir();
  }

  static Future<void> _randevuHizmetiniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('randevular').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_canliKayit(data)) continue;
      final mevcut = (data['hizmetAdi'] ?? '').toString();
      final ad = hizmetMetniniGuncelle(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'hizmetAdi': ad}));
    }
    await yigin.bitir();
  }

  static Future<void> _beklemeHizmetiniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('bekleme_listesi').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (!_canliBekleme(data)) continue;
      final mevcut = (data['hizmetAdi'] ?? '').toString();
      final ad = hizmetMetniniGuncelle(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'hizmetAdi': ad}));
    }
    await yigin.bitir();
  }

  static Future<void> _paketHizmetiniYaz(String esnafId, Map<String, String> degisimler) async {
    final snap = await FirebaseFirestore.instance.collection('musteri_paketleri').where('esnafId', isEqualTo: esnafId).get();
    final yigin = _Yigin();
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['durum'] ?? '').toString() != 'aktif') continue;
      final kalan = (data['kalanSeans'] as num?)?.toInt() ?? 0;
      if (kalan <= 0) continue;
      final bitis = data['bitis'];
      if (bitis is Timestamp && bitis.toDate().isBefore(DateTime.now())) continue;
      final mevcut = (data['hizmetAdi'] ?? '').toString();
      final ad = yeni(degisimler, mevcut);
      if (ad == null || ad == mevcut.trim()) continue;
      await yigin.yaz((b) => b.update(doc.reference, {'hizmetAdi': ad}));
    }
    await yigin.bitir();
  }

  static bool _canliKayit(Map<String, dynamic> data) {
    const bitmis = {'İptal Edildi', 'Reddedildi', 'Tamamlandı', 'Gelmedi'};
    if (bitmis.contains((data['durum'] ?? '').toString())) return false;
    if ((data['durum'] ?? '').toString() == 'Kullanımda') return true;
    final tarih = data['tarih'];
    if (tarih is! Timestamp) return false;
    return bugunVeyaSonrasi(tarih.toDate());
  }

  static bool _canliBekleme(Map<String, dynamic> data) {
    const acik = {'bekliyor', 'bildirildi'};
    if (!acik.contains((data['durum'] ?? '').toString())) return false;
    final tarih = data['tarih'];
    if (tarih is! Timestamp) return false;
    return bugunVeyaSonrasi(tarih.toDate());
  }

  static _AjandaParca? _parcala(String id) {
    if (id.length < 11 || id[10] != '_') return null;
    final tarih = id.substring(0, 10);
    if (DateTime.tryParse(tarih) == null) return null;
    return _AjandaParca(tarih, id.substring(11));
  }

  static String _aktifHedef(String id, Map<String, String> degisimler) {
    final parca = _parcala(id);
    if (parca == null) return id;
    final tarih = DateTime.tryParse(parca.tarih);
    if (tarih == null || !bugunVeyaSonrasi(tarih)) return id;
    final ad = yeni(degisimler, parca.kanal);
    if (ad == null) return id;
    return '${parca.tarih}_$ad';
  }

  static void _listeleriUygula(Map<String, dynamic> veri, Map<String, String> degisimler) {
    final kanallar = veri['kanallar'];
    if (kanallar is List) {
      veri['kanallar'] = kanallar.map((e) {
        final ad = yeni(degisimler, e.toString());
        return ad ?? e;
      }).toList();
    }
    final personeller = veri['personeller'];
    if (personeller is List) {
      veri['personeller'] = personeller.map((p) {
        if (p is! Map) return p;
        final kayit = Map<String, dynamic>.from(p);
        final ad = yeni(degisimler, (kayit['kanal'] ?? '').toString());
        if (ad != null) kayit['kanal'] = ad;
        return kayit;
      }).toList();
    }
  }

  static Map<String, dynamic> _birlestir(Map<String, dynamic>? onceki, Map<String, dynamic> gelen) {
    if (onceki == null) return gelen;
    final kapali = Map<String, dynamic>.from(onceki['kapaliSlotlar'] ?? {});
    kapali.addAll(Map<String, dynamic>.from(gelen['kapaliSlotlar'] ?? {}));
    gelen['kapaliSlotlar'] = kapali;
    return gelen;
  }
}

class _AjandaParca {
  final String tarih;
  final String kanal;
  const _AjandaParca(this.tarih, this.kanal);
}

class _Yigin {
  WriteBatch batch = FirebaseFirestore.instance.batch();
  int sayi = 0;

  Future<void> yaz(void Function(WriteBatch batch) islem) async {
    islem(batch);
    sayi++;
    if (sayi >= 400) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      sayi = 0;
    }
  }

  Future<void> bitir() async {
    if (sayi > 0) await batch.commit();
  }
}
