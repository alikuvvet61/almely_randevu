import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class KimlikDogrulamaServisi {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Telefon numarasına doğrulama kodu gönder
  Future<void> telefonIleDogrula({
    required String telefon,
    required Function(PhoneAuthCredential) dogrulamaTamamlandi,
    required Function(FirebaseAuthException) dogrulamaHatasi,
    required Function(String, int?) kodGonderildi,
    required Function(String) zamanAsimi,
  }) async {
    // Formatlama: 05xx -> +905xx
    String formatliTel = telefon;
    if (telefon.startsWith('0')) {
      formatliTel = '+90${telefon.substring(1)}';
    } else if (!telefon.startsWith('+')) {
      formatliTel = '+90$telefon';
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: formatliTel,
      verificationCompleted: dogrulamaTamamlandi,
      verificationFailed: dogrulamaHatasi,
      codeSent: kodGonderildi,
      codeAutoRetrievalTimeout: zamanAsimi,
      timeout: const Duration(seconds: 60),
    );
  }

  // Gönderilen kod ile giriş yap
  Future<UserCredential?> kodIleGirisYap(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Giriş hatası: $e");
      return null;
    }
  }

  // Çıkış yap
  Future<void> cikisYap() async {
    await _auth.signOut();
  }

  // Mevcut kullanıcıyı al
  User? get mevcutKullanici => _auth.currentUser;
}
