# Bildirim ve Akıllı Takip Sistemi İyileştirme Planı

Bu plan, bildirimlerin uygulama kapalıyken veya bilgisayardan işlem yapıldığında telefona ulaşmama sorununu gidermeyi amaçlar.

## Problem Analizi
1.  **Cihaz Bağımlılığı**: Mevcut "Akıllı Takip" bildirimleri sadece randevunun alındığı cihazda (Chrome veya Telefon) yerel olarak kuruluyor. Chrome'dan alınan randevu için telefonun haberi olmuyor.
2.  **Uygulama Durumu**: Bildirimler şu an Firestore dinleyicisi (`snapshots().listen`) ile çalışıyor. Uygulama tamamen kapalıysa (terminated) bu dinleyici çalışmaz ve bildirim gelmez.
3.  **Çözüm Gereksinimi**: Bildirimlerin cihazdan bağımsız ve uygulama kapalıyken de çalışması için bulut tabanlı bir tetikleyici mekanizmaya ihtiyaç vardır.

## Önerilen Değişiklikler

### [Bildirim Servisi]

#### [bildirim_servisi.dart](file:///D:/Users/KULLANICI/AndroidStudioProjects/almely_randevu/lib/servisler/bildirim_servisi.dart)

- **Arka Plan Desteği**: `FirebaseMessaging.onBackgroundMessage` handler'ı eklenerek uygulamanın kapalı olduğu durumlarda FCM mesajlarının yakalanması sağlanacak.
- **Dinamik Kanal Yönetimi**: Bildirim kanallarının Android tarafında uygulama kapalıyken de doğru çalışması için konfigürasyonlar netleştirilecek.

### [Randevu Ekranı]

#### [randevu_ekrani.dart](file:///D:/Users/KULLANICI/AndroidStudioProjects/almely_randevu/lib/ekranlar/randevu_ekrani.dart)

- **Akıllı Takip Veri Kaydı**: Akıllı takip bildirimi sadece cihaz yereline kurulmakla kalmayacak, aynı zamanda Firestore'daki `randevular` belgesine `bildirimZamani` ve `akilliTakipAktif: true` olarak kaydedilecek.
- **Bulut Tetikleyici Mantığı**: (Bu aşama için öneri) Gerçekten uygulama kapalıyken bildirim gitmesi için Firebase Cloud Functions kullanılmalıdır. Ancak Agent olarak Cloud Functions yazamadığım için, mevcut Firestore tabanlı sistemi en üst düzeye çıkaracak "Background Fetch" veya "FCM Data Message" yapılarını güçlendireceğim.

## Önemli Not: Cihaz Kapalıyken Bildirim
Kullanıcının "Telefon kapalı olsada bildirim gitmeli" talebi teknik olarak şöyledir:
- **Uygulama Kapalıyken**: FCM (Firebase Cloud Messaging) ile bu mümkündür. Kod tarafında bunu destekleyeceğiz.
- **Cihaz Tamamen Güç Olarak Kapalıyken**: Hiçbir uygulama veya servis bildirim alamaz. Telefon açıldığı anda bildirimler ekrana düşer.

## Doğrulama Planı

### Otomatik Testler
- Mevcut testler çalıştırılacak: `flutter test test/widget_test.dart`

### Manuel Doğrulama
- **Uygulama Arka Planda**: Randevu alınacak ve telefonun ana ekranındayken (uygulama simge durumundayken) bildirimin gelip gelmediği kontrol edilecek.
*Not: Tam "Terminated" (kapalı) durumunu test etmek için fiziksel cihazda test gereklidir.*
- **Chrome -> Telefon**: Chrome'dan randevu oluşturulduğunda, telefona anlık bildirim gidip gitmediği (FCM üzerinden) test edilecek.
