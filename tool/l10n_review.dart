// The Kiswahili review round trip (docs/PHASE2_LOCALISATION_SPEC.md 8):
// export_l10n_review.dart writes docs/kiswahili_review.csv, the owner edits
// it in Excel, import_l10n_review.dart reads it back into app_sw.arb.
import 'dart:convert';

import 'l10n_arb.dart';

const reviewCsvPath = 'docs/kiswahili_review.csv';

/// What export last wrote (or import last read), so export can tell the
/// owner's edits from drafts changed in app_sw.arb since. Committed.
const reviewSnapshotPath = 'docs/.kiswahili_snapshot.json';

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

  /// Rows not imported (a warning says why): still the owner's to fix.
  final List<String> skipped = [];
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
      result.skipped.add(key);
      result.warnings.add('$key: no such key in app_en.arb, row skipped.');
      continue;
    }
    if (text.isEmpty) {
      result.skipped.add(key);
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
      result.skipped.add(key);
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

// --- Snapshot: what the CSV said when the tools last touched it ---
//
// Export compares the CSV with this, not with app_sw.arb: a draft changed
// in the ARB since the last export is not an owner edit, but a cell the
// owner changed in Excel is.

/// key -> [kiswahili, notes, status] for every row of [csv] after the header.
Map<String, List<String>> snapshotOf(List<List<String>> csv) {
  String cell(List<String> row, int i) => i < row.length ? row[i].trim() : '';
  return {
    for (final row in csv.skip(1))
      if (cell(row, 0).isNotEmpty) cell(row, 0): [cell(row, 2), cell(row, 3), cell(row, 4).toLowerCase()],
  };
}

/// One line per key, so a commit of it shows only the rows that changed.
String encodeSnapshot(Map<String, List<String>> snapshot) =>
    '{\n${snapshot.entries.map((e) => '  ${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(',\n')}\n}\n';

Map<String, List<String>> decodeSnapshot(String text) => {
      for (final e in (jsonDecode(text) as Map<String, dynamic>).entries)
        e.key: (e.value as List).cast<String>(),
    };

/// Keys whose row in [csv] differs from [snapshot]: owner edits not imported
/// yet. A row the owner added (a key the snapshot lacks) counts too.
List<String> editedSince(Map<String, List<String>> snapshot, List<List<String>> csv) {
  if (!hasReviewHeader(csv)) return ['(the first row is not the review header)'];
  final now = snapshotOf(csv);
  return [
    for (final e in now.entries)
      if (snapshot[e.key] == null || snapshot[e.key]!.join('\u0000') != e.value.join('\u0000')) e.key,
  ];
}

/// Why export must not overwrite the CSV: the owner's edits it would lose.
/// With no snapshot yet (the first run), falls back to comparing with the ARB.
List<String> exportBlockers(Arb en, Arb sw, String csvText, String? snapshotText) {
  final csv = parseCsv(csvText);
  if (snapshotText == null) return pendingEdits(en, sw, csv);
  return editedSince(decodeSnapshot(snapshotText), csv);
}

/// The snapshot after importing [csv]: the rows as the owner left them, so
/// export sees them as read back. A skipped row keeps its old snapshot
/// entry, so it still counts as an edit and export still refuses.
Map<String, List<String>> snapshotAfterImport(
    Map<String, List<String>> old, List<List<String>> csv, ReviewResult result) {
  if (!hasReviewHeader(csv)) return old;
  final next = snapshotOf(csv);
  for (final k in result.skipped) {
    final before = old[k];
    if (before == null) {
      next.remove(k);
    } else {
      next[k] = before;
    }
  }
  return next;
}
