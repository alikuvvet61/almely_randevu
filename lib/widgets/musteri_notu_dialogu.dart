import 'package:flutter/material.dart';
import '../servisler/firestore_servisi.dart';

Future<void> musteriNotuDuzenle({
  required BuildContext context,
  required FirestoreServisi firestore,
  required String esnafId,
  required String telefon,
  required String ad,
  required String mevcutNot,
}) async {
  final controller = TextEditingController(text: mevcutNot);
  final kaydet = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ad.trim().isEmpty ? 'Müşteri notu' : ad),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        maxLength: 300,
        decoration: const InputDecoration(
          hintText: 'Örnek: çarpana kadar gelindi',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
      ],
    ),
  );
  final yazi = controller.text;
  controller.dispose();
  if (kaydet != true) return;
  await firestore.musteriNotuKaydet(esnafId, telefon, yazi);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Müşteri notu kaydedildi')),
  );
}
