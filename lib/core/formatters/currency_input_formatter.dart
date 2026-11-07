import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatter for live currency input fields (Indonesian Rupiah style: 1.000.000).
/// Automatically inserts dots as thousands separators as the user types,
/// and maintains cursor position cleanly.
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Strip everything that isn't a digit
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(cleanDigits);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number).trim();

    // Determine how many digits were before the cursor in newValue
    int digitsBeforeCursor = 0;
    final selectionEnd = newValue.selection.end.clamp(0, newValue.text.length);
    for (int i = 0; i < selectionEnd; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // Find the offset in formatted string corresponding to same number of digits
    int newCursorOffset = 0;
    int digitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorOffset = i + 1;
        break;
      }
    }

    if (digitsBeforeCursor == 0) {
      newCursorOffset = 0;
    } else if (newCursorOffset == 0 || newCursorOffset > formatted.length) {
      newCursorOffset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }

  /// Parses dot-formatted string (e.g. "2.500.000") or raw numeric string to double.
  static double parse(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Parses dot-formatted string to integer.
  static int parseInt(String text) {
    final clean = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(clean) ?? 0;
  }

  /// Formats a number into a clean dot-separated string without "Rp" prefix (e.g. 2500000 -> "2.500.000").
  static String format(num value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    return formatter.format(value.round()).trim();
  }
}

