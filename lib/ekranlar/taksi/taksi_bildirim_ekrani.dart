import 'package:flutter/material.dart';

class TaksiBildirimEkrani extends StatelessWidget {
  const TaksiBildirimEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taksi Bildirimleri'),
      ),
      body: const Center(
        child: Text('Taksi özel bildirim akışı burada ayrılacak.'),
      ),
    );
  }
}
