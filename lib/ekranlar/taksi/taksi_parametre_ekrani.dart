import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../servisler/firestore_servisi.dart';
import '../../servisler/taksi/taksi_iptal_bedeli.dart';
import '../../modeller/esnaf_modeli.dart';

class TaksiParametreEkrani extends StatefulWidget {
  final String esnafId;
  const TaksiParametreEkrani({super.key, required this.esnafId});

  @override
  State<TaksiParametreEkrani> createState() => _TaksiParametreEkraniState();
}

class _TaksiParametreEkraniState extends State<TaksiParametreEkrani> {
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
        title: const Text("Taksi Durağı Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    subtitle: const Text(
                      "Açık: yolcu plaka seçer, randevu o araca yazılır.\nKapalı: plaka seçilmez, randevu durak adına alınır; aracı durak ayırır.",
                    ),
                    value: _esnaf!.aracOdakliSistem,
                    onChanged: (v) async {
                      setState(() { _esnaf = _esnaf!.copyWith(aracOdakliSistem: v); });
                      await _guncelle({'aracOdakliSistem': v});
                    },
                  ),
                ],
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Randevuyu kim onaylasın?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Ben onaylayacağım derseniz yeni randevu sizden onay bekler. Otomatik onaylansın derseniz kayıt hemen onaylanır.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('taksi_onay_${_esnaf!.randevuOnayModu}'),
                  initialValue: _esnaf!.randevuOnayModu == 'Otomatik' ? 'Otomatik' : 'Manuel',
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Manuel', child: Text('Ben onaylayacağım')),
                    DropdownMenuItem(value: 'Otomatik', child: Text('Otomatik onaylansın')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() { _esnaf = _esnaf!.copyWith(randevuOnayModu: v); });
                    await _guncelle({'randevuOnayModu': v});
                  },
                ),
              ],
            ),
          ),
          _parametreKart(
            baslik: "Çağrı ve rezervasyon bildirimleri",
            altBaslik: "Yolcu çağırınca, rezervasyon düşünce ve saat yaklaşınca kime haber gideceğini seçin.",
            icon: Icons.notifications_active_outlined,
            icerik: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Anlık çağrı", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Yolcu “Taksi İstiyorum” deyince durak telefonuna ve varsa sıradaki şoföre “Yeni taksi çağrısı” bildirimi gider. Uygulama kapalı olsa da gelir. Kabul ve red penceresi, taksi paneli açılınca bekleyen talep için çıkar. Reddederseniz yolcuya “şu an araç çıkarılamadı” gider."),
                  value: _esnaf!.taksiCagriBildirim,
                  onChanged: (v) async {
                    setState(() { _esnaf = _esnaf!.copyWith(taksiCagriBildirim: v); });
                    await _guncelle({'taksiCagriBildirim': v});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Navigasyon kendiliğinden açılsın", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Yolcu taksi istedikten sonra, çağrıyı kabul eden şoföre sorulup sorulmayacağını seçer. Kapalıyken o şoföre “Navigasyon başlasın mı?” diye sorulur. Açıkken sorulmaz, Google Haritalar alış noktasına kendiliğinden açılır."),
                  value: _esnaf!.taksiNavigasyonOtomatik,
                  onChanged: (v) async {
                    setState(() { _esnaf = _esnaf!.copyWith(taksiNavigasyonOtomatik: v); });
                    await _guncelle({'taksiNavigasyonOtomatik': v});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Yeni rezervasyon (durağa)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("İleri saatli rezervasyon düşünce durak telefonuna haber gider."),
                  value: _esnaf!.taksiRezervasyonEsnafBildirim,
                  onChanged: (v) async {
                    setState(() { _esnaf = _esnaf!.copyWith(taksiRezervasyonEsnafBildirim: v); });
                    await _guncelle({'taksiRezervasyonEsnafBildirim': v});
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Onay ve red (yolcuya)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Rezervasyonu onaylayınca, reddedince veya iptal edince yolcuya bildirim gider."),
                  value: _esnaf!.taksiRezervasyonMusteriBildirim,
                  onChanged: (v) async {
                    setState(() { _esnaf = _esnaf!.copyWith(taksiRezervasyonMusteriBildirim: v); });
                    await _guncelle({'taksiRezervasyonMusteriBildirim': v});
                  },
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Alış saatinden kaç dakika önce hatırlatılsın?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Yalnızca onaylanmış taksi rezervasyonunda, alış saatinden seçilen dakika önce yolcuya “Taksi rezervasyonunuz yaklaşıyor” bildirimi gider. Kapalı derseniz hatırlatma kurulmaz.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: ValueKey('taksi_hat_${_esnaf!.taksiRezervasyonHatirlatmaDk}'),
                  initialValue: const [0, 15, 30, 60].contains(_esnaf!.taksiRezervasyonHatirlatmaDk)
                      ? _esnaf!.taksiRezervasyonHatirlatmaDk
                      : 30,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Kapalı')),
                    DropdownMenuItem(value: 15, child: Text('15 dakika önce')),
                    DropdownMenuItem(value: 30, child: Text('30 dakika önce')),
                    DropdownMenuItem(value: 60, child: Text('60 dakika önce')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() { _esnaf = _esnaf!.copyWith(taksiRezervasyonHatirlatmaDk: v); });
                    await _guncelle({'taksiRezervasyonHatirlatmaDk': v});
                  },
                ),
              ],
            ),
          ),
          _parametreKart(
            baslik: "İptal bedeli",
            altBaslik: "Şoför çağrıyı kabul edince araç sıradan çıkar. Yolcu vazgeçerse şoföre ödeyeceği tutar burada belirlenir.",
            icon: Icons.money_off_csred_outlined,
            icerik: _IptalTarifeAlanlari(
              key: ValueKey(
                '${_esnaf!.taksiIptalTabanUcret}-${_esnaf!.taksiIptalKmUcret}-${_esnaf!.taksiIptalDakikaUcret}',
              ),
              taban: _esnaf!.taksiIptalTabanUcret,
              km: _esnaf!.taksiIptalKmUcret,
              dakika: _esnaf!.taksiIptalDakikaUcret,
              kaydet: (taban, km, dakika) async {
                setState(() {
                  _esnaf = _esnaf!.copyWith(
                    taksiIptalTabanUcret: taban,
                    taksiIptalKmUcret: km,
                    taksiIptalDakikaUcret: dakika,
                  );
                });
                await _guncelle({
                  'taksiIptalTabanUcret': taban,
                  'taksiIptalKmUcret': km,
                  'taksiIptalDakikaUcret': dakika,
                });
              },
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
                  subtitle: const Text("İstirahatteki araçları müşteriler “Bugün Çalışan Araçlarımız” listesinde göremez."),
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
                    Expanded(child: Text("Konum Doğrulama Mesafesi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Şoför yeşil okla sıraya girerken durağa bu kadar yakın olmalıdır. Daha uzaktaysa sıraya alınmaz.",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
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
      ),
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

class _IptalTarifeAlanlari extends StatefulWidget {
  final double taban;
  final double km;
  final double dakika;
  final Future<void> Function(double taban, double km, double dakika) kaydet;

  const _IptalTarifeAlanlari({
    super.key,
    required this.taban,
    required this.km,
    required this.dakika,
    required this.kaydet,
  });

  @override
  State<_IptalTarifeAlanlari> createState() => _IptalTarifeAlanlariState();
}

class _IptalTarifeAlanlariState extends State<_IptalTarifeAlanlari> {
  late final TextEditingController _taban;
  late final TextEditingController _km;
  late final TextEditingController _dakika;
  bool _yaziliyor = false;

  @override
  void initState() {
    super.initState();
    _taban = TextEditingController(text: taksiTlAlan(widget.taban));
    _km = TextEditingController(text: taksiTlAlan(widget.km));
    _dakika = TextEditingController(text: taksiTlAlan(widget.dakika));
  }

  @override
  void dispose() {
    _taban.dispose();
    _km.dispose();
    _dakika.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _yaziliyor = true);
    await widget.kaydet(taksiTlOku(_taban.text), taksiTlOku(_km.text), taksiTlOku(_dakika.text));
    if (mounted) setState(() => _yaziliyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final taban = taksiTlOku(_taban.text);
    final km = taksiTlOku(_km.text);
    final dakika = taksiTlOku(_dakika.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _IptalSureNotu(),
        const SizedBox(height: 12),
        Text(
          taksiIptalTarifeMetni(taban, km, dakika),
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _soru(
          _taban,
          'Vazgeçince taban ücreti kaç TL?',
          taban <= 0 ? '' : 'Vazgeçince en az ${taksiTlEtiket(taban)}.',
        ),
        const SizedBox(height: 8),
        _soru(
          _km,
          'Şoförün gittiği her kilometre başına kaç TL?',
          km <= 0 ? '' : 'Her kilometre ${taksiTlEtiket(km)}.',
        ),
        const SizedBox(height: 8),
        _soru(
          _dakika,
          'Şoförün çağrıyı kabul ettiği andan yolcunun vazgeçtiği ana kadar geçen her dakika için kaç TL?',
          dakika <= 0
              ? 'Süre, şoförün çağrıyı kabul ettiği andan yolcunun vazgeçtiği ana kadardır.'
              : 'Her dakika ${taksiTlEtiket(dakika)}. Süre, şoförün çağrıyı kabul ettiği andan yolcunun vazgeçtiği ana kadardır.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _yaziliyor ? null : _kaydet,
            child: Text(_yaziliyor ? 'Kaydediliyor' : 'İptal tarifesini kaydet'),
          ),
        ),
      ],
    );
  }

  Widget _soru(TextEditingController c, String soru, String yardim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(soru, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'TL',
            helperText: yardim.isEmpty ? null : yardim,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _IptalSureNotu extends StatelessWidget {
  const _IptalSureNotu();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: const Text(
        taksiIptalSureNotu,
        style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w600, height: 1.35),
      ),
    );
  }
}
