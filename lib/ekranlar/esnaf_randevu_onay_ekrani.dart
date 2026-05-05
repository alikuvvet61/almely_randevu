import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/randevu_modeli.dart';

class EsnafRandevuYonetimEkrani extends StatefulWidget {
  final String esnafId;
  const EsnafRandevuYonetimEkrani({super.key, required this.esnafId});

  @override
  State<EsnafRandevuYonetimEkrani> createState() => _EsnafRandevuYonetimEkraniState();
}

class _EsnafRandevuYonetimEkraniState extends State<EsnafRandevuYonetimEkrani> {
  final FirestoreServisi _firestoreServisi = FirestoreServisi();

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
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
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
                Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 20),
                Text("Herhangi bir randevu bulunmuyor", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: sureDoldu ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: (sureDoldu && r.durum == 'Onay bekliyor') ? BorderSide(color: Colors.red.shade200, width: 1) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(r.kullaniciAd, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: (sureDoldu && r.durum == 'Onay bekliyor') ? Colors.grey : Colors.indigo))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: durumRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(r.durum, style: TextStyle(color: durumRenk, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    if (r.durum == 'Onay bekliyor')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          sureDoldu ? "SÜRE DOLDU - SAAT BOŞALDI" : "Kalan Onay Süresi: $kalanDakika dk",
                          style: TextStyle(color: sureDoldu ? Colors.red : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            _bilgiSatiri(Icons.phone, r.kullaniciTel),
            _bilgiSatiri(Icons.event, "${DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(r.tarih)} - ${r.saat}"),
            _bilgiSatiri(Icons.content_cut, r.hizmetAdi),
            if (r.randevuKanali != null) _bilgiSatiri(Icons.layers, "Kanal: ${r.randevuKanali}"),
            if (r.calisanPersonel != null) _bilgiSatiri(Icons.person, "Personel: ${r.calisanPersonel}"),
            
            if (r.seriId != null && r.seriId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.repeat, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text("Periyodik Randevu Serisi", style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            if (r.iptalNedeni != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("Neden: ${r.iptalNedeni}", style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
              ),

            const SizedBox(height: 10),
            Row(
              children: [
                if (r.durum == 'Onaylandı') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _iptalDialog(context, r),
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                      label: const Text("İptal Et", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
                if (r.durum == 'Onay bekliyor') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reddetDialog(context, r),
                      icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      label: const Text("Reddet", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        
                        if (sureDoldu) {
                          bool? devamEt = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Zaman Aşımı"),
                              content: const Text("Bu randevunun 10 dakikalık onay süresi dolduğu için ilgili saat diğer müşterilere açılmış olabilir. Yine de onaylamak istiyor musunuz?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Evet, Onayla")),
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
                        if (mounted) messenger.showSnackBar(const SnackBar(content: Text("Randevu onaylandı")));
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Onayla"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            if (r.durum == 'Onay bekliyor' && sureDoldu)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("⚠️ Süresi dolduğu için bu saat diğer müşterilere açık görünmektedir.", 
                  style: TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
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
            Text(r.seriId != null && r.seriId!.isNotEmpty ? "Seriyi İptal Et" : "Randevuyu İptal Et", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                        onTap: () async {
                          final navigator = Navigator.of(c);
                          final messenger = ScaffoldMessenger.of(context);
                          
                          if (r.seriId != null && r.seriId!.isNotEmpty) {
                            // Seri iptali sor
                            bool? seri = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Tüm Seriyi İptal Et"),
                                content: const Text("Bu randevu bir serinin parçası. Sadece bu randevuyu mu yoksa tüm seriyi mi iptal etmek istersiniz?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Sadece Bu")),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Tüm Seri")),
                                ],
                              ),
                            );
                            
                            if (seri == null) return;
                            
                            if (seri) {
                              // Tüm seriyi sil (veya durum güncelle)
                              await _firestoreServisi.randevuSerisiniSil(r.seriId!);
                              navigator.pop();
                              messenger.showSnackBar(const SnackBar(content: Text("Tüm randevu serisi silindi")));
                              return;
                            }
                          }

                          String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                          await _firestoreServisi.randevuDurumGuncelle(
                            r.id, 
                            'İptal Edildi',
                            iptalNedeni: nedenler[index],
                            aliciTel: r.kullaniciTel,
                            esnafAdi: r.esnafAdi,
                            tarihSaat: "$tarihFormat ${r.saat}"
                          );
                          navigator.pop();
                          messenger.showSnackBar(const SnackBar(content: Text("Randevu iptal edildi")));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Icon(ikon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 10), Expanded(child: Text(metin, style: const TextStyle(fontSize: 14)))]),
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
}
