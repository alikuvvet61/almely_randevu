import 'package:flutter/material.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';

/// Genel esnaf ayarları (Taksi ve Araç Kiralama hariç).
class EsnafParametreEkrani extends StatefulWidget {
  final String esnafId;
  const EsnafParametreEkrani({super.key, required this.esnafId});

  @override
  State<EsnafParametreEkrani> createState() => _EsnafParametreEkraniState();
}

class _EsnafParametreEkraniState extends State<EsnafParametreEkrani> {
  final _firestoreServisi = FirestoreServisi();
  bool _yukleniyor = true;
  EsnafModeli? _esnaf;

  @override
  void initState() {
    super.initState();
    _verileriGetir();
  }

  Future<void> _verileriGetir() async {
    _firestoreServisi.esnafGetir(widget.esnafId).first.then((esnaf) {
      if (mounted) {
        setState(() {
          _esnaf = esnaf;
          _yukleniyor = false;
        });
      }
    });
  }

  Future<void> _guncelle(Map<String, dynamic> veriler) async {
    try {
      await _firestoreServisi.esnafGuncelle(widget.esnafId, veriler);
      _verileriGetir();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ayarlar güncellendi"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor || _esnaf == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("İşletme Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _parametreKart(
            baslik: "Randevu Ayarları",
            altBaslik: "İşletmenizin randevu alma kurallarını ve onay akışını buradan yönetin.",
            icon: Icons.event_note_rounded,
            icerik: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Randevu Alımını Durdur", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Aktif edilirse müşteriler 'Hemen Randevu Al' butonunu göremez."),
                  value: _esnaf!.randevuAlinmasin,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(randevuAlinmasin: v);
                    });
                    await _guncelle({'randevuAlinmasin': v});
                  },
                ),
                if (!_esnaf!.randevuAlinmasin) ...[
                  const Divider(),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Randevu Onay Modu", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Yeni randevular otomatik mi onaylansın yoksa sizin onayınız mı beklensin?",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_esnaf!.randevuOnayModu),
                    initialValue: _esnaf!.randevuOnayModu.isEmpty ? 'Manuel' : _esnaf!.randevuOnayModu,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Manuel',
                        child: Text("Manuel (Ben onaylayacağım)", style: TextStyle(fontSize: 15)),
                      ),
                      DropdownMenuItem(
                        value: 'Otomatik',
                        child: Text("Otomatik (Anında onaylansın)", style: TextStyle(fontSize: 15)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _guncelle({'randevuOnayModu': v});
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Aynı Gün Randevu Sınırı", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Bir müşteri aynı gün içerisinde sadece 1 randevu alabilsin."),
                    value: _esnaf!.ayniGunRandevuEngelle,
                    onChanged: (v) => _guncelle({'ayniGunRandevuEngelle': v}),
                  ),
                ],
              ],
            ),
          ),
          _parametreKart(
            baslik: "Ajanda ve Takvim Ayarları",
            altBaslik: "Ajandanın manuel mi dinamik mi çalışacağını ve randevu aralıklarını belirleyin.",
            icon: Icons.calendar_month_rounded,
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Ajandayı Kendim Ayarlayacağım", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    "İşaretli olursa ajanda defterini manuel hazırlamanız gerekir. İşaretsiz olursa tam otomatik canlı sistem aktif olur.",
                  ),
                  value: _esnaf!.ajandayiKendimAyarlayacagim,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(ajandayiKendimAyarlayacagim: v);
                    });
                    await _guncelle({'ajandayiKendimAyarlayacagim': v});
                  },
                ),
                if (!_esnaf!.ajandayiKendimAyarlayacagim) ...[
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text("Randevu Penceresi (İleriye Dönük)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Text(
                    "Müşteriler bugünden itibaren en fazla kaç gün ilerisi için randevu alabilir?",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _esnaf!.maksimumRandevuGunu.toDouble(),
                          min: 1,
                          max: 365,
                          divisions: 364,
                          label: "${_esnaf!.maksimumRandevuGunu} Gün",
                          onChanged: (v) {
                            setState(() {
                              _esnaf = _esnaf!.copyWith(maksimumRandevuGunu: v.toInt());
                            });
                          },
                          onChangeEnd: (v) => _guncelle({'maksimumRandevuGunu': v.toInt()}),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          "${_esnaf!.maksimumRandevuGunu} Gün",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(),
                const SizedBox(height: 6),
                const Text("Minimum Randevu Süresi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Text("Müşteriler en az ne kadarlık randevu seçebilir?", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _esnaf!.minimumRandevuSuresi.toDouble(),
                        min: 15,
                        max: 300,
                        divisions: 19,
                        label: "${_esnaf!.minimumRandevuSuresi} dk",
                        onChanged: (v) {
                          setState(() {
                            _esnaf = _esnaf!.copyWith(minimumRandevuSuresi: v.toInt());
                          });
                        },
                        onChangeEnd: (v) => _guncelle({'minimumRandevuSuresi': v.toInt()}),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _esnaf!.minimumRandevuSuresi >= 60
                            ? "${_esnaf!.minimumRandevuSuresi ~/ 60} Sa ${_esnaf!.minimumRandevuSuresi % 60 > 0 ? '${_esnaf!.minimumRandevuSuresi % 60} dk' : ''}"
                            : "${_esnaf!.minimumRandevuSuresi} dk",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Aralıklı Slot Gösterimi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    "Randevu saatleri '10:00' yerine '10:00 - 11:00' şeklinde aralıklı gösterilir (Örn: Halı Sahalar için).",
                  ),
                  value: _esnaf!.slotAralikliGoster,
                  onChanged: (v) => _guncelle({'slotAralikliGoster': v}),
                ),
              ],
            ),
          ),
          _parametreKart(
            baslik: "Personel ve Seçim Ayarları",
            altBaslik: "Müşterinin personel seçimi yapma zorunluluğunu ve randevu atamasını yönetin.",
            icon: Icons.people_alt_rounded,
            icerik: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Personel Odaklı Sistem", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Müşteri doğrudan personeli seçer. Personel seçimi zorunlu hale gelir."),
                  value: _esnaf!.randevularPersonelAdinaAlinsin,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(
                        randevularPersonelAdinaAlinsin: v,
                        personelSecimiZorunlu: v,
                      );
                    });
                    await _guncelle({
                      'randevularPersonelAdinaAlinsin': v,
                      'personelSecimiZorunlu': v,
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parametreKart({
    required String baslik,
    required String altBaslik,
    required IconData icon,
    required Widget icerik,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    baslik,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(altBaslik, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
            const SizedBox(height: 18),
            icerik,
          ],
        ),
      ),
    );
  }
}
