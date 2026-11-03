// PH7b seams: View Reports, Review, the detail and full views, the tabbed
// content and the activity-log loader take their Firestore (and View
// Reports its AuthService); null is the app's own, so nothing changes in the
// app. Each builds in a test on a fake.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_detail_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_full_view_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

void main() {
  const wide = Size(1200, 800);

  ph5TestWidgets('View Reports reads today\'s report from the fake Firestore', (tester) async {
    final report = ph7bReport();
    await pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
        size: wide, seed: (fs) => ph7bSeedReport(fs, report));
    ph7bDropWideFontErrors(tester);
    expect(find.text('Daily Closing Report - Today\'s Report'), findsOneWidget);
    expect(find.text('Asha Mohamed'), findsOneWidget, reason: 'the Accountability card');
  });

  ph5TestWidgets('View Reports with no report today shows its empty state', (tester) async {
    await pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()), size: wide);
    ph7bDropWideFontErrors(tester);
    expect(find.text('No report generated yet today'), findsOneWidget);
  });

  ph5TestWidgets('the Activity Log tab reads the admin\'s log from the fake Firestore', (tester) async {
    await ph7bPumpTabs(tester, ph7bReport(activityLog: true), size: wide);
    await ph7bOpenTab(tester, 'Activity Log');
    ph7bDropWideFontErrors(tester);
    expect(find.text('Expense: Electricity'), findsOneWidget);
  });

  ph5TestWidgets('the detail screen builds on the fake Firestore', (tester) async {
    final report = ph7bReport(activityLog: true);
    await pumpPh5(tester, (fs) => ReportDetailScreen(report: report, firestore: fs),
        size: wide, seed: (fs) => ph7bSeedReport(fs, report));
    ph7bDropWideFontErrors(tester);
    expect(find.text('Submitted by Asha Mohamed'), findsOneWidget);
  });

  ph5TestWidgets('the full view reads the admin\'s log from the fake Firestore', (tester) async {
    final report = ph7bReport(activityLog: true);
    await pumpPh5(tester, (fs) => ReportFullViewScreen(report: report, isModal: false, firestore: fs),
        size: wide, seed: (fs) => ph7bSeedReport(fs, report));
    ph7bDropWideFontErrors(tester);
    expect(find.textContaining('Expense: Electricity'), findsOneWidget);
  });

  ph5TestWidgets('Review builds on the fake Firestore', (tester) async {
    final report = ph7bReport(status: 'draft');
    await pumpPh5(tester, (fs) => ReportReviewScreen(report: report, firestore: fs),
        size: wide, seed: (fs) => ph7bSeedReport(fs, report));
    ph7bDropWideFontErrors(tester);
    expect(find.text('Submit Daily Closing'), findsOneWidget);
  });

  ph5TestWidgets('Past Reports lists the earlier reports (not today\'s) and opens one on the same Firestore', (tester) async {
    final yesterday = ph7bToday.subtract(const Duration(days: 1));
    await pumpPh5(tester, (fs) => PastReportsScreen(firestore: fs), size: wide, seed: (fs) async {
      await ph7bSeedReport(fs, ph7bReport());
      await ph7bSeedReport(fs, ph7bReport(day: yesterday, activityLog: true));
    });
    ph7bDropWideFontErrors(tester);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget, reason: 'yesterday only');
    await tester.tap(find.byIcon(Icons.description_outlined));
    await ph5Settle(tester);
    await ph7bOpenTab(tester, 'Activity Log');
    expect(find.text('Expense: Electricity'), findsOneWidget);
  });
}
