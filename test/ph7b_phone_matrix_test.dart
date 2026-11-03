// PH7b (R10, R11): the report screens on phones at 360x740, 390x844 and
// 740x360, in Light, Dark and Kiswahili, with very long Kiswahili names and
// 8-digit amounts: no overflow, 48 px targets, no text under 12 px, and the
// body (the size most of the text is drawn at) at least 14. The tabs are
// each visited, and Sales' See all page; the full view and the detail fit
// the width with nothing scrolling sideways.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/past_reports_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_detail_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_full_view_screen.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';
import 'package:vetbiz_pro/screens/reports/view_reports_screen.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';

// The screens done so far: the others stay skipped until theirs is.
const Set<String> _done = {};

const _tabsEn = ['Summary', 'Sales', 'Services', 'Products', 'Stock Reconciliation', 'Debt', 'Expenses', 'Transactions', 'Activity Log', 'Payment Methods'];

/// The size most characters on screen are drawn at.
double _bodyPx(WidgetTester tester) {
  final chars = <double, int>{};
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject as RenderParagraph?;
    if (p == null || !p.attached) continue;
    void visit(InlineSpan span, double inherited) {
      final size = span.style?.fontSize ?? inherited;
      if (span is TextSpan) {
        final n = (span.text ?? '').trim().length;
        if (n > 0) chars[size] = (chars[size] ?? 0) + n;
        for (final c in span.children ?? const <InlineSpan>[]) {
          visit(c, size);
        }
      }
    }

    visit(p.text, 14);
  }
  return chars.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

Future<void> _check(WidgetTester tester, String where) async {
  await checkCase(tester, phone: true, where: where);
  expect(_bodyPx(tester), greaterThanOrEqualTo(14), reason: '$where: body text');
  // Only the tab bar, the swipe between tabs and the quick chips move
  // sideways.
  for (final e in find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right).evaluate()) {
    var allowed = false;
    e.visitAncestorElements((a) {
      allowed = a.widget is TabBar || a.widget is TabBarView || a.widget is PhoneQuickChips;
      return !allowed;
    });
    expect(allowed, isTrue, reason: '$where: something scrolls sideways');
  }
}

void main() {
  final screens = <String, (Widget Function(dynamic fs), Future<void> Function(dynamic fs)?, bool)>{
    'View Reports': ((fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()), (fs) => ph7bSeedReport(fs, ph7bReport(activityLog: true)), true),
    'View Reports empty': ((fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()), null, true),
    'Review': ((fs) => ReportReviewScreen(report: ph7bReport(status: 'draft'), firestore: fs), (fs) => ph7bSeedReport(fs, ph7bReport(status: 'draft')), true),
    'Full view': ((fs) => ReportFullViewScreen(report: ph7bReport(activityLog: true), isModal: false, firestore: fs), (fs) => ph7bSeedReport(fs, ph7bReport(activityLog: true)), true),
    'Detail': ((fs) => ReportDetailScreen(report: ph7bReport(), firestore: fs), (fs) => ph7bSeedReport(fs, ph7bReport()), true),
    'Past Reports': (
      (fs) => PastReportsScreen(firestore: fs),
      (fs) async {
        for (var d = 1; d <= 3; d++) {
          await ph7bSeedReport(fs, ph7bReport(day: DateTime(2025, 3, 12).subtract(Duration(days: d)), status: d == 2 ? 'draft' : 'submitted'));
        }
      },
      true
    ),
  };

  for (final e in screens.entries) {
    final (build, seed, pushed) = e.value;
    group('${e.key} phone matrix', () {
      for (final size in ph5PhoneSizes) {
        for (final look in MatrixLook.values) {
          final where = '${e.key} ${matrixCase(size, look)}';
          ph5TestWidgets(where, (tester) async {
            await pumpPh5(tester, (fs) => build(fs), size: size.size, look: look, pushed: pushed, seed: seed);
            await _check(tester, where);
            if (e.key == 'View Reports') {
              // Every tab (Kiswahili labels found by position), and Sales' See all.
              final tabs = find.descendant(of: find.byType(TabBar), matching: find.byType(Tab));
              for (var i = 0; i < _tabsEn.length; i++) {
                await tester.ensureVisible(tabs.at(i));
                await tester.pump();
                await tester.tap(tabs.at(i));
                await ph5Settle(tester);
                await _check(tester, '$where tab ${_tabsEn[i]}');
                if (_tabsEn[i] == 'Sales') {
                  final seeAll = find.byKey(const ValueKey('phoneReport-seeAll-sales'));
                  await tester.ensureVisible(seeAll);
                  await tester.pump();
                  await tester.tap(seeAll);
                  await ph5Settle(tester);
                  await _check(tester, '$where See all');
                  await tester.tap(find.byType(BackButton).last);
                  await ph5Settle(tester);
                }
              }
            }
          }, skip: !_done.contains(e.key));
        }
      }
    });
  }

  group('an assistant\'s View Reports (9 tabs)', () {
    for (final size in ph5PhoneSizes) {
      ph5TestWidgets(size.label, (tester) async {
        await pumpPh5(tester, (fs) => ViewReportsScreen(firestore: fs, authService: Ph7bNoAuth()),
            size: size.size, admin: false, pushed: true, seed: (fs) => ph7bSeedReport(fs, ph7bReport()));
        await _check(tester, 'assistant ${size.label}');
      }, skip: !_done.contains('View Reports'));
    }
  });
}
