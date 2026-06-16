import 'package:intl/intl.dart';

class AppFormatters {
  static String currency(double value, {String symbol = 'NGN'}) {
    final format = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return format.format(value);
  }

  static String compactDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}
