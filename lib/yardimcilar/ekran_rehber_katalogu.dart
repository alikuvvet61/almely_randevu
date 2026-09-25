import 'package:flutter/material.dart';

/// Tek bir ekranın kullanım rehberi içeriği.
class EkranRehberIcerik {
  final String baslik;
  final String ozet;
  final List<RehberBolum> bolumler;
  final List<String> ipuclari;
  final List<String> bildirimler;

  const EkranRehberIcerik({
    required this.baslik,
    required this.ozet,
    this.bolumler = const [],
    this.ipuclari = const [],
    this.bildirimler = const [],
  });
}

class RehberBolum {
  final String baslik;
  final String icerik;
  final IconData? ikon;

  const RehberBolum({
    required this.baslik,
    required this.icerik,
    this.ikon,
  });
}

/// Sınıf adı → bu ekrana özel detaylı rehber.
class EkranRehberKatalogu {
  EkranRehberKatalogu._();

  static EkranRehberIcerik getir(String? sinifAdi) {
    if (sinifAdi == null || sinifAdi.isEmpty) return _genel;
    return _harita[sinifAdi] ?? _genelKopya(sinifAdi);
  }

  static bool gizlensinMi(String? sinifAdi) {
    if (sinifAdi == null) return true;
    return sinifAdi.contains('Rehber') ||
        sinifAdi == 'EkranRehberDetayEkrani';
  }

  static EkranRehberIcerik _genelKopya(String sinif) => EkranRehberIcerik(
        baslik: 'Bu Ekran',
        ozet:
            'Bu sayfa için henüz özel bir rehber tanımlanmamış. Genel kullanım için giriş ekranındaki “Kullanım Rehberi & Yardım”a bakabilirsiniz.',
        bolumler: [
          RehberBolum(
            baslik: 'Ne yapmalıyım?',
            icerik:
                'Ekrandaki buton ve listeleri inceleyin. Takıldığınız yerde destek@almely.com adresine yazabilirsiniz.\n\n(Ekran kodu: $sinif)',
            ikon: Icons.touch_app_outlined,
          ),
        ],
        ipuclari: const [
          'Geri tuşu ile bir önceki ekrana dönebilirsiniz.',
        ],
      );

  static const _genel = EkranRehberIcerik(
    baslik: 'AlmEly Go Hizmet & Randevu',
    ozet:
        'Yerel hizmet sağlayıcılarından randevu alın, taksi çağırın veya araç kiralayın. Her ekranın sağ üstündeki ? düğmesi o ekranı anlatır.',
    bolumler: [
      RehberBolum(
        baslik: 'Başlarken',
        icerik:
            'Telefon numaranızla giriş yapın. SMS doğrulaması sonrası ana sayfadan kategori seçerek ilerleyin.',
        ikon: Icons.login_rounded,
      ),
    ],
    bildirimler: [
      'Randevu onay / red, hatırlatma ve (kira için) süre uzatma bildirimleri telefonunuza gelir.',
      'Bildirim izni kapalıysa kritik uyarıları kaçırabilirsiniz; ayarlardan izin verin.',
    ],
  );

  static final Map<String, EkranRehberIcerik> _harita = {
    'GirisSecimSayfasi': const EkranRehberIcerik(
      baslik: 'Giriş',
      ozet:
          'Uygulamaya telefon numaranızla güvenli giriş yaptığınız ekrandır. Esnaf veya müşteri ayrımı numaraya göre otomatik yönlendirilir.',
      bolumler: [
        RehberBolum(
          baslik: 'Nasıl giriş yapılır?',
          icerik:
              '1. Telefon numaranızı 05xx… formatında yazın.\n'
              '2. “Giriş Yap”a basın.\n'
              '3. Gelen SMS kodunu girin.\n'
              '4. Sistem sizi müşteri ana sayfasına veya (kayıtlı esnafsanız) ilgili panele yönlendirir.',
          ikon: Icons.phone_android,
        ),
        RehberBolum(
          baslik: 'Kullanım Rehberi & Yardım',
          icerik:
              'Genel kılavuza buradan ulaşabilirsiniz. Her ekranda ayrıca o ekrana özel ? kısayolu bulunur.',
          ikon: Icons.help_outline,
        ),
        RehberBolum(
          baslik: 'Geliştirme – Hızlı Giriş',
          icerik:
              'Yalnızca geliştirme derlemelerinde görünür. Kayıtlı esnaf kartına dokunarak o numarayla hızlı deneme girişi yapılır. Canlı kullanıcılar bunu görmez.',
          ikon: Icons.developer_mode,
        ),
      ],
      ipuclari: [
        'SMS gelmezse operatör filtresi veya yanlış numara olabilir; birkaç dakika bekleyip tekrar deneyin.',
        'Logo alanına art arda 5 kez dokunmak yönetici girişi içindir (yetkili personel).',
      ],
      bildirimler: [
        'İlk açılışta bildirim izni istenir. İzin verirseniz randevu ve hatırlatmalar size ulaşır.',
      ],
    ),

    'AnaEkran': const EkranRehberIcerik(
      baslik: 'Ana Sayfa',
      ozet:
          'Kategorilerden hizmet seçtiğiniz merkez ekrandır. Esnafsanız üstteki geçiş ikonuyla işletme paneline dönebilirsiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Kategori seçimi',
          icerik:
              'Liste veya ızgaradan kategoriye dokunun (ör. Kuaför, Taksi, Araç Kiralama). Seçilen kategoriye göre esnaf listesi veya özel modül açılır.',
          ikon: Icons.category_outlined,
        ),
        RehberBolum(
          baslik: 'Konum',
          icerik:
              'Konum izni verirseniz size yakın işletmeler öncelikli listelenir. İzin yoksa genel liste gösterilir.',
          ikon: Icons.my_location,
        ),
        RehberBolum(
          baslik: 'Esnaf / müşteri geçişi',
          icerik:
              'Telefonunuz bir işletmeye bağlıysa AppBar’daki geçiş ikonuyla esnaf paneline gidebilirsiniz.',
          ikon: Icons.swap_horiz,
        ),
      ],
      ipuclari: [
        'Aradığınız kategoriyi göremiyorsanız aşağı kaydırın veya uygulama güncellemesini kontrol edin.',
      ],
      bildirimler: [
        'Onay bekleyen veya yaklaşan randevularınız için bildirim alırsınız.',
      ],
    ),

    'MusteriEkrani': const EkranRehberIcerik(
      baslik: 'Esnaf Listesi',
      ozet:
          'Seçtiğiniz kategorideki işletmeleri görür, sıralar ve randevu için esnaf seçersiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Listeyi okuma',
          icerik:
              'Her kartta işletme adı, puan, mesafe ve kısa bilgiler yer alır. Karta dokunarak detaya / randevuya geçin.',
          ikon: Icons.storefront_outlined,
        ),
        RehberBolum(
          baslik: 'Sıralama ve filtre',
          icerik:
              'Varsayılan olarak size yakınlık önceliklidir (konum açıksa). Puan veya popülerlik seçenekleri varsa üst menüden değiştirin.',
          ikon: Icons.sort,
        ),
      ],
      ipuclari: [
        'Kapalı veya randevu alımı durdurulmuş işletmelerde randevu butonu görünmeyebilir.',
      ],
      bildirimler: [
        'Randevu oluşturunca esnafa talep bildirimi gider; onay/red sonucu size iletilir.',
      ],
    ),

    'RandevuEkrani': const EkranRehberIcerik(
      baslik: 'Randevu Alma',
      ozet:
          'Hizmet, gün ve saat seçerek randevu oluşturursunuz. Onay modu esnafa göre otomatik veya manueldir.',
      bolumler: [
        RehberBolum(
          baslik: 'Adım adım',
          icerik:
              '1. Hizmet(ler)i seçin.\n'
              '2. Tarih seçin (esnafın açık günleri gösterilir).\n'
              '3. Müsait saate dokunun.\n'
              '4. Not varsa yazın ve onaylayın.\n'
              '5. “Randevularım”dan durumu takip edin.',
          ikon: Icons.event_available,
        ),
        RehberBolum(
          baslik: 'Otomatik / manuel onay',
          icerik:
              'Otomatik: randevu hemen kesinleşir.\n'
              'Manuel: esnaf onaylayana kadar “Bekliyor” kalır; red edilirse bildirim alırsınız.',
          ikon: Icons.verified_outlined,
        ),
      ],
      ipuclari: [
        'Geçmiş saatler ve dolu slotlar seçilemez.',
        'Aynı güne sınır koyan işletmelerde bugün için slot çıkmayabilir.',
      ],
      bildirimler: [
        'Onay, red ve hatırlatma bildirimleri telefonunuza gelir.',
        'Randevu saati yaklaşınca hatırlatma planlanabilir.',
      ],
    ),

    'KullaniciRandevuEkrani': const EkranRehberIcerik(
      baslik: 'Randevularım',
      ozet:
          'Oluşturduğunuz tüm randevu ve talepleri görür, iptal veya detay işlemlerini buradan yaparsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Durumlar',
          icerik:
              'Bekliyor = esnaf onayı bekleniyor.\n'
              'Onaylandı = kesinleşti.\n'
              'Reddedildi / İptal = geçersiz.\n'
              'Tamamlandı = hizmet bitti; yorum istenebilir.',
          ikon: Icons.list_alt,
        ),
        RehberBolum(
          baslik: 'İptal',
          icerik:
              'Politika uygunsa iptal butonu görünür. İptal sonrası esnafa bilgi gider; slot yeniden açılabilir.',
          ikon: Icons.cancel_outlined,
        ),
      ],
      bildirimler: [
        'Durum değişince (onay/red) anlık bildirim alırsınız.',
        'Hizmet sonrası yorum hatırlatması gelebilir.',
      ],
    ),

    'EsnafPaneli': const EkranRehberIcerik(
      baslik: 'Esnaf Paneli',
      ozet:
          'İşletmenizin yönetim merkezi: profil, mesai, hizmetler, ajanda ve gelen randevular.',
      bolumler: [
        RehberBolum(
          baslik: 'Menü kartları',
          icerik:
              'Her kart bir yönetim ekranına gider. Önce profil ve mesaiyi tamamlayın; sonra hizmet tanımlayıp randevu alımını açın.',
          ikon: Icons.dashboard_outlined,
        ),
        RehberBolum(
          baslik: 'Randevu akışı',
          icerik:
              'Manuel onaydaysanız “Randevu Kayıtları”ndan talepleri onaylayın/reddedin. Otomatik modda slot dolunca müşteriye anında onay gider.',
          ikon: Icons.assignment_turned_in_outlined,
        ),
      ],
      ipuclari: [
        'Parametrelerden “Randevu alımını durdur” ile geçici kapatma yapabilirsiniz.',
      ],
      bildirimler: [
        'Yeni randevu talebinde anlık bildirim alırsınız.',
        'Bildirim gelmiyorsa OneSignal / telefon iznini kontrol edin.',
      ],
    ),

    'EsnafAjandaEkrani': const EkranRehberIcerik(
      baslik: 'Ajanda',
      ozet:
          'Günlük / haftalık doluluk ve randevu slotlarını görsel olarak yönettiğiniz takvimdir.',
      bolumler: [
        RehberBolum(
          baslik: 'Kullanım',
          icerik:
              'Güne dokunarak o günün randevularını görün. Dolu saatler müşteriye kapalı görünür. Manuel blokaj varsa ilgili butonlarla saat kapatabilirsiniz.',
          ikon: Icons.calendar_month,
        ),
      ],
      bildirimler: [
        'Yeni rezervasyon ajandayı anında günceller; aynı anda çakışma olmaması için işlemler atomik yapılır.',
      ],
    ),

    'EsnafParametreEkrani': const EkranRehberIcerik(
      baslik: 'Gelişmiş Ayarlar',
      ozet:
          'Onay modu, ileriye dönük gün limiti, minimum süre gibi işletme kurallarını ayarlarsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Önemli ayarlar',
          icerik:
              '• Randevu onay modu (Otomatik / Manuel)\n'
              '• Maksimum randevu günü (kaç gün ileriye açılsın)\n'
              '• Minimum randevu süresi\n'
              '• Randevu alımını durdur (acil kapatma)',
          ikon: Icons.tune,
        ),
      ],
      ipuclari: [
        'Değişiklikleri kaydetmeden çıkarsanız uygulanmaz.',
      ],
      bildirimler: [
        'Ayarlar müşteri tarafındaki müsaitlik hesaplamasını hemen etkiler.',
      ],
    ),

    'EsnafRandevuYonetimEkrani': const EkranRehberIcerik(
      baslik: 'Randevu Kayıtları',
      ozet:
          'Gelen talepleri onaylama, reddetme ve geçmişi inceleme ekranıdır.',
      bolumler: [
        RehberBolum(
          baslik: 'Onay / red',
          icerik:
              'Bekleyen kayda girip onaylayın veya red nedeni ile reddedin. Onay slotu kilitler; red müşteriye bildirilir.',
          ikon: Icons.fact_check_outlined,
        ),
      ],
      bildirimler: [
        'Onay veya red sonrası müşteriye bildirim gider.',
        'Yeni talep geldiğinde size bildirim düşer.',
      ],
    ),

    'TumYorumlarEkrani': const EkranRehberIcerik(
      baslik: 'Yorumlar',
      ozet: 'İşletmeye yapılan müşteri değerlendirmelerini okursunuz.',
      bolumler: [
        RehberBolum(
          baslik: 'Okuma',
          icerik:
              'Puan ve metin yorumları listelenir. En yeni veya en yüksek puan sıralaması varsa üstten seçin.',
          ikon: Icons.reviews_outlined,
        ),
      ],
    ),

    'AdminEkrani': const EkranRehberIcerik(
      baslik: 'Yönetici Paneli',
      ozet:
          'Esnaf onayları, kategori yönetimi ve sistem ayarlarının yapıldığı yetkili ekrandır.',
      bolumler: [
        RehberBolum(
          baslik: 'Esnaf onayı',
          icerik:
              'Bekleyen işletmeleri inceleyip onaylayın veya reddedin. Onaysız esnaf müşteriye görünmez.',
          ikon: Icons.admin_panel_settings,
        ),
      ],
      bildirimler: [
        'Kritik sistem bildirimleri yönetici kanalına düşebilir.',
      ],
    ),

    // ——— Araç Kiralama ———
    'AracKiralamaMusteriEkrani': const EkranRehberIcerik(
      baslik: 'Araç Kiralama – Firmalar',
      ozet: 'Kiralama firmalarını listeler; araç ve tarih seçimine giden giriş noktasıdır.',
      bolumler: [
        RehberBolum(
          baslik: 'Firma seçimi',
          icerik:
              'Firmaya dokunun. Filo, fiyat ve müsaitlik bilgisi sonraki adımlarda gelir.',
          ikon: Icons.directions_car,
        ),
      ],
      bildirimler: [
        'Kiralama talebi oluşunca firmaya bildirim gider; onay sonucu size iletilir.',
      ],
    ),

    'AracKiralamaRandevuEkrani': const EkranRehberIcerik(
      baslik: 'Araç Kiralama – Rezervasyon',
      ozet:
          'Teslim alma / bırakma tarihlerini ve aracı seçerek kiralama talebi oluşturursunuz.',
      bolumler: [
        RehberBolum(
          baslik: 'Tarih aralığı',
          icerik:
              'Başlangıç ve bitiş tarihini seçin. Bakım / temizlik tamponu varsa bitiş sonrası o süre dolana kadar araç başkasına açılmaz.',
          ikon: Icons.date_range,
        ),
        RehberBolum(
          baslik: 'Araç seçimi',
          icerik:
              'Müsait araçlardan birini seçin. Çakışan tarihlerde araç listede çıkmaz veya seçilemez.',
          ikon: Icons.car_rental,
        ),
      ],
      ipuclari: [
        'Teslimat / iade ekranları kira sürecinde fotoğraf ve kilometre kaydı için kullanılır.',
      ],
      bildirimler: [
        'Akıllı takip açıksa süre bitimine yakın uzatma hatırlatması alırsınız.',
        'Gecikme durumunda firmaya gecikme uyarısı planlanabilir.',
      ],
    ),

    'AracKiralamaEsnafPaneli': const EkranRehberIcerik(
      baslik: 'Araç Kiralama – İşletme Paneli',
      ozet:
          'Filo, kanallar, kiralama kayıtları, parametreler ve teslimat süreçlerini yönetirsiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Filo',
          icerik:
              'Araç ekleyin / düzenleyin. Plaka, durum ve müsaitlik rezervasyon motorunu besler.',
          ikon: Icons.local_shipping_outlined,
        ),
        RehberBolum(
          baslik: 'Kayıtlar',
          icerik:
              'Gelen kiralama taleplerini onaylayın. Teslim / iade ve kaza bildirimi ilgili kayıttan açılır.',
          ikon: Icons.assignment,
        ),
      ],
      bildirimler: [
        'Yeni kira talebi bildirimi.',
        'Akıllı takip: gecikme / uzatma hatırlatmaları (ayar açıksa).',
      ],
    ),

    'AracParametreEkrani': const EkranRehberIcerik(
      baslik: 'Araç Kiralama – Parametreler',
      ozet:
          'Bakım/temizlik süresi, akıllı takip, onay modu gibi kiralama kurallarını ayarlarsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Bakım / temizlik süresi',
          icerik:
              'İade sonrası aracın kaç dakika / saat başkasına verilmeyeceğini belirler. Çakışmayı önler.',
          ikon: Icons.cleaning_services,
        ),
        RehberBolum(
          baslik: 'Akıllı takip',
          icerik:
              'Açıksa müşteriye süre uzatma, size gecikme uyarıları zamanlanır.',
          ikon: Icons.notifications_active_outlined,
        ),
      ],
      bildirimler: [
        'Akıllı takip kapalıysa otomatik süre bildirimleri planlanmaz.',
      ],
    ),

    'AracKiralamaEsnafRandevuOnayEkrani': const EkranRehberIcerik(
      baslik: 'Kiralama Kayıtları',
      ozet: 'Kiralama taleplerini onaylar, reddeder ve geçmişi incelersiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Onay akışı',
          icerik:
              'Bekleyen talebi açın → aracı / tarihleri kontrol edin → onay veya red. Onay sonrası müşteriye bildirim gider.',
          ikon: Icons.task_alt,
        ),
      ],
      bildirimler: [
        'Onay/red müşteriye iletilir.',
        'Yeni talep size anlık bildirilir.',
      ],
    ),

    'KiraTeslimatEkrani': const EkranRehberIcerik(
      baslik: 'Teslim / İade',
      ozet:
          'Araç tesliminde ve iadesinde fotoğraf, kilometre ve durum kaydı alırsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Nasıl kullanılır?',
          icerik:
              '1. İlgili kira kaydını açın.\n'
              '2. Teslim veya iade modunu seçin.\n'
              '3. Fotoğrafları ekleyin, km / not girin.\n'
              '4. Kaydedin — anlaşmazlıklarda delil olur.',
          ikon: Icons.photo_camera_outlined,
        ),
      ],
      bildirimler: [
        'Kayıt tamamlanınca karşı tarafa bilgilendirme gidebilir.',
      ],
    ),

    'KazaBildirimEkrani': const EkranRehberIcerik(
      baslik: 'Kaza Bildirimi',
      ozet:
          'Kaza anında tutanak ve fotoğrafları sisteme işlersiniz. Araç müsaitliği etkilenir.',
      bolumler: [
        RehberBolum(
          baslik: 'Güvenli adımlar',
          icerik:
              '1. Önce kendi güvenliğiniz; dörtlüleri yakın.\n'
              '2. Yaralı varsa 112.\n'
              '3. Araçları oynatmadan geniş açılı fotoğraf.\n'
              '4. Tutanak + ehliyet/ruhsat/sigorta fotoğrafları.\n'
              '5. Formu kaydedin.',
          ikon: Icons.car_crash_outlined,
        ),
      ],
      bildirimler: [
        'Bildirim kaydı firmaya iletilir; araç bakım / hasar sürecine alınabilir.',
      ],
    ),

    // ——— Taksi ———
    'TaksiModSecimEkrani': const EkranRehberIcerik(
      baslik: 'Taksi Mod Seçimi',
      ozet:
          'Yönetici paneli, sürücü / durak takibi veya yolcu ekranı arasında seçim yaparsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Roller',
          icerik:
              '• Yönetici: filo, çizelge, parametreler\n'
              '• Sürücü: sıra, profil, SOS\n'
              '• Yolcu: çağrı / rezervasyon',
          ikon: Icons.groups_outlined,
        ),
      ],
    ),

    'TaksiMusteriEkrani': const EkranRehberIcerik(
      baslik: 'Taksi – Yolcu',
      ozet: 'Müsait araçları görür, hemen çağrı veya ileri rezervasyon yaparsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Çağrı / rezervasyon',
          icerik:
              'Konumunuz alış noktası olur. Varış yazarak (mekan adı da olur) talep oluşturun. Bugün çalışan / nöbetçi araçlar listelenir; istirahatli araçlar gizlenebilir.',
          ikon: Icons.local_taxi,
        ),
      ],
      bildirimler: [
        'Talebiniz durağa / araca bildirilir; durum değişince size bildirim gelir.',
      ],
    ),

    'TaksiRandevuEkrani': const EkranRehberIcerik(
      baslik: 'Taksi Rezervasyonu',
      ozet: 'Tarih-saat ve güzergah ile taksi rezervasyonu oluşturursunuz.',
      bolumler: [
        RehberBolum(
          baslik: 'Adımlar',
          icerik:
              'Alış / varış → tarih-saat → müsait araç/şoför → onay. Araç odaklı sistemde plaka seçilir.',
          ikon: Icons.schedule,
        ),
      ],
      bildirimler: [
        'Onay ve hatırlatma bildirimleri aktifse telefonunuza düşer.',
      ],
    ),

    'TaksiEsnafPaneli': const EkranRehberIcerik(
      baslik: 'Taksi – Yönetici Paneli',
      ozet:
          'Durak yönetimi: filo, nöbet çizelgesi, mesai, takip ve randevu kayıtları.',
      bolumler: [
        RehberBolum(
          baslik: 'Önerilen sıra',
          icerik:
              '1. Profil / konum\n2. Mesai ve çalışma günleri\n3. Filoya araç ekle (şoför plaka tanımlı olmalı)\n4. Nöbet çizelgesi\n5. Gelişmiş ayarlar (mesafe, gizleme)',
          ikon: Icons.rule,
        ),
      ],
      bildirimler: [
        'Yeni rezervasyon ve SOS acil sinyalleri yöneticiye iletilir.',
      ],
    ),

    'TaksiCizelgeEkrani': const EkranRehberIcerik(
      baslik: 'Nöbet Çizelgesi',
      ozet:
          'Hangi aracın hangi gün Nöbetçi / Çalışıyor / İstirahat olacağını planlarsınız. Kaydetmeden çıkmayın.',
      bolumler: [
        RehberBolum(
          baslik: 'Durumlar',
          icerik:
              'N = Nöbetçi (nöbet saatleri)\nÇ = Çalışıyor (gündüz mesai)\nİ = İstirahat (müşteriye görünmez olabilir)',
          ikon: Icons.event_note,
        ),
        RehberBolum(
          baslik: 'Toplu plan',
          icerik:
              'Seçili araçlara gün/hafta/ay/yıl yayabilirsiniz. “1 gün çalış 1 gün istirahat” ve sıralı nöbet seçenekleri vardır. Sıralı nöbet için filo nöbet sırası tanımlı olmalı.',
          ikon: Icons.auto_awesome,
        ),
        RehberBolum(
          baslik: 'Kaydet / sil',
          icerik:
              'Mavi disk = kaydet. Kayıt sil kapsam seçerek temizler; geniş silmede onay uyarısı çıkar.',
          ikon: Icons.save,
        ),
      ],
      ipuclari: [
        'Kaydetmeden çıkarsanız değişiklikler kaybolur.',
      ],
    ),

    'TaksiDurakTakipEkrani': const EkranRehberIcerik(
      baslik: 'Durak Takip',
      ozet:
          'Araçların sıraya giriş-çıkış ve mola durumlarını anlık izlersiniz / yönetirsiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Yeşil / turuncu ok',
          icerik:
              'Yeşil: sıraya gir (durak merkezine tanımlı mesafede olmalısınız).\n'
              'Turuncu: sıradan çık.\n'
              'Mesafe aşımı varsa yeşil ok reddedilir.',
          ikon: Icons.alt_route,
        ),
      ],
      bildirimler: [
        'Sıra değişiklikleri anlık yansır; SOS sinyali bu ekosistemde yöneticilere gider.',
      ],
    ),

    'TaksiParametreEkrani': const EkranRehberIcerik(
      baslik: 'Taksi – Gelişmiş Ayarlar',
      ozet: 'Konum doğrulama mesafesi, araç odaklı sistem, istirahat gizleme ve randevu durdurma.',
      bolumler: [
        RehberBolum(
          baslik: 'Konum doğrulama mesafesi',
          icerik:
              'Şoförün sıraya girebilmesi için durağa maksimum metre. Uzaktan haksız sıra girişini engeller.',
          ikon: Icons.social_distance,
        ),
        RehberBolum(
          baslik: 'Araç odaklı sistem',
          icerik:
              'Açıksa rezervasyonlar plaka üzerine alınır; müşteri plaka görür.',
          ikon: Icons.pin,
        ),
        RehberBolum(
          baslik: 'İstirahatli araçları gizle',
          icerik:
              'İ işaretli araçlar yolcu listesinde görünmez.',
          ikon: Icons.visibility_off,
        ),
        RehberBolum(
          baslik: 'Randevu alımını durdur',
          icerik:
              'Online rezervasyonu geçici kapatır; mevcut kayıtlar silinmez.',
          ikon: Icons.block,
        ),
      ],
    ),

    'TaksiEsnafRandevuOnayEkrani': const EkranRehberIcerik(
      baslik: 'Taksi Randevu Kayıtları',
      ozet: 'Gelen taksi rezervasyonlarını onaylar / yönetirsiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'İşlem',
          icerik:
              'Bekleyen kaydı açın, güzergah ve saati kontrol edin, onay veya red verin.',
          ikon: Icons.fact_check,
        ),
      ],
      bildirimler: [
        'Sonuç yolcuya bildirilir.',
      ],
    ),

    'TaksiSurucuProfilDetayEkrani': const EkranRehberIcerik(
      baslik: 'Sürücü Profili',
      ozet: 'Plaka, belgeler ve sürücü bilgilerinizi güncellersiniz. Plaka olmadan durağa eklenemezsiniz.',
      bolumler: [
        RehberBolum(
          baslik: 'Plaka',
          icerik:
              'Plakanızı kaydedin. Yönetici “Yeni Araç Ekle” ile sizi filo’ya alabilir.',
          ikon: Icons.directions_car_filled,
        ),
        RehberBolum(
          baslik: 'SOS',
          icerik:
              'Tehlikede SOS’u ~3 sn basılı tutun; konumunuzla acil sinyal gider.',
          ikon: Icons.sos,
        ),
      ],
      bildirimler: [
        'SOS yöneticilere ve meslektaşlara iletilir.',
      ],
    ),

    'TaksiSurucuDogrulamaEkrani': const EkranRehberIcerik(
      baslik: 'Güvenlik Doğrulaması',
      ozet: 'Ehliyet, ruhsat ve sigorta belgelerini yükleyerek güvenilirliğinizi artırırsınız.',
      bolumler: [
        RehberBolum(
          baslik: 'Belge yükleme',
          icerik:
              'İstenen belgelerin net fotoğraflarını ekleyin. Onay süreci yönetici / sistem tarafındadır.',
          ikon: Icons.badge_outlined,
        ),
      ],
    ),
  };
}
