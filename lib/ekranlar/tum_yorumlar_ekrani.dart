import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';

class TumYorumlarEkrani extends StatelessWidget {
  final String esnafId;
  final String esnafAd;

  const TumYorumlarEkrani({super.key, required this.esnafId, required this.esnafAd});

  @override
  Widget build(BuildContext context) {
    final FirestoreServisi firestoreServisi = FirestoreServisi();

    return Scaffold(
      appBar: AppBar(
        title: Text("$esnafAd - Tüm Yorumlar"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestoreServisi.yorumlariGetir(esnafId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final yorumlar = snapshot.data ?? [];
          if (yorumlar.isEmpty) {
            return const Center(child: Text("Henüz yorum yapılmamış."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: yorumlar.length,
            itemBuilder: (context, i) {
              final y = yorumlar[i];
              final DateTime tarih = (y['tarih'] as Timestamp).toDate();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(y['kullaniciAd'] ?? "Müşteri", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(DateFormat('dd.MM.yyyy').format(tarih), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < (y['puan'] ?? 0) ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(y['yorum'] ?? "", style: const TextStyle(fontSize: 14)),
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
}
