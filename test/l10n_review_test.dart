import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_arb.dart';
import '../tool/l10n_review.dart';

/// The Kiswahili review round trip: export, the owner's edits in Excel,
/// import (tool/export_l10n_review.dart, tool/import_l10n_review.dart).
void main() {
  Arb en() => Arb('en', {'a_save': 'Save', 'a_sold': 'Sold {count} to {name}'}, {
        'a_save': {'description': 'Save button.'},
        'a_sold': {
          'description': 'Sale line.',
          'placeholders': {'count': {'type': 'int'}, 'name': {'type': 'String'}},
        },
      });
  Arb sw() => Arb('sw', {'a_save': 'Hifadhi', 'a_sold': 'Umeuza {count} kwa {name}'}, {
        'a_save': {'x-review': 'draft'},
        'a_sold': {'x-review': 'draft'},
      });
  List<List<String>> edited(List<List<String>> rows) => [reviewColumns, ...rows];

  test('CSV survives commas, quotes, line breaks and Kiswahili, as Excel saves it', () {
    final rows = [
      reviewColumns,
      ['k', 'Say "hi", then go', 'Sema "habari",\nkisha uende', ' lead', 'draft'],
    ];
    expect(parseCsv(toCsv(rows)), rows);
    // Excel in some regions saves with ';' and without a BOM.
    expect(parseCsv('key;english;kiswahili;notes;status\r\nk;a;b;;draft\r\n')[1], ['k', 'a', 'b', '', 'draft']);
  });

  test('export writes LF line ends and keeps the BOM', () {
    final csv = toCsv([reviewColumns, ['k', 'a', 'mstari\nmwingine', '', 'draft']]);
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv.contains('\r'), isFalse);
  });

  test('import reads a CRLF file (Excel) and an LF file the same, line breaks in cells included', () {
    final lf = toCsv(edited([['a_save', 'Save', 'Hifadhi\nsasa', 'Save button.', 'draft']]));
    final crlf = lf.replaceAll('\n', '\r\n');
    expect(parseCsv(crlf), parseCsv(lf));
    final fromLf = sw();
    final fromCrlf = sw();
    applyReview(en(), fromLf, parseCsv(lf));
    applyReview(en(), fromCrlf, parseCsv(crlf));
    expect(fromCrlf.values, fromLf.values);
    expect(fromCrlf.values['a_save'], 'Hifadhi\nsasa');
  });

  test('export lists every English key, with the context as notes', () {
    final rows = reviewRows(en(), sw());
    expect(rows.first, reviewColumns);
    expect(rows[1], ['a_save', 'Save', 'Hifadhi', 'Save button.', 'draft']);
  });

  test('an edited text, or a reviewed status, is saved and marked reviewed', () {
    final s = sw();
    final r = applyReview(en(), s, edited([
      ['a_save', 'Save', 'Hifadhi sasa', 'Save button.', 'draft'],
      ['a_sold', '', 'Umeuza {count} kwa {name}', 'Sale line.', 'Reviewed'],
    ]));
    expect(r.reviewed, ['a_save', 'a_sold']);
    expect(s.values['a_save'], 'Hifadhi sasa');
    expect(s.reviewOf('a_save'), 'reviewed');
    expect(s.reviewOf('a_sold'), 'reviewed');
    expect(s.meta['a_save']!.containsKey('x-notes'), isFalse, reason: 'the context is not the owner\'s note');
  });

  test("an untouched draft stays draft; the owner's own note is kept", () {
    final s = sw();
    applyReview(en(), s, edited([['a_save', 'Save', 'Hifadhi', 'Use "Weka" instead?', 'draft']]));
    expect(s.reviewOf('a_save'), 'draft');
    expect(s.meta['a_save']!['x-notes'], 'Use "Weka" instead?');
  });

  test('a reviewed entry is never turned back into a draft', () {
    final s = sw()..meta['a_save'] = {'x-review': 'reviewed'};
    applyReview(en(), s, edited([['a_save', 'Save', 'Hifadhi', '', 'draft']]));
    expect(s.reviewOf('a_save'), 'reviewed');
  });

  test('empty cells, unknown keys, broken placeholders and a bad header change nothing', () {
    final s = sw();
    final r = applyReview(en(), s, edited([
      ['a_save', 'Save', '', '', 'reviewed'],
      ['nope', 'x', 'y', '', 'reviewed'],
      ['a_sold', '', 'Umeuza {idadi} kwa {name}', '', 'reviewed'],
    ]));
    expect(r.reviewed, isEmpty);
    expect(r.warnings, hasLength(3));
    expect(s.values, sw().values);
    expect(applyReview(en(), s, [['wrong', 'header']]).warnings.single, contains('first row'));
  });

  test('export sees edits not imported yet, and leaves the ARB alone while checking', () {
    final s = sw();
    expect(pendingEdits(en(), s, reviewRows(en(), s)), isEmpty);
    final rows = reviewRows(en(), s)..[1][2] = 'Hifadhi sasa';
    expect(pendingEdits(en(), s, rows), ['a_save']);
    expect(s.values['a_save'], 'Hifadhi');
    expect(pendingEdits(en(), s, [['a', 'b']]), isNotEmpty);
  });

  group('export compares the CSV with the snapshot of what it last wrote', () {
    // What export_l10n_review.dart leaves on disk: the CSV and its snapshot.
    ({String csv, String snapshot}) exported(Arb e, Arb s) {
      final rows = reviewRows(e, s);
      return (csv: toCsv(rows), snapshot: encodeSnapshot(snapshotOf(rows)));
    }

    test('an unedited CSV plus a draft changed in the ARB: export goes ahead', () {
      final out = exported(en(), sw());
      final s = sw()..values['a_save'] = 'Hifadhi sasa';
      expect(exportBlockers(en(), s, out.csv, out.snapshot), isEmpty);
      // Comparing with the ARB (no snapshot yet) mistook this for an owner edit.
      expect(exportBlockers(en(), s, out.csv, null), ['a_save']);
    });

    test('an edited CSV: export refuses, whichever column the owner changed', () {
      final out = exported(en(), sw());
      final rows = parseCsv(out.csv);
      expect(exportBlockers(en(), sw(), toCsv(rows..[1][2] = 'Weka'), out.snapshot), ['a_save']);
      final notes = parseCsv(out.csv)..[2][3] = 'Too long?';
      expect(exportBlockers(en(), sw(), toCsv(notes), out.snapshot), ['a_sold']);
      final status = parseCsv(out.csv)..[2][4] = 'reviewed';
      expect(exportBlockers(en(), sw(), toCsv(status), out.snapshot), ['a_sold']);
      expect(exportBlockers(en(), sw(), 'not,the,header\r\n', out.snapshot), isNotEmpty);
    });

    test('a CSV saved by Excel with CRLF and no changed cell is not an edit; a changed cell still is', () {
      final s = sw()..values['a_save'] = 'Hifadhi\nsasa';
      final out = exported(en(), s);
      final crlf = out.csv.replaceAll('\n', '\r\n');
      expect(exportBlockers(en(), s, crlf, out.snapshot), isEmpty);
      expect(exportBlockers(en(), s, crlf.replaceFirst('Umeuza', 'Uliuza'), out.snapshot), ['a_sold']);
    });

    test('import, then export: the imported rows no longer block it', () {
      final out = exported(en(), sw());
      final csv = parseCsv(out.csv)..[1][2] = 'Weka';
      final s = sw();
      final result = applyReview(en(), s, csv);
      final snapshot = encodeSnapshot(snapshotAfterImport(decodeSnapshot(out.snapshot), csv, result));
      expect(exportBlockers(en(), s, toCsv(csv), snapshot), isEmpty);
      expect(reviewRows(en(), s)[1], ['a_save', 'Save', 'Weka', 'Save button.', 'reviewed']);
    });

    test('a row import skipped still blocks export, so the edit is not lost', () {
      final out = exported(en(), sw());
      final csv = parseCsv(out.csv)..[2][2] = 'Umeuza {idadi} kwa {name}';
      final s = sw();
      final result = applyReview(en(), s, csv);
      expect(result.skipped, ['a_sold']);
      final snapshot = encodeSnapshot(snapshotAfterImport(decodeSnapshot(out.snapshot), csv, result));
      expect(exportBlockers(en(), s, toCsv(csv), snapshot), ['a_sold']);
    });
  });

  test('placeholders and plural arguments are compared by name', () {
    final e = Arb('en', {'k': '{count, plural, =1{1 item} other{{count} items}}'}, {
      'k': {'description': 'd', 'placeholders': {'count': {'type': 'int'}}},
    });
    expect(argumentProblem(e, 'k', '{count, plural, =1{Kitu 1} other{Vitu {count}}}'), isNull);
    expect(argumentProblem(e, 'k', 'Vitu {count}'), contains('plural'));
  });
}
