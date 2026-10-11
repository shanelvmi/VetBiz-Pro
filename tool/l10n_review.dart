// The Kiswahili review round trip (docs/PHASE2_LOCALISATION_SPEC.md 8):
// export_l10n_review.dart writes docs/kiswahili_review.csv, the owner edits
// it in Excel, import_l10n_review.dart reads it back into app_sw.arb.
import 'l10n_arb.dart';

const reviewCsvPath = 'docs/kiswahili_review.csv';

/// Status words that mean "approved as it stands".
const _approved = {'reviewed', 'ok', 'approved', 'done', 'sawa'};

/// One CSV row per English key. The notes are the owner's own, if any,
/// otherwise where the text appears.
List<List<String>> reviewRows(Arb en, Arb sw) => [
      reviewColumns,
      for (final k in en.values.keys)
        [
          k,
          en.values[k]!,
          sw.values[k] ?? '',
          (sw.meta[k]?['x-notes'] as String?) ?? (en.meta[k]?['description'] as String?) ?? '',
          sw.reviewOf(k),
        ],
    ];

bool hasReviewHeader(List<List<String>> csv) =>
    csv.isNotEmpty && csv.first.map((s) => s.trim().toLowerCase()).join(',') == reviewColumns.join(',');

class ReviewResult {
  final List<String> reviewed = [];
  final List<String> warnings = [];
}

/// Applies the owner's edited [csv] to [sw]. A row is reviewed when its
/// status says so, or when its Kiswahili text was changed. A reviewed entry
/// is never turned back into a draft, and an empty cell never blanks one.
ReviewResult applyReview(Arb en, Arb sw, List<List<String>> csv) {
  final result = ReviewResult();
  if (!hasReviewHeader(csv)) {
    result.warnings.add('The first row must be: ${reviewColumns.join(', ')}. Nothing was changed.');
    return result;
  }
  for (final row in csv.skip(1)) {
    final cells = [...row, ...List.filled(reviewColumns.length, '')];
    final key = cells[0].trim();
    final text = cells[2].trim();
    final notes = cells[3].trim();
    final status = cells[4].trim().toLowerCase();
    if (!en.values.containsKey(key)) {
      result.warnings.add('$key: no such key in app_en.arb, row skipped.');
      continue;
    }
    if (text.isEmpty) {
      result.warnings.add('$key: Kiswahili cell is empty, row skipped.');
      continue;
    }
    final changed = text != sw.values[key];
    if (!changed && !_approved.contains(status)) {
      _keepNotes(en, sw, key, notes);
      continue;
    }
    final problem = argumentProblem(en, key, text);
    if (problem != null) {
      result.warnings.add('$key: $problem. Row skipped.');
      continue;
    }
    sw.values[key] = text;
    sw.meta.putIfAbsent(key, () => {})['x-review'] = 'reviewed';
    _keepNotes(en, sw, key, notes);
    result.reviewed.add(key);
  }
  return result;
}

// The owner's own note is kept in app_sw.arb; the context description
// that export fills in is not copied.
void _keepNotes(Arb en, Arb sw, String key, String notes) {
  final m = sw.meta.putIfAbsent(key, () => {});
  if (notes.isEmpty || notes == en.meta[key]?['description']) {
    m.remove('x-notes');
  } else {
    m['x-notes'] = notes;
  }
}

/// Keys whose row in [csv] would change [sw] if imported: owner edits not
/// read back yet. Export refuses to overwrite a file that has any.
List<String> pendingEdits(Arb en, Arb sw, List<List<String>> csv) {
  // A file Excel has mangled can't be checked, so it isn't overwritten either.
  if (!hasReviewHeader(csv)) return ['(the first row is not the review header)'];
  final copy = Arb(sw.locale, Map.of(sw.values), {for (final e in sw.meta.entries) e.key: Map.of(e.value)});
  final result = applyReview(en, copy, csv);
  final notesChanged = [
    for (final k in en.values.keys)
      if (copy.meta[k]?['x-notes'] != sw.meta[k]?['x-notes']) k,
  ];
  return {...result.reviewed.where((k) => sw.reviewOf(k) != 'reviewed' || copy.values[k] != sw.values[k]), ...notesChanged}
      .toList();
}
