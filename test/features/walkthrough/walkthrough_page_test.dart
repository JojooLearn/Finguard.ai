import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/features/walkthrough/presentation/pages/walkthrough_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'WalkthroughPage displays initial slide with correct heading & description',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WalkthroughPage()));
      await tester.pumpAndSettle();

      // Verify Slide 1 Heading & Description
      expect(find.text('Ngobrol Santai Sama AI Coach'), findsOneWidget);
      expect(
        find.textContaining('Catat pengeluaran, cek uang dingin'),
        findsOneWidget,
      );
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    },
  );

  testWidgets(
    'WalkthroughPage can navigate through all 3 slides to Mulai Sekarang',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WalkthroughPage()));
      await tester.pumpAndSettle();

      // Tap Lanjut to Slide 2
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Jatah Belanja Otomatis Beres'), findsOneWidget);
      expect(
        find.textContaining('50/30/20 buatmu dalam hitungan detik'),
        findsOneWidget,
      );

      // Tap Lanjut to Slide 3
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Anti Boncos Sebelum Belanja'), findsOneWidget);
      expect(
        find.textContaining('Lapar mata pengen beli barang mahal?'),
        findsOneWidget,
      );
      expect(find.text('Mulai Sekarang'), findsOneWidget);
    },
  );
}
