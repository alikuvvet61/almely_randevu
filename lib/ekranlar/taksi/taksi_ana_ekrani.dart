import 'package:flutter/material.dart';

class TaksiAnaEkrani extends StatelessWidget {
  final String? kullaniciTel;

  const TaksiAnaEkrani({
    super.key,
    this.kullaniciTel,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AnaKart(
        baslik: 'Güncel Talepler',
        aciklama: 'Müşteri taleplerini ve araç durumunu izleyin.',
        ikon: Icons.assignment_turned_in_rounded,
        renk: Colors.indigo,
      ),
      _AnaKart(
        baslik: 'Araç Durumu',
        aciklama: 'Araçlar, nöbet ve durak bilgilerini yönetin.',
        ikon: Icons.local_taxi_rounded,
        renk: Colors.amber,
      ),
      _AnaKart(
        baslik: 'Rezervasyon',
        aciklama: 'Nerden-nereye akışını hızlıca başlatın.',
        ikon: Icons.route_rounded,
        renk: Colors.green,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taksi Modülü'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) => cards[index],
        ),
      ),
    );
  }
}

class _AnaKart extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData ikon;
  final Color renk;

  const _AnaKart({
    required this.baslik,
    required this.aciklama,
    required this.ikon,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: renk.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: renk, size: 32),
          const SizedBox(height: 12),
          Text(
            baslik,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            aciklama,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
