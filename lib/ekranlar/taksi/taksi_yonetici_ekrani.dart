import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../modeller/taksi/taksi_talep_modeli.dart';
import '../../modeller/esnaf_modeli.dart';
import '../../servisler/taksi/taksi_servisi.dart';
import '../../servisler/firestore_servisi.dart';
import '../../servisler/taksi/taksi_bildirim_servisi.dart';
import '../../modeller/randevu_modeli.dart';

/// Taksi için yönetici (durak başkanı/şoför) yönetim paneli.
class TaksiYoneticiEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const TaksiYoneticiEkrani({super.key, required this.esnaf, this.soforTel});

  @override
  State<TaksiYoneticiEkrani> createState() => _TaksiYoneticiEkraniState();
}

class _TaksiYoneticiEkraniState extends State<TaksiYoneticiEkrani> {
  final TaksiServisi _taksiServisi = TaksiServisi();
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  bool _loadingAction = false;

  Future<void> _accept(String talepId, Map<String, dynamic> data) async {
    setState(() => _loadingAction = true);
    try {
      await _taksiServisi.talepDurumGuncelle(talepId, 'Kabul edildi');

      // Raporlama için randevu kaydı oluştur
      final now = DateTime.now();
      final saat = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

      final yeniR = RandevuModeli(
        id: '',
        esnafId: widget.esnaf.id,
        esnafAdi: widget.esnaf.isletmeAdi,
        esnafTel: widget.esnaf.telefon,
        kullaniciAd: data['kullaniciAd'] ?? data['ad'] ?? 'Müşteri',
        kullaniciTel: (data['kullaniciTel'] ?? data['telefon'] ?? '').toString(),
        tarih: now,
        saat: saat,
        sure: 30,
        hizmetAdi: 'Taksi Rezervasyonu',
        durum: 'Onaylandı',
      );

      await _firestoreServisi.randevuEkle(yeniR);

      // Kullanıcıya bildirim gönder
      final hedefTel = (data['kullaniciTel'] ?? data['telefon'] ?? '').toString();
      await TaksiBildirimServisi.sendTalepKabulBildirim(hedefTel, widget.esnaf.isletmeAdi);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talep kabul edildi ve randevu oluşturuldu.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _reject(String talepId, Map<String, dynamic> data) async {
    setState(() => _loadingAction = true);
    try {
      await _taksiServisi.talepDurumGuncelle(talepId, 'Reddedildi');
      final hedefTel = (data['kullaniciTel'] ?? data['telefon'] ?? '').toString();
      await TaksiBildirimServisi.sendTalepReddetBildirim(hedefTel, widget.esnaf.isletmeAdi);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talep reddedildi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.esnaf.isletmeAdi} - Taksi Talepleri')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _taksiServisi.talepleriDinle(widget.esnaf.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Bekleyen taksi talebi yok.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final talep = TaksiTalepModeli.fromMap(data, d.id);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(talep.kullaniciAd, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(talep.durum, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Nereden: ${talep.nereden}'),
                      Text('Nereye: ${talep.nereye}'),
                      const SizedBox(height: 8),
                      Row(children: [
                        ElevatedButton.icon(onPressed: _loadingAction ? null : () => _accept(d.id, data), icon: const Icon(Icons.check), label: const Text('Kabul Et')),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(onPressed: _loadingAction ? null : () => _reject(d.id, data), icon: const Icon(Icons.close), label: const Text('Reddet')),
                        const Spacer(),
                        IconButton(onPressed: () async { await showModalBottomSheet(context: context, builder: (_) => _detaySheet(data)); }, icon: const Icon(Icons.info_outline)),
                      ])
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _detaySheet(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Müşteri: ${data['kullaniciAd'] ?? data['ad'] ?? ''}'),
          Text('Telefon: ${data['kullaniciTel'] ?? data['telefon'] ?? ''}'),
          Text('Adres: ${data['nereden'] ?? ''}'),
          Text('Hedef: ${data['nereye'] ?? ''}'),
          const SizedBox(height: 12),
          Text('Oluşturulma: ${data['olusturulmaTarihi'] ?? ''}'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
