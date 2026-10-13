/// Bilgi kutusundaki kanal ve hizmet cümleleri. Düğme yazılarına dokunulmaz.
class KategoriKanalRehberi {
  final String kanalBilgi;
  final String hizmetBilgi;

  const KategoriKanalRehberi({
    required this.kanalBilgi,
    required this.hizmetBilgi,
  });

  static KategoriKanalRehberi bul(String? kategori) {
    switch ((kategori ?? '').trim()) {
      case 'Diyetisyen':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Kanal adı olarak Oda 1, Bölüm veya Diyetisyenlik yazabilirsiniz.',
          hizmetBilgi: 'Örnek: İlk görüşme, Kontrol, Online diyet, Sağlıklı yaşam. Her birinin dakikasını yazın.',
        );
      case 'Fizyoterapi ve Rehabilitasyon':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kaç hasta alınabiliyorsa o kadar yatak yazın. Örnek: Yatak 1.',
          hizmetBilgi: 'Örnek: Tedavi seansı, Egzersiz. Süreyi dakika yazın.',
        );
      case 'Psikolog':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Tek başınıza çalışıyorsanız Görüşme odası 1 yazın.',
          hizmetBilgi: 'Örnek: Yüz yüze görüşme, Online görüşme. Süreyi dakika yazın.',
        );
      case 'Veteriner':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kaç hayvan bakılabiliyorsa o kadar muayene yeri yazın. Örnek: Muayene 1.',
          hizmetBilgi: 'Örnek: Muayene, Aşı. Süreyi dakika yazın.',
        );
      case 'Pet Kuaför':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kaç hayvan tıraş edilebiliyorsa o kadar masa yazın. Örnek: Bakım masası 1.',
          hizmetBilgi: 'Örnek: Tıraş, Banyo. Süreyi dakika yazın.',
        );
      case 'Özel Ders':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Tek öğretmen tek odaysa Derslik 1 yazın.',
          hizmetBilgi: 'Örnek: Matematik, İngilizce. Süreyi dakika yazın.',
        );
      case 'Kuaför':
      case 'Berber':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kaç müşteri oturabiliyorsa o kadar koltuk yazın. Kişi seçimi Personeller kısmındadır. Örnek: Koltuk 1.',
          hizmetBilgi: 'Örnek: Saç kesim, Sakal, Fön, Boya. Süreyi dakika yazın.',
        );
      case 'Restoran':
      case 'Kafe':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Rezervasyon yapılacak her masayı ayrı yazın. Örnek: Masa 1, Teras.',
          hizmetBilgi: 'Örnek: Akşam yemeği. Süre, masanın dolu kalacağı dakikadır.',
        );
      case 'Halı Saha':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kiralanabilen her sahayı ayrı yazın. Örnek: Saha 1, Kapalı saha.',
          hizmetBilgi: 'Örnek: Maç. Süre genelde 60 dk.',
        );
      case 'Oto Yıkama':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte kaç araç yıkanabiliyorsa o kadar peron yazın. Örnek: Peron 1.',
          hizmetBilgi: 'Örnek: İç dış yıkama, Detaylı temizlik. Süreyi dakika yazın.',
        );
      case 'Düğün Salonu':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı gün kiralanabilen her salonu ayrı yazın. Tek salon varsa Ana salon yazın.',
          hizmetBilgi: 'Örnek: Nikah, Düğün. Süreyi dakika yazın.',
        );
      case 'Taksi':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Tek durak varsa Merkez durak yazın. Birden fazla durak varsa her birini ayrı yazın.',
          hizmetBilgi: 'Örnek: Şehir içi, Havalimanı. Süreyi dakika yazın.',
        );
      case 'Araç Kiralama':
        return const KategoriKanalRehberi(
          kanalBilgi: 'Her aracı plakasıyla yazın. Aynı saatte iki müşteri aynı aracı alamaz. Örnek: 61 ALM 001.',
          hizmetBilgi: 'Saatlik için dakikayı yazın, örneğin 120. Günlük için 1440.',
        );
      default:
        return const KategoriKanalRehberi(
          kanalBilgi: 'Aynı saatte bir kişi alınabiliyorsa Oda 1 yazın. İkinci yer varsa onu da ekleyin.',
          hizmetBilgi: 'Örnek: Görüşme. Süreyi dakika yazın.',
        );
    }
  }
}
