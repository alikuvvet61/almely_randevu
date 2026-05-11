import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../servisler/bildirim_servisi.dart';
import '../modeller/randevu_modeli.dart';

class KullaniciRandevuEkrani extends StatelessWidget {
  final String telefon;
  KullaniciRandevuEkrani({super.key, required this.telefon});

  final FirestoreServisi _firestoreServisi = FirestoreServisi();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Randevularım"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Yaklaşanlar"),
              Tab(text: "Geçmiş"),
            ],
            indicatorColor: Colors.blue,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<List<RandevuModeli>>(
          stream: _firestoreServisi.kullaniciRandevulariniGetir(telefon),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tumRandevular = snapshot.data ?? [];
            final simdi = DateTime.now().subtract(const Duration(hours: 1));

            // Randevuları tarihlerine göre ayır
            final yaklasanlar = tumRandevular.where((r) => !r.tarih.isBefore(simdi)).toList();
            final gecmisler = tumRandevular.where((r) => r.tarih.isBefore(simdi)).toList();

            return TabBarView(
              children: [
                _randevuListesi(context, yaklasanlar, false),
                _randevuListesi(context, gecmisler, true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _randevuListesi(BuildContext context, List<RandevuModeli> liste, bool gecmisMi) {
    if (liste.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              gecmisMi ? Icons.history : Icons.calendar_today_outlined,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              gecmisMi ? "Geçmiş randevunuz bulunmuyor." : "Yaklaşan randevunuz bulunmuyor.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: liste.length,
      itemBuilder: (context, i) => _randevuKarti(context, liste[i], gecmisMi),
    );
  }

  Widget _randevuKarti(BuildContext context, RandevuModeli r, bool gecmisMi) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business, color: Colors.blue),
          ),
          title: Text(
            r.esnafAdi,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                "${DateFormat('dd MMMM yyyy', 'tr_TR').format(r.tarih)} - ${r.saat}",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              _durumRozeti(r.durum),
            ],
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _bilgiSatiri(Icons.content_cut, "Hizmet: ${r.hizmetAdi}"),
                  if (r.randevuKanali != null)
                    _bilgiSatiri(
                      Icons.layers,
                      r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+'))
                          ? "Araç: ${r.randevuKanali}"
                          : "Bölüm: ${r.randevuKanali}",
                    ),
                  if (r.calisanPersonel != null && !r.randevuKanali!.contains(RegExp(r'[0-9]{2}\s[A-Z]+\s[0-9]+')))
                    _bilgiSatiri(Icons.person, "Personel: ${r.calisanPersonel}"),
                  
                  if (r.durum == 'İptal Edildi' && r.iptalNedeni != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "İptal Nedeni: ${r.iptalNedeni}", 
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  if (!gecmisMi && r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _randevuIptalDialog(context, r),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text("Randevuyu İptal Et"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    )
                  else if (gecmisMi && r.durum == 'Onaylandı' && !r.puanlandi)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _degerlendirmeYapDialog(context, r),
                        icon: const Icon(Icons.star_outline),
                        label: const Text("Hizmeti Değerlendir"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(metin, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _durumRozeti(String durum) {
    Color renk = Colors.orange;
    if (durum == 'Onaylandı') renk = Colors.green;
    if (durum == 'Reddedildi' || durum == 'İptal Edildi') renk = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Text(
        durum,
        style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _degerlendirmeYapDialog(BuildContext context, RandevuModeli r) {
    double secilenPuan = 5.0;
    final TextEditingController yorumController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Hizmeti Değerlendir"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.esnafAdi, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < secilenPuan ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => secilenPuan = index + 1.0),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yorumController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Deneyiminizi paylaşın...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
            ElevatedButton(
              onPressed: () async {
                await _firestoreServisi.yorumEkle({
                  'esnafId': r.esnafId,
                  'randevuId': r.id,
                  'kullaniciAd': r.kullaniciAd,
                  'kullaniciTel': r.kullaniciTel,
                  'puan': secilenPuan,
                  'yorum': yorumController.text,
                  'tarih': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Değerlendirmeniz için teşekkür ederiz!")));
                }
              },
              child: const Text("Yorumu Gönder"),
            ),
          ],
        ),
      ),
    );
  }

  void _randevuIptalDialog(BuildContext context, RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Randevu İptal Nedeni", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen bir iptal nedeni seçin", style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('kullanici'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final nedenler = snapshot.data!;
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: nedenler.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(nedenler[index]),
                        leading: const Icon(Icons.radio_button_off, color: Colors.blue),
                        onTap: () async {
                          String tarihFormat = DateFormat('dd.MM.yyyy').format(r.tarih);
                          await _firestoreServisi.randevuIptalEt(r.id, nedenler[index]);

                          await BildirimServisi.bildirimGonder(
                            kullaniciTel: r.esnafTel,
                            baslik: "🚫 Randevu İptal Edildi",
                            icerik: "${r.kullaniciAd}, $tarihFormat tarihli saat ${r.saat} randevusunu iptal etti. Neden: ${nedenler[index]}",
                          );

                          if (context.mounted) {
                            Navigator.pop(c);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Randevunuz başarıyla iptal edildi.")),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Vazgeç")),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
