import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;

import '../../modeller/esnaf_modeli.dart';
import '../../servisler/firestore_servisi.dart';
import '../rehber_ekrani.dart';
import 'taksi_surucu_dogrulama_ekrani.dart';

class TaksiSurucuProfilDetayEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final Map<String, dynamic> arac;

  const TaksiSurucuProfilDetayEkrani({super.key, required this.esnaf, required this.arac});

  @override
  State<TaksiSurucuProfilDetayEkrani> createState() => _TaksiSurucuProfilDetayEkraniState();
}

class _TaksiSurucuProfilDetayEkraniState extends State<TaksiSurucuProfilDetayEkrani> {
  bool _isUploading = false;
  String _uploadingDocName = "";

  Future<void> _direktBelgeYukle(String tur, String baslik) async {
    // [GÜVENLİK]: Canlı Yüz Doğrulama Web üzerinden (dosya seçilerek) yapılamaz.
    if (kIsWeb && tur == 'selfie') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.red),
              SizedBox(width: 10),
              Text("Güvenlik Kısıtlaması"),
            ],
          ),
          content: const Text(
            "Canlı Yüz Doğrulama (Selfie) işlemi güvenlik nedeniyle sadece mobil uygulama üzerinden, canlı kamera çekimi ile yapılabilmektedir.\n\nLütfen işleminize telefonunuzdan devam edin.",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANLADIM"))],
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 50,
      preferredCameraDevice: tur == 'selfie' ? CameraDevice.front : CameraDevice.rear,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
      _uploadingDocName = baslik;
    });

    try {
      final tel = widget.arac['soforTel'];
      if (tel == null) throw "Şoför numarası belirlenemedi.";

      dynamic data;
      if (kIsWeb) {
        data = await image.readAsBytes();
      } else {
        data = File(image.path);
      }

      String extension = "jpg";
      String storagePath = 'belgeler/$tel/${tur}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      final firestore = FirestoreServisi();
      String? downloadUrl = await firestore.dosyaYukle(data, storagePath);

      if (downloadUrl != null) {
        await firestore.belgeYukle(tel, tur, downloadUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$baslik başarıyla yüklendi ve onaya gönderildi."), backgroundColor: Colors.green),
          );
        }
      } else {
        throw "Dosya yüklenemedi.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text("Sürücü Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RehberEkrani(mod: 'surucu'))),
                child: const Text("Yardım", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          body: StreamBuilder<Map<String, dynamic>?>(
            stream: FirestoreServisi().kullaniciGetir(widget.arac['soforTel'] ?? ""),
            builder: (context, snapshot) {
              final Map<String, dynamic> userData = snapshot.data ?? {};
              final Map<dynamic, dynamic> belgeler = userData['belgeler'] is Map ? userData['belgeler'] : {};
              
              // Durumları al ve detaylı kontrol et
              String getDocStatus(String key) {
                final doc = belgeler[key];
                if (doc == null || doc is! Map || doc['url'] == null || doc['url'].toString().isEmpty) {
                  return 'Eksik / Yükle';
                }
                String status = doc['status']?.toString() ?? 'Bekliyor';
                if (status == 'Bekliyor') return 'Onay Bekliyor';
                return status;
              }

              String selfieStatus = getDocStatus('selfie');
              String ehliyetStatus = getDocStatus('ehliyet');
              String ikametgahStatus = getDocStatus('ikametgah');
              String soforKartiStatus = getDocStatus('sofor_karti');
              String adliSicilStatus = getDocStatus('adli_sicil');
              String psikoteknikStatus = getDocStatus('psikoteknik');
              String saglikStatus = getDocStatus('saglik_raporu');
              String alkolStatus = getDocStatus('alkol_testi');
              String ruhsatStatus = getDocStatus('ruhsat');
              String belediyeRuhsatStatus = getDocStatus('belediye_ruhsat');
              String muayeneStatus = getDocStatus('muayene_raporu');
              String sigortaStatus = getDocStatus('sigorta');
              String ferdiKazaStatus = getDocStatus('ferdi_kaza');
              String taksimetreStatus = getDocStatus('taksimetre_belge');
              String vergiStatus = getDocStatus('vergi_levhasi');

              // Toplam ilerleme hesapla (arac_foto yerine 4 yeni fotoğraf eklendi)
          List<String> docs = [
            'selfie', 'ehliyet', 'ikametgah',
            'sofor_karti', 'adli_sicil', 'psikoteknik', 'saglik_raporu', 'alkol_testi',
            'ruhsat', 'belediye_ruhsat', 'muayene_raporu', 'sigorta', 'ferdi_kaza', 'taksimetre_belge',
            'arac_on', 'arac_arka', 'arac_sag', 'arac_sol',
            'vergi_levhasi'
          ];
              int approvedCount = docs.where((d) => belgeler[d]?['status'] == 'Onaylandı').length;
              int progress = ((approvedCount / docs.length) * 100).round();
              int pendingCount = docs.where((d) => belgeler[d]?['status'] == 'Bekliyor').length;
              int missingCount = docs.where((d) => belgeler[d] == null || belgeler[d]['url'] == null).length;

              String progressSubText = "";
              if (missingCount > 0) progressSubText += "$missingCount Belge Eksik";
              if (pendingCount > 0) {
                progressSubText += "${progressSubText.isEmpty ? "" : " - "}$pendingCount Onay Bekliyor";
              }
              if (progress == 100) progressSubText = "Tüm Belgeler Onaylandı";

              // Onaylanmış selfie fotoğrafını profil resmi olarak kullan
              String? profilFotoUrl = userData['fotoUrl'];
              final selfieDoc = belgeler['selfie'];
              if (selfieDoc != null && selfieDoc['status'] == 'Onaylandı' && selfieDoc['url'] != null) {
                profilFotoUrl = selfieDoc['url'];
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // ÜST PROFİL BÖLÜMÜ
                    _buildHeader(userData, profilFotoUrl),

                    // DURUM ÇUBUĞU
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      color: progress == 100 ? Colors.green.shade700 : Colors.blue.shade700,
                      child: Row(
                        children: [
                          Icon(progress == 100 ? Icons.verified_user : Icons.info_outline, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "DURUM: %$progress TAMAMLANDI - $progressSubText",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BÖLÜMLER
                _bolumBaslik("1. KİMLİK & GÜVENLİK (Uber Standardı)"),
                _listeElemani(context, "Canlı Yüz Doğrulama (Selfie)", "selfie", selfieStatus, selfieDoc?['url']),
                _listeElemani(context, "Kimlik / Ehliyet", "ehliyet", ehliyetStatus, belgeler['ehliyet']?['url']),
                _listeElemani(context, "İkametgah Belgesi", "ikametgah", ikametgahStatus, belgeler['ikametgah']?['url']),

                _bolumBaslik("2. YEREL MEVZUAT & LİSANSLAR (BiTaksi & Singapur)"),
                _listeElemani(context, "Ticari Araç Kullanma Belgesi", "sofor_karti", soforKartiStatus, belgeler['sofor_karti']?['url']),
                _listeElemani(context, "Adli Sicil Kaydı (QR)", "adli_sicil", adliSicilStatus, belgeler['adli_sicil']?['url']),
                _listeElemani(context, "Psikoteknik Raporu", "psikoteknik", psikoteknikStatus, belgeler['psikoteknik']?['url']),
                _listeElemani(context, "Sürücü Sağlık Raporu", "saglik_raporu", saglikStatus, belgeler['saglik_raporu']?['url']),
                _listeElemani(context, "Madde / Alkol Tarama Testi", "alkol_testi", alkolStatus, belgeler['alkol_testi']?['url']),

                _bolumBaslik("3. ARAÇ VE TİCARİ UYGUNLUK"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Plaka: ${widget.arac['plaka'] ?? ''} (Sarı Taksi / BiTaksi)", style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      const Text("Hizmet: Comfort / VIP (Uber XL)", style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                _listeElemani(context, "Ruhsat Bilgileri (Tescil)", "ruhsat", ruhsatStatus, belgeler['ruhsat']?['url']),
                _listeElemani(context, "Belediye Çalışma Ruhsatı", "belediye_ruhsat", belediyeRuhsatStatus, belgeler['belediye_ruhsat']?['url']),
                _listeElemani(context, "Araç Muayene Raporu (TÜVTÜRK)", "muayene_raporu", muayeneStatus, belgeler['muayene_raporu']?['url']),
                _listeElemani(context, "Zorunlu Trafik Sigortası", "sigorta", sigortaStatus, belgeler['sigorta']?['url']),
                _listeElemani(context, "Koltuk Ferdi Kaza Sigortası", "ferdi_kaza", ferdiKazaStatus, belgeler['ferdi_kaza']?['url']),
                _listeElemani(context, "Taksimetre Kalibrasyon Belgesi", "taksimetre_belge", taksimetreStatus, belgeler['taksimetre_belge']?['url']),
                
                // Araç Görselleri (4 Açı) - Özel Menü
                _aracGorselleriMaddesi(context, belgeler),

                _bolumBaslik("4. FİNANSAL BİLGİLER"),
                _listeElemani(context, "Vergi Levhası / Şirket Kaydı", "vergi_levhasi", vergiStatus, belgeler['vergi_levhasi']?['url']),
                _finansElemani("Banka (IBAN)", userData['iban'] ?? "TR-- ---- ---- ---- ---- ----", "Güncelle"),
                    _finansElemani("Bağlı Filo", widget.esnaf.isletmeAdi, "Detay"),

                    const SizedBox(height: 40),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => TaksiSurucuDogrulamaEkrani(esnaf: widget.esnaf, soforTel: widget.arac['soforTel']))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("TÜM BELGELERİ YÖNET", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text("$_uploadingDocName Yükleniyor...", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text("Lütfen bekleyiniz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData, String? profilFotoUrl) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      width: double.infinity,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade100, width: 2),
                  image: profilFotoUrl != null 
                      ? DecorationImage(image: NetworkImage(profilFotoUrl), fit: BoxFit.cover) 
                      : null,
                ),
                child: profilFotoUrl == null ? const Icon(Icons.person, size: 60, color: Colors.indigo) : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            userData['adSoyad'] ?? userData['ad'] ?? "İsimsiz Sürücü",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              const Text("4.95", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 10),
              const Text("|", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text("AKTİF / ÇEVRİMİÇİ", style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bolumBaslik(String metin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        metin,
        style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }

  Widget _listeElemani(BuildContext context, String baslik, String tur, String status, String? url) {
    bool approved = status == 'Onaylandı';
    bool rejected = status == 'Reddedildi' || status == 'Süresi Doldu / Yenile';
    bool missing = status == 'Eksik / Yükle';
    bool pending = status == 'Onay Bekliyor';

    Color color = Colors.grey;
    IconData icon = Icons.pending;

    if (approved) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (rejected) {
      color = Colors.red;
      icon = Icons.error;
    } else if (pending) {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (missing) {
      color = Colors.blueGrey;
      icon = Icons.add_a_photo_outlined;
    }

    return InkWell(
      onTap: missing ? () => _direktBelgeYukle(tur, baslik) : () => _belgeIslemleriniGoster(context, tur, baslik, status, url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _belgeIslemleriniGoster(BuildContext context, String tur, String baslik, String status, String? url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(baslik, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Durum: $status", style: const TextStyle(color: Colors.grey)),
            const Divider(height: 30),
            if (url != null && url.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text("Görüntüle", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _belgeGoruntule(context, url, baslik);
                },
              ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text("Yeniden Yükle", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _direktBelgeYukle(tur, baslik);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Belgeyi Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _belgeSilmeOnayiAl(context, tur, baslik);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _belgeSilmeOnayiAl(BuildContext context, String tur, String baslik) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Belgeyi Sil"),
        content: Text("'$baslik' belgesini silmek istediğinize emin misiniz? Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirestoreServisi().belgeSil(widget.arac['soforTel'] ?? "", tur);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$baslik silindi."), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("SİL"),
          ),
        ],
      ),
    );
  }

  void _belgeGoruntule(BuildContext context, String url, String baslik) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url.startsWith('http'))
              Image.network(url, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100))
            else if (kIsWeb)
              const Column(
                children: [
                  Icon(Icons.computer, color: Colors.blue, size: 50),
                  SizedBox(height: 10),
                  Text("Web tarayıcıda yerel dosya önizleme kısıtlıdır.", textAlign: TextAlign.center),
                ],
              )
            else if (File(url).existsSync())
              Image.file(File(url), height: 300, fit: BoxFit.contain)
            else
              const Icon(Icons.broken_image, size: 100),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kapat"))],
      ),
    );
  }

  Widget _aracGorselleriMaddesi(BuildContext context, Map<dynamic, dynamic> belgeler) {
    List<String> acilar = ['arac_on', 'arac_arka', 'arac_sag', 'arac_sol'];
    int approvedCount = acilar.where((a) => belgeler[a]?['status'] == 'Onaylandı').length;
    int pendingCount = acilar.where((a) => belgeler[a]?['status'] == 'Bekliyor').length;
    
    String overallStatus = "Eksik / Yükle";
    Color color = Colors.blueGrey;
    IconData icon = Icons.photo_library_outlined;

    if (approvedCount == 4) {
      overallStatus = "Onaylandı";
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (approvedCount + pendingCount == 4) {
      overallStatus = "Onay Bekliyor";
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else if (approvedCount + pendingCount > 0) {
      overallStatus = "${approvedCount + pendingCount}/4 Yüklendi";
      color = Colors.blue;
      icon = Icons.camera_alt_outlined;
    }

    return InkWell(
      onTap: () => _aracAcilariMenuGoster(context, belgeler),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Araç Görselleri (4 Açı)", style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text(
              overallStatus,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _aracAcilariMenuGoster(BuildContext context, Map<dynamic, dynamic> belgeler) {
    String getStatus(String key) {
      final doc = belgeler[key];
      if (doc == null || doc['url'] == null) return 'Eksik / Yükle';
      return doc['status'] ?? 'Bekliyor';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Araç Dış Görünüm Fotoğrafları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Lütfen 4 farklı açıdan fotoğrafları yükleyin", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            _aciButonu(context, "Ön Görünüm", "arac_on", getStatus('arac_on'), belgeler['arac_on']?['url']),
            _aciButonu(context, "Arka Görünüm", "arac_arka", getStatus('arac_arka'), belgeler['arac_arka']?['url']),
            _aciButonu(context, "Sağ Yan Görünüm", "arac_sag", getStatus('arac_sag'), belgeler['arac_sag']?['url']),
            _aciButonu(context, "Sol Yan Görünüm", "arac_sol", getStatus('arac_sol'), belgeler['arac_sol']?['url']),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _aciButonu(BuildContext context, String baslik, String tur, String status, String? url) {
    bool approved = status == 'Onaylandı';
    bool missing = status == 'Eksik / Yükle';
    Color color = approved ? Colors.green : (missing ? Colors.blueGrey : Colors.orange);

    return ListTile(
      leading: Icon(approved ? Icons.check_circle : (missing ? Icons.camera_alt : Icons.hourglass_top), color: color),
      title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(status == 'Bekliyor' ? 'Onay Bekliyor' : status, style: TextStyle(color: color, fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url != null)
            IconButton(
              icon: const Icon(Icons.visibility, size: 20, color: Colors.blue),
              onPressed: () => _belgeGoruntule(context, url, baslik),
            ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        if (approved) {
           _belgeIslemleriniGoster(context, tur, baslik, status, url);
        } else if (!missing) {
           _belgeIslemleriniGoster(context, tur, baslik, "Onay Bekliyor", url);
        } else {
           _direktBelgeYukle(tur, baslik);
        }
      },
    );
  }

  Widget _finansElemani(String baslik, String deger, String aksiyon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(deger, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Row(
              children: [
                Text(aksiyon, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right, size: 18, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
