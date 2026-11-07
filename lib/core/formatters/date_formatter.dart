import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static const List<String> _shortMonthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Juli', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  /// Format date as "November 2026"
  static String formatMonthYear(DateTime date) {
    final local = date.toLocal();
    try {
      return DateFormat('MMMM yyyy', 'id_ID').format(local);
    } catch (_) {
      return '${_monthNames[local.month - 1]} ${local.year}';
    }
  }

  /// Format date as "6 November 2026"
  static String formatFullDate(DateTime date) {
    final local = date.toLocal();
    try {
      return DateFormat('d MMMM yyyy', 'id_ID').format(local);
    } catch (_) {
      return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
    }
  }

  /// Format date as "6 Nov"
  static String formatShortDayMonth(DateTime date) {
    final local = date.toLocal();
    try {
      return DateFormat('d MMM', 'id_ID').format(local);
    } catch (_) {
      return '${local.day} ${_shortMonthNames[local.month - 1]}';
    }
  }

  /// Format date as "6 Nov 2026"
  static String formatDateWithShortMonth(DateTime date) {
    final local = date.toLocal();
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(local);
    } catch (_) {
      return '${local.day} ${_shortMonthNames[local.month - 1]} ${local.year}';
    }
  }

  /// Format time as "14:25"
  static String formatTime(DateTime date) {
    final local = date.toLocal();
    return DateFormat('HH:mm').format(local);
  }

  /// Format time as "14:25 WIB"
  static String formatTimeWithZone(DateTime date) {
    final local = date.toLocal();
    return '${DateFormat('HH:mm').format(local)} WIB';
  }

  /// Format relative date: "Hari ini", "Kemarin", "Besok", or "6 Nov"
  static String formatRelativeDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);

    final diffDays = today.difference(target).inDays;
    if (diffDays == 0) return 'Hari ini';
    if (diffDays == 1) return 'Kemarin';
    if (diffDays == -1) return 'Besok';

    return formatShortDayMonth(local);
  }

  /// Format relative date and time: "Hari ini, 14:25", "Kemarin, 14:25", or "6 Nov 2026, 14:25"
  static String formatRelativeDateTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final timeStr = formatTime(local);

    final diffDays = today.difference(target).inDays;
    if (diffDays == 0) return 'Hari ini, $timeStr';
    if (diffDays == 1) return 'Kemarin, $timeStr';
    if (diffDays == -1) return 'Besok, $timeStr';

    if (local.year == now.year) {
      return '${formatShortDayMonth(local)}, $timeStr';
    }
    return '${formatDateWithShortMonth(local)}, $timeStr';
  }

  /// Format header for transaction list groups:
  /// e.g. "Hari ini • 6 Nov 2026" or "Kemarin • 5 Nov 2026" or "1 Nov 2026"
  static String formatTransactionDateHeader(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);

    final diffDays = today.difference(target).inDays;
    final dateStr = formatDateWithShortMonth(local);
    if (diffDays == 0) return 'Hari ini • $dateStr';
    if (diffDays == 1) return 'Kemarin • $dateStr';
    return dateStr;
  }
}
