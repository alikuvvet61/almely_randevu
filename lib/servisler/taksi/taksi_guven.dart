import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Yolcunun plakada BELGELİ görmesi için durağın onayladığı belgeler.
const List<String> taksiZorunluBelgeler = ['ehliyet', 'ruhsat', 'sigorta', 'taksimetre_belge'];

const Map<String, String> taksiBelgeAdlari = {
  'ehliyet': 'Ehliyet',
  'ruhsat': 'Ruhsat',
  'sigorta': 'Sigorta',
  'taksimetre_belge': 'Taksimetre',
};

bool taksiBelgeli(dynamic belgeler) {
  if (belgeler is! Map) return false;
  for (final tur in taksiZorunluBelgeler) {
    final belge = belgeler[tur];
    if (belge is! Map || (belge['status'] ?? '').toString() != 'Onaylandı') return false;
  }
  return true;
}

String taksiSaatYazi(dynamic t) {
  DateTime? saat;
  if (t is Timestamp) saat = t.toDate();
  if (t is DateTime) saat = t;
  if (saat == null) return '';
  return DateFormat('d MMMM HH:mm', 'tr_TR').format(saat);
}

/// Yakına giden yazı. Ücret yoktur. Durağın adı ve plakası vardır.
String taksiYakinaMetin({
  required String durak,
  required String plaka,
  required String durum,
  required String durakTel,
  String adres = '',
  String nereye = '',
  double? enlem,
  double? boylam,
}) {
  final satir = <String>[
    '$durak taksisi yolda.',
    if (plaka.isNotEmpty) 'Plaka: $plaka',
    'Durum: $durum',
    if (adres.isNotEmpty) 'Alış: $adres',
    if (nereye.isNotEmpty) 'Varış: $nereye',
    if (durakTel.isNotEmpty) 'Durak telefonu: $durakTel',
    if (enlem != null && boylam != null) 'Canlı konum: https://maps.google.com/?q=$enlem,$boylam',
    'Ücret taksimetrededir.',
  ];
  return satir.join('\n');
}
