import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../modeller/randevu_modeli.dart';
import '../servisler/storage_servisi.dart';
import '../servisler/firestore_servisi.dart';
import '../widgets/medya_goruntuleyici.dart';

class KiraTeslimatEkrani extends StatefulWidget {
  final RandevuModeli randevu;
  final bool isTeslimat; // true: Araç Teslim Edilirken, false: Araç İade Alınırken
  const KiraTeslimatEkrani({super.key, required this.randevu, required this.isTeslimat});

  @override
  State<KiraTeslimatEkrani> createState() => _KiraTeslimatEkraniState();
}

class _KiraTeslimatEkraniState extends State<KiraTeslimatEkrani> {
  final _storageServisi = StorageServisi();
  final _firestoreServisi = FirestoreServisi();
  final _picker = ImagePicker();
  bool _yukleniyor = false;

  Future<void> _medyaSec(bool isVideo) async {
    final XFile? file = isVideo 
        ? await _picker.pickVideo(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (file != null) {
      setState(() => _yukleniyor = true);
      
      final String? url = await _storageServisi.dosyaYukle(
        widget.randevu.id, 
        File(file.path), 
        widget.isTeslimat
      );

      if (url != null) {
        await _firestoreServisi.randevuGorselEkle(widget.randevu.id, url, widget.isTeslimat);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Görsel başarıyla eklendi."), backgroundColor: Colors.green));
        }
      }
      
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _gorselGoster(List<String> tumu, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => MedyaGoruntuleyici(gorseller: tumu, baslangicIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeslimat ? "Teslimat Kanıtları" : "İade Kanıtları"),
        backgroundColor: widget.isTeslimat ? Colors.indigo : Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<RandevuModeli>(
        stream: _firestoreServisi.randevuyuGetir(widget.randevu.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final r = snapshot.data!;
          final gorseller = widget.isTeslimat ? r.teslimatGorselleri : r.iadeGorselleri;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: (widget.isTeslimat ? Colors.indigo : Colors.green).withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueGrey),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "${r.randevuKanali} plakalı aracın ${widget.isTeslimat ? 'teslimat' : 'iade'} anındaki durumunu fotoğraflayarak veya video çekerek mühürleyin.",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              if (_yukleniyor) const LinearProgressIndicator(),
              Expanded(
                child: gorseller.isEmpty 
                    ? const Center(child: Text("Henüz görsel kanıt eklenmedi.", style: TextStyle(color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(15),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: gorseller.length,
                        itemBuilder: (c, i) {
                          final url = gorseller[i];
                          bool isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('video');
                          return InkWell(
                            onTap: () => _gorselGoster(gorseller, i),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: isVideo 
                                      ? Container(color: Colors.black87, child: const Center(child: Icon(Icons.videocam, color: Colors.white)))
                                      : Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 5, right: 5,
                                  child: GestureDetector(
                                    onTap: () async {
                                      await _firestoreServisi.randevuGorselSil(r.id, url, widget.isTeslimat);
                                    },
                                    child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5))
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _yukleniyor ? null : () => _medyaSec(false),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("FOTO ÇEK"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _yukleniyor ? null : () => _medyaSec(true),
                          icon: const Icon(Icons.videocam),
                          label: const Text("VİDEO ÇEK"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
