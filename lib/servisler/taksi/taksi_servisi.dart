import 'package:cloud_firestore/cloud_firestore.dart';

class TaksiServisi {
  final FirebaseFirestore _firestore;

  TaksiServisi({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> talepGonder({
    required String esnafId,
    required String kullaniciAd,
    required String kullaniciTel,
    required String nereden,
    required String nereye,
    GeoPoint? konum,
  }) async {
    await _firestore.collection('taksi_talepleri').add({
      'esnafId': esnafId,
      'kullaniciAd': kullaniciAd,
      'kullaniciTel': kullaniciTel,
      'nereden': nereden,
      'nereye': nereye,
      'konum': konum,
      'durum': 'Bekliyor',
      'olusturulmaTarihi': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> talepleriDinle(String esnafId) {
    return _firestore
        .collection('taksi_talepleri')
        .where('esnafId', isEqualTo: esnafId)
        .orderBy('olusturulmaTarihi', descending: true)
        .snapshots();
  }

  Future<void> talepDurumGuncelle(String talepId, String durum) async {
    await _firestore.collection('taksi_talepleri').doc(talepId).update({
      'durum': durum,
    });
  }
}
