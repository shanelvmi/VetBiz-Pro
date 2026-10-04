/// Decides whether a new (or edited) client looks like one that already
/// exists - used to stop the same person being added twice.
///
/// Deliberately plain functions with no database access, so the rules for
/// "similar" live in one place and are easy to reason about. The database
/// side (finding candidates to compare against) is
/// ClientProvider.findSimilarClient.
class ClientDuplicateMatcher {
  ClientDuplicateMatcher._();

  // ==================== names ====================

  /// Lowercase, punctuation removed, spaces collapsed:
  /// "  Juma   HASSAN. " -> "juma hassan".
  static String normalizeName(String name) {
    final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// The words of a name, normalised: "Juma Hassan" -> [juma, hassan].
  static List<String> nameWords(String name) {
    final n = normalizeName(name);
    return n.isEmpty ? <String>[] : n.split(' ');
  }

  /// Whether two names are, in practice, the same person written twice:
  ///   - identical once case, punctuation and spacing are ignored;
  ///   - the same words in a different order ("Hassan Juma" / "Juma Hassan");
  ///   - or one slipped letter - added, missing or wrong - in a name long
  ///     enough that a typo is likelier than a different person
  ///     ("Juma Hasan" / "Juma Hassan").
  /// Short names (under 5 letters) only match when identical, so "Asha" and
  /// "Aisha" stay separate people.
  static bool areNamesSimilar(String a, String b) {
    final na = normalizeName(a);
    final nb = normalizeName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;

    final sortedA = (nameWords(a)..sort()).join(' ');
    final sortedB = (nameWords(b)..sort()).join(' ');
    if (sortedA == sortedB) return true;

    if (na.length >= 5 && nb.length >= 5 && _withinOneEdit(na, nb)) return true;
    if (sortedA.length >= 5 && sortedB.length >= 5 && _withinOneEdit(sortedA, sortedB)) return true;
    return false;
  }

  /// True if [a] and [b] differ by at most one inserted, deleted or
  /// substituted character.
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return true;
    final lengthDiff = a.length - b.length;
    if (lengthDiff > 1 || lengthDiff < -1) return false;

    final longer = a.length >= b.length ? a : b;
    final shorter = a.length >= b.length ? b : a;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < longer.length && j < shorter.length) {
      if (longer[i] == shorter[j]) {
        i++;
        j++;
        continue;
      }
      edits++;
      if (edits > 1) return false;
      if (longer.length == shorter.length) {
        // A wrong letter: step past it in both.
        i++;
        j++;
      } else {
        // The longer one has an extra letter: step past just that.
        i++;
      }
    }
    // Anything left over at the end of the longer name is one more edit.
    edits += longer.length - i;
    return edits <= 1;
  }

  // ==================== phone numbers ====================

  /// A comparable form of a phone number, or null if it's too short to
  /// compare reliably.
  ///
  /// Tanzanian numbers get written many ways - 0712 345 678, 0712345678,
  /// 255712345678, +255 712 345 678, 00255712345678 - and all of those are
  /// the same number, so they reduce to the same 9 digits (712345678).
  /// Anything that isn't a Tanzanian number keeps its full digits, so a
  /// Kenyan +254 712 345 678 is never mistaken for it.
  static String? phoneKey(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length < 7) return null;
    if (digits.length == 12 && digits.startsWith('255')) return digits.substring(3);
    if (digits.length == 10 && digits.startsWith('0')) return digits.substring(1);
    return digits;
  }

  /// The ways a Tanzanian number is commonly typed, for finding clients
  /// saved BEFORE phoneKey existed (they only have the raw text, which a
  /// database query can match exactly or not at all). Includes the number
  /// exactly as typed. Once the Settings backfill has run, phoneKey covers
  /// every client regardless of format and these are redundant.
  static List<String> phoneVariants(String typed) {
    final out = <String>{typed.trim()};
    final key = phoneKey(typed);
    if (key != null && key.length == 9) {
      final a = key.substring(0, 3);
      final b = key.substring(3, 6);
      final c = key.substring(6);
      out.addAll([
        key,
        '0$key',
        '255$key',
        '+255$key',
        '00255$key',
        '$a $b $c',
        '0$a $b $c',
        '0$a-$b-$c',
        '0$a.$b.$c',
        '255 $a $b $c',
        '+255 $a $b $c',
        '+255-$a-$b-$c',
      ]);
    }
    out.removeWhere((v) => v.isEmpty);
    return out.toList();
  }
}
