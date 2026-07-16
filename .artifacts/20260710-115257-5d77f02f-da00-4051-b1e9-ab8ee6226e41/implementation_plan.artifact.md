# Giriş Kontrolleri ve Bildirim Senkronizasyonu (Revize)

Bu plan, müşteriler uygulamaya girdiğinde randevu bildirimlerinin (uzatma ve gecikme) otomatik olarak kontrol edilmesini, çakışan/arka arkaya gelen randevuların bildirimlerinin iptal edilmesini ve kullanıcıya (Web/Mobil) uygun görsel geri bildirimin verilmesini sağlar.

## Proposed Changes

### Bildirim Servisi

#### [bildirim_servisi.dart](file:///D:/Users/KULLANICI/AndroidStudioProjects/almely_randevu/lib/servisler/bildirim_servisi.dart)

- `girisKontrolleri` metodu eklenecek:
    - Parametre olarak `BuildContext` alacak.
    - İlk aşamada `Hoşgeldiniz Bildirimleriniz gözden geçiriliyor. Lütfen Bekleyiniz.` mesajını gösteren (veya SnackBar ile belirten) bir akış başlatacak.
    - `syncAkilliTakipBildirimleri` metodunu çağıracak.
    - `syncAkilliTakipBildirimleri` sonucuna göre; eğer `ALICI_YOK` hatası dönerse ve cihaz Web ise: `"Hoşgeldiniz Bildirimlerinizin telefonunuza gelebilmesi için Telefonunuzdan giriş yapmalısınız"` uyarısını gösterecek.
- `syncAkilliTakipBildirimleri` metodu güncellenecek:
    - **Karşılıklı Kontrol (Ön ve Arka)**:
        - Müşterinin mevcut randevusunu bul.
        - **Önündeki Randevu**: Eğer mevcut randevu, önündeki kişinin uzamasını engelliyorsa (aradaki süre `minimumRandevuSuresi`'nden azsa), önündeki randevunun `uzatmaBildirimId`'sini OneSignal'den iptal et.
        - **Arkasındaki Randevu**: Eğer müşterinin arkasında başka bir randevu varsa ve bu randevu müşterinin uzamasını engelliyorsa, müşterinin kendi `uzatmaBildirimId`'sini iptal et.
    - Web üzerinde `ALICI_YOK` durumunu bir hata kodu olarak döndürecek.

---

### UI Bileşenleri

#### [ana_ekran.dart](file:///D:/Users/KULLANICI/AndroidStudioProjects/almely_randevu/lib/ekranlar/ana_ekran.dart)

- `initState` içinde `BildirimServisi.girisKontrolleri(widget.kullaniciTel!, context)` çağrılacak.
- Mesajların ön planda görünmesi için `ScaffoldMessenger` veya `showDialog` mekanizması kullanılacak.

---

## Verification Plan

### Manual Verification
1. **Mobil Giriş**:
   - Uygulamayı aç.
   - SnackBar veya Dialog'da "Hoşgeldiniz Bildirimleriniz gözden geçiriliyor..." mesajını gör.
   - Bildirimler başarıyla senkronize edildiğinde "Bildirimleriniz oluştu ✅" mesajını teyit et.
2. **Web Giriş (Telefon Kaydı Yok)**:
   - Web'den gir.
   - Eğer telefon OneSignal'e hiç kaydedilmemişse (`ALICI_YOK` durumu): `"Hoşgeldiniz Bildirimlerinizin telefonunuza gelebilmesi için Telefonunuzdan giriş yapmalısınız"` uyarısını ön planda gör.
3. **Randevu Çakışma Senaryosu (Önündeki Randevu)**:
   - A kullanıcısı (Öndeki) 10:00 - 10:30 randevusu olsun.
   - B kullanıcısı (Yeni) 10:35'e randevu alsın.
   - B kullanıcısı giriş yaptığında; A'nın 10:25'te (5 dk önce) alması gereken uzatma bildiriminin OneSignal'den iptal edildiğini loglardan/panelden doğrula.
