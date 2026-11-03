// PH7b R9 (docs/design/phone_reports.md): View Reports on a phone. The title
// only and one menu holding today's Quick Actions, the tabs filling the
// page, today's action pinned at the bottom, Accountability and
// Declaration under the Summary, and the PH5a error state with Retry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

Future<Ph5App> _view(WidgetTester tester, {String? status = 'submitted', bool admin = true, CountingFirestore? firestore}) =>
    pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
        pushed: true,
        admin: admin,
        firestore: firestore,
        seed: status == null ? null : (fs) => ph7bSeedReport(fs, ph7bReport(status: status)));

Future<List<String>> _menu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show menu'));
  await ph5Settle(tester);
  final items = [
    for (final e in find.descendant(of: find.byType(PopupMenuItem<int>), matching: find.byType(Text)).evaluate())
      (e.widget as Text).data!,
  ];
  return items;
}

FilledButton _primary(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('formActionBar-primary')));

void main() {
  ph5TestWidgets('a submitted report: the title only, the menu, the tabs filling the page, the Submitted state pinned', (tester) async {
    await _view(tester);
    expect(find.text('View Reports'), findsOneWidget);
    expect(find.text('Daily closing report for this facility'), findsNothing, reason: 'no subtitle');
    expect(tester.getSize(find.byType(TabBarView)).height, greaterThan(500), reason: 'not the 500 px box of the narrow branch');
    expect(find.descendant(of: find.byKey(const ValueKey('formActionBar')), matching: find.text('Today\'s Report - Submitted')),
        findsOneWidget);
    expect(_primary(tester).onPressed, isNull);
    expect(await _menu(tester), ['Past Reports', 'View Full Report', 'Download PDF']);
  }, skip: _skip);

  ph5TestWidgets('an admin\'s draft: Delete Draft in the menu; Continue Closing opens Review', (tester) async {
    await _view(tester, status: 'draft');
    expect(await _menu(tester), ['Past Reports', 'View Full Report', 'Download PDF', 'Delete Draft']);
    await tester.tapAt(const Offset(5, 5));
    await ph5Settle(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('formActionBar')), matching: find.text('Continue Closing')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('formActionBar-primary')));
    await ph5Settle(tester);
    expect(find.byType(ReportReviewScreen), findsOneWidget);
    // Review's own phone layout is ph7b_review_phone_test.dart's.
    while (tester.takeException() != null) {}
  }, skip: _skip);

  ph5TestWidgets('an assistant: Share with Admin in the menu, no Delete Draft', (tester) async {
    await _view(tester, status: 'draft', admin: false);
    expect(await _menu(tester), ['Past Reports', 'View Full Report', 'Download PDF', 'Share with Admin']);
  }, skip: _skip);

  ph5TestWidgets('Past Reports in the menu opens it', (tester) async {
    await _view(tester);
    await _menu(tester);
    await tester.tap(find.text('Past Reports'));
    await ph5Settle(tester);
    expect(find.byType(PastReportsScreen), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('Accountability and Declaration sit under the Summary\'s figures', (tester) async {
    await _view(tester);
    for (final t in ['Accountability', 'Daily Closing Declaration']) {
      await tester.scrollUntilVisible(find.text(t), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Asha Mohamed'), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('no report yet: today\'s empty texts, the generate action pinned', (tester) async {
    await _view(tester, status: null);
    expect(find.text('No report generated yet today'), findsOneWidget);
    expect(find.byKey(const ValueKey('formActionBar')), findsOneWidget);
    expect(find.byType(TabBarView), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('a failed load shows the error with Retry (not the empty state)', (tester) async {
    final db = CountingFirestore()..failDocGets = true;
    await tester.runAsync(() => ph7bSeedReport(db.inner, ph7bReport()));
    await _view(tester, status: null, firestore: db);
    expect(find.byKey(const ValueKey('viewReports-error')), findsOneWidget);
    expect(find.text('No report generated yet today'), findsNothing);
    db.failDocGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(find.byType(TabBarView), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('R12: a phone opens with the computer\'s reads (one get of today\'s report), no listener', (tester) async {
    final counts = <String, (int, int, int)>{};
    for (final size in const [Size(1200, 800), Size(390, 844)]) {
      final db = CountingFirestore();
      await tester.runAsync(() => ph7bSeedReport(db.inner, ph7bReport()));
      await pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
          size: size, pushed: true, firestore: db);
      ph7bDropWideFontErrors(tester);
      counts['${size.width.toInt()}'] = (db.listeners, db.gets, db.reads);
      await tester.pumpWidget(const SizedBox());
    }
    // ignore: avoid_print
    print('PH7b View Reports cold open (listeners, gets, reads): computer ${counts['1200']}, phone ${counts['390']}');
    expect(counts['390'], counts['1200']);
  }, skip: _skip);
}
