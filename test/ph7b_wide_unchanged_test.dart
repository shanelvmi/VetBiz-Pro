// PH7b: tablets and computers keep today's reports exactly. At 768x1024,
// 1024x768 and 1200x800 the whole widget tree of each is compared with the
// fingerprint recorded from the code before PH7b
// (test/fixtures/ph5a_wide_fingerprints.json, the ph7b- names): each of the
// 10 tabs (an admin's) and an assistant's Summary, View Reports (a submitted
// report, a draft, none yet), Review, the full view, the detail screen and
// Past Reports. Today's overflows under the square test font are part of
// the fingerprint.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_detail_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_full_view_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_tabbed_content.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/tree_fingerprint.dart';

const _skip = false;

const _tabs = [
  'Summary',
  'Sales',
  'Services',
  'Products',
  'Stock Reconciliation',
  'Debt',
  'Expenses',
  'Transactions',
  'Activity Log',
  'Payment Methods',
];

String _errors(WidgetTester tester) {
  final out = StringBuffer();
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    out.writeln('ERROR ${e.toString().split('\n').first}');
  }
  return out.toString();
}

final _weekday = RegExp(r'\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b');
final _size = RegExp(r' [-\d.]+x[-\d.]+@[-\d.]+,[-\d.]+$');

/// View Reports shows TODAY's date (the report is today's), whose weekday
/// and day of the month change length from day to day: on a line that
/// shows a date, the weekday becomes "Day", a run of digits one "#", and the
/// box size goes. Every other line is compared whole.
String _stable(String fingerprint) => [
      for (final line in fingerprint.split('\n'))
        line.contains(_weekday) || line.contains('"') && line.contains('Mon')
            ? line.replaceAll(_weekday, 'Day').replaceAll(RegExp('#+'), '#').replaceAll(_size, '')
            : line,
    ].join('\n');

void _expect(WidgetTester tester, String name, Finder root) =>
    expectSameFingerprint(name, '${_errors(tester)}${_stable(treeFingerprint(tester, root.first))}');

/// A fixed day in the past, so the dates every other screen shows never move.
final _day = DateTime(2025, 3, 12);

String _slug(String tab) => tab.toLowerCase().replaceAll(' ', '-');

void main() {
  for (final size in ph5WideSizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    final modal = size.width >= 900;

    ph5TestWidgets('ph7b-tabs-$at: every tab of an admin\'s report as before PH7b', (tester) async {
      await ph7bPumpTabs(tester, ph7bReport(activityLog: true, day: _day), size: size);
      for (final tab in _tabs) {
        await ph7bOpenTab(tester, tab);
        _expect(tester, 'ph7b-tab-${_slug(tab)}-$at', find.byType(ReportTabbedContent));
      }
    }, skip: _skip);

    ph5TestWidgets('ph7b-tabs-$at: an assistant\'s Summary (no Activity Log tab) as before PH7b', (tester) async {
      await ph7bPumpTabs(tester, ph7bReport(day: _day), size: size, admin: false);
      _expect(tester, 'ph7b-tab-summary-assistant-$at', find.byType(ReportTabbedContent));
    }, skip: _skip);

    for (final (name, report) in [
      ('submitted', ph7bReport()),
      ('draft', ph7bReport(status: 'draft')),
      ('none', null),
    ]) {
      ph5TestWidgets('ph7b-view-reports-$name-$at: View Reports as before PH7b', (tester) async {
        await pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
            size: size, pushed: true, seed: report == null ? null : (fs) => ph7bSeedReport(fs, report));
        _expect(tester, 'ph7b-view-reports-$name-$at', find.byType(ViewReportsScreen));
      }, skip: _skip);
    }

    ph5TestWidgets('ph7b-review-$at: the review form as before PH7b', (tester) async {
      final report = ph7bReport(status: 'draft', day: _day);
      await pumpPh5(tester, (fs) => ReportReviewScreen(report: report, isModal: modal, firestore: fs),
          size: size, seed: (fs) => ph7bSeedReport(fs, report));
      _expect(tester, 'ph7b-review-$at', find.byType(ReportReviewScreen));
    }, skip: _skip);

    ph5TestWidgets('ph7b-full-view-$at: the full view as before PH7b', (tester) async {
      final report = ph7bReport(activityLog: true, day: _day);
      await pumpPh5(tester, (fs) => ReportFullViewScreen(report: report, isModal: modal, firestore: fs),
          size: size, seed: (fs) => ph7bSeedReport(fs, report));
      _expect(tester, 'ph7b-full-view-$at', find.byType(ReportFullViewScreen));
    }, skip: _skip);

    ph5TestWidgets('ph7b-detail-$at: the detail screen as before PH7b', (tester) async {
      final report = ph7bReport(day: _day);
      await pumpPh5(tester, (fs) => ReportDetailScreen(report: report, firestore: fs),
          size: size, pushed: true, seed: (fs) => ph7bSeedReport(fs, report));
      _expect(tester, 'ph7b-detail-$at', find.byType(ReportDetailScreen));
    }, skip: _skip);

    ph5TestWidgets('ph7b-past-reports-$at: Past Reports as before PH7b', (tester) async {
      await pumpPh5(tester, (fs) => PastReportsScreen(firestore: fs), size: size, pushed: true, seed: (fs) async {
        for (var d = 1; d <= 3; d++) {
          await ph7bSeedReport(fs, ph7bReport(day: _day.subtract(Duration(days: d)), status: d == 2 ? 'draft' : 'submitted'));
        }
      });
      _expect(tester, 'ph7b-past-reports-$at', find.byType(PastReportsScreen));
    }, skip: _skip);
  }
}
