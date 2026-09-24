# Araç Kiralama ayrımı — yedekler

**Tarih:** 2026-09-24

Paylaşılan ekranlardan Araç Kiralama dalları ayrılmadan önceki kopyalar.
`.bak` uzantılıdır; çalıştırılmaz (analyzer’a takılmasın diye).

## Dosyalar

| Yedek | Kaynak |
|---|---|
| `randevu_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/randevu_ekrani.dart` |
| `musteri_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/musteri_ekrani.dart` |
| `esnaf_paneli_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/esnaf_paneli.dart` |
| `esnaf_ajanda_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/esnaf_ajanda_ekrani.dart` |
| `esnaf_parametre_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/esnaf_parametre_ekrani.dart` |
| `kira_teslimat_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak` | `ekranlar/kira_teslimat_ekrani.dart` |

## Geri dönüş örneği

```powershell
Copy-Item `
  "lib\ekranlar\arac_kiralama\yedek\randevu_ekrani_arac_kiralama_kodlu_yedek_20260924.dart.bak" `
  "lib\ekranlar\randevu_ekrani.dart" -Force
```
