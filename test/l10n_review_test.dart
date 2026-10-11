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

  test('placeholders and plural arguments are compared by name', () {
    final e = Arb('en', {'k': '{count, plural, =1{1 item} other{{count} items}}'}, {
      'k': {'description': 'd', 'placeholders': {'count': {'type': 'int'}}},
    });
    expect(argumentProblem(e, 'k', '{count, plural, =1{Kitu 1} other{Vitu {count}}}'), isNull);
    expect(argumentProblem(e, 'k', 'Vitu {count}'), contains('plural'));
  });
}
