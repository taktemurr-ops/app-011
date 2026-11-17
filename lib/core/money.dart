import 'package:intl/intl.dart';

const currencies = <String>['TRY', 'USD', 'EUR'];
const maxMinor = 100000000000;

/// Converts localized input to integer minor units without binary float parsing.
/// Accepts Arabic and Persian digits and Arabic decimal/grouping symbols.
int? parseMinor(String input, {String locale = 'tr'}) {
  if (input.isEmpty || input.length > 40) return null;
  final normalized = StringBuffer();
  for (final rune in input.trim().runes) {
    if (rune >= 48 && rune <= 57) {
      normalized.writeCharCode(rune);
    } else if (rune >= 0x660 && rune <= 0x669) {
      normalized.writeCharCode(rune - 0x660 + 48);
    } else if (rune >= 0x6f0 && rune <= 0x6f9) {
      normalized.writeCharCode(rune - 0x6f0 + 48);
    } else if (rune == 0x66b) {
      normalized.write('.');
    } else if (rune == 0x66c) {
      normalized.write(',');
    } else if (rune == 44 || rune == 46) {
      normalized.writeCharCode(rune);
    } else if (rune == 32 || rune == 0xa0 || rune == 0x202f) {
      normalized.write(' ');
    } else {
      return null;
    }
  }
  final text = normalized.toString();
  if (text.isEmpty || text.startsWith(' ') || text.endsWith(' ') || text.contains('  ')) return null;
  final separators = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '.' || text[i] == ',') separators.add(i);
  }
  int? decimal;
  if (separators.isNotEmpty) {
    final last = separators.last;
    final count = text.length - last - 1;
    if (count >= 1 && count <= 2) decimal = last;
  }
  var integer = decimal == null ? text : text.substring(0, decimal);
  final fraction = decimal == null ? '' : text.substring(decimal + 1);
  if (!RegExp(r'^\d{0,2}$').hasMatch(fraction)) return null;
  if (RegExp(r'[,\. ]').hasMatch(integer)) {
    if (!RegExp(r'^\d{1,3}([,\. ]\d{3})+$').hasMatch(integer)) return null;
    integer = integer.replaceAll(RegExp(r'[,\. ]'), '');
  }
  if (!RegExp(r'^\d{1,11}$').hasMatch(integer)) return null;
  final major = int.tryParse(integer);
  if (major == null) return null;
  final amount = major * 100 + (fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0')));
  if (amount < 1 || amount > maxMinor) return null;
  return amount;
}

String money(int minor, String currency, String locale) =>
  NumberFormat.currency(locale: locale, name: currency, decimalDigits: 2).format(minor / 100);

/// Positive amount saved per period. Returns null when impossible/invalid.
int? monthlyNeeded(int remainingMinor, DateTime deadline, DateTime today) {
  if (remainingMinor <= 0) return 0;
  if (deadline.isBefore(DateTime(today.year, today.month, today.day))) return null;
  final months = (deadline.year - today.year) * 12 + deadline.month - today.month + 1;
  if (months <= 0) return null;
  return (remainingMinor + months - 1) ~/ months;
}

/// Local forecast, not a guarantee. Does not include interest or inflation.
DateTime? projectedFinish(int remainingMinor, int contributionMinor, DateTime start) {
  if (remainingMinor <= 0) return DateTime(start.year, start.month);
  if (contributionMinor <= 0) return null;
  final periods = (remainingMinor + contributionMinor - 1) ~/ contributionMinor;
  if (periods > 1200) return null;
  return DateTime(start.year, start.month + periods);
}
