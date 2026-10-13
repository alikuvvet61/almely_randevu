import 'package:flutter/material.dart';

/// Profil fotoğrafı. Adres boşsa veya yüklenemezse kişi ikonu durur.
class ProfilDairesi extends StatelessWidget {
  final String fotoUrl;
  final double boyut;
  final VoidCallback? onTap;

  const ProfilDairesi({
    super.key,
    required this.fotoUrl,
    this.boyut = 72,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = fotoUrl.trim();
    final daire = Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.person, size: boyut * 0.55, color: Colors.indigo.shade300)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Icon(Icons.person, size: boyut * 0.55, color: Colors.indigo.shade300),
            ),
    );
    if (onTap == null) return daire;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: daire,
      ),
    );
  }
}
