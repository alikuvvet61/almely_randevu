import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../modeller/esnaf_modeli.dart';
import '../../modeller/mac_ilani.dart';
import '../../servisler/firestore_servisi.dart';
import '../randevu_ekrani.dart';

class MacIlanlariEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? kullaniciTel;

  const MacIlanlariEkrani({super.key, required this.esnaf, this.kullaniciTel});

  @override
  State<MacIlanlariEkrani> createState() => _MacIlanlariEkraniState();
}

class _MacIlanlariEkraniState extends State<MacIlanlariEkrani> {
  final FirestoreServisi _db = FirestoreServisi();
  String _suzgec = 'tumu';
  final Set<String> _islem = {};

  String get _anahtar => _db.musteriTelefonAnahtari(widget.kullaniciTel ?? '');

  List<String> get _sahalar {
    final adlar = <String>[];
    for (final k in widget.esnaf.kanallar ?? []) {
      final ad = k is Map
          ? (k['ad'] ?? k['plaka'] ?? '').toString().trim()
          : k.toString().trim();
      if (ad.isNotEmpty && !adlar.contains(ad)) adlar.add(ad);
    }
    return adlar;
  }

  List<MacIlani> _liste(List<MacIlani> gelen) {
    final gorunen = gelen.where((m) {
      if (m.durum == 'İptal') return false;
      if (m.acik && m.saatiGecti && !m.dahil(_anahtar)) return false;
      if (!m.acik && !m.dahil(_anahtar)) return false;
      if (_suzgec == 'saha' && m.esnafId != widget.esnaf.id) return false;
      if (_suzgec == 'benim' && !m.dahil(_anahtar)) return false;
      return true;
    }).toList();
    gorunen.sort((a, b) {
      final acik = (a.acik ? 0 : 1).compareTo(b.acik ? 0 : 1);
      if (acik != 0) return acik;
      final gun = a.an.compareTo(b.an);
      if (gun != 0) return gun;
      return a.isletmeAdi.compareTo(b.isletmeAdi);
    });
    return gorunen;
  }

  Future<void> _calistir(String id, Future<String?> Function() islem, String tamam) async {
    if (_anahtar.isEmpty) {
      _uyari('Giriş yapın.');
      return;
    }
    if (_islem.contains(id)) return;
    setState(() => _islem.add(id));
    final hata = await islem();
    if (mounted) setState(() => _islem.remove(id));
    if (!mounted) return;
    _uyari(hata ?? tamam);
  }

  void _uyari(String metin) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(metin), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _sor(String baslik, String metin) async {
    final cevap = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(baslik),
        content: Text(metin),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tamam')),
        ],
      ),
    );
    return cevap == true;
  }

  Future<void> _sahayiTut(MacIlani ilan) async {
    final esnaf = ilan.esnafId == widget.esnaf.id
        ? widget.esnaf
        : await _db.esnafGetirDoc(ilan.esnafId);
    if (!mounted) return;
    if (esnaf == null) {
      _uyari('Saha bulunamadı.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RandevuEkrani(esnaf: esnaf, kullaniciTel: widget.kullaniciTel),
      ),
    );
  }

  Future<void> _ilanAc() async {
    if (_anahtar.isEmpty) {
      _uyari('Giriş yapın.');
      return;
    }
    var tur = 'eksik';
    var gun = DateTime.now();
    var saha = '';
    var kac = 5;
    var oyuncu = 7;
    final takim = TextEditingController();
    final not = TextEditingController();
    var ajanda = await _db.gunlukAjandaGetir(widget.esnaf.id, gun, null);
    if (!mounted) return;
    var saatler = _mesaiSaatleri(ajanda, gun);
    var saat = saatler.contains('21:00') ? '21:00' : (saatler.isEmpty ? '' : saatler.first);
    Future<void> saatleriYukle(void Function(void Function()) yenile) async {
      final gelen = await _db.gunlukAjandaGetir(widget.esnaf.id, gun, saha.isEmpty ? null : saha);
      if (!mounted) return;
      final yeni = _mesaiSaatleri(gelen, gun);
      yenile(() {
        ajanda = gelen;
        saatler = yeni;
        if (!saatler.contains(saat)) saat = saatler.isEmpty ? '' : saatler.first;
      });
    }
    final kaydet = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, yenile) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.viewInsetsOf(c).bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Oyuncu veya rakip arıyorum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.esnaf.isletmeAdi, style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                Text(
                  'Altı seçenekten birini yazın. Bu istek sahayı tutmaz. Saati randevudan alırsınız.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _turSec('Oyuncu arıyorum', tur == 'eksik', () => yenile(() => tur = 'eksik')),
                    const SizedBox(width: 8),
                    _turSec('Takım arıyorum', tur == 'oyuncu', () => yenile(() => tur = 'oyuncu')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _turSec('Kaleciyim', tur == 'kaleci', () => yenile(() => tur = 'kaleci')),
                    const SizedBox(width: 8),
                    _turSec('Kaleci arıyorum', tur == 'kaleci_ara', () => yenile(() => tur = 'kaleci_ara')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _turSec('Rakibiz', tur == 'rakip', () => yenile(() => tur = 'rakip')),
                    const SizedBox(width: 8),
                    _turSec('Rakip arıyoruz', tur == 'takim', () => yenile(() => tur = 'takim')),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih'),
                  subtitle: Text(DateFormat('d MMMM EEEE', 'tr_TR').format(gun)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final sec = await showDatePicker(
                      context: c,
                      initialDate: gun,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (sec != null) {
                      gun = sec;
                      await saatleriYukle(yenile);
                    }
                  },
                ),
                if (saatler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Bu gün için ayarlı saat yok.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(saatler.join('|')),
                    initialValue: saatler.contains(saat) ? saat : saatler.first,
                    decoration: const InputDecoration(labelText: 'Saat'),
                    items: saatler
                        .map((s) => DropdownMenuItem(value: s, child: Text(_saatEtiket(s, ajanda))))
                        .toList(),
                    onChanged: (v) => yenile(() => saat = v ?? saat),
                  ),
                if (_sahalar.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: saha,
                    decoration: const InputDecoration(labelText: 'Saha'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Fark etmez')),
                      ..._sahalar.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                    ],
                    onChanged: (v) async {
                      saha = v ?? '';
                      await saatleriYukle(yenile);
                    },
                  ),
                if (tur == 'eksik')
                  DropdownButtonFormField<int>(
                    initialValue: kac,
                    decoration: const InputDecoration(labelText: 'Kaç kişi lazım'),
                    items: [for (var n = 1; n <= 21; n++) DropdownMenuItem(value: n, child: Text('$n'))],
                    onChanged: (v) => yenile(() => kac = v ?? kac),
                  )
                else if (tur == 'takim' || tur == 'rakip') ...[
                  TextField(
                    controller: takim,
                    decoration: const InputDecoration(labelText: 'Takım adı'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: oyuncu,
                    decoration: const InputDecoration(labelText: 'Oyuncu sayısı'),
                    items: [for (var n = 5; n <= 14; n++) DropdownMenuItem(value: n, child: Text('$n'))],
                    onChanged: (v) => yenile(() => oyuncu = v ?? oyuncu),
                  ),
                ],
                TextField(
                  controller: not,
                  decoration: const InputDecoration(labelText: 'Not, isteğe bağlı'),
                  maxLength: 140,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Listeye yaz'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (kaydet != true) {
      takim.dispose();
      not.dispose();
      return;
    }
    final hata = await _db.macIlaniAc(
      telefon: widget.kullaniciTel!,
      esnafId: widget.esnaf.id,
      isletmeAdi: widget.esnaf.isletmeAdi,
      tur: tur,
      tarih: DateFormat('yyyy-MM-dd').format(gun),
      saat: saat,
      saha: saha,
      kacKisi: kac,
      takimAdi: takim.text,
      oyuncuSayisi: oyuncu,
      notu: not.text,
    );
    takim.dispose();
    not.dispose();
    if (!mounted) return;
    _uyari(hata ?? 'Listeye yazıldı.');
  }

  List<String> _mesaiSaatleri(Map<String, dynamic>? gunAjanda, DateTime gun) {
    final ayar = widget.esnaf.calismaSaatleri;
    final gunler = ayar?['gunler'];
    if (gunler is Map) {
      final ad = DateFormat('EEEE', 'tr_TR').format(gun);
      if (gunler[ad] == false) return [];
    }
    final calisma = gunAjanda ?? ayar;
    if (calisma == null) return [];

    final acilis = (calisma['acilis'] ?? '09:00').toString();
    var kapanis = (calisma['kapanis'] ?? '18:00').toString();
    final is724 = calisma['is724'] == true || acilis == kapanis || (acilis == '00:00' && kapanis == '00:00');
    if (is724) kapanis = acilis;
    final hamAralik = calisma['slotDakika'] ?? calisma['slotAraligi'] ?? 30;
    final aralik = hamAralik is num ? hamAralik.toInt() : int.tryParse('$hamAralik') ?? 30;
    if (aralik <= 0) return [];

    final slotlar = <String>[];
    final acilisDk = _saatiDakikaya(acilis);
    final kapanisDk = _saatiDakikaya(kapanis);
    void ekle(int bas, int bit) {
      var dk = bas;
      while (dk < bit) {
        final yazi = _dakikaYazi(dk);
        if (!slotlar.contains(yazi)) slotlar.add(yazi);
        dk += aralik;
      }
    }
    if (kapanisDk < acilisDk || is724) {
      ekle(0, is724 ? acilisDk : kapanisDk);
      ekle(acilisDk, 1440);
    } else {
      ekle(acilisDk, kapanisDk);
    }

    final kapali = calisma['kapaliSlotlar'];
    final ogleBas = calisma['ogleBaslangic']?.toString();
    final ogleBit = calisma['ogleBitis']?.toString();
    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final secilen = DateTime(gun.year, gun.month, gun.day);
    return slotlar.where((s) {
      if (kapali is Map && kapali.containsKey(s)) return false;
      final dk = _saatiDakikaya(s);
      if (ogleBas != null && ogleBit != null && ogleBas.contains(':') && ogleBit.contains(':')) {
        final bas = _saatiDakikaya(ogleBas);
        final bit = _saatiDakikaya(ogleBit);
        if (dk >= bas && dk < bit) return false;
      }
      if (secilen == bugun) {
        final an = DateTime(gun.year, gun.month, gun.day, dk ~/ 60, dk % 60);
        if (!an.isAfter(simdi)) return false;
      }
      return true;
    }).toList();
  }

  int _saatiDakikaya(String saat) {
    final p = saat.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  String _dakikaYazi(int toplam) {
    final h = (toplam ~/ 60) % 24;
    final m = toplam % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _saatEtiket(String bas, Map<String, dynamic>? ajanda) {
    if (!widget.esnaf.slotAralikliGoster) return bas;
    final calisma = ajanda ?? widget.esnaf.calismaSaatleri;
    final ham = calisma?['slotDakika'] ?? calisma?['slotAraligi'] ?? 60;
    final aralik = ham is num ? ham.toInt() : int.tryParse('$ham') ?? 60;
    final bit = _dakikaYazi(_saatiDakikaya(bas) + (aralik > 0 ? aralik : 60));
    return '$bas - $bit';
  }

  Widget _turSec(String yazi, bool secili, VoidCallback bas) {
    return Expanded(
      child: OutlinedButton(
        onPressed: bas,
        style: OutlinedButton.styleFrom(
          foregroundColor: secili ? Colors.blueGrey.shade800 : Colors.blueGrey,
          backgroundColor: secili ? Colors.blueGrey.shade50 : Colors.transparent,
          side: BorderSide(color: secili ? Colors.blueGrey.shade400 : Colors.blueGrey.shade200),
        ),
        child: Text(yazi, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            SizedBox(width: 30, height: 30, child: Icon(Icons.person, size: 24)),
            SizedBox(width: 8),
            Flexible(child: Text('Oyuncu veya Rakip Bul', overflow: TextOverflow.ellipsis)),
            SizedBox(width: 8),
            SizedBox(width: 30, height: 30, child: Icon(Icons.groups, size: 30)),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: const [SizedBox(width: 48)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Herkesin adı görünür. Oyuncu, takım, kaleci ve rakip aynı listede durur. Telefon yalnızca isteği yazana gider. Saha saati burada tutulmaz.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ElevatedButton(
              onPressed: _ilanAc,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Oyuncu veya rakip arıyorum', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Tümü'), selected: _suzgec == 'tumu', onSelected: (_) => setState(() => _suzgec = 'tumu')),
                ChoiceChip(label: const Text('Bu saha'), selected: _suzgec == 'saha', onSelected: (_) => setState(() => _suzgec = 'saha')),
                ChoiceChip(label: const Text('Benim'), selected: _suzgec == 'benim', onSelected: (_) => setState(() => _suzgec = 'benim')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MacIlani>>(
              stream: _db.macIlanlariDinle(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Maçlar açılamadı.'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final liste = _liste(snap.data!);
                if (liste.isEmpty) {
                  return const Center(child: Text('Henüz istek yok.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: liste.length,
                  itemBuilder: (context, i) => _kart(liste[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kart(MacIlani ilan) {
    final sahip = _anahtar.isNotEmpty && ilan.acanTel == _anahtar;
    final katildim = ilan.katilanlar.any((k) => k.tel == _anahtar);
    final rakibim = _anahtar.isNotEmpty && ilan.rakipTel == _anahtar;
    final cagiran = _anahtar.isNotEmpty && ilan.cagiranTel == _anahtar;
    final mesgul = _islem.contains(ilan.id);
    final tarihYazi = DateFormat('d MMMM EEEE', 'tr_TR').format(ilan.an);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ilan.baslik,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                ilan.acik ? (ilan.saatiGecti ? 'Saati geçti' : 'Açık') : ilan.durum,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(ilan.isletmeAdi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            [if (ilan.saha.isNotEmpty) ilan.saha, tarihYazi, ilan.saat].join(' · '),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(ilan.hazir ? 'Yazan: ${ilan.acanAd}' : 'Arayan: ${ilan.acanAd}'),
          if (ilan.eksik) ...[
            Text('${ilan.katilanlar.length} / ${ilan.kacKisi} kişi katıldı'),
            for (final k in ilan.katilanlar)
              Text(sahip && k.telYazi.isNotEmpty ? '${k.ad} · ${k.telYazi}' : k.ad),
          ] else if (ilan.kaleciAriyor) ...[
            Text('${ilan.katilanlar.length} / 1 kaleci katıldı'),
            for (final k in ilan.katilanlar)
              Text(sahip && k.telYazi.isNotEmpty ? '${k.ad} · ${k.telYazi}' : k.ad),
          ] else if (ilan.takim) ...[
            Text('${ilan.takimAdi} · ${ilan.oyuncuSayisi} oyuncu'),
            if (ilan.eslesti)
              Text(
                sahip && ilan.rakipTelYazi.isNotEmpty
                    ? 'Rakip: ${ilan.rakipTakimAdi} · ${ilan.rakipAd} · ${ilan.rakipTelYazi}'
                    : 'Rakip: ${ilan.rakipTakimAdi}${ilan.rakipAd.isEmpty ? '' : ' · ${ilan.rakipAd}'}',
              )
            else
              const Text('Rakip takım aranıyor'),
          ] else if (ilan.benOyuncu) ...[
            const Text('Takım arıyor'),
            if (ilan.cagrildi) Text(_cagiranYazi(ilan, sahip)),
          ] else if (ilan.kaleciyim) ...[
            const Text('Kaleci olarak hazır'),
            if (ilan.cagrildi) Text(_cagiranYazi(ilan, sahip)),
          ] else if (ilan.benRakip) ...[
            Text('${ilan.takimAdi} · ${ilan.oyuncuSayisi} oyuncu'),
            const Text('Rakip olarak hazır'),
            if (ilan.cagrildi) Text(_cagiranYazi(ilan, sahip)),
          ],
          if (ilan.notu.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ilan.notu, style: TextStyle(color: Colors.grey.shade700)),
          ],
          Wrap(
            spacing: 4,
            children: [
              if (ilan.katilma && ilan.acik && !ilan.saatiGecti && !sahip && !katildim)
                TextButton(
                  onPressed: mesgul
                      ? null
                      : () async {
                          final olur = await _sor('Maça katıl', 'Adınız listede görünür. Telefonunuz yalnızca isteği yazana gider.');
                          if (!olur) return;
                          await _calistir(ilan.id, () => _db.macIlaninaKatil(ilan.id, widget.kullaniciTel!), 'Katıldınız.');
                        },
                  child: const Text('Katıl'),
                ),
              if (ilan.katilma && katildim && (ilan.acik || ilan.doldu))
                TextButton(
                  onPressed: mesgul
                      ? null
                      : () async {
                          final olur = await _sor('Ayrıl', 'Maçtan ayrılmak istiyor musunuz?');
                          if (!olur) return;
                          await _calistir(ilan.id, () => _db.macIlanindanAyril(ilan.id, widget.kullaniciTel!), 'Ayrıldınız.');
                        },
                  child: const Text('Ayrıl'),
                ),
              if (ilan.takim && ilan.acik && !ilan.saatiGecti && !sahip)
                TextButton(
                  onPressed: mesgul ? null : () => _rakipOl(ilan),
                  child: const Text('Rakip ol'),
                ),
              if (ilan.hazir && ilan.acik && !ilan.saatiGecti && !sahip)
                TextButton(
                  onPressed: mesgul ? null : () => _cagir(ilan),
                  child: const Text('Çağır'),
                ),
              if (rakibim && ilan.eslesti)
                TextButton(
                  onPressed: mesgul
                      ? null
                      : () async {
                          final olur = await _sor('Vazgeç', 'Rakip olmaktan vazgeçilsin mi? İstek yeniden açılır.');
                          if (!olur) return;
                          await _calistir(ilan.id, () => _db.macRakipVazgec(ilan.id, widget.kullaniciTel!), 'Vazgeçildi.');
                        },
                  child: const Text('Vazgeç'),
                ),
              if (cagiran && ilan.cagrildi)
                TextButton(
                  onPressed: mesgul
                      ? null
                      : () async {
                          final olur = await _sor('Vazgeç', 'Çağrı kalksın mı? İstek yeniden açılır.');
                          if (!olur) return;
                          await _calistir(ilan.id, () => _db.macCagriVazgec(ilan.id, widget.kullaniciTel!), 'Vazgeçildi.');
                        },
                  child: const Text('Vazgeç'),
                ),
              if (sahip && ilan.durum != 'İptal')
                TextButton(
                  onPressed: mesgul
                      ? null
                      : () async {
                          final olur = await _sor('İsteği kaldır', 'İstek kalksın mı?');
                          if (!olur) return;
                          await _calistir(ilan.id, () => _db.macIlaniIptal(ilan.id, widget.kullaniciTel!), 'İstek kaldırıldı.');
                        },
                  child: const Text('İptal'),
                ),
              TextButton(
                onPressed: () => _sahayiTut(ilan),
                child: const Text('Sahayı tut'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rakipOl(MacIlani ilan) async {
    if (_anahtar.isEmpty) {
      _uyari('Giriş yapın.');
      return;
    }
    final ad = TextEditingController();
    final olur = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rakip ol'),
        content: TextField(
          controller: ad,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Takımınızın adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kabul et')),
        ],
      ),
    );
    final yazi = ad.text;
    ad.dispose();
    if (olur != true) return;
    await _calistir(ilan.id, () => _db.macRakipKabul(ilan.id, widget.kullaniciTel!, yazi), 'Eşleşti.');
  }

  String _cagiranYazi(MacIlani ilan, bool sahip) {
    final ad = ilan.cagiranTakim.isEmpty ? ilan.cagiranAd : '${ilan.cagiranTakim} · ${ilan.cagiranAd}';
    if (sahip && ilan.cagiranTelYazi.isNotEmpty) return 'Çağıran: $ad · ${ilan.cagiranTelYazi}';
    return 'Çağıran: $ad';
  }

  Future<void> _cagir(MacIlani ilan) async {
    if (_anahtar.isEmpty) {
      _uyari('Giriş yapın.');
      return;
    }
    if (ilan.kaleciyim) {
      final olur = await _sor('Çağır', 'Bu kaleciyi maça çağırıyorsunuz. Adınız ona görünür. Telefonunuz yalnızca ona gider.');
      if (!olur) return;
      await _calistir(ilan.id, () => _db.macCagir(ilan.id, widget.kullaniciTel!), 'Çağrı gitti.');
      return;
    }
    final ad = TextEditingController();
    final olur = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Çağır'),
        content: TextField(
          controller: ad,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Takımınızın adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çağır')),
        ],
      ),
    );
    final yazi = ad.text;
    ad.dispose();
    if (olur != true) return;
    await _calistir(ilan.id, () => _db.macCagir(ilan.id, widget.kullaniciTel!, takimAdi: yazi), 'Çağrı gitti.');
  }
}
