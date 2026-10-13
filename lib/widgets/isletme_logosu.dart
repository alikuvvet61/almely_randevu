import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// İşletme logosu. Adres ve dosya boşsa yer kaplamaz.
class IsletmeLogosu extends StatelessWidget {
  final String url;
  final dynamic dosya;
  final double boyut;
  final bool yuvarlak;
  final bool kenarBoslugu;

  const IsletmeLogosu({
    super.key,
    required this.url,
    this.dosya,
    this.boyut = 56,
    this.yuvarlak = false,
    this.kenarBoslugu = true,
  });

  @override
  Widget build(BuildContext context) {
    final resim = isletmeLogoResmi(url, dosya);
    if (resim == null) return const SizedBox.shrink();
    final koseli = yuvarlak ? boyut / 2 : 12.0;
    return Padding(
      padding: kenarBoslugu ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
      child: Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(
          shape: yuvarlak ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: yuvarlak ? null : BorderRadius.circular(koseli),
          border: Border.all(color: Colors.indigo.shade100, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(koseli),
          child: Image(image: resim, width: boyut, height: boyut, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ),
    );
  }
}

ImageProvider? isletmeLogoResmi(String url, dynamic dosya) {
  if (dosya is Uint8List) return MemoryImage(dosya);
  if (dosya is File) return FileImage(dosya);
  final adres = url.trim();
  if (adres.isEmpty) return null;
  return NetworkImage(adres);
}

/// İşletme bilgilerindeki logo kutusu. Dokununca galeriden seçilir.
class IsletmeLogoSecici extends StatefulWidget {
  final String url;
  final dynamic dosya;
  final ValueChanged<dynamic> onSecildi;

  const IsletmeLogoSecici({super.key, required this.url, required this.dosya, required this.onSecildi});

  @override
  State<IsletmeLogoSecici> createState() => _IsletmeLogoSeciciState();
}

class _IsletmeLogoSeciciState extends State<IsletmeLogoSecici> {
  dynamic _dosya;

  @override
  void initState() {
    super.initState();
    _dosya = widget.dosya;
  }

  Future<void> _sec() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null || !mounted) return;
    final veri = kIsWeb ? await image.readAsBytes() : File(image.path);
    if (!mounted) return;
    setState(() => _dosya = veri);
    widget.onSecildi(veri);
  }

  @override
  Widget build(BuildContext context) {
    final resim = isletmeLogoResmi(widget.url, _dosya);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Material(
            color: Colors.indigo.shade50,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sec,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade200, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: resim == null
                    ? Icon(Icons.add_photo_alternate_outlined, color: Colors.indigo.shade700, size: 36)
                    : Image(image: resim, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Logo', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            resim == null ? 'İsteğe bağlı. Dokununca galeriden seçilir.' : 'Değiştirmek için dokunun.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
