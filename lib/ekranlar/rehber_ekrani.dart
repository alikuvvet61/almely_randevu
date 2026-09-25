import 'package:flutter/material.dart';

class RehberEkrani extends StatelessWidget {
  final String? mod; // 'musteri', 'esnaf' veya null (hepsi)
  const RehberEkrani({super.key, this.mod});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            _ustBilgiKutusu(),
            const SizedBox(height: 20),

            // 1. MÜŞTERİ BÖLÜMÜ (Tüm Müşteriler İçin)
            if (mod == null || mod == 'musteri') ...[
              _rehberKarti(
                renk: Colors.blue,
                baslik: "Hizmet ve Esnaf Seçimi",
                icerik: "İhtiyacınız olan kategoriyi seçerek size en yakın veya en popüler esnafları listeleyebilirsiniz. Harita üzerinden konum kontrolü yapabilirsiniz.",
              ),
              _rehberKarti(
                renk: Colors.blue,
                baslik: "Randevu Sistemi",
                icerik: "Müsait gün ve saatleri görüntüleyerek saniyeler içinde randevu oluşturun. Randevularım sayfasından tüm taleplerinizi yönetebilirsiniz.",
              ),
            ],
            
            // 2. GENEL ESNAF BÖLÜMÜ (Taksi Dışındaki Tüm Esnaflar İçin)
            if (mod == null || mod == 'esnaf') ...[
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "İşletme Profili Yönetimi",
                icerik: "İşletme adınızı, iletişim bilgilerinizi ve harita konumunuzu güncelleyerek müşterilerinizin size daha kolay ulaşmasını sağlayın.",
              ),
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Mesai ve Çalışma Günleri",
                icerik: "Haftalık çalışma günlerinizi ve günlük açılış-kapanış saatlerinizi belirleyerek randevu takviminizi otomatik olarak mühürleyin.",
              ),
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Hizmet Tanımlama",
                icerik: "Verdiğiniz hizmetleri ve sürelerini sisteme girerek müşterilerinizin doğru saatlerde randevu almasını sağlayın.",
              ),
            ],

            const SizedBox(height: 10),
            _iletisimKutusu(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _ustBilgiKutusu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_center_rounded, color: Colors.blue.shade800, size: 28),
              const SizedBox(width: 12),
              Text(
                mod == 'esnaf' ? "İşletme Yönetim Rehberi" : "AlmEly Hizmet & Randevu Rehberi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Uygulamamızı daha verimli kullanabilmeniz için hazırlanan genel kılavuzdur. Taksi ve Araç Kiralama’ya özel detaylar için ilgili sayfadaki yardımı inceleyin.",
            style: TextStyle(fontSize: 13, color: Colors.blue.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _rehberKarti({required Color renk, required String baslik, required String icerik}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk),
          ),
          const SizedBox(height: 10),
          Text(
            icerik,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _iletisimKutusu() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.support_agent_rounded, color: Colors.grey, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Destek Hattı:\ndestek@almely.com",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
