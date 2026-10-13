import 'package:flutter/material.dart';

/// Müşteri ana ekranındaki profil ikonuyla aynı salınım.
class SallananProfilIkonu extends StatefulWidget {
  final bool salla;
  final VoidCallback onPressed;
  final String tooltip;
  final Widget? ikon;

  const SallananProfilIkonu({
    super.key,
    required this.salla,
    required this.onPressed,
    this.tooltip = 'İşletme Profili',
    this.ikon,
  });

  @override
  State<SallananProfilIkonu> createState() => _SallananProfilIkonuState();
}

class _SallananProfilIkonuState extends State<SallananProfilIkonu> with SingleTickerProviderStateMixin {
  late final AnimationController _salla;

  @override
  void initState() {
    super.initState();
    _salla = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      value: 0.5,
    );
    _uygula();
  }

  @override
  void didUpdateWidget(covariant SallananProfilIkonu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salla != widget.salla) _uygula();
  }

  void _uygula() {
    if (widget.salla) {
      if (!_salla.isAnimating) _salla.repeat(reverse: true);
    } else {
      if (_salla.isAnimating) _salla.stop();
      _salla.value = 0.5;
    }
  }

  @override
  void dispose() {
    _salla.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _salla,
      builder: (context, child) {
        final kayma = (_salla.value * 2 - 1) * 3;
        return Transform.translate(offset: Offset(kayma, 0), child: child);
      },
      child: IconButton(
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        icon: widget.ikon ?? const Icon(Icons.account_circle, size: 28, color: Colors.indigo),
      ),
    );
  }
}
