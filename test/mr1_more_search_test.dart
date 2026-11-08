// MR1, written before the change: Find a feature on the More page (labels and
// English and Kiswahili keywords, partial words, any case, accents ignored;
// only the sections that keep a match; one plain line when nothing matches;
// clear restores all), the keyboard never hiding the results, and four
// icons a row at 360 and 390.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mr1_more.dart';

const _skip = false;

void main() {
  group('Find a feature', () {
    Future<Map<String, List<String>>> search(WidgetTester tester, String query, {String locale = 'en'}) async {
      await mrPump(tester, mrMore(isPlatformAdmin: true), locale: locale);
      await mrType(tester, query);
      return mrDrawn();
    }

    final cases = <String, Map<String, List<String>>>{
      'export': {'app': ['export']},
      'csv': {'app': ['export']},
      'Excel': {'app': ['export']},
      'expo': {'app': ['export']},
      'EXPORT': {'app': ['export']},
      'Éxport': {'app': ['export']},
      // UI1: Team Members is in the profile menu, no longer here.
      'printer': {'app': ['printerSettings']},
      'bluetooth': {'app': ['printerSettings']},
      'plan': {'teamAndBusiness': ['subscription']},
      'renew': {'teamAndBusiness': ['subscription']},
      'opening': {'teamAndBusiness': ['businessHours']},
      // Kiswahili keywords match whatever the app's language.
      'pakua': {'app': ['export']},
      'kifurushi': {'teamAndBusiness': ['subscription']},
    };
    for (final c in cases.entries) {
      testWidgets('"${c.key}" leaves only ${c.value}', (tester) async {
        expect(await search(tester, c.key), c.value);
        expect(find.byKey(mrNoMatch), findsNothing);
      }, skip: _skip);
    }

    testWidgets('in Kiswahili: English and Kiswahili keywords both match', (tester) async {
      expect(await search(tester, 'export', locale: 'sw'), {'app': ['export']});
      await mrType(tester, 'kifurushi');
      expect(mrDrawn(), {'teamAndBusiness': ['subscription']});
    }, skip: _skip);

    testWidgets('no match: one plain line, the query kept; clear restores every section', (tester) async {
      expect(await search(tester, 'zzqx'), isEmpty);
      expect(find.text('No feature matches your search'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(mrSearch)).controller!.text, 'zzqx');
      await tester.tap(find.byKey(mrClear));
      await tester.pump();
      expect(mrDrawn(), {...mrAdminSections, 'platform': ['platformAdmin']});
      expect(find.byKey(mrNoMatch), findsNothing);
      expect(find.byKey(mrClear), findsNothing);
    }, skip: _skip);

    testWidgets('the field is 48 high and rounded, with a search icon and Find a feature', (tester) async {
      await mrPump(tester, mrMore());
      expect(tester.getSize(find.byKey(mrSearch)).height, greaterThanOrEqualTo(48));
      expect(find.descendant(of: find.byKey(mrSearch), matching: find.byIcon(Icons.search)), findsOneWidget);
      expect(find.text('Find a feature'), findsOneWidget);
      await mrType(tester, 'ex');
      expect(tester.getSize(find.byKey(mrClear)).height, greaterThanOrEqualTo(48));
    }, skip: _skip);

    testWidgets('the keyboard (viewInsets 300) never hides the results', (tester) async {
      await mrPump(tester, mrMore());
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await mrType(tester, 'export');
      final r = tester.getRect(mrItem('export'));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(844 - 300));
      // Without a query the sections scroll above the keyboard too.
      await mrType(tester, '');
      final scrollable = tester.getRect(find.byType(Scrollable).first);
      expect(scrollable.bottom, lessThanOrEqualTo(844 - 300));
    }, skip: _skip);
  });

  testWidgets('four icons a row at 360 and 390', (tester) async {
    for (final width in [360.0, 390.0]) {
      await mrPump(tester, mrMore(), size: Size(width, 800));
      final row = mrAdminSections['dailyWork']!;
      final y = tester.getTopLeft(mrItem(row.first)).dy;
      for (final name in row.take(4)) {
        expect(tester.getTopLeft(mrItem(name)).dy, y, reason: '$width $name');
      }
      expect(tester.getTopLeft(mrItem(row[4])).dy, greaterThan(y), reason: '$width');
    }
  }, skip: _skip);
}
