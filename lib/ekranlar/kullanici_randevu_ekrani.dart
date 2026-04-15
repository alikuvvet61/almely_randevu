import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/randevu_modeli.dart';

class KullaniciRandevuEkrani extends StatelessWidget {
  final String telefon;
  KullaniciRandevuEkrani({super.key, required this.telefon});

  final FirestoreServisi _firestoreServisi = FirestoreServisi();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Randevularım"),
        centerTitle: true,
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

          final randevular = snapshot.data ?? [];
          if (randevular.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("Henüz bir randevunuz bulunmuyor.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: randevular.length,
                  itemBuilder: (context, i) {
                    final r = randevular[i];
                    final gecmisMi = r.tarih.isBefore(DateTime.now().subtract(const Duration(hours: 1)));

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.esnafAdi,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                _durumRozeti(r.durum),
                              ],
                            ),
                            const Divider(height: 25),
                            _bilgiSatiri(Icons.event, "${DateFormat('dd MMMM yyyy', 'tr_TR').format(r.tarih)} - ${r.saat} randevunuz bulunmaktadır."),
                            _bilgiSatiri(Icons.content_cut, r.hizmetAdi),
                            if (r.calisan_personel != null)
                              _bilgiSatiri(Icons.person, "Personel: ${r.calisan_personel}"),
                            if (r.randevu_kanali != null)
                              _bilgiSatiri(Icons.layers, "Randevu Kanalı: ${r.randevu_kanali}"),
                            
                            if (r.durum == 'İptal Edildi' && r.iptalNedeni != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text("İptal Nedeni: ${r.iptalNedeni}", 
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                              ),

                            const SizedBox(height: 15),
                            if (!gecmisMi && r.durum != 'İptal Edildi' && r.durum != 'Reddedildi')
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _randevuIptalDialog(context, r),
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  label: const Text("Randevuyu İptal Et", style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              )
                            else if (gecmisMi && r.durum != 'İptal Edildi')
                               const Center(child: Text("Bu randevunun tarihi geçmiş", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                color: Colors.orange.shade50,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Not: Randevuya gitmeyecekseniz lütfen randevunuzu iptal ediniz.",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bilgiSatiri(IconData ikon, String metin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk),
      ),
      child: Text(
        durum,
        style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _randevuIptalDialog(BuildContext context, RandevuModeli r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Randevu İptal Nedeni", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Lütfen randevuyu iptal etme nedeninizi seçiniz:", style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            Flexible(
              child: StreamBuilder<List<String>>(
                stream: _firestoreServisi.iptalNedenleriniGetir('kullanici'),
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
          ],
        ),
      ),
    );
  }
}
