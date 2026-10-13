import 'package:flutter/material.dart';
import '../servisler/bildirim_servisi.dart';

Future<void> musteriyeBildirimDialogu({
  required BuildContext context,
  required String telefon,
  required String ad,
  required String isletmeAdi,
}) async {
  final controller = TextEditingController();
  final gonder = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kullanıcıya bildirim gönder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          hintText: ad.trim().isEmpty ? 'Müşteriye gidecek metin' : '$ad için metin yazın',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: const Text('Gönder'),
        ),
      ],
    ),
  );
  final metin = controller.text.trim();
  controller.dispose();
  if (gonder != true || metin.isEmpty || !context.mounted) return;
  final oldu = await BildirimServisi.musteriyeYaziGonder(
    kullaniciTel: telefon,
    isletmeAdi: isletmeAdi,
    metin: metin,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        oldu
            ? 'Bildirim gönderildi'
            : 'Bildirim gitmedi. Müşteri telefonundan uygulamaya girmiş olmalı.',
      ),
    ),
  );
}
