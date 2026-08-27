import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Live thousand-separator formatting for money input fields - typing
/// "5000" displays as "5,000" as each digit is entered, not just after
/// saving. Whole numbers only (no decimal point), since Tsh amounts
/// are handled as whole shillings throughout this app.
///
/// This consolidates what used to be two separate, near-identical
/// copies of this exact class (one in add_sale_screen.dart, one in
/// add_edit_service_screen.dart) into a single shared definition, so
/// future changes only need to happen in one place.
///
/// Apply to a TextFormField via:
///   inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorInputFormatter()]
///
/// Read the underlying numeric value back out with [parseThousands],
/// which strips the commas before parsing - never parse the field's
/// raw text directly, since it contains display-only separators.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('en_US');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Cap at a sane digit length - beyond ~15 digits, int.parse risks
    // overflow and the amount is nonsensical for a real transaction
    // anyway, so further typing is simply ignored rather than crashing.
    if (digitsOnly.length > 15) {
      return oldValue;
    }

    final intValue = int.parse(digitsOnly);
    final newText = _formatter.format(intValue);

    int selectionIndex = newText.length - (oldValue.text.length - oldValue.selection.end);
    if (selectionIndex < 0) selectionIndex = 0;
    if (selectionIndex > newText.length) selectionIndex = newText.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}

/// Strips thousand-separator commas and parses the remaining digits -
/// the counterpart read for any field using
/// [ThousandsSeparatorInputFormatter]. Returns 0 for empty or
/// unparsable input, same fallback already used throughout this app's
/// other amount parsing.
double parseThousands(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return 0;
  return double.tryParse(digitsOnly) ?? 0;
}
