import 'package:flutter_test/flutter_test.dart';
import 'package:almely_randevu/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    // Uygulamayı başlat
    await tester.pumpWidget(const AlmElyApp());

    // Giriş ekranında "Kullanıcı Girişi" yazısını ara
    expect(find.text('Kullanıcı Girişi'), findsOneWidget);
  });
}