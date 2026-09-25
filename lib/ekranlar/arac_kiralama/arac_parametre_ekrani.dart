import 'package:flutter/material.dart';
import '../../servisler/firestore_servisi.dart';
import '../../modeller/esnaf_modeli.dart';

/// Araç Kiralama işletme ayarları (esnaf_parametre'den ayrıldı).
class AracParametreEkrani extends StatefulWidget {
  final String esnafId;
  const AracParametreEkrani({super.key, required this.esnafId});

  @override
  State<AracParametreEkrani> createState() => _AracParametreEkraniState();
}

class _AracParametreEkraniState extends State<AracParametreEkrani> {
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
        title: const Text("Araç Kiralama Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: const [
          SizedBox(width: 48), // global ? için yer
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _parametreKart(
            baslik: "Bakım ve Temizlik Süresi",
            altBaslik:
                "Her kiralama randevusu bittikten sonra araç yaklaşık ${_esnaf!.bakimTemizlikSuresi ~/ 60} saat ${_esnaf!.bakimTemizlikSuresi % 60 > 0 ? '${_esnaf!.bakimTemizlikSuresi % 60} dk ' : ''}boyunca bakıma alınacaktır.",
            icon: Icons.cleaning_services_rounded,
            icerik: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _esnaf!.bakimTemizlikSuresi.toDouble(),
                        min: 0,
                        max: 480,
                        divisions: 16,
                        label: "${_esnaf!.bakimTemizlikSuresi} dk",
                        onChanged: (v) {
                          setState(() {
                            _esnaf = _esnaf!.copyWith(bakimTemizlikSuresi: v.round());
                          });
                        },
                        onChangeEnd: (v) => _guncelle({'bakimTemizlikSuresi': v.round()}),
                      ),
                    ),
                    Container(
                      width: 70,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_esnaf!.bakimTemizlikSuresi}dk",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const Text("Sınır: 0 - 8 Saat (480 dk)", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Divider(height: 30),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Bakım Sırasında Kiralama", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("İşaretli olursa araç bakım sürecindeyken de yeni randevu alınabilir."),
                  value: _esnaf!.bakimSurecindeRandevuAlinsin,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(bakimSurecindeRandevuAlinsin: v);
                    });
                    await _guncelle({'bakimSurecindeRandevuAlinsin': v});
                  },
                ),
                const Divider(height: 30),
                _parametreBaslik("Akıllı Takip Modu", Icons.auto_graph_rounded),
                const SizedBox(height: 10),
                Text(
                  "Kiralama bitimine ${_esnaf!.akilliTakipSuresi ~/ 60} saat ${_esnaf!.akilliTakipSuresi % 60 > 0 ? '${_esnaf!.akilliTakipSuresi % 60} dk ' : ''}kala müşteriye bildirim gider. Eğer araç müsaitse, sistem otonom olarak uzatma teklif eder.",
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Modu Aktif Et", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  value: _esnaf!.akilliTakipModu,
                  onChanged: (v) async {
                    setState(() {
                      _esnaf = _esnaf!.copyWith(akilliTakipModu: v);
                    });
                    await _guncelle({'akilliTakipModu': v});
                  },
                ),
                if (_esnaf!.akilliTakipModu) ...[
                  const SizedBox(height: 10),
                  const Text("Bildirim Zamanı", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _esnaf!.akilliTakipSuresi.toDouble(),
                          min: 30,
                          max: 300,
                          divisions: 9,
                          label: "${_esnaf!.akilliTakipSuresi} dk",
                          onChanged: (v) {
                            setState(() {
                              _esnaf = _esnaf!.copyWith(akilliTakipSuresi: v.round());
                            });
                          },
                          onChangeEnd: (v) => _guncelle({'akilliTakipSuresi': v.round()}),
                        ),
                      ),
                      Text(
                        "${_esnaf!.akilliTakipSuresi} dk",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text("Saatlik Uzatma Ücreti (TL)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey("uzatma_ucreti_${_esnaf!.id}"),
                    initialValue: _esnaf!.saatlikUzatmaUcreti.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixText: "TL / Saat",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onFieldSubmitted: (v) {
                      final ucret = double.tryParse(v);
                      if (ucret != null) {
                        _guncelle({'saatlikUzatmaUcreti': ucret});
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
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
                ],
              ],
            ),
          ),
          _parametreKart(
            baslik: "Ajanda ve Takvim Ayarları",
            altBaslik: "Randevu aralıklarını ve ileriye dönük pencereyi buradan yönetin.",
            icon: Icons.calendar_month_rounded,
            icerik: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parametreBaslik(String baslik, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
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
