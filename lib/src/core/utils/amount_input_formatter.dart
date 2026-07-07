import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.maxDecimalPlaces});

  final int? maxDecimalPlaces;

  static final NumberFormat _wholeNumberFormat = NumberFormat('#,##0', 'en_US');

  static String normalize(String value) {
    return value.replaceAll(',', '').trim();
  }

  static String formatValue(num value) {
    return formatRaw(value.toString());
  }

  static String formatRaw(String raw) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) {
      return '';
    }

    final parts = normalized.split('.');
    final integerDigits = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final sanitizedInteger = integerDigits.isEmpty ? '0' : integerDigits;
    final formattedInteger = _wholeNumberFormat.format(
      int.parse(sanitizedInteger),
    );

    if (parts.length == 1) {
      return formattedInteger;
    }

    final fractionDigits = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
    return '$formattedInteger.$fractionDigits';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalize(newValue.text);
    if (normalized.isEmpty) {
      return const TextEditingValue(text: '');
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(normalized)) {
      return oldValue;
    }

    final parts = normalized.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    if (maxDecimalPlaces != null &&
        parts.length == 2 &&
        parts[1].length > maxDecimalPlaces!) {
      return oldValue;
    }

    final formatted = formatRaw(normalized);
    final targetCursor = _mapCursorPosition(
      formattedText: formatted,
      digitsBeforeCursor: _countSignificantCharacters(
        newValue.text.substring(
          0,
          newValue.selection.end.clamp(0, newValue.text.length),
        ),
      ),
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: targetCursor),
    );
  }

  int _countSignificantCharacters(String value) {
    return normalize(value).length;
  }

  int _mapCursorPosition({
    required String formattedText,
    required int digitsBeforeCursor,
  }) {
    if (digitsBeforeCursor <= 0) {
      return 0;
    }

    var significantCount = 0;
    for (var index = 0; index < formattedText.length; index++) {
      if (formattedText[index] != ',') {
        significantCount++;
      }
      if (significantCount >= digitsBeforeCursor) {
        return index + 1;
      }
    }
    return formattedText.length;
  }
}
