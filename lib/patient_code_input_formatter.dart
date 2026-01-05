import 'package:flutter/services.dart';

class PatientCodeInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 6;
  static const int _groupSize = 3;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = _extractDigits(newValue.text);
    final digits = rawDigits.length > _maxDigits
        ? rawDigits.substring(0, _maxDigits)
        : rawDigits;
    final formatted = _format(digits);

    final selection = _mapSelection(
      newValue,
      digits.length,
      formatted.length,
    );

    return TextEditingValue(
      text: formatted,
      selection: selection,
      composing: TextRange.empty,
    );
  }

  String _format(String digits) {
    if (digits.length <= _groupSize) return digits;
    final first = digits.substring(0, _groupSize);
    final rest = digits.substring(_groupSize);
    return '$first $rest';
  }

  String _extractDigits(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final codeUnit = value.codeUnitAt(i);
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  TextSelection _mapSelection(
    TextEditingValue newValue,
    int digitsLength,
    int formattedLength,
  ) {
    final selection = newValue.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: formattedLength);
    }
    final base = _mapOffset(
      newValue.text,
      selection.baseOffset,
      digitsLength,
    );
    final extent = _mapOffset(
      newValue.text,
      selection.extentOffset,
      digitsLength,
    );
    return TextSelection(
      baseOffset: base.clamp(0, formattedLength),
      extentOffset: extent.clamp(0, formattedLength),
    );
  }

  int _mapOffset(String rawText, int offset, int digitsLength) {
    if (offset <= 0) return 0;
    var safeOffset = offset;
    if (safeOffset > rawText.length) {
      safeOffset = rawText.length;
    }
    var digitCount = 0;
    var spaceCount = 0;
    for (var i = 0; i < safeOffset; i++) {
      final codeUnit = rawText.codeUnitAt(i);
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        digitCount++;
      } else if (codeUnit == 0x20) {
        spaceCount++;
      }
    }
    if (digitCount > digitsLength) digitCount = digitsLength;
    final needsSpace = digitsLength > _groupSize;
    final pastSpace = needsSpace &&
        (digitCount > _groupSize ||
            (digitCount == _groupSize && spaceCount > 0));
    return digitCount + (pastSpace ? 1 : 0);
  }
}
