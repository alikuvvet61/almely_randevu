import 'package:flutter/material.dart';

class TaksiRehberEkrani extends StatelessWidget {
  const TaksiRehberEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taksi Rehberi'),
      ),
      body: const Center(
        child: Text('Taksi rehberi ve kuralları burada ayrılacak.'),
      ),
    );
  }
}
