import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Format money as "Rp35.000"
  static String format(num amount) {
    return _idrFormat.format(amount).replaceAll(' ', '');
  }

  /// Format money without symbol, e.g. "35.000"
  static String formatWithoutSymbol(num amount) {
    return _idrFormat.format(amount).replaceAll('Rp', '').trim();
  }

  /// Format money with explicit +/- sign, e.g. "+Rp8.000.000" or "-Rp35.000"
  static String formatSigned(num amount, {required bool isIncome}) {
    final absFormatted = format(amount.abs());
    return isIncome ? '+$absFormatted' : '-$absFormatted';
  }

  /// Format compact money, e.g. "Rp9,6 jt" or "Rp24 jt"
  static String formatCompact(num amount) {
    if (amount >= 1000000000) {
      final val = amount / 1000000000;
      final formatted = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1).replaceAll('.', ',');
      return 'Rp$formatted M';
    } else if (amount >= 1000000) {
      final val = amount / 1000000;
      final formatted = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1).replaceAll('.', ',');
      return 'Rp$formatted jt';
    } else if (amount >= 1000) {
      final val = amount / 1000;
      final formatted = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1).replaceAll('.', ',');
      return 'Rp$formatted rb';
    }
    return format(amount);
  }
}
