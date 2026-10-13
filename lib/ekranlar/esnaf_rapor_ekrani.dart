import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modeller/esnaf_modeli.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/firestore_servisi.dart';

class EsnafRaporEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  const EsnafRaporEkrani({super.key, required this.esnaf});

  @override
  State<EsnafRaporEkrani> createState() => _EsnafRaporEkraniState();
}

class _EsnafRaporEkraniState extends State<EsnafRaporEkrani> {
  final _firestore = FirestoreServisi();
  bool _buAy = true;
  bool _yukleniyor = true;
  List<RandevuModeli> _randevular = [];
  List<({DateTime baslangic, double ucret, String durum})> _paketler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final randevular = await _firestore.esnafRandevulariBirKez(widget.esnaf.id);
    final paketler = await _firestore.esnafPaketOzetleri(widget.esnaf.id);
    if (!mounted) return;
    setState(() {
      _randevular = randevular;
      _paketler = paketler;
      _yukleniyor = false;
    });
  }

  DateTime get _ayBas {
    final simdi = DateTime.now();
    if (_buAy) return DateTime(simdi.year, simdi.month);
    return DateTime(simdi.year, simdi.month - 1);
  }

  DateTime get _aySon {
    final bas = _ayBas;
    return DateTime(bas.year, bas.month + 1);
  }

  bool _ayIcinde(DateTime tarih) {
    final gun = DateTime(tarih.year, tarih.month, tarih.day);
    return !gun.isBefore(_ayBas) && gun.isBefore(_aySon);
  }

  @override
  Widget build(BuildContext context) {
    final ayYazi = DateFormat('MMMM yyyy', 'tr_TR').format(_ayBas);
    final ozet = _ozet();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor'),
        actions: [
          IconButton(onPressed: _yukleniyor ? null : _yukle, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 48),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Bu ay')),
                    ButtonSegment(value: false, label: Text('Geçen ay')),
                  ],
                  selected: {_buAy},
                  onSelectionChanged: (s) => setState(() => _buAy = s.first),
                ),
                const SizedBox(height: 8),
                Text(ayYazi, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                _kart(
                  baslik: 'Doluluk',
                  deger: ozet.dolulukYazi,
                  alt: ozet.dolulukAlt,
                  renk: Colors.blue,
                  ikon: Icons.event_available,
                ),
                _kart(
                  baslik: 'İptal oranı',
                  deger: ozet.iptalYazi,
                  alt: ozet.iptalAlt,
                  renk: Colors.orange,
                  ikon: Icons.event_busy,
                ),
                _kart(
                  baslik: 'Ciro tahmini',
                  deger: ozet.ciroYazi,
                  alt: 'Onaylı randevu ve bu ay açılan paket ücretleri. Paket bir kez sayılır. Kasada tahsil edilen tutar değildir.',
                  renk: Colors.green,
                  ikon: Icons.payments_outlined,
                ),
              ],
            ),
    );
  }

  Widget _kart({
    required String baslik,
    required String deger,
    required String alt,
    required Color renk,
    required IconData ikon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renk.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, color: renk),
              const SizedBox(width: 8),
              Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(deger, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renk)),
          const SizedBox(height: 6),
          Text(alt, style: const TextStyle(color: Colors.black54, height: 1.3)),
        ],
      ),
    );
  }

  _RaporOzet _ozet() {
    final ayin = _randevular.where((r) => _ayIcinde(r.tarih)).toList();
    final doluDurum = {'Onaylandı', 'Tamamlandı', 'Onay bekliyor', 'Beklemede', 'Kullanımda'};
    final iptalDurum = {'İptal Edildi', 'Reddedildi', 'Gelmedi'};
    final para = NumberFormat.decimalPattern('tr_TR');

    final acikDakika = _acikDakika();
    final doluDakika = ayin.where((r) => doluDurum.contains(r.durum)).fold<int>(0, (t, r) => t + (r.sure < 0 ? 0 : r.sure));
    String dolulukYazi;
    String dolulukAlt;
    if (acikDakika <= 0) {
      dolulukYazi = '—';
      dolulukAlt = 'Mesai saati seçilmemiş. Açılış, kapanış ve çalışma günü kaydedilince doluluk hesaplanır.';
    } else {
      final yuzde = (doluDakika / acikDakika * 100).round();
      dolulukYazi = '%$yuzde';
      dolulukAlt = '${_saatYazi(doluDakika)} dolu, ${_saatYazi(acikDakika)} mesai açık.';
    }

    final iptal = ayin.where((r) => iptalDurum.contains(r.durum)).length;
    final String iptalYazi;
    final String iptalAlt;
    if (ayin.isEmpty) {
      iptalYazi = '—';
      iptalAlt = 'Bu ayda randevu kaydı yok.';
    } else {
      iptalYazi = '%${(iptal / ayin.length * 100).round()}';
      iptalAlt = '$iptal kayıt iptal, red veya gelmedi. Toplam ${ayin.length} randevu.';
    }

    var ciro = 0.0;
    for (final p in _paketler) {
      if (p.durum == 'iptal') continue;
      if (!_ayIcinde(p.baslangic)) continue;
      ciro += p.ucret;
    }
    final onayli = {'Onaylandı', 'Tamamlandı'};
    for (final r in ayin) {
      if ((r.paketKayitId ?? '').isNotEmpty) continue;
      if (!onayli.contains(r.durum)) continue;
      ciro += _hizmetUcreti(r.hizmetAdi);
    }

    return _RaporOzet(
      dolulukYazi: dolulukYazi,
      dolulukAlt: dolulukAlt,
      iptalYazi: iptalYazi,
      iptalAlt: iptalAlt,
      ciroYazi: '${para.format(ciro.round())} TL',
    );
  }

  String _saatYazi(int dakika) {
    final saat = dakika ~/ 60;
    final dk = dakika % 60;
    if (saat == 0) return '$dk dk';
    if (dk == 0) return '$saat saat';
    return '$saat saat $dk dk';
  }

  int _acikDakika() {
    final cs = widget.esnaf.calismaSaatleri;
    if (cs == null) return 0;
    final acilis = (cs['acilis'] ?? '').toString();
    final kapanis = (cs['kapanis'] ?? '').toString();
    final is724 = cs['is724'] == true || (acilis == '00:00' && kapanis == '00:00' && acilis.isNotEmpty);
    final gunluk = is724 ? 24 * 60 : _aralikDakika(acilis, kapanis);
    if (gunluk <= 0) return 0;

    final gunlerHam = cs['gunler'];
    final gunler = gunlerHam is Map ? Map<String, dynamic>.from(gunlerHam) : null;
    var gunSayisi = 0;
    for (var gun = _ayBas; gun.isBefore(_aySon); gun = gun.add(const Duration(days: 1))) {
      if (is724 || gunler == null || _gunAcik(gunler, gun)) gunSayisi++;
    }
    if (!is724 && gunler != null && gunSayisi == 0) return 0;
    return gunSayisi * gunluk * _koltukSayisi();
  }

  bool _gunAcik(Map<String, dynamic> gunler, DateTime gun) {
    final ad = DateFormat('EEEE', 'tr_TR').format(gun).toLowerCase();
    for (final e in gunler.entries) {
      if (e.key.toLowerCase() == ad) return e.value == true;
    }
    return false;
  }

  int _aralikDakika(String acilis, String kapanis) {
    int dakika(String saat) {
      final p = saat.split(':');
      if (p.length != 2) return -1;
      final sa = int.tryParse(p[0]);
      final dk = int.tryParse(p[1]);
      if (sa == null || dk == null) return -1;
      return sa * 60 + dk;
    }

    final a = dakika(acilis);
    final b = dakika(kapanis);
    if (a < 0 || b < 0 || b <= a) return 0;
    return b - a;
  }

  int _koltukSayisi() {
    final esnaf = widget.esnaf;
    if (esnaf.randevularPersonelAdinaAlinsin) {
      final n = esnaf.personeller?.length ?? 0;
      if (n > 0) return n;
    }
    final n = esnaf.kanallar?.length ?? 0;
    return n > 0 ? n : 1;
  }

  double _hizmetUcreti(String ad) {
    final hedef = ad.toLowerCase();
    for (final h in widget.esnaf.hizmetler ?? []) {
      if (h is! Map) continue;
      if ((h['isim'] ?? '').toString().toLowerCase() != hedef) continue;
      return (h['ucret'] as num?)?.toDouble() ?? 0;
    }
    return 0;
  }
}

class _RaporOzet {
  final String dolulukYazi;
  final String dolulukAlt;
  final String iptalYazi;
  final String iptalAlt;
  final String ciroYazi;
  const _RaporOzet({
    required this.dolulukYazi,
    required this.dolulukAlt,
    required this.iptalYazi,
    required this.iptalAlt,
    required this.ciroYazi,
  });
}
