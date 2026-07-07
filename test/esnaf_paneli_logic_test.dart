import 'package:flutter_test/flutter_test.dart';

void main() {
  bool shouldShowRental({
    required DateTime rBit,
    required String durum,
    required DateTime simdi,
    required bool gecmisKiraHareketleriGosterilsin,
    required bool teslimAlinmayanlarGosterilsin,
  }) {
    bool gecmisMi = rBit.isBefore(simdi) || durum == 'Tamamlandı' || durum == 'İptal Edildi' || durum == 'Reddedildi';
    bool teslimAlinmadi = durum == 'Onaylandı' && rBit.isBefore(simdi);

    if (teslimAlinmayanlarGosterilsin) {
      return teslimAlinmadi;
    }

    if (gecmisKiraHareketleriGosterilsin) {
      return gecmisMi;
    } else {
      return !gecmisMi;
    }
  }

  group('Esnaf Paneli Filtering Logic', () {
    final simdi = DateTime(2026, 7, 6, 14, 0); // 14:00

    test('Should show late unreceived rental when filter is active', () {
      final rBit = DateTime(2026, 7, 6, 13, 0); // Past
      final res = shouldShowRental(
        rBit: rBit,
        durum: 'Onaylandı',
        simdi: simdi,
        gecmisKiraHareketleriGosterilsin: false,
        teslimAlinmayanlarGosterilsin: true,
      );
      expect(res, isTrue);
    });

    test('Should NOT show finished rental when "unreceived" filter is active', () {
      final rBit = DateTime(2026, 7, 6, 13, 0); // Past
      final res = shouldShowRental(
        rBit: rBit,
        durum: 'Tamamlandı',
        simdi: simdi,
        gecmisKiraHareketleriGosterilsin: false,
        teslimAlinmayanlarGosterilsin: true,
      );
      expect(res, isFalse);
    });

    test('Should show future rental when no filters active', () {
      final rBit = DateTime(2026, 7, 6, 15, 0); // Future
      final res = shouldShowRental(
        rBit: rBit,
        durum: 'Onaylandı',
        simdi: simdi,
        gecmisKiraHareketleriGosterilsin: false,
        teslimAlinmayanlarGosterilsin: false,
      );
      expect(res, isTrue);
    });

    test('Should NOT show late rental when no filters active (it is past)', () {
      final rBit = DateTime(2026, 7, 6, 13, 0); // Past
      final res = shouldShowRental(
        rBit: rBit,
        durum: 'Onaylandı',
        simdi: simdi,
        gecmisKiraHareketleriGosterilsin: false,
        teslimAlinmayanlarGosterilsin: false,
      );
      expect(res, isFalse);
    });

    test('Should show late rental when "past" filter is active', () {
      final rBit = DateTime(2026, 7, 6, 13, 0); // Past
      final res = shouldShowRental(
        rBit: rBit,
        durum: 'Onaylandı',
        simdi: simdi,
        gecmisKiraHareketleriGosterilsin: true,
        teslimAlinmayanlarGosterilsin: false,
      );
      expect(res, isTrue);
    });
  });
}
