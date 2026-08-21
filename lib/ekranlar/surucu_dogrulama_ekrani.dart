import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import '../servisler/firestore_servisi.dart';
import '../modeller/esnaf_modeli.dart';
import '../widgets/ana_buton.dart';

class SurucuDogrulamaEkrani extends StatefulWidget {
  final EsnafModeli esnaf;
  final String? soforTel; // Şoförün telefon numarasını doğrudan alalım
  final String? baslangicBelge; // Belirli bir belgeden başlatmak için

  const SurucuDogrulamaEkrani({super.key, required this.esnaf, this.soforTel, this.baslangicBelge});

  @override
  State<SurucuDogrulamaEkrani> createState() => _SurucuDogrulamaEkraniState();
}

class _SurucuDogrulamaEkraniState extends State<SurucuDogrulamaEkrani> {
  final _firestoreServisi = FirestoreServisi();
  final _picker = ImagePicker();
  
  final Map<String, dynamic> _yuklenenDosyaVerileri = {
    'selfie': null,
    'ehliyet': null,
    'sofor_karti': null,
    'adli_sicil': null,
    'psikoteknik': null,
    'ruhsat': null,
    'sigorta': null,
    'arac_foto': null,
    // Yeni belgeler
    'saglik_raporu': null,
    'alkol_testi': null,
    'muayene_raporu': null,
    'belediye_ruhsat': null,
    'ferdi_kaza': null,
    'taksimetre_belge': null,
    'vergi_levhasi': null,
    'ikametgah': null,
  };

  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    // Eğer belirli bir belge için gelindiyse, kamerayı otomatik aç
    if (widget.baslangicBelge != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fotoSec(widget.baslangicBelge!);
      });
    }
  }

  Future<void> _fotoSec(String tur) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 50,
      preferredCameraDevice: tur == 'selfie' ? CameraDevice.front : CameraDevice.rear,
    );
    
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _yuklenenDosyaVerileri[tur] = bytes;
        });
      } else {
        setState(() {
          _yuklenenDosyaVerileri[tur] = File(image.path);
        });
      }
    }
  }

  Future<void> _belgeleriGonder() async {
    // En az bir belge seçilmiş olmalı
    if (_yuklenenDosyaVerileri.values.every((element) => element == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen en az bir belge yükleyin.")),
      );
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      String? tel = widget.soforTel;
      
      if (tel == null || tel.isEmpty) {
         // Eğer parametre gelmediyse (Müşteri ekranından geçiş gibi) ilk aracı dene
         tel = widget.esnaf.araclar.isNotEmpty ? widget.esnaf.araclar.first['soforTel'] : null;
      }

      if (tel == null) throw "Telefon numarası belirlenemedi. Lütfen profilinizden telefonunuzu güncelleyin.";

      for (var entry in _yuklenenDosyaVerileri.entries) {
        if (entry.value != null) {
          // 1. Storage'a yükle
          String extension = kIsWeb ? "jpg" : "jpg"; // İleride kontrol edilebilir
          String storagePath = 'belgeler/$tel/${entry.key}_${DateTime.now().millisecondsSinceEpoch}.$extension';
          String? downloadUrl = await _firestoreServisi.dosyaYukle(entry.value, storagePath);
          
          if (downloadUrl != null) {
            // 2. Firestore'a URL'yi kaydet
            await _firestoreServisi.belgeYukle(tel, entry.key, downloadUrl);
          } else {
            throw "${entry.key} yüklenirken bir sorun oluştu.";
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Başarılı"),
            content: const Text("Belgeleriniz incelemeye alındı. Admin onayından sonra paneliniz güncellenecektir."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("TAMAM"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Widget _dosyaKarti(String baslik, String tur, IconData ikon) {
    bool yuklendi = _yuklenenDosyaVerileri[tur] != null;
    bool isFocus = widget.baslangicBelge == tur;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: isFocus ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: yuklendi ? Colors.green : (isFocus ? Colors.blue : Colors.grey.shade300),
          width: isFocus ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(ikon, color: yuklendi ? Colors.green : Colors.indigo),
        title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(yuklendi ? "Dosya Hazır" : "Fotoğraf çekmek için tıklayın"),
        trailing: yuklendi 
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.camera_alt_outlined),
        onTap: () => _fotoSec(tur),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Güvenlik & Belge Yükleme")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Profesyonel Sürücü Standartları",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 10),
            const Text(
              "Lütfen belgelerinizi güncel ve net şekilde yükleyin. Onay süreci 24 saat sürebilir.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            _sectionTitle("1. KİMLİK & GÜVENLİK"),
            _dosyaKarti("Canlı Yüz Doğrulama (Selfie)", "selfie", Icons.face_retouching_natural),
            _dosyaKarti("Kimlik / Ehliyet", "ehliyet", Icons.badge_outlined),
            _dosyaKarti("İkametgah Belgesi (e-Devlet)", "ikametgah", Icons.home_work_outlined),
            
            _sectionTitle("2. MEVZUAT & LİSANSLAR"),
            _dosyaKarti("Ticari Araç Kullanma Belgesi", "sofor_karti", Icons.card_membership),
            _dosyaKarti("Adli Sicil Kaydı (QR)", "adli_sicil", Icons.history_edu),
            _dosyaKarti("Psikoteknik Raporu", "psikoteknik", Icons.health_and_safety_outlined),
            _dosyaKarti("Sürücü Sağlık Raporu", "saglik_raporu", Icons.medical_services_outlined),
            _dosyaKarti("Madde / Alkol Tarama Testi", "alkol_testi", Icons.biotech_outlined),

            _sectionTitle("3. ARAÇ VE TİCARİ UYGUNLUK"),
            _dosyaKarti("Ruhsat Bilgileri (Tescil)", "ruhsat", Icons.directions_car_filled_outlined),
            _dosyaKarti("Belediye Çalışma Ruhsatı", "belediye_ruhsat", Icons.account_balance_outlined),
            _dosyaKarti("Araç Muayene Raporu (TÜVTÜRK)", "muayene_raporu", Icons.fact_check_outlined),
            _dosyaKarti("Zorunlu Trafik Sigortası", "sigorta", Icons.description_outlined),
            _dosyaKarti("Koltuk Ferdi Kaza Sigortası", "ferdi_kaza", Icons.airline_seat_recline_extra_outlined),
            _dosyaKarti("Taksimetre Kalibrasyon Belgesi", "taksimetre_belge", Icons.settings_input_component_outlined),
            _dosyaKarti("Araç Görselleri (4 Açı)", "arac_foto", Icons.photo_library_outlined),

            _sectionTitle("4. FİNANSAL BİLGİLER"),
            _dosyaKarti("Vergi Levhası / Şirket Kaydı", "vergi_levhasi", Icons.assignment_ind_outlined),

            const SizedBox(height: 40),
            if (_yukleniyor)
              const Center(child: CircularProgressIndicator())
            else
              AnaButon(metin: "BELGELERİ ONAYA GÖNDER", onPressed: _belgeleriGonder),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo, fontSize: 13)),
    );
  }
}
