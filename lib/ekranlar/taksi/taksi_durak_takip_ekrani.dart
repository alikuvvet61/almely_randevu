import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../modeller/esnaf_modeli.dart';
import '../surucu_profil_detay_ekrani.dart';

class TaksiDurakTakipEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel;

  const TaksiDurakTakipEkrani({super.key, required this.esnaf, this.soforTel});

  @override
  State<TaksiDurakTakipEkrani> createState() => _TaksiDurakTakipEkraniState();
}

class _TaksiDurakTakipEkraniState extends State<TaksiDurakTakipEkrani> {
  List<Map<String, dynamic>> araclar = [];
  Map<String, dynamic> gunlukAjanda = {};
  Map<String, Map<String, dynamic>> kullaniciProfilleri = {}; // Profil önbelleği
  StreamSubscription? _aracSubscription;
  StreamSubscription? _ajandaSubscription;
  StreamSubscription? _kullaniciSubscription;

  @override
  void initState() {
    super.initState();
    _verileriDinle();
  }

  @override
  void dispose() {
    _aracSubscription?.cancel();
    _ajandaSubscription?.cancel();
    _kullaniciSubscription?.cancel();
    super.dispose();
  }

  void _verileriDinle() {
    // Araç listesini dinle
    _aracSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          List<Map<String, dynamic>> hamListe = List<Map<String, dynamic>>.from(data['araclar'] ?? []);
          araclar = hamListe;
          _kullanicilariDinle(); // Araç listesi değişince kullanıcıları da dinle
          _sirala();
        }
      }
    });

    // Bugünün ajanda defteri verisini dinle
    String ayKey = DateFormat('yyyy-MM').format(DateTime.now());
    String gunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _ajandaSubscription = FirebaseFirestore.instance
        .collection('esnaflar')
        .doc(widget.esnaf.id)
        .collection('taksi_ajanda')
        .doc(ayKey)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        gunlukAjanda = Map<String, dynamic>.from(snapshot.data()?[gunKey] ?? {});
        _sirala();
      }
    });
  }

  void _kullanicilariDinle() {
    _kullaniciSubscription?.cancel();
    
    final telefonlar = araclar
        .map((a) => a['soforTel']?.toString())
        .where((t) => t != null && t.isNotEmpty)
        .toSet()
        .toList();

    if (telefonlar.isEmpty) return;

    // Tüm şoförleri tek bir toplu sorguda dinle (Performans artışı sağlar)
    _kullaniciSubscription = FirebaseFirestore.instance
        .collection('kullanicilar')
        .where(FieldPath.documentId, whereIn: telefonlar.take(30).toList())
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var doc in snapshot.docs) {
            kullaniciProfilleri[doc.id] = Map<String, dynamic>.from(doc.data());
          }
        });
      }
    });
  }

  bool _istirahatKontrol(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    // Manuel durum kontrolü
    if (arac['durum'] == 'İstirahatte') return true;
    // Çizelge (Ajanda Defteri) kontrolü
    if (gunlukAjanda.containsKey(plaka) && gunlukAjanda[plaka]?.toString().contains('I') == true) return true;
    
    // Haftalık şablon kontrolü
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());
    bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
    if (!calisiyor) return true;

    return false;
  }

  void _sirala() {
    if (!mounted) return;
    setState(() {
      araclar.sort((a, b) {
        // 1. Öncelik: İstirahat durumu (İstirahatte olanlar EN ALTA)
        bool aIst = _istirahatKontrol(a);
        bool bIst = _istirahatKontrol(b);
        if (aIst != bIst) return aIst ? 1 : -1;

        // 2. Öncelik: Durakta olma durumu
        bool aDurakta = a['durakta'] == true;
        bool bDurakta = b['durakta'] == true;
        if (aDurakta != bDurakta) return aDurakta ? -1 : 1;

        // 3. Öncelik: Nöbet Sırası (Nöbetçiler en üstte olsun istenirse)
        int aNobetSira = a['nobetSirasi'] ?? 999999;
        int bNobetSira = b['nobetSirasi'] ?? 999999;
        if (aNobetSira != bNobetSira) return aNobetSira.compareTo(bNobetSira);

        // 4. Öncelik: Sıra zamanı (Duraktakiler için)
        if (aDurakta && bDurakta) {
          int aZaman = a['siraZamani'] ?? 0;
          int bZaman = b['siraZamani'] ?? 0;
          if (aZaman != bZaman) return aZaman.compareTo(bZaman);
        }

        // 5. Öncelik: Plaka
        return (a['plaka'] ?? "").compareTo(b['plaka'] ?? "");
      });
    });
  }

  String _getDurumEtiketi(Map<String, dynamic> arac) {
    String plaka = arac['plaka'] ?? "";
    String gunAdi = DateFormat('EEEE', 'tr_TR').format(DateTime.now());

    // 1. Öncelik: Aylık Ajanda (Özel Gün Tanımı)
    if (gunlukAjanda.containsKey(plaka)) {
      String durum = gunlukAjanda[plaka].toString();
      if (durum.contains('I')) return "İSTİRAHAT";
      if (durum.contains('N')) return "NÖBETÇİ";
      return ""; // 'C' ise ekstra etiket gösterme
    }

    // 2. Öncelik: Haftalık Şablon
    bool calisiyor = (arac['calismaGunleri'] ?? {})[gunAdi] ?? true;
    if (!calisiyor) return "İSTİRAHAT";

    bool nobetci = ((arac['nobetBilgileri'] ?? {})[gunAdi] ?? {})['nobetci'] ?? false;
    if (nobetci) return "NÖBETÇİ";

    return "";
  }


  bool get _isSofor => widget.soforTel != null;
  
  void _profilGoster() async {
    final tel = widget.soforTel;
    if (tel == null) return;

    // Fetch user doc (if needed) and navigate to driver profile detail
    try {
      final esnaf = widget.esnaf;
      final arac = (esnaf.araclar).firstWhere((a) => a['soforTel'] == tel, orElse: () => {});

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (c) => SurucuProfilDetayEkrani(esnaf: esnaf, arac: arac)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profil açılamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Canlı Durak Takip", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isSofor)
            IconButton(
              icon: const Icon(Icons.account_circle, size: 28, color: Colors.indigo),
              onPressed: () => _profilGoster(),
              tooltip: "Profilim",
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.withValues(alpha: 0.1), height: 1),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (araclar.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text("Henüz kayıtlı araç bulunmuyor.", style: TextStyle(color: Colors.grey))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    var arac = araclar[idx];
                    bool durakta = arac['durakta'] ?? false;
                    String durum = arac['durum'] ?? 'Müsait';
                    bool kendiAraci = _isSofor && arac['soforTel'] == widget.soforTel;
                    String ajandaEtiketi = _getDurumEtiketi(arac);
                    bool isNobetci = ajandaEtiketi == "NÖBETÇİ";

                    // Çizelge (Ajanda) kontrolü: Eğer çizelgede istirahat ise UI durumunu buna zorla
                    bool cizelgeIstirahat = ajandaEtiketi == "İSTİRAHAT";
                    if (cizelgeIstirahat) {
                      durum = 'İstirahatte';
                    }

                    Color durumRengi = Colors.green;
                    IconData durumIkonu = Icons.local_taxi;

                    if (durum == 'Meşgul') {
                      durumRengi = Colors.red;
                      durumIkonu = Icons.not_interested;
                    } else if (durum == 'Mola') {
                      durumRengi = Colors.orange;
                      durumIkonu = Icons.coffee_rounded;
                    } else if (durum == 'İstirahatte') {
                      // İstirahatte olan araçlar için kullanıcı isteği üzerine kırmızı rozet rengi
                      durumRengi = Colors.red; 
                      durumIkonu = Icons.hotel_rounded;
                    }

                    int siraNo = 0;
                    if (durakta) {
                      var duraktakiler = araclar.where((a) => a['durakta'] == true).toList();
                      siraNo = duraktakiler.indexOf(arac) + 1;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: isNobetci 
                              ? Colors.orange.withValues(alpha: 0.5) 
                              : Colors.grey.withValues(alpha: 0.1),
                          width: isNobetci ? 1.5 : 1,
                        ),
                      ),
                      color: kendiAraci ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final String tel = (arac['soforTel'] ?? "").toString();
                                final userData = kullaniciProfilleri[tel] ?? {};
                                final belgeler = userData['belgeler'] ?? {};
                                
                                // Öncelik: Onaylı selfie, yoksa profil fotosu
                                String? fotoUrl = userData['fotoUrl'];
                                if (belgeler['selfie']?['status'] == 'Onaylandı') {
                                  fotoUrl = belgeler['selfie']['url'];
                                }

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: durakta ? Colors.blue.withValues(alpha: 0.1) : (durum == 'İstirahatte' ? Colors.grey : durumRengi).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        image: fotoUrl != null
                                            ? DecorationImage(
                                                image: NetworkImage(fotoUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: fotoUrl == null
                                          ? Center(
                                              child: durakta
                                                  ? Text(
                                                      siraNo.toString(),
                                                      style: TextStyle(color: Colors.blue.shade800, fontSize: 22, fontWeight: FontWeight.bold),
                                                    )
                                                  : Icon(durumIkonu, color: durum == 'İstirahatte' ? Colors.grey : durumRengi, size: 28),
                                            )
                                          : null,
                                    ),
                                    if (isNobetci)
                                      Positioned(
                                        top: -6,
                                        right: -6,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                          ),
                                          child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                        ),
                                      ),
                                  ],
                                );
                              }
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        arac['plaka'] ?? "Plaka Yok",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                      ),
                                      if (isNobetci)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.shield_rounded, color: Colors.orange, size: 18),
                                        ),
                                      if (kendiAraci)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text("SİZ", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    arac['soforAd'] ?? 'Şoför Belirtilmemiş',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _durumRozeti(durum, durumRengi),
                                      if (durakta) _durumRozeti(siraNo == 1 ? "SIRADAKİ" : "$siraNo. SIRA", Colors.blue),
                                      if (ajandaEtiketi.isNotEmpty && !(durum == 'İstirahatte' && ajandaEtiketi == 'İSTİRAHAT'))
                                        _durumRozeti(ajandaEtiketi, ajandaEtiketi == "NÖBETÇİ" ? Colors.orange.shade800 : Colors.red),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.navigation, color: Colors.blue),
                                  onPressed: () => _navigasyonSor(arac['konum'], arac['konumAdres']),
                                ),
                                const SizedBox(height: 4),
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _surucuMenuGoster(arac),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: araclar.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _durumRozeti(String text, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  void _navigasyonSor(dynamic konum, String? adres) {
    if (konum == null && (adres == null || adres.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konum bilgisi yok')));
      return;
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Navigasyon'),
        content: Text(adres ?? 'Konum verisi ile navigasyon başlatılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat')),
          TextButton(onPressed: () {
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigasyon başlatıldı (simülasyon)')));
          }, child: const Text('Evet')),
        ],
      ),
    );
  }

  void _surucuMenuGoster(Map<String, dynamic> arac) {
    showModalBottomSheet(context: context, builder: (c) => SafeArea(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: const Icon(Icons.person), title: const Text('Profil'), onTap: () { Navigator.pop(c); _profilGoster(); }),
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Fotoğraf Ekle'), onTap: () { Navigator.pop(c); /* TODO: implement */ }),
      ],
    )));
  }

}
