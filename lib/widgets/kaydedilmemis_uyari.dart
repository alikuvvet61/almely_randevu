import 'package:flutter/material.dart';

class KaydedilmemisUyari extends StatelessWidget {
  final bool gorunur;

  const KaydedilmemisUyari({super.key, required this.gorunur});

  @override
  Widget build(BuildContext context) {
    if (!gorunur) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kaydedilmemiş değişiklik var. Ayarları Kaydet’e basın.',
                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _KayitSecimi { vazgec, cik, kaydet }

/// Geri tuşu ve Kapat aynı soruya düşer. sor true dönerse pencere kapanır.
class KapatKontrolluDiyalog extends StatefulWidget {
  final Future<bool> Function() sor;
  final Widget Function(Future<void> Function() kapat, VoidCallback zorlaKapat) olustur;

  const KapatKontrolluDiyalog({super.key, required this.sor, required this.olustur});

  @override
  State<KapatKontrolluDiyalog> createState() => _KapatKontrolluDiyalogState();
}

class _KapatKontrolluDiyalogState extends State<KapatKontrolluDiyalog> {
  var _izin = false;
  var _suruyor = false;

  Future<void> _kapat() async {
    if (_suruyor || _izin) return;
    _suruyor = true;
    final olur = await widget.sor();
    if (!mounted) return;
    if (!olur) {
      _suruyor = false;
      return;
    }
    _zorlaKapat();
  }

  void _zorlaKapat() {
    setState(() => _izin = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _izin,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _kapat();
      },
      child: widget.olustur(_kapat, _zorlaKapat),
    );
  }
}

/// Değişiklik yoksa hemen true.
/// Vazgeç false döner. Kaydetmeden çık yazmaz, geri alır ve true döner. Kaydet yazmayı dener.
Future<bool> kaydedilmemisDevam(
  BuildContext context,
  bool degisiklikVar, {
  required Future<void> Function() kaydet,
  required bool Function() kayitTamam,
  required Future<void> Function() kaydetmedenCik,
}) async {
  if (!degisiklikVar) return true;
  final secim = await showDialog<_KayitSecimi>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kaydedilmemiş değişiklik'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Yaptığınız değişiklikler henüz kaydedilmedi.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx, _KayitSecimi.vazgec), child: const Text('Vazgeç')),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx, _KayitSecimi.cik), child: const Text('Kaydetmeden çık')),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(ctx, _KayitSecimi.kaydet), child: const Text('Kaydet')),
          ),
        ],
      ),
    ),
  );
  if (secim == _KayitSecimi.kaydet) {
    await kaydet();
    return kayitTamam();
  }
  if (secim == _KayitSecimi.cik) {
    await kaydetmedenCik();
    await WidgetsBinding.instance.endOfFrame;
    return true;
  }
  return false;
}
