import 'package:flutter/material.dart';

class TaksiRehberEkrani extends StatelessWidget {
  final String? mod; // 'yonetici', 'surucu', 'yolcu' veya null (hepsi)
  final String? bolum; // 'cizelge', 'takip', 'parametre', 'kayit' gibi spesifik bölümler
  
  const TaksiRehberEkrani({super.key, this.mod, this.bolum});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(bolum != null ? "Kullanım Rehberi" : "Taksi Kullanım Kılavuzu", style: const TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 25),
            ],

            // 1. YÖNETİCİ BÖLÜMÜ
            if (mod == null || mod == 'yonetici') ...[
              if (bolum == null || bolum == 'filo')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Filo Yönetimi",
                icerik: "Yeni Araç Ekle, yöneticinin sisteme yeni araç kaydı oluşturduğu ekrandır.\n\nDurağa yeni bir araç eklemek için şoförün uygulamaya kendi telefonuyla giriş yapmış ve profilinde PLAKA bilgisini tanımlamış olması gerekir. Bu işlemi tamamlayan şoförler ve araçları, Yeni Araç Ekle adımı üzerinden ilgili durağa kaydedilebilir.\n\nNot: Daha önce durağa eklenmiş olan araçlar bu listede yer almaz ve tekrar eklenemez.",
              ),
              if (bolum == null)
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Nöbet Çizelgesi",
                icerik: "Aylık planlama yaparak hangi şoförün hangi gün 'Nöbetçi' veya 'İstirahatte' olacağını mühürleyebilirsiniz.\n\n● Nöbetçi (N); O gün 7/24 hizmet verecek araç.\n● Çalışıyor (C); Normal mesai saatlerinde aktif araç.\n● İstirahat (I); O gün tamamen kapalı, sıraya giremez araç.\n\nBu planlama, randevu alımını ve durak sırasını otomatik olarak yönetir.",
              ),
              if (bolum == 'cizelge') ...[
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "1. DURUM TANIMLARI",
                  icerik: "Nöbetçi (N); Mesai Tanım ekranındaki Nöbetçi Saatlerinde hizmet verecek araçtır.\n\nÇalışıyor (Ç); Mesai Tanım ekranındaki Gündüz Mesai saatlerinde hizmet verecek araçtır.\n\nİstirahat (İ); O gün çalışmayacak / istirahatli olan araçtır.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "2. PLAN OLUŞTURMA YÖNTEMLERİ",
                  icerik: "A. Seçili Araçlara Plan Oluştur; Gün seçimi yapın. İlgili araçların durumunu 'Çalış' olarak işaretleyin. 'Seçili Araçlara Plan Oluştur' butonuna basın. Seçilen araçların belirlediğiniz kapsam boyunca (Gün, Hafta, Ay, Yıl) çalışmasını onaylayın.\n\n"
                          "B. 1 Gün Çalış 1 Gün İstirahat (Grup Çalışması); Gün seçimi yapın ve ilgili araçları seçin. '1 gün çalış 1 gün istirahat' butonuna basın. İşlemin uygulanacağı kapsamı (Gün, Hafta, Ay, Yıl) seçin.\n\n"
                          "Çalışma Mantığı; Seçilen araçlar belirtilen gün çalışır; seçilmeyen diğer araçlar ise sistem tarafından otomatik olarak İstirahat (İ) durumuna getirilir. Ertesi gün bu durum tam tersine döner.\n\n"
                          "Örnek; 10 taksili bir durakta 5 taksi (A-B-C-D-E) seçilip işlem yapılırsa; ilk gün bu 5 taksi çalışır, ertesi gün ise diğer 5 taksi (F-G-H-I-İ) çalışır.\n\n"
                          "C. Nöbet Planı Oluştur; Gün seçimi yaptıktan sonra nöbet tutacak aracı belirleyip 'Nöbet Planı Oluştur' dediğinizde karşınıza 2 seçenek çıkar:\n\n"
                          "Sabit Nöbet; Seçili aracın belirtilen kapsam boyunca her gün nöbetçi olarak atanmasını sağlar.\n\n"
                          "Sıralı Nöbet (Filo Geneli); Seçili araçtan başlayarak, belirtilen kapsam boyunca nöbeti tüm filoya sırayla dağıtır.\n\n"
                          "⚠️ Sıralı Nöbet İçin Ön Koşul; Nöbet sırasının çalışabilmesi için önceden sıralama tanımlanmalıdır: Esnaf Paneli -> Filo Yönetimi -> Aracı Düzenle -> 'Nöbet Sırası' (1, 2, 3...).",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "3. AKILLI SEÇİM VE KAPSAM MANTIĞI",
                  icerik: "Yapacağınız planlama veya silme işlemlerini tek bir butona basarak GÜN, HAFTA, AY veya YIL bazında tüm takvime saniyeler içinde yayabilirsiniz.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "4. KAYDETME VE SİLME İŞLEMLERİ",
                  icerik: "Kaydetme (Mavi Disk İkonu); Yapılan tüm değişiklikleri sisteme mühürler. Kaydetmeden ekrandan çıkarsanız yapılan tüm değişiklikler kaybolur.\n\nToplu Kayıt Silme; 'Kayıt Sil' butonuna bastığınızda seçtiğiniz kapsama (Gün, Hafta, Ay, Yıl) göre temizlik yapılır. Yanlışlıkla geniş kapsamlı silme yapılmaması için işlem sırasında dinamik onay uyarısı gösterilir.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "5. DURAĞA YENİ ARAÇ EKLEME",
                  icerik: "Şoför uygulamaya giriş yapıp profilinden 'PLAKA' bilgisini kaydetmelidir. Bu işlemi tamamlayan şoförler, yönetici panelindeki 'Yeni Araç Ekle' butonu ile durağa eklenebilir.",
                ),
              ],
              if (bolum == null || bolum == 'mesai')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Mesai Saatleri",
                icerik: "7/24 Çalışma Modu; İşletmenin 7/24 hizmet verdiğini gösterir. Bu işaretli olursa müşteri ekranında müşteri bunu görür. 7/24 işaretlendiğinde Nöbet Saatleri kısmı otomatik aktif olur. Bu durumda sistem sizden Nöbetçi saatleri belirlemenizi ister.\n\nGündüz Mesaisi; Bu tanım gündüz çalışan araçların çalışma saatleridir. Taksi Çağırma ekranında müşterilerin o gün çalışan araçları görmesini sağlar. NOT: İstirahatte olan araçlar müşteriye görünmezler.\n\nNöbetçi Saatleri; Nöbetçi aracin hangi saatler arasında çalıştığını belirleyebilirsiniz.",
              ),
              if (bolum == null || bolum == 'gunler')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Çalışma Günleri",
                icerik: "Haftalık Takvim; Durağın hangi günlerde hizmet verdiğini belirlemenizi sağlar. Seçilmeyen günlerde sistem randevu alımını otomatik kapatır.",
              ),
              if (bolum == null || bolum == 'takip')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Durak Takip",
                icerik: "Sıra Yönetimi; Araçların günlük takiplerinin; Sıraya giriş-çıkış, istirahat veya mola durumlarının anlık izlendiği ekrandır.\n\n● Yeşil Ok; Aracın Durağa yakınlık mesafesi (Gelişmiş ayarlar ekranı Konum Doğrulama Mesafesinden seçilen değer) altında ise sıraya girmesine izin verir.Eğer aracın durağa mesafesi (Gelişmiş ayarlar ekranı Konum Doğrulama Mesafesinden seçilen değer) üstünde ise aracın sıraya girmesini engeller \n● Turuncu Ok; Sıradan çıkmanızı sağlar.",
              ),
              if (bolum == null || bolum == 'profil')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "İşletme Profili",
                icerik: "Profil Güncelleme; Durağın adı, resmi iletişim numaraları ve haritadaki merkez konumunu güncelleyebileceğiniz bölümdür.",
              ),
              if (bolum == 'parametre') ...[
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "1. KONUM DOĞRULAMA MESAFESİ",
                  icerik: "Şoförlerin sıraya girebilmesi için durak merkezine maksimum ne kadar uzaklıkta (metre) olması gerektiğini belirler.\n\n"
                          "Kullanım Amacı; Şoförlerin durak dışından (evinden veya uzak bir noktadan) sıraya girerek haksızlık yapmasını engellemek içindir. Şoför bu mesafenin dışındayken yeşil oka basarsa sistem sıraya girişi reddeder.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "2. ARAÇ ODAKLI SİSTEM",
                  icerik: "Taksi modülünde rezervasyonların doğrudan plakalar üzerine alınmasını sağlar.\n\n"
                          "Aktif Edildiğinde; Müşteriler randevu alırken şoför ismi yerine araç plakalarını görür ve rezervasyonlar bu araçların ajandasına mühürlenir.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "3. İSTİRAHATLİ ARAÇLARI GİZLE",
                  icerik: "Nöbet Çizelgesinde o gün için 'İstirahatte (I)' olarak işaretlenen araçların durumunu yönetir.\n\n"
                          "Görünürlük; Bu ayar aktifse, istirahatli şoförler müşteri ekranındaki 'Bugün Çalışan Araçlarımız' listesinden otomatik olarak çıkarılır, ekran kalabalığı önlenir.",
                ),
                _rehberKarti(
                  renk: Colors.indigo,
                  baslik: "4. RANDEVU ALIMINI DURDUR",
                  icerik: "Beklenmedik durumlarda veya özel günlerde durağın tüm online rezervasyon sistemini tek tıkla kapatmanızı sağlar.\n\n"
                          "Etkisi; Aktif edildiğinde müşteriler 'Hemen Randevu Al' butonunu göremezler, ancak mevcut kayıtlar silinmez.",
                ),
              ],
              if (bolum == null || bolum == 'kayit')
              _rehberKarti(
                renk: Colors.indigo,
                baslik: "Randevu Kayıtları",
                icerik: "Rezervasyon Yönetimi; Gelen tüm rezervasyon taleplerini görebileceğiniz, onay bekleyenleri yönetebileceğiniz ve geçmiş kayıtları inceleyebileceğiniz paneldir.",
              ),
            ],

            // 2. SÜRÜCÜ BÖLÜMÜ
            if (mod == null || mod == 'surucu') ...[
              _rehberKarti(
                renk: Colors.green,
                baslik: "Durak Sırası & Durum",
                icerik: "Canlı Durak Takip ekranındaki yeşil ok butonuna basarak sıraya girebilirsiniz. Sıraya girebilmek için durak merkezine yönetici tarafından belirlenen mesafede olmanız gerekir.",
              ),
              _rehberKarti(
                renk: Colors.green,
                baslik: "Güvenlik Doğrulaması",
                icerik: "Profilinizdeki 'Güvenlik Doğrulaması' kısmından ehliyet, ruhsat ve sigorta belgelerinizi sisteme yükleyin. Onaylı belgeler güvenilirliğinizi artırır.",
              ),
              _rehberKarti(
                renk: Colors.red,
                baslik: "SOS Acil Butonu",
                icerik: "Tehlikeli bir durumda SOS butonuna 3 saniye basılı tutarak durak başkanına ve diğer meslektaşlarınıza anlık konumunuzla birlikte acil durum sinyali gönderebilirsiniz.",
              ),
            ],

            // 3. YOLCU/MÜŞTERİ BÖLÜMÜ
            if (mod == null || mod == 'yolcu') ...[
              _rehberKarti(
                renk: Colors.blue,
                baslik: "Taksi Çağırma & Rezervasyon",
                icerik: "Gitmek istediğiniz yeri yazarak size en yakın müsait aracı çağırabilir veya ileri bir saat için taksi rezervasyonu oluşturabilirsiniz.",
              ),
              _rehberKarti(
                renk: Colors.blue,
                baslik: "Güzergah Bilgisi",
                icerik: "Arama kısmına mekan adı (Örn: Papara Park) yazarak tam adrese ulaşabilirsiniz. Sistem otomatik olarak bulunduğunuz konumu Alış Noktası olarak belirler.",
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 15),
          Text(
            _getBaslik(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Taksi modülündeki tüm süreçleri bu kılavuzdan inceleyebilirsiniz.",
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _getBaslik() {
    if (mod == 'yonetici') return "Yönetici Rehberi";
    if (mod == 'surucu') return "Şoför Rehberi";
    if (mod == 'yolcu') return "Yolcu Rehberi";
    return "Taksi Rehberi";
  }

  Widget _rehberKarti({required Color renk, required String baslik, required String icerik}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Renkli Sol Çizgi (Stack ile mühürlendi, overflow yapamaz)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(width: 6, color: renk),
            ),
            // İçerik
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: renk, letterSpacing: 1.1)),
                  const SizedBox(height: 15),
                  _zenginMetinOlustur(icerik),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zenginMetinOlustur(String icerik) {
    final satirlar = icerik.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: satirlar.map((satir) {
        String s = satir.trim();
        if (s.isEmpty) return const SizedBox(height: 12);
        
        // İç başlık kontrolü (; olan yerleri kalın yap)
        if (s.contains(';')) {
          final p = s.split(';');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: p[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
                  TextSpan(text: p.length > 1 ? "; ${p[1]}" : "", style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
              style: const TextStyle(height: 1.5),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5)),
        );
      }).toList(),
    );
  }

  Widget _iletisimKutusu() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.support_agent_rounded, color: Colors.indigo.shade700, size: 30),
          const SizedBox(width: 15),
          const Expanded(child: Text("Taksi Destek Merkezi\ndestek@almely.com", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
        ],
      ),
    );
  }
}
