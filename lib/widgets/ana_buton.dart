import 'package:flutter/material.dart';

class AnaButon extends StatelessWidget {
  final String metin;
  final VoidCallback? onPressed; // Burayı nullable yaptık (?)
  final Color renk;

  const AnaButon({
    super.key,
    required this.metin,
    required this.onPressed,
    this.renk = Colors.blue
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: renk,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: Colors.grey.shade300, // Pasif renk
          ),
          child: Text(metin, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}