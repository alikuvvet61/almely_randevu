import 'package:flutter/material.dart';

class RehberEkrani extends StatelessWidget {
  final String? mod; // 'musteri', 'esnaf', 'surucu' veya null (hepsi)
  const RehberEkrani({super.key, this.mod});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Kullanım Rehberi & Yardım", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mod == null || mod == 'musteri') ...[
              _yardimBolumu(
                ikon: Icons.person_search_rounded,
                renk: Colors.blue,
                baslik: "Müşteriler İçin",
                maddeler: [
                  "Kategoriler arasından ihtiyacınız olan hizmeti seçin.",
                  "Size en yakın veya en yüksek puanlı esnafı listeleyin.",
                  "Müsait gün ve saatleri seçerek anında randevu alın.",
                  "Randevularım sekmesinden geçmiş ve gelecek randevularınızı takip edin.",
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            if (mod == null || mod == 'esnaf') ...[
              _yardimBolumu(
                ikon: Icons.business_center_rounded,
                renk: Colors.indigo,
                baslik: "Esnaflar İçin",
                maddeler: [
                  "İşletme Profilim kısmından çalışma saatlerinizi ve hizmetlerinizi güncelleyin.",
                  "Ajanda Defteri üzerinden randevu saatlerinizi yönetin.",
                  "Müşterilerinizden gelen randevu taleplerini anlık onaylayın.",
                  "Canlı Durak Takip sistemi ile araçlarınızın sırasını ve konumunu izleyin.",
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (mod == null || mod == 'surucu') ...[
              _yardimBolumu(
                ikon: Icons.local_taxi_rounded,
                renk: Colors.green,
                baslik: "Sürücüler İçin",
                maddeler: [
                  "Canlı Durak Takip ekranından sıraya girin ve durumunuzu (Müsait, Meşgul vb.) güncelleyin.",
                  "Profilim -> Bilgilerimi Güncelle kısmından ad, soyad ve plakanızı mühürleyin.",
                  "Güvenlik Doğrulaması bölümünden ehliyet ve sigorta belgelerinizi sisteme yükleyin.",
                  "Acil durumlarda SOS butonuna 3 saniye basılı tutarak merkeze sinyal gönderin.",
                ],
              ),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: Colors.blue, size: 30),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Sorularınız için bizimle iletişime geçebilirsiniz:\ndestek@almely.com",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _yardimBolumu({required IconData ikon, required Color renk, required String baslik, required List<String> maddeler}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, color: renk, size: 28),
              const SizedBox(width: 12),
              Text(baslik, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: renk)),
            ],
          ),
          const SizedBox(height: 15),
          ...maddeler.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Expanded(child: Text(m, style: const TextStyle(fontSize: 14, color: Colors.black87))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
