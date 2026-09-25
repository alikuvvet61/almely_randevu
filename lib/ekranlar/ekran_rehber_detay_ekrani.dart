import 'package:flutter/material.dart';
import '../yardimcilar/ekran_rehber_katalogu.dart';

/// Belirli bir ekranın detaylı kullanım rehberi.
class EkranRehberDetayEkrani extends StatelessWidget {
  final String? sinifAdi;

  const EkranRehberDetayEkrani({super.key, this.sinifAdi});

  static void ac(BuildContext context, {String? sinifAdi}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EkranRehberDetayEkrani(sinifAdi: sinifAdi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icerik = EkranRehberKatalogu.getir(sinifAdi);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Kullanım Rehberi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _baslikKutusu(icerik),
          const SizedBox(height: 16),
          for (final b in icerik.bolumler) ...[
            _bolumKarti(b),
            const SizedBox(height: 12),
          ],
          if (icerik.ipuclari.isNotEmpty) ...[
            _listeKarti(
              baslik: 'İpuçları',
              renk: Colors.teal,
              ikon: Icons.lightbulb_outline,
              maddeler: icerik.ipuclari,
            ),
            const SizedBox(height: 12),
          ],
          if (icerik.bildirimler.isNotEmpty) ...[
            _listeKarti(
              baslik: 'Bildirimler',
              renk: Colors.deepOrange,
              ikon: Icons.notifications_active_outlined,
              maddeler: icerik.bildirimler,
            ),
            const SizedBox(height: 12),
          ],
          _destekKutusu(),
        ],
      ),
    );
  }

  Widget _baslikKutusu(EkranRehberIcerik icerik) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_center_rounded, color: Colors.blue.shade800, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  icerik.baslik,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            icerik.ozet,
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  Widget _bolumKarti(RehberBolum b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(b.ikon ?? Icons.article_outlined, color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  b.baslik,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            b.icerik,
            style: const TextStyle(fontSize: 14, height: 1.55, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _listeKarti({
    required String baslik,
    required Color renk,
    required IconData ikon,
    required List<String> maddeler,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: renk.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, color: renk, size: 22),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final m in maddeler) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      m,
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _destekKutusu() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.support_agent_rounded, color: Colors.grey, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Destek: destek@almely.com',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
