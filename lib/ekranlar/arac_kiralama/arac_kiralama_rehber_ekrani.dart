import 'package:flutter/material.dart';

/// Araç Kiralama kullanım rehberi (genel rehber_ekrani'nden ayrıldı).
class AracKiralamaRehberEkrani extends StatelessWidget {
  final String? mod; // 'musteri', 'esnaf' veya null (hepsi)
  final String? bolum; // 'parametre', 'kayit' gibi spesifik bölümler

  const AracKiralamaRehberEkrani({super.key, this.mod, this.bolum});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          bolum != null ? "Kullanım Rehberi" : "Araç Kiralama Rehberi",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bolum == null) ...[
              _ustBilgiKutusu(),
              const SizedBox(height: 20),
            ],

            // MÜŞTERİ
            if (mod == null || mod == 'musteri') ...[
              if (bolum == null) ...[
                _rehberKarti(
                  renk: Colors.blue,
                  baslik: "Araç Filomuza Göz Atın",
                  icerik:
                      "İşletme detayında kiralık araç listesini görürsünüz. Araç kartlarında plaka, model ve o anki durum (müsait / kirada / rezerveli) bilgisi yer alır. Harita üzerinden işletme konumunu kontrol edebilirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.blue,
                  baslik: "Kiralama Randevusu",
                  icerik:
                      "İstediğiniz aracı seçip alış–iade tarih ve saatlerini belirleyerek kiralama talebi oluşturun. Saatlik (2–8 saat) veya günlük kiralama seçenekleri işletmenin tanımladığı hizmetlere göre sunulur.\n\n"
                      "Randevularım sayfasından taleplerinizi izleyebilir, akıllı takip açıksa süre uzatma tekliflerini değerlendirebilirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.blue,
                  baslik: "Kaza / Hasar Bildirimi",
                  icerik:
                      "Aktif kiralamanız sırasında oluşabilecek hasar veya kaza durumunu Randevularım üzerinden bildirebilir; fotoğraf ve konum ekleyebilirsiniz.",
                ),
              ],
            ],

            // ESNAF / YÖNETİCİ
            if (mod == null || mod == 'esnaf') ...[
              if (bolum == null) ...[
                _rehberKarti(
                  renk: Colors.blueGrey,
                  baslik: "İşletme Profili Yönetimi",
                  icerik:
                      "İşletme adınızı, iletişim bilgilerinizi ve harita konumunuzu güncelleyerek müşterilerinizin size daha kolay ulaşmasını sağlayın.",
                ),
                _rehberKarti(
                  renk: Colors.blueGrey,
                  baslik: "Mesai ve Çalışma Günleri",
                  icerik:
                      "Haftalık çalışma günlerinizi ve günlük açılış–kapanış saatlerinizi belirleyerek kiralama takviminizi otomatik olarak mühürleyin. 7/24 modu varsa araçlar gün boyu rezervasyona açılabilir.",
                ),
                _rehberKarti(
                  renk: Colors.blueGrey,
                  baslik: "Kiralık Araç Tanımlama",
                  icerik:
                      "Örn: '34 ABC 123 - Fiat Egea', '61 ALM 001 - VW Passat'. Her araç bir kanal olarak tanımlanır; böylece aynı aracın çakışan kiralamaları engellenir. Araç kartından aktif/pasif durumunu yönetebilirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.blueGrey,
                  baslik: "Hizmet Tanımlama (Saatlik / Günlük)",
                  icerik:
                      "Kiralama hizmetlerinizi 'Saatlik' (120–480 dk) veya 'Günlük' (1440 dk) olarak tanımlayabilirsiniz. Sistem bu sürelere göre araç takvimini otomatik kapatır.",
                ),
                _rehberKarti(
                  renk: Colors.blueGrey,
                  baslik: "Randevu Ver / Araç Kirala",
                  icerik:
                      "Paneldeki hızlı kiralama ile müşteri adına doğrudan rezervasyon oluşturabilirsiniz. Gelen talepler Randevu Kayıtları ekranından onaylanır veya reddedilir.",
                ),
              ],
              if (bolum == null || bolum == 'parametre') ...[
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "Bakım ve Temizlik Süresi",
                  icerik:
                      "Her kiralama bittikten sonra aracın kaç dakika bakıma alınacağını belirler. Bu süre boyunca araç takvimde dolu görünür; çakışmalar önlenir.\n\n"
                      "Bakım Sırasında Kiralama; işaretliyse bakım sürecindeki araca yine de yeni randevu alınabilir.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "Akıllı Takip Modu",
                  icerik:
                      "Kiralama bitimine belirli süre kala müşteriye bildirim gider. Araç müsaitse sistem uzatma teklifi sunabilir.\n\n"
                      "Bildirim zamanı ve saatlik uzatma ücretini Araç Kiralama Ayarları ekranından yönetirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "Randevu Alımını Durdur / Onay Modu",
                  icerik:
                      "Randevu Alımını Durdur; müşterilerden online kiralama alınmasını tek dokunuşla kapatır.\n\n"
                      "Onay Modu; Manuel (sizin onayınız) veya Otomatik (anında onay) seçenekleriyle yeni taleplerin akışını belirler.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "Randevu Penceresi ve Minimum Süre",
                  icerik:
                      "İleriye dönük pencere; müşterinin bugünden itibaren kaç gün ilerisi için kiralama yapabileceğini sınırlar.\n\n"
                      "Minimum süre; seçilebilecek en kısa kiralama süresidir (ör. 1 saat).",
                ),
              ],
              if (bolum == null || bolum == 'kayit') ...[
                _rehberKarti(
                  renk: Colors.teal,
                  baslik: "Kiralama Randevu Yönetimi",
                  icerik:
                      "Bekleyen, onaylanan ve iptal/red kayıtlarını sekmeler halinde görürsünüz. Talepleri onaylayıp reddedebilir; geçmiş kayıtları inceleyebilirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.teal,
                  baslik: "Teslim / İade ve Kira Sonlandırma",
                  icerik:
                      "Aktif kiralamalarda araç teslim ve iade fotoğraflarını kaydedebilir, geciken iadelerde uyarı alıp kirayı sonlandırabilirsiniz. Gecikme ve bakımdaki araç durumları panel alarmlarıyla takip edilir.",
                ),
              ],
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
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.car_rental_rounded, color: Colors.blueGrey.shade800, size: 28),
              const SizedBox(width: 12),
              Text(
                mod == 'esnaf' ? "Araç Kiralama İşletme Rehberi" : "Araç Kiralama Kullanım Rehberi",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Filo, kiralama randevusu, bakım süreci ve akıllı takip özelliklerini verimli kullanmanız için hazırlanan kılavuzdur.",
            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade700, height: 1.5),
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
          Text(baslik, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk)),
          const SizedBox(height: 10),
          Text(icerik, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5)),
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
