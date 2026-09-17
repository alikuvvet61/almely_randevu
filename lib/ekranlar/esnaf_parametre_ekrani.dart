import 'package:flutter/material.dart';
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import 'package:almely_randevu/ekranlar/taksi/taksi_rehber_ekrani.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ayarlar güncellendi"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor || _esnaf == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("İşletme Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_esnaf?.kategori == 'Taksi')
            IconButton(
              tooltip: "Kullanım Rehberi",
              icon: const Icon(Icons.help_outline, color: Colors.blue),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TaksiRehberEkrani(mod: 'yonetici', bolum: 'parametre'))),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_esnaf!.kategori == 'Taksi') ...[
            _parametreKart(
              baslik: "Randevu Ayarları",
              altBaslik: "Durağın online rezervasyon sistemine dair tüm kısıtlamaları buradan yönetin.",
              icon: Icons.event_note_rounded,
              icerik: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Randevu Alımını Durdur", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Aktif edilirse müşteriler 'Hemen Randevu Al' butonunu göremez."),
                    value: _esnaf!.randevuAlinmasin,
                    onChanged: (v) async {
                      setState(() { _esnaf = _esnaf!.copyWith(randevuAlinmasin: v); });
                      await _guncelle({'randevuAlinmasin': v});
                    },
                  ),
                  if (!_esnaf!.randevuAlinmasin) ...[
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Araç Odaklı Sistem", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Randevular doğrudan plakalar adına alınır."),
                      value: _esnaf!.aracOdakliSistem,
                      onChanged: (v) async {
                        setState(() { _esnaf = _esnaf!.copyWith(aracOdakliSistem: v); });
                        await _guncelle({'aracOdakliSistem': v});
                      },
                    ),
                  ],
                ],
              ),
            ),
            _parametreKart(
              baslik: "Durak Görünürlük Ayarları",
              altBaslik: "Müşteri ekranındaki araç listesi ve mesafe kısıtlamalarını yönetin.",
              icon: Icons.visibility_off_rounded,
              icerik: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("İstirahetli Araçları Gizle", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    subtitle: const Text("İstirahatteki araçlar 'Bugün Çalışanlar' listesinde görünmez."),
                    value: _esnaf!.istirahatliAraclariGizle,
                    onChanged: (v) async {
                      setState(() { _esnaf = _esnaf!.copyWith(istirahatliAraclariGizle: v); });
                      await _guncelle({'istirahatliAraclariGizle': v});
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.location_searching_rounded, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("Konum Doğrulama Mesafesi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _esnaf!.konumDogrulamaMesafesi,
                          min: 5, max: 500, divisions: 99,
                          label: "${_esnaf!.konumDogrulamaMesafesi.round()} m",
                          onChanged: (v) {
                            setState(() { _esnaf = _esnaf!.copyWith(konumDogrulamaMesafesi: v); });
                          },
                          onChangeEnd: (v) => _guncelle({'konumDogrulamaMesafesi': v}),
                        ),
                      ),
                      Container(
                        width: 55, padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text("${_esnaf!.konumDogrulamaMesafesi.round()}m", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_esnaf!.kategori == 'Araç Kiralama')
            _parametreKart(
              baslik: "Bakım ve Temizlik Süresi",
              altBaslik: "Her kiralama randevusu bittikten sonra araç yaklaşık ${_esnaf!.bakimTemizlikSuresi ~/ 60} saat ${_esnaf!.bakimTemizlikSuresi % 60 > 0 ? '${_esnaf!.bakimTemizlikSuresi % 60} dk ' : ''}boyunca bakıma alınacaktır.",
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
                          divisions: 16, // 30 dk aralıklar
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
                            divisions: 9, // 30 dk aralıklar
                            label: "${_esnaf!.akilliTakipSuresi} dk",
                            onChanged: (v) {
                              setState(() {
                                _esnaf = _esnaf!.copyWith(akilliTakipSuresi: v.round());
                              });
                            },
                            onChangeEnd: (v) => _guncelle({'akilliTakipSuresi': v.round()}),
                          ),
                        ),
                        Text("${_esnaf!.akilliTakipSuresi} dk", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
                        double? ucret = double.tryParse(v);
                        if (ucret != null) {
                          _guncelle({'saatlikUzatmaUcreti': ucret});
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          if (_esnaf!.kategori != 'Taksi') 
          _parametreKart(
            baslik: "Minimum Randevu Süresi",
            altBaslik: "Müşteriler en az ne kadarlık randevu alabilir? Bu sürenin altındaki seçimler engellenir.",
            icon: Icons.hourglass_bottom_rounded,
            icerik: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _esnaf!.minimumRandevuSuresi.toDouble(),
                    min: 15,
                    max: 300,
                    divisions: 19, // 15 dk aralıklar: (300-15)/15 = 19
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
          ),
          if (_esnaf!.kategori != 'Taksi' && _esnaf!.kategori != 'Araç Kiralama')
            _parametreKart(
              baslik: "Personel Odaklı Sistem",
              altBaslik: "Müşteri kanal/saha yerine personeli seçsin. Personel seçimi zorunlu hale gelir.",
              icon: Icons.people_alt_rounded,
              icerik: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Aktif Et", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _parametreKart({required String baslik, required String altBaslik, required IconData icon, required Widget icerik}) {
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              altBaslik, 
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)
            ),
            const SizedBox(height: 18),
            icerik,
          ],
        ),
      ),
    );
  }
}
