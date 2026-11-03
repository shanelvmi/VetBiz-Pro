// PH7b R9 (docs/design/phone_reports.md): Past Reports on a phone, on the
// PH5a list: search in the bar, the four time filters as quick chips, the
// summary line and sheet, rows under month headers, the same taps, the
// skeleton, empty and error states, Load more; the same two queries.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/models/daily_report.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_detail_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';

import 'helpers/counting_firestore.dart';
import 'helpers/ph5b_finders.dart';
import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

const _skip = false;

/// Three days in March and two in February 2025: one a draft.
final _days = [DateTime(2025, 3, 12), DateTime(2025, 3, 11), DateTime(2025, 3, 10), DateTime(2025, 2, 27), DateTime(2025, 2, 26)];
List<DailyReport> get _reports => [
      for (final d in _days) ph7bReport(day: d, status: d.day == 11 ? 'draft' : 'submitted'),
    ];

Future<Ph5App> _past(WidgetTester tester,
        {List<DailyReport>? reports, CountingFirestore? firestore, bool settle = true, Size size = const Size(390, 844)}) =>
    pumpPh5(tester, (fs) => PastReportsScreen(firestore: fs),
        size: size,
        pushed: true, firestore: firestore, settle: settle, seed: (fs) async {
      for (final r in reports ?? _reports) {
        await ph7bSeedReport(fs, r);
      }
    });

void main() {
  ph5TestWidgets('the bar: the title, search and back; the time filters as chips; no Filter button', (tester) async {
    await _past(tester);
    expect(find.text('Past Reports'), findsOneWidget);
    expect(find.text('Every daily closing report for this facility'), findsNothing, reason: 'no subtitle');
    expect(find.byTooltip('Search'), findsOneWidget);
    for (final chip in ['All time', 'Last 7 days', 'This month', 'This year']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
    }
    expect(find.byTooltip('Filter'), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('rows under month headers: the date and the revenue, who generated it, Completed or Not submitted', (tester) async {
    await _past(tester);
    expect(ph5RowIds(tester).toList(), [for (final d in _days) ph7bReportId(d)]);
    expect(find.text('March 2025'), findsOneWidget);
    expect(find.text('February 2025'), findsOneWidget);
    final row = ph5Key('phoneList-row-${ph7bReportId(_days.first)}');
    final texts = ph5Texts(row);
    final r = _reports.first;
    expect(texts, containsAll(['Wednesday, 12 Mar 2025', Money.format(r.salesTotalValue + r.servicesTotalValue), 'Asha Mohamed', 'Completed']));
    expect(ph5Texts(ph5Key('phoneList-row-${ph7bReportId(_days[1])}')), contains('Not submitted'));
  }, skip: _skip);

  ph5TestWidgets('a submitted report opens its detail; a draft opens Review', (tester) async {
    await _past(tester);
    await tester.tap(ph5Key('phoneList-row-${ph7bReportId(_days.first)}'));
    await ph5Settle(tester);
    expect(find.byType(ReportDetailScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await ph5Settle(tester);
    await tester.tap(ph5Key('phoneList-row-${ph7bReportId(_days[1])}'));
    await ph5Settle(tester);
    expect(find.byType(ReportReviewScreen), findsOneWidget);
  }, skip: _skip);

  ph5TestWidgets('the summary line and its sheet: the three old cards', (tester) async {
    await _past(tester);
    expect(find.text('5 reports'), findsOneWidget);
    await tester.tap(ph5Key('phoneList-summaryLink'));
    await ph5Settle(tester);
    for (final t in ['Reports generated', 'Loaded period', 'Latest', 'Feb 2025 - Mar 2025', '12 Mar 2025']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  }, skip: _skip);

  ph5TestWidgets('search filters the loaded rows by date or name, as the tablet\'s field', (tester) async {
    await _past(tester);
    await tester.tap(find.byTooltip('Search'));
    await ph5Settle(tester);
    await tester.enterText(find.byKey(const ValueKey('phoneList-searchField')), 'feb');
    await ph5Settle(tester);
    expect(ph5RowIds(tester).toList(), [ph7bReportId(_days[3]), ph7bReportId(_days[4])]);
  }, skip: _skip);

  ph5TestWidgets('a chip reloads with today\'s queries (the page and the count)', (tester) async {
    final db = CountingFirestore();
    await tester.runAsync(() async {
      for (final r in _reports) {
        await ph7bSeedReport(db.inner, r);
      }
    });
    await _past(tester, firestore: db, reports: const []);
    db.resetCounts();
    final chip = find.widgetWithText(ChoiceChip, 'This year');
    await tester.ensureVisible(chip);
    await tester.pump();
    db.resetCounts();
    await tester.tap(chip);
    await ph5Settle(tester);
    expect(db.gets, 2, reason: 'one page and one count, as the tablet\'s dropdown');
    expect(ph5RowIds(tester), isEmpty, reason: 'nothing this year');
  }, skip: _skip);

  ph5TestWidgets('states: the skeleton, then the rows; empty; the error with Retry', (tester) async {
    final held = CountingFirestore()..holdGets = Completer<void>();
    await tester.runAsync(() => ph7bSeedReport(held.inner, _reports.first));
    await _past(tester, firestore: held, reports: const [], settle: false);
    await tester.pump();
    expect(ph5Key('phoneList-skeleton'), findsOneWidget);
    held.holdGets!.complete();
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(1));

    await _past(tester, reports: const []);
    expect(ph5Key('phoneList-empty'), findsOneWidget);
    expect(find.text('No reports generated yet.'), findsOneWidget);

    final failing = CountingFirestore()..failGets = true;
    await tester.runAsync(() => ph7bSeedReport(failing.inner, _reports.first));
    await _past(tester, firestore: failing, reports: const []);
    expect(ph5Key('phoneList-error'), findsOneWidget);
    failing.failGets = false;
    await tester.tap(find.text('Retry'));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(1));
  }, skip: _skip);

  ph5TestWidgets('paging: 25 rows, the next page near the end, Load more as the fallback', (tester) async {
    final many = [for (var i = 0; i < 30; i++) ph7bReport(day: DateTime(2025, 1, 31).subtract(Duration(days: i)))];
    // Tall enough to build every row reached.
    await _past(tester, reports: many, size: const Size(390, 4000));
    expect(ph5RowIds(tester), hasLength(25));
    await tester.tap(find.descendant(of: ph5Key('phoneList-loadMore'), matching: find.byType(OutlinedButton)));
    await ph5Settle(tester);
    expect(ph5RowIds(tester), hasLength(30));
  }, skip: _skip);
}
