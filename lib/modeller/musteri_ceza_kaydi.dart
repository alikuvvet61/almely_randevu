import 'package:cloud_firestore/cloud_firestore.dart';

/// Esnaf bazında müşteri geç iptal / gelmedi sayacı ve kara liste bayrağı.
class MusteriCezaKaydi {
  final String id;
  final String esnafId;
  final String telefon;
  final String ad;
  final int gecIptal;
  final int gelmedi;
  final bool karaListede;
  final String? sonNot;

  const MusteriCezaKaydi({
    required this.id,
    required this.esnafId,
    required this.telefon,
    this.ad = '',
    this.gecIptal = 0,
    this.gelmedi = 0,
    this.karaListede = false,
    this.sonNot,
  });

  int get toplam => gecIptal + gelmedi;

  factory MusteriCezaKaydi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MusteriCezaKaydi(
      id: doc.id,
      esnafId: data['esnafId'] ?? '',
      telefon: data['telefon'] ?? '',
      ad: data['ad'] ?? '',
      gecIptal: (data['gecIptal'] as num?)?.toInt() ?? 0,
      gelmedi: (data['gelmedi'] as num?)?.toInt() ?? 0,
      karaListede: data['karaListede'] == true,
      sonNot: data['sonNot'],
    );
  }
}
