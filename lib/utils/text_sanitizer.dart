/// Strips or safely replaces any character outside printable ASCII
/// before it's shown in the UI.
///
/// This app has historical Firestore data (activity log descriptions,
/// mainly) written before emoji were removed from the code that
/// generates them - fixing that code doesn't retroactively clean data
/// already stored, and a free-text field could always pick up
/// something unexpected from a user in the future too. Filtering at
/// the point of display, rather than chasing every possible source,
/// protects against this regardless of where the text came from.
///
/// Common punctuation gets a safe ASCII equivalent rather than just
/// vanishing, so text doesn't look visibly broken; anything else
/// outside printable ASCII is stripped entirely.
String sanitizeForDisplay(String input) {
  final withReplacements = input
      .replaceAll('\u2014', '-') // em dash
      .replaceAll('\u2013', '-') // en dash
      .replaceAll('\u2022', '-') // bullet
      .replaceAll('\u2192', '->') // rightwards arrow
      .replaceAll('\u2026', '...'); // ellipsis
  return withReplacements.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
}
