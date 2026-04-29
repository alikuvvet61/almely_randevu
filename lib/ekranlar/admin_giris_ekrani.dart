import 'package:flutter/material.dart';
import 'admin_ekrani.dart';

class AdminGirisSayfasi extends StatelessWidget {
  const AdminGirisSayfasi({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Admin Girişi")),
    body: Padding(
      padding: const EdgeInsets.all(25),
      child: Column(children: [
        const TextField(
            obscureText: true,
            decoration: InputDecoration(
                labelText: "Yönetici Şifresi", border: OutlineInputBorder())),
        const SizedBox(height: 25),
        ElevatedButton(
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (c) => const AdminEkrani())),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: const Text("Giriş Yap"),
        ),
      ]),
    ),
  );
}
