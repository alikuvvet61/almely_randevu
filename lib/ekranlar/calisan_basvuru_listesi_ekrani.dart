import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servisler/firestore_servisi.dart';
import '../servisler/taksi/taksi_guven.dart';
import '../yardimcilar/calisan_gorevleri.dart';

Future<void> calisanBasvurusuHatirlat(BuildContext context, String esnafId) async {
  final liste = await FirestoreServisi().calisanBasvurulariDinle(esnafId).first;
  if (!context.mounted || liste.isEmpty) return;
  final n = liste.length;
  final iptal = liste.where((b) => b['durum']?.toString() == 'İptal bekliyor').length;
  final yeni = n - iptal;
  final String metin;
  if (iptal > 0 && yeni > 0) {
    metin = 'Bekleyen başvuru ve çalışmayı bırakma talebi var. Çalışan başvuruları kartından bakın.';
  } else if (iptal > 0) {
    metin = iptal == 1
        ? 'Bir çalışan çalışmayı bırakmak istiyor. İptali, başvuruyu kabul eden kişi onaylar.'
        : '$iptal çalışan çalışmayı bırakmak istiyor. İptali, başvuruyu kabul eden kişi onaylar.';
  } else {
    metin = n == 1
        ? 'Bekleyen bir çalışan başvurusu var. Çalışan başvuruları kartından kabul veya red edebilirsiniz.'
        : 'Bekleyen $n çalışan başvurusu var. Çalışan başvuruları kartından kabul veya red edebilirsiniz.';
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Çalışan başvurusu'),
      content: Text(metin),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
      ],
    ),
  );
}

String calisanBasvuruDurumYazi(String durum) {
  switch (durum) {
    case 'Bekliyor':
      return 'Bekleyen';
    case 'Kabul':
      return 'Onaylandı';
    case 'İptal bekliyor':
      return 'İptal onay bekliyor';
    case 'Reddedildi':
      return 'Ret';
    case 'İptal':
      return 'İptal';
    default:
      return durum;
  }
}

MaterialColor calisanBasvuruDurumRengi(String durum) {
  switch (durum) {
    case 'Kabul':
      return Colors.green;
    case 'İptal bekliyor':
      return Colors.orange;
    case 'Reddedildi':
      return Colors.red;
    case 'İptal':
      return Colors.blueGrey;
    default:
      return Colors.orange;
  }
}

class CalisanBasvuruDurumKarti extends StatelessWidget {
  final Map<String, dynamic> basvuru;

  const CalisanBasvuruDurumKarti({super.key, required this.basvuru});

  @override
  Widget build(BuildContext context) {
    final durum = (basvuru['durum'] ?? '').toString();
    final renk = calisanBasvuruDurumRengi(durum);
    final plaka = (basvuru['plaka'] ?? '').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Çalışan başvurunuz', style: TextStyle(fontWeight: FontWeight.bold, color: renk.shade800)),
          const SizedBox(height: 6),
          Text((basvuru['isletmeAdi'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if ((basvuru['gorev'] ?? '').toString().trim().isNotEmpty) Text((basvuru['gorev'] ?? '').toString()),
          if (plaka.isNotEmpty) Text('Plaka: $plaka'),
          const SizedBox(height: 4),
          Text('Durum: ${calisanBasvuruDurumYazi(durum)}', style: TextStyle(color: renk.shade800, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class CalisanBasvuruListesiEkrani extends StatefulWidget {
  final String esnafId;

  const CalisanBasvuruListesiEkrani({super.key, required this.esnafId});

  @override
  State<CalisanBasvuruListesiEkrani> createState() => _CalisanBasvuruListesiEkraniState();
}

class _CalisanBasvuruListesiEkraniState extends State<CalisanBasvuruListesiEkrani> with SingleTickerProviderStateMixin {
  late final TabController _sekme;
  final _firestore = FirestoreServisi();

  @override
  void initState() {
    super.initState();
    _sekme = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _sekme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışan başvuruları'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _sekme,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: 'Bekleyen'),
            Tab(text: 'Onaylanan'),
            Tab(text: 'İptal/Ret'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestore.calisanBasvurulariTumunuDinle(widget.esnafId),
        builder: (context, snapshot) {
          final liste = snapshot.data ?? [];
          return TabBarView(
            controller: _sekme,
            children: [
              _liste(
                liste.where((b) => b['durum']?.toString() == 'Bekliyor' || b['durum']?.toString() == 'İptal bekliyor').toList(),
                'Bekleyen başvuru yok.',
              ),
              _liste(liste.where((b) => b['durum']?.toString() == 'Kabul').toList(), 'Onaylanan başvuru yok.'),
              _liste(
                liste.where((b) => b['durum']?.toString() == 'Reddedildi' || b['durum']?.toString() == 'İptal').toList(),
                'İptal veya ret yok.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _liste(List<Map<String, dynamic>> liste, String bos) {
    if (liste.isEmpty) return Center(child: Text(bos));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: liste.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = liste[i];
        final gorev = (b['gorev'] ?? '').toString();
        final plaka = (b['plaka'] ?? '').toString();
        final durum = (b['durum'] ?? '').toString();
        final renk = calisanBasvuruDurumRengi(durum);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((b['adSoyad'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(gorev),
                Text((b['telefon'] ?? '').toString()),
                if (plaka.isNotEmpty) Text('Plaka: $plaka'),
                _belgeBaglantilari(b['belgeler']),
                const SizedBox(height: 8),
                Text(calisanBasvuruDurumYazi(durum), style: TextStyle(color: renk.shade800, fontWeight: FontWeight.w600)),
                if (durum == 'Bekliyor')
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _sonuc(context, b, kabul: false),
                        child: const Text('Reddet', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _sonuc(context, b, kabul: true),
                        child: const Text('Kabul et'),
                      ),
                    ],
                  ),
                if (durum == 'İptal bekliyor')
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _iptalKarar(context, b, onay: false),
                        child: const Text('Reddet', style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _iptalKarar(context, b, onay: true),
                        child: const Text('İptali onayla'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _belgeBaglantilari(dynamic belgeler) {
    if (belgeler is! Map) return const SizedBox.shrink();
    final satirlar = <Widget>[];
    for (final tur in taksiZorunluBelgeler) {
      final url = (belgeler[tur] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final ad = switch (tur) {
        'ehliyet' => 'Kimlik / Ehliyet',
        'ruhsat' => 'Ruhsat',
        'sigorta' => 'Sigorta',
        'taksimetre_belge' => 'Taksimetre',
        _ => tur,
      };
      satirlar.add(TextButton(
        onPressed: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Text('$ad gör'),
      ));
    }
    if (satirlar.isEmpty) return const SizedBox.shrink();
    return Wrap(children: satirlar);
  }

  Future<void> _sonuc(BuildContext context, Map<String, dynamic> b, {required bool kabul}) async {
    final id = (b['id'] ?? '').toString();
    final hata = kabul ? await _firestore.calisanBasvurusuKabul(id) : await _firestore.calisanBasvurusuReddet(id);
    if (!context.mounted) return;
    final taksi = CalisanGorevleri.plakaGerekli((b['gorev'] ?? '').toString());
    final mesaj = hata ?? (kabul ? (taksi ? 'Kabul edildi. Araç filoya yazıldı. Nöbet sırasını siz verirsiniz.' : 'Kabul edildi.') : 'Başvuru reddedildi.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  Future<void> _iptalKarar(BuildContext context, Map<String, dynamic> b, {required bool onay}) async {
    final id = (b['id'] ?? '').toString();
    final hata = onay ? await _firestore.calisanIptalOnayla(id) : await _firestore.calisanIptalReddet(id);
    if (!context.mounted) return;
    final mesaj = hata ?? (onay ? 'İptal onaylandı. Kişi işletmeden çıktı.' : 'İptal reddedildi. Kayıt duruyor.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }
}
