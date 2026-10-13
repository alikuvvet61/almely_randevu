import 'dart:async';

import 'package:flutter/material.dart';

import '../servisler/taksi/nereye_arama.dart';

/// Çağrı penceresindeki Nereye. Liste, randevu ekranındaki aramayla aynıdır.
class NereyeAlani extends StatefulWidget {
  final TextEditingController controller;
  final double enlem;
  final double boylam;
  final String il;
  final String ilce;
  final double esnafEnlem;
  final double esnafBoylam;

  const NereyeAlani({
    super.key,
    required this.controller,
    required this.enlem,
    required this.boylam,
    this.il = '',
    this.ilce = '',
    required this.esnafEnlem,
    required this.esnafBoylam,
  });

  @override
  State<NereyeAlani> createState() => _NereyeAlaniState();
}

class _NereyeAlaniState extends State<NereyeAlani> {
  final _odak = FocusNode();
  Timer? _bekle;
  int _istek = 0;
  bool _ariyor = false;
  bool _bittiBos = false;
  List<NereyeOneri> _liste = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_degisti);
    _odak.addListener(() {
      if (!_odak.hasFocus && mounted) {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted && !_odak.hasFocus) setState(() => _liste = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _bekle?.cancel();
    widget.controller.removeListener(_degisti);
    _odak.dispose();
    super.dispose();
  }

  void _degisti() {
    if (!mounted) return;
    final String q;
    try {
      q = widget.controller.text.trim();
    } catch (_) {
      return;
    }
    _bekle?.cancel();
    if (q.isEmpty) {
      setState(() {
        _liste = [];
        _ariyor = false;
        _bittiBos = false;
      });
      return;
    }
    final cached = NereyeAramaci.onbellek[q.toLowerCase()];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _liste = List<NereyeOneri>.from(cached);
        _bittiBos = false;
      });
    } else {
      setState(() {});
    }
    _bekle = Timer(const Duration(milliseconds: 120), () => _ara(q));
  }

  Future<void> _ara(String sorgu) async {
    final no = ++_istek;
    if (mounted) {
      setState(() {
        _ariyor = true;
        _bittiBos = false;
      });
    }
    final arama = NereyeAramaci(
      enlem: widget.enlem,
      boylam: widget.boylam,
      il: widget.il,
      ilce: widget.ilce,
      esnafEnlem: widget.esnafEnlem,
      esnafBoylam: widget.esnafBoylam,
    );
    final liste = await arama.ara(
      sorgu,
      iptal: () => !mounted || no != _istek,
      kismi: (kismi) {
        if (!mounted || no != _istek) return;
        setState(() => _liste = kismi);
      },
    );
    if (!mounted || no != _istek) return;
    setState(() {
      _liste = liste;
      _ariyor = false;
      _bittiBos = liste.isEmpty;
    });
  }

  void _sec(NereyeOneri s) {
    widget.controller.removeListener(_degisti);
    widget.controller.text = s.etiket;
    widget.controller.addListener(_degisti);
    _odak.unfocus();
    setState(() {
      _liste = [];
      _bittiBos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _odak,
          decoration: InputDecoration(
            labelText: 'Nereye (isteğe bağlı)',
            hintText: 'Lise, taksi durağı, mahalle, cadde',
            suffixIcon: _ariyor
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (widget.controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() {
                            _liste = [];
                            _bittiBos = false;
                          });
                        },
                      )),
          ),
        ),
        if (_liste.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ExcludeFocus(
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _liste.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 56),
                      InkWell(
                        onTap: () => _sec(_liste[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.place, color: Colors.redAccent, size: 22),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_liste[i].baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    if (_liste[i].alt.isNotEmpty)
                                      Text(
                                        _liste[i].alt,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (_bittiBos && widget.controller.text.trim().isNotEmpty && !_ariyor)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Adres bulunamadı. Farklı yazmayı deneyin.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ),
      ],
    );
  }
}
