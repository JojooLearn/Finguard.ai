import 'package:flutter_test/flutter_test.dart';
import 'package:finguard/core/formatters/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats standard IDR amounts without spaces', () {
      expect(CurrencyFormatter.format(35000), 'Rp35.000');
      expect(CurrencyFormatter.format(8000000), 'Rp8.000.000');
      expect(CurrencyFormatter.format(0), 'Rp0');
    });

    test('formats signed amounts for income and expense', () {
      expect(CurrencyFormatter.formatSigned(8000000, isIncome: true), '+Rp8.000.000');
      expect(CurrencyFormatter.formatSigned(35000, isIncome: false), '-Rp35.000');
    });

    test('formats compact representations correctly', () {
      expect(CurrencyFormatter.formatCompact(9600000), 'Rp9,6 jt');
      expect(CurrencyFormatter.formatCompact(24000000), 'Rp24 jt');
      expect(CurrencyFormatter.formatCompact(1500000000), 'Rp1,5 M');
    });
  });
}
