import 'package:flutter/services.dart';

/// Actively capitalizes the first letter of each sentence as the person
/// types, rather than just hinting the on-screen keyboard to do it.
///
/// `TextCapitalization.sentences` alone only tells a virtual (on-screen)
/// keyboard to auto-engage Shift at the start of a sentence - it has no
/// effect on a physical keyboard, since there's no virtual Shift key for
/// Flutter to press. That means on desktop/web, where most people type
/// with a real keyboard, `TextCapitalization.sentences` alone does
/// nothing at all. This formatter rewrites the text itself, so it works
/// the same way regardless of what kind of keyboard produced it.
///
/// Capitalizes: the very first letter of the field, and the first
/// letter after a `.`, `!`, `?`, or newline (skipping over any
/// whitespace in between). Never touches letters anywhere else - a
/// deliberately lowercase word mid-sentence stays exactly as typed.
///
/// Apply to a TextFormField/TextField alongside the existing
/// TextCapitalization.sentences (kept for virtual-keyboard behavior)
/// via:
///   textCapitalization: TextCapitalization.sentences,
///   inputFormatters: [SentenceCapitalizationFormatter()],
class SentenceCapitalizationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final isLowerLetter = char.toLowerCase() == char && char.toUpperCase() != char;

      if (capitalizeNext && isLowerLetter) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        if (char == '.' || char == '!' || char == '?' || char == '\n') {
          capitalizeNext = true;
        } else if (char != ' ' && char != '\t') {
          // Any other non-whitespace character marks mid-sentence -
          // stop looking to capitalize until the next sentence starts.
          // Whitespace itself doesn't cancel a pending capitalization,
          // since a sentence can start after any amount of it.
          capitalizeNext = false;
        }
      }
    }

    final newText = buffer.toString();
    // Case changes never change the string's length, so the cursor's
    // numeric position is still valid without any adjustment.
    return newValue.copyWith(text: newText);
  }
}
