import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatRupiah(
    num amount, {
    bool withSymbol = true,
    int decimalDigits = 0,
  }) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: withSymbol ? 'Rp' : '',
      decimalDigits: decimalDigits,
    );

    return formatter.format(amount);
  }
}
