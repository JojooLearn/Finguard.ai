import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/core/widgets/metric_card.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  group('MetricCard Widget Tests', () {
    testWidgets('renders info icon by default when infoExplanation is provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              cardTheme: MetricCardTheme.lime,
              icon: Icons.attach_money,
              label: 'Total Pemasukan',
              value: 'Rp1.000.000',
              infoExplanation: 'Penjelasan pemasukan',
            ),
          ),
        ),
      );

      expect(find.byIcon(PhosphorIcons.info(PhosphorIconsStyle.bold)), findsOneWidget);
    });

    testWidgets('hides info icon when showInfoIcon is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              cardTheme: MetricCardTheme.lime,
              icon: Icons.attach_money,
              label: 'Total Pemasukan',
              value: 'Rp1.000.000',
              showInfoIcon: false,
              infoExplanation: 'Penjelasan pemasukan',
            ),
          ),
        ),
      );

      expect(find.byIcon(PhosphorIcons.info(PhosphorIconsStyle.bold)), findsNothing);
      expect(find.text('Total Pemasukan'), findsOneWidget);
      expect(find.text('Rp1.000.000'), findsOneWidget);
    });

    testWidgets('tapping card with infoExplanation triggers explanation sheet',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(
              cardTheme: MetricCardTheme.dark,
              icon: Icons.shopping_bag,
              label: 'Total Pengeluaran',
              value: 'Rp35.000',
              showInfoIcon: false,
              infoExplanation: 'Akumulasi belanja keluar',
            ),
          ),
        ),
      );

      // Tap the card itself
      await tester.tap(find.text('Total Pengeluaran'));
      await tester.pumpAndSettle();

      // Explanation sheet modal should appear
      expect(find.text('Akumulasi belanja keluar'), findsOneWidget);
    });
  });
}

