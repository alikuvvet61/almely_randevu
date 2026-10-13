import 'package:flutter/material.dart';

/// Kategori adından ikon ve renk seçer. Kayıtlı kod yoksa bu tahmin kullanılır.
class KategoriGorseli {
  static IconData ikon(String ad) => _bul(ad).ikon;
  static Color renk(String ad) => _bul(ad).renk;

  static _Secim _bul(String ad) {
    final n = _norm(ad);
    if (n.isEmpty) return const _Secim(Icons.business, Colors.blueAccent);
    for (final kural in _kurallar) {
      for (final anahtar in kural.anahtarlar) {
        if (_eslesir(n, anahtar)) return kural.secim;
      }
    }
    return const _Secim(Icons.business, Colors.blueAccent);
  }

  static bool _eslesir(String metin, String anahtar) {
    if (metin == anahtar || metin.contains(anahtar) && anahtar.contains(' ')) {
      return metin == anahtar || metin.contains(anahtar);
    }
    final parcalar = metin.split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty);
    if (parcalar.contains(anahtar)) return true;
    if (anahtar.length >= 5) {
      for (final p in parcalar) {
        if (p.contains(anahtar)) return true;
      }
    }
    return false;
  }

  static String _norm(String s) {
    const donus = {
      'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g',
      'ı': 'i', 'I': 'i', 'İ': 'i', 'i': 'i',
      'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's',
      'ü': 'u', 'Ü': 'u',
    };
    final b = StringBuffer();
    for (final birim in s.trim().characters) {
      final karsilik = donus[birim];
      if (karsilik != null) {
        b.write(karsilik);
      } else {
        b.write(birim.toLowerCase().replaceAll('\u0307', ''));
      }
    }
    return b.toString();
  }
}

class _Secim {
  final IconData ikon;
  final Color renk;
  const _Secim(this.ikon, this.renk);
}

class _Kural {
  final List<String> anahtarlar;
  final _Secim secim;
  const _Kural(this.anahtarlar, this.secim);
}

const List<_Kural> _kurallar = [
  _Kural(['pet kuafor', 'pet bakim'], _Secim(Icons.pets, Colors.brown)),
  _Kural(['veteriner'], _Secim(Icons.pets, Colors.redAccent)),
  _Kural(['diyetisyen', 'diyet', 'beslenme'], _Secim(Icons.apple, Colors.lightGreen)),
  _Kural(['fizyoterapi', 'fizik tedavi', 'rehabilitasyon', 'ergoterapi', 'fizyo'], _Secim(Icons.healing, Colors.teal)),
  _Kural(['konusma terapisi', 'dil terapisi'], _Secim(Icons.record_voice_over, Colors.indigo)),
  _Kural(['psikolog', 'psikiyatri', 'psikoterapi', 'terapi'], _Secim(Icons.psychology, Colors.indigo)),
  _Kural(['ozel ders'], _Secim(Icons.school, Colors.deepOrange)),
  _Kural(['arac kiralama', 'oto kiralama', 'rent a car'], _Secim(Icons.car_rental, Colors.blueGrey)),
  _Kural(['oto yikama', 'arac yikama'], _Secim(Icons.local_car_wash, Colors.blue)),
  _Kural(['hali saha', 'halisaha', 'futbol sahasi'], _Secim(Icons.sports_soccer, Colors.green)),
  _Kural(['dugun', 'nikah', 'nisan', 'kina', 'sunnet'], _Secim(Icons.celebration, Colors.purple)),
  _Kural(['taksi', 'dolmus'], _Secim(Icons.local_taxi, Colors.amber)),
  _Kural(['oto servis', 'oto tamir', 'lastik', 'mekanik', 'ekspertiz', 'oto galeri'], _Secim(Icons.car_repair, Colors.blueGrey)),
  _Kural(['internet kafe', 'playstation', 'oyun salonu'], _Secim(Icons.sports_esports, Colors.deepPurple)),
  _Kural(['restoran', 'lokanta', 'catering', 'kasap'], _Secim(Icons.restaurant, Colors.redAccent)),
  _Kural(['pastane', 'firin', 'tatli', 'unlu'], _Secim(Icons.cake, Colors.pink)),
  _Kural(['kafe', 'cafe', 'kahve', 'kahveci'], _Secim(Icons.local_cafe, Colors.brown)),
  _Kural(['kuafor', 'berber'], _Secim(Icons.content_cut, Colors.orange)),
  _Kural(['dis hekimi', 'disci', 'ortodonti', 'dis'], _Secim(Icons.medical_services, Colors.cyan)),
  _Kural(['eczane'], _Secim(Icons.local_pharmacy, Colors.green)),
  _Kural(['gozluk', 'optik'], _Secim(Icons.visibility, Colors.blue)),
  _Kural(['isitme', 'kulak'], _Secim(Icons.hearing, Colors.blue)),
  _Kural(['laboratuvar', 'tahlil'], _Secim(Icons.science, Colors.teal)),
  _Kural(['eczane'], _Secim(Icons.local_pharmacy, Colors.green)),
  _Kural(['doktor', 'klinik', 'muayene', 'hastane', 'hemsire', 'ambulans', 'dis'], _Secim(Icons.medical_services, Colors.redAccent)),
  _Kural(['spa', 'masaj', 'hamam', 'sauna'], _Secim(Icons.spa, Colors.pink)),
  _Kural(['tirnak', 'manikur', 'pedikur'], _Secim(Icons.back_hand, Colors.pinkAccent)),
  _Kural(['makyaj', 'kirpik', 'estetisyen', 'guzellik', 'epilasyon', 'lazer', 'cilt'], _Secim(Icons.face, Colors.pink)),
  _Kural(['fitness', 'spor salonu', 'pilates', 'yoga', 'crossfit', 'gym'], _Secim(Icons.fitness_center, Colors.deepOrange)),
  _Kural(['yuzme', 'havuz'], _Secim(Icons.pool, Colors.lightBlue)),
  _Kural(['tenis'], _Secim(Icons.sports_tennis, Colors.green)),
  _Kural(['basketbol'], _Secim(Icons.sports_basketball, Colors.orange)),
  _Kural(['voleybol'], _Secim(Icons.sports_volleyball, Colors.orange)),
  _Kural(['boks', 'kickboks'], _Secim(Icons.sports_mma, Colors.red)),
  _Kural(['futbol'], _Secim(Icons.sports_soccer, Colors.green)),
  _Kural(['otel', 'pansiyon', 'konaklama', 'bungalov'], _Secim(Icons.hotel, Colors.indigo)),
  _Kural(['emlak', 'gayrimenkul'], _Secim(Icons.home_work, Colors.brown)),
  _Kural(['avukat', 'hukuk'], _Secim(Icons.gavel, Colors.brown)),
  _Kural(['muhasebe', 'mali musavir', 'smmm'], _Secim(Icons.calculate, Colors.blueGrey)),
  _Kural(['fotograf', 'fotografci'], _Secim(Icons.photo_camera, Colors.blueGrey)),
  _Kural(['video', 'kameraman'], _Secim(Icons.videocam, Colors.blueGrey)),
  _Kural(['muzik', 'piyano', 'gitar', 'keman'], _Secim(Icons.music_note, Colors.deepPurple)),
  _Kural(['dans'], _Secim(Icons.music_note, Colors.purple)),
  _Kural(['tiyatro'], _Secim(Icons.theaters, Colors.deepPurple)),
  _Kural(['sinema'], _Secim(Icons.movie, Colors.indigo)),
  _Kural(['nargile'], _Secim(Icons.smoking_rooms, Colors.brown)),
  _Kural(['bar', 'pub'], _Secim(Icons.local_bar, Colors.deepPurple)),
  _Kural(['hali yikama', 'koltuk yikama', 'kuru temizleme', 'camasir', 'temizlik'], _Secim(Icons.cleaning_services, Colors.lightBlue)),
  _Kural(['elektrik'], _Secim(Icons.electrical_services, Colors.amber)),
  _Kural(['tesisat'], _Secim(Icons.plumbing, Colors.blue)),
  _Kural(['boya', 'badana'], _Secim(Icons.format_paint, Colors.orange)),
  _Kural(['cilingir', 'kilit'], _Secim(Icons.lock, Colors.blueGrey)),
  _Kural(['klima', 'kombi', 'dogalgaz'], _Secim(Icons.ac_unit, Colors.lightBlue)),
  _Kural(['kamera', 'alarm'], _Secim(Icons.videocam, Colors.blueGrey)),
  _Kural(['camci', 'cam'], _Secim(Icons.window, Colors.lightBlue)),
  _Kural(['nakliye', 'nakliyat', 'kargo', 'kurye'], _Secim(Icons.local_shipping, Colors.orange)),
  _Kural(['cicek', 'cicekci'], _Secim(Icons.local_florist, Colors.pink)),
  _Kural(['market', 'bakkal', 'manav'], _Secim(Icons.shopping_basket, Colors.green)),
  _Kural(['kuyum'], _Secim(Icons.diamond, Colors.amber)),
  _Kural(['terzi', 'dikis'], _Secim(Icons.checkroom, Colors.purple)),
  _Kural(['kres', 'anaokulu', 'bebek', 'cocuk bakimi'], _Secim(Icons.child_care, Colors.orange)),
  _Kural(['petshop', 'akvaryum', 'hayvan', 'pet'], _Secim(Icons.pets, Colors.brown)),
  _Kural(['bilgisayar', 'yazilim', 'bilisim'], _Secim(Icons.computer, Colors.blue)),
  _Kural(['telefon'], _Secim(Icons.phone_android, Colors.teal)),
  _Kural(['matbaa', 'baski'], _Secim(Icons.print, Colors.blueGrey)),
  _Kural(['grafik', 'reklam', 'tabela'], _Secim(Icons.brush, Colors.deepOrange)),
  _Kural(['sigorta'], _Secim(Icons.shield, Colors.blue)),
  _Kural(['guvenlik'], _Secim(Icons.security, Colors.blueGrey)),
  _Kural(['ceviri', 'tercume', 'ingilizce'], _Secim(Icons.translate, Colors.indigo)),
  _Kural(['surucu', 'ehliyet'], _Secim(Icons.directions_car, Colors.blue)),
  _Kural(['kodlama', 'robotik'], _Secim(Icons.code, Colors.indigo)),
  _Kural(['mimar'], _Secim(Icons.architecture, Colors.brown)),
  _Kural(['danisman'], _Secim(Icons.support_agent, Colors.teal)),
  _Kural(['noter'], _Secim(Icons.description, Colors.blueGrey)),
  _Kural(['otobus', 'minibus'], _Secim(Icons.directions_bus, Colors.amber)),
  _Kural(['transfer'], _Secim(Icons.airport_shuttle, Colors.blue)),
  _Kural(['tekne', 'yat'], _Secim(Icons.directions_boat, Colors.blue)),
  _Kural(['bisiklet'], _Secim(Icons.directions_bike, Colors.green)),
  _Kural(['motosiklet'], _Secim(Icons.two_wheeler, Colors.blueGrey)),
  _Kural(['otopark'], _Secim(Icons.local_parking, Colors.blue)),
  _Kural(['benzin', 'akaryakit'], _Secim(Icons.local_gas_station, Colors.red)),
  _Kural(['mobilya'], _Secim(Icons.chair, Colors.brown)),
  _Kural(['cati'], _Secim(Icons.roofing, Colors.blueGrey)),
  _Kural(['asansor'], _Secim(Icons.elevator, Colors.blueGrey)),
  _Kural(['bahce', 'peyzaj', 'bahcivan'], _Secim(Icons.grass, Colors.green)),
  _Kural(['ilaclama', 'bocek', 'hasere'], _Secim(Icons.pest_control, Colors.green)),
  _Kural(['aritma'], _Secim(Icons.water_drop, Colors.lightBlue)),
  _Kural(['gunes enerji', 'gunes panel', 'solar'], _Secim(Icons.wb_sunny, Colors.amber)),
  _Kural(['yasli bakim', 'hasta bakim', 'evde bakim'], _Secim(Icons.health_and_safety, Colors.teal)),
  _Kural(['resim', 'sanat'], _Secim(Icons.palette, Colors.deepOrange)),
  _Kural(['kurs', 'egitim', 'ogretmen', 'dershane', 'etut', 'ders'], _Secim(Icons.school, Colors.deepOrange)),
  _Kural(['organizasyon'], _Secim(Icons.celebration, Colors.purple)),
  _Kural(['tamir', 'teknik servis'], _Secim(Icons.build, Colors.blueGrey)),
];
