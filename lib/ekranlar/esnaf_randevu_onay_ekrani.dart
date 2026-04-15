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
                Text("Bu kategoride randevu bulunmuyor.", style: TextStyle(color: Colors.grey.shade500)),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(r.kullaniciAd, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.indigo))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: durumRenk.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(r.durum, style: TextStyle(color: durumRenk, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            _bilgiSatiri(Icons.phone, r.kullaniciTel),
            _bilgiSatiri(Icons.event, "${DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(r.tarih)} - ${r.saat}"),
            _bilgiSatiri(Icons.content_cut, r.hizmetAdi),
            if (r.randevu_kanali != null) _bilgiSatiri(Icons.layers, "Kanal: ${r.randevu_kanali}"),
            if (r.calisan_personel != null) _bilgiSatiri(Icons.person, "Personel: ${r.calisan_personel}"),
            
            if (r.iptalNedeni != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("Neden: ${r.iptalNedeni}", style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
              ),

            if (r.durum == 'Onay bekliyor') ...[
              const SizedBox(height: 15),
              Row(
                children: [
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
                        await _firestoreServisi.randevuDurumGuncelle(r.id, 'Onaylandı');
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Randevu onaylandı.")));
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Onayla"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              )
            ]
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
            const Text("Lütfen reddetme nedenini seçiniz:"),
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
                          await _firestoreServisi.randevuIptalEt(r.id, nedenler[index]);
                          if (mounted) Navigator.pop(c);
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
