import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:almely_randevu/servisler/firestore_servisi.dart';
import 'package:almely_randevu/modeller/randevu_modeli.dart';
import 'package:almely_randevu/modeller/esnaf_modeli.dart';

class EsnafRandevuYonetimEkrani extends StatefulWidget {
  final String esnafId;
  final EsnafModeli? esnaf; // Esnaf nesnesini opsiyonel olarak alalım
  const EsnafRandevuYonetimEkrani({super.key, required this.esnafId, this.esnaf});

  @override
  State<EsnafRandevuYonetimEkrani> createState() => _EsnafRandevuYonetimEkraniState();
}

class _EsnafRandevuYonetimEkraniState extends State<EsnafRandevuYonetimEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();
  EsnafModeli? _esnaf;

  @override
  void initState() {
    super.initState();
    _esnaf = widget.esnaf;
    if (_esnaf == null) {
      _esnafYukle();
    }
  }

  Future<void> _esnafYukle() async {
    final e = await _firestoreServisi.esnafGetirDoc(widget.esnafId);
    if (e != null && mounted) {
      setState(() {
        _esnaf = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Randevu Yönetimi"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Bekleyen"),
              Tab(text: "Onaylanan"),
              Tab(text: "İptal/Red"),
            ],
            indicatorColor: Colors.blue,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
          ),
        ),
        body: TabBarView(
          children: [
            _randevuListesi('Onay bekliyor'),
            _randevuListesi('Onaylandı'),
            _randevuListesi('Red/İptal'),
          ],
        ),
      ),
    );
  }

  Widget _randevuListesi(String durumFiltresi) {
    return StreamBuilder<List<RandevuModeli>>(
      stream: _firestoreServisi.esnafTumRandevulariGetir(widget.esnafId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final hepsi = snapshot.data ?? [];
        List<RandevuModeli> liste;
        
        if (durumFiltresi == 'Red/İptal') {
          liste = hepsi.where((r) => r.durum == 'Reddedildi' || r.durum == 'İptal Edildi').toList();
        } else {
          liste = hepsi.where((r) => r.durum == durumFiltresi).toList();
        }

        // Tarihe göre sırala (Yeni en üstte)
        liste.sort((a, b) => b.tarih.compareTo(a.tarih));

        if (liste.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  durumFiltresi == 'Onay bekliyor' 
                    ? Icons.hourglass_empty 
                    : (durumFiltresi == 'Onaylandı' ? Icons.check_circle_outline : Icons.history), 
                  size: 80, 
                  color: Colors.grey.withValues(alpha: 0.3)
                ),
                const SizedBox(height: 20),
                Text(
                  "$durumFiltresi randevunuz bulunmuyor", 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: liste.length,
          itemBuilder: (context, i) {
            final r = liste[i];
            return _randevuKarti(r);
          },
        );
      },
    );
  }

  Widget _randevuKarti(RandevuModeli r) {
    Color durumRenk = Colors.orange;
    if (r.durum == 'Onaylandı') durumRenk = Colors.green;
    if (r.durum == 'Reddedildi' || r.durum == 'İptal Edildi') durumRenk = Colors.red;

    bool sureDoldu = false;
    int kalanDakika = 10;
    if (r.durum == 'Onay bekliyor' && r.olusturulmaTarihi != null) {
      int gecen = DateTime.now().difference(r.olusturulmaTarihi!).inMinutes;
      sureDoldu = gecen >= 10;
      kalanDakika = 10 - gecen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: sureDoldu ? Colors.red.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (sureDoldu && r.durum == 'Onay bekliyor') 
              ? Colors.red.withValues(alpha: 0.1) 
              : Colors.grey.withValues(alpha: 0.06),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minTileHeight: 64, 
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              (sureDoldu && r.durum == 'Onay bekliyor') ? Icons.timer_off : Icons.person, 
              color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red : Colors.blue,
              size: 28,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  r.kullaniciAd, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 17,
                    color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.red.shade900 : Colors.black87
                  )
                ),
              ),
              _durumRozeti(r.durum, durumRenk),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${DateFormat('dd MMM yyyy, EEEE', 'tr_TR').format(r.tarih)} - ${r.saat}",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              if (r.durum == 'Onay bekliyor')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sureDoldu ? "⚠️ SÜRE DOLDU" : "⏳ Kalan: $kalanDakika dk",
                    style: TextStyle(
                      color: sureDoldu ? Colors.red : Colors.orange, 
                      fontSize: 14, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
            ],
          ),
          children: [
            const Divider(height: 1, indent: 4, endIndent: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  _bilgiSatiri(Icons.phone, r.kullaniciTel),
                  _bilgiSatiri(Icons.content_cut, r.hizmetAdi),
                  if (r.randevuKanali != null) 
                    Builder(
                      builder: (context) {
                        String label = "Kanal: ${r.randevuKanali}";
                        IconData icon = Icons.layers;

                        if (_esnaf?.kategori == 'Taksi' && (_esnaf?.aracOdakliSistem ?? false)) {
                          icon = Icons.local_taxi;
                          final arac = _esnaf?.araclar?.firstWhere(
                            (a) => a is Map && a['plaka'] == r.randevuKanali,
                            orElse: () => null,
                          );
                          if (arac != null) {
                            final sofor = arac['soforAd'] ?? arac['sofor'] ?? '';
                            label = sofor.isNotEmpty ? "Araç: ${r.randevuKanali} ($sofor)" : "Araç: ${r.randevuKanali}";
                          } else {
                            label = "Araç: ${r.randevuKanali}";
                          }
                        }
                        return _bilgiSatiri(icon, label);
                      }
                    ),
                  if (r.calisanPersonel != null && !(_esnaf?.kategori == 'Taksi' && (_esnaf?.aracOdakliSistem ?? false))) 
                    _bilgiSatiri(Icons.person_outline, "Personel: ${r.calisanPersonel}"),
                  
                  if (r.seriId != null && r.seriId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: Colors.blue.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text("Periyodik Randevu Serisi", style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                  if (r.iptalNedeni != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Neden: ${r.iptalNedeni}", 
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (r.durum == 'Onaylandı') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _iptalDialog(context, r),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text("İptal Et", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                      if (r.durum == 'Onay bekliyor') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reddetDialog(context, r),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text("Reddet", style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              
                              if (sureDoldu) {
                                bool? devamEt = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text("Zaman Aşımı"),
                                    content: const Text("Bu randevunun 10 dakikalık onay süresi dolduğu için ilgili saat diğer müşterilere açılmış olabilir. Yine de onaylamak istiyor musunuz?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        child: const Text("Evet, Onayla"),
                                      ),
                                    ],
                                  ),
                                );
                                if (devamEt != true) return;
                              }

                              String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                              await _firestoreServisi.randevuDurumGuncelle(
                                r.id, 
                                'Onaylandı',
                                aliciTel: r.kullaniciTel,
                                esnafAdi: r.esnafAdi,
                                tarihSaat: "$tarihFormat ${r.saat}"
                              );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text("Randevu onaylandı"),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  )
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Onayla", style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _durumRozeti(String durum, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.1)),
      ),
      child: Text(
        durum,
        style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(ikon, size: 20, color: Colors.grey.shade600), const SizedBox(width: 10), Expanded(child: Text(metin, style: const TextStyle(fontSize: 15)))]),
  );

  void _reddetDialog(BuildContext context, RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Randevuyu Reddet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen bir reddetme nedeni seçin:"),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          final navigator = Navigator.of(c);
                          String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                          await _firestoreServisi.randevuIptalEt(
                            r.id, 
                            nedenler[index],
                            aliciTel: r.kullaniciTel,
                            esnafAdi: r.esnafAdi,
                            tarihSaat: "$tarihFormat ${r.saat}"
                          );
                          if (navigator.mounted) navigator.pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          ],
        ),
      ),
    );
  }

  void _iptalDialog(BuildContext context, RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Randevuyu İptal Et", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen bir iptal nedeni seçin:"),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('esnaf'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          final navigator = Navigator.of(c);
                          String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                          await _firestoreServisi.randevuDurumGuncelle(
                            r.id, 
                            'İptal Edildi',
                            iptalNedeni: nedenler[index],
                            aliciTel: r.kullaniciTel,
                            esnafAdi: r.esnafAdi,
                            tarihSaat: "$tarihFormat ${r.saat}"
                          );
                          if (navigator.mounted) navigator.pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
          ],
        ),
      ),
    );
  }
}
