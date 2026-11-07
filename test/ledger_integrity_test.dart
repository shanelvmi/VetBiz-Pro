// LEDGER INTEGRITY: a ledger row must never vanish silently again (the
// PH8a-fix row was lost in ffd3a5d when its status was updated).
// docs/ledger_rows.txt lists the id of every table row of docs/RUNBOOK2.md;
// this test fails, naming the id, when any of them is no longer there. Rows may
// be added (append their ids to the manifest), never removed.
//
// A row's id is the first word of its first cell ("PH8a-fix", "Q1", "D5"):
// the rest of the cell is a description, and the other cells change when a
// row is updated. An id listed twice (PH1: the first audit and the one that
// superseded it) must be found at least twice.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _ledger = 'docs/RUNBOOK2.md';
const _manifest = 'docs/ledger_rows.txt';

final _separator = RegExp(r'^\|[\s|:-]+\|?\s*$');

/// The id of every table row in [markdown], in order, header rows left out.
List<String> ledgerRowIds(String markdown) {
  final lines = markdown.split(RegExp(r'\r?\n'));
  final ids = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('|') || _separator.hasMatch(line)) continue;
    // A header row is the one right above its separator.
    if (i + 1 < lines.length && _separator.hasMatch(lines[i + 1])) continue;
    final cells = line.split('|');
    if (cells.length < 2) continue;
    final first = cells[1].trim();
    if (first.isEmpty) continue;
    ids.add(first.split(RegExp(r'\s+')).first);
  }
  return ids;
}

/// The manifest's ids: one per line, blank lines and # comments ignored.
List<String> manifestIds(String text) => [
      for (final raw in text.split(RegExp(r'\r?\n')))
        if (raw.trim().isNotEmpty && !raw.trim().startsWith('#')) raw.trim(),
    ];

/// Each id the manifest lists more often than [present] holds it.
List<String> missingIds(List<String> manifest, List<String> present) {
  final have = <String, int>{};
  for (final id in present) {
    have[id] = (have[id] ?? 0) + 1;
  }
  final missing = <String>[];
  for (final id in manifest) {
    final left = have[id] ?? 0;
    if (left == 0) {
      missing.add(id);
    } else {
      have[id] = left - 1;
    }
  }
  return missing;
}

void main() {
  test('every row listed in $_manifest is still in $_ledger', () {
    final present = ledgerRowIds(File(_ledger).readAsStringSync());
    final listed = manifestIds(File(_manifest).readAsStringSync());
    expect(listed, isNotEmpty);
    final missing = missingIds(listed, present);
    expect(missing, isEmpty,
        reason: 'Ledger rows missing from $_ledger: ${missing.join(', ')}. '
            'A ledger edit must keep every existing row.');
  });

  test('every row of $_ledger is listed in $_manifest (append new ids)', () {
    final present = ledgerRowIds(File(_ledger).readAsStringSync());
    final listed = manifestIds(File(_manifest).readAsStringSync());
    final unlisted = missingIds(present, listed);
    expect(unlisted, isEmpty, reason: 'Append these ids to $_manifest: ${unlisted.join(', ')}');
  });

  group('the parser', () {
    const sample = '| Batch | Status |\r\n|---|---|\r\n| Q1 (x) | DONE |\n| PH1 a | DONE |\n| PH1 b | DONE |\nText | not a row\n';

    test('takes the first word of each row, headers and separators left out', () {
      expect(ledgerRowIds(sample), ['Q1', 'PH1', 'PH1']);
    });

    test('a removed row is named, a twice-listed id needs both rows', () {
      final without = sample.replaceFirst('| PH1 b | DONE |\n', '');
      expect(missingIds(['Q1', 'PH1', 'PH1'], ledgerRowIds(without)), ['PH1']);
      expect(missingIds(['Q1', 'PH1'], ledgerRowIds(sample.replaceFirst('| Q1 (x) | DONE |\n', ''))), ['Q1']);
    });

    test('an added row is fine for the first check', () {
      expect(missingIds(['Q1'], ledgerRowIds(sample)), isEmpty);
    });
  });
}
