import 'package:flutter/material.dart';

/// Mesai saati kadranla değil listeden seçilir. Dokunulan yazı aynen kaydolur.
Future<String?> mesaiSaatiSec(BuildContext context, {required String baslik, required String secili}) {
  final liste = <String>[
    for (var saat = 0; saat < 24; saat++)
      for (final dakika in [0, 30])
        '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}',
  ];
  if (secili.contains(':') && !liste.contains(secili)) {
    liste.add(secili);
    liste.sort();
  }
  return showDialog<String>(
    context: context,
    builder: (ctx) => _SaatListesi(baslik: baslik, secili: secili, liste: liste),
  );
}

class _SaatListesi extends StatefulWidget {
  final String baslik;
  final String secili;
  final List<String> liste;
  const _SaatListesi({required this.baslik, required this.secili, required this.liste});

  @override
  State<_SaatListesi> createState() => _SaatListesiState();
}

class _SaatListesiState extends State<_SaatListesi> {
  late final ScrollController _kaydir = ScrollController(
    initialScrollOffset: (widget.liste.indexOf(widget.secili).clamp(0, widget.liste.length - 1)) * 48,
  );

  @override
  void dispose() {
    _kaydir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.baslik),
      content: SizedBox(
        width: 240,
        height: 360,
        child: ListView.builder(
          controller: _kaydir,
          itemCount: widget.liste.length,
          itemBuilder: (context, i) {
            final saat = widget.liste[i];
            final secildi = saat == widget.secili;
            return ListTile(
              title: Text(
                saat,
                style: TextStyle(
                  fontWeight: secildi ? FontWeight.bold : FontWeight.normal,
                  color: secildi ? Colors.indigo : null,
                ),
              ),
              trailing: secildi ? const Icon(Icons.check, color: Colors.indigo) : null,
              onTap: () => Navigator.pop(context, saat),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
      ],
    );
  }
}
