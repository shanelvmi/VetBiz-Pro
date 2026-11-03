// PH7b R8 (docs/design/phone_reports.md): the review form on a phone in the
// PH6 shell. One column; count fields 48 high with the number keyboard;
// reserved error lines; the declaration above the pinned bar; Cancel and
// Submit Daily Closing pinned above the keyboard; Back with anything typed
// asks first. What it submits: ph7b_review_submit_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/reports/report_review_screen.dart';

import 'helpers/ph7b_report.dart';
import 'helpers/phone_list_harness.dart';

const _skip = true;

Future<void> _review(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  final report = ph7bReport(status: 'draft');
  await pumpPh5(tester, (fs) => ReportReviewScreen(report: report, firestore: fs),
      size: size, pushed: true, seed: (fs) => ph7bSeedReport(fs, report));
}

Finder _hint(String hint) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);

void main() {
  ph5TestWidgets('one column; the count fields 48 high with the number keyboard; the bar holds Cancel and Submit', (tester) async {
    await _review(tester);
    expect(tester.takeException(), isNull);
    final counts = _hint('Physical count');
    expect(counts, findsNWidgets(2));
    final money = _hint('0');
    expect(money, findsNWidgets(2), reason: 'Cash and M-Pesa; Bank Transfer was only paid out');
    for (final f in [counts.at(0), counts.at(1), money.at(0), money.at(1)]) {
      expect(tester.widget<TextField>(f).keyboardType, TextInputType.number);
      expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(f).width, greaterThan(300), reason: 'one column, the full width');
    }
    final bar = find.byKey(const ValueKey('formActionBar'));
    expect(find.descendant(of: bar, matching: find.text('Submit Daily Closing')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Cancel')), findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Enter a physical count for every watch-listed product')), findsOneWidget,
        reason: 'why Submit is off, above the buttons');
  }, skip: _skip);

  ph5TestWidgets('the declaration is the form\'s last item, right above the bar; ticking it is a 48 px row', (tester) async {
    await _review(tester);
    final checkbox = find.byType(Checkbox);
    await tester.scrollUntilVisible(checkbox, 300, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    final row = find.ancestor(of: checkbox, matching: find.byType(InkWell)).first;
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(tester.getRect(row).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('formActionBar'))).top));
  }, skip: _skip);

  ph5TestWidgets('the keyboard lifts the bar: Submit stays visible', (tester) async {
    await _review(tester);
    await tester.tap(_hint('Physical count').first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final submit = tester.getRect(find.byKey(const ValueKey('formActionBar-primary')));
    expect(submit.bottom, lessThanOrEqualTo(844 - 320));
  }, skip: _skip);

  ph5TestWidgets('reserved error lines: the reason field keeps its height when its error goes', (tester) async {
    await _review(tester);
    await tester.enterText(_hint('Physical count').first, '118');
    await tester.pump();
    final reason = _hint('Reason for variance (e.g. damaged, unable to locate)');
    expect(find.text('Please provide a reason for the variance.'), findsOneWidget);
    final before = tester.getSize(reason).height;
    await tester.enterText(reason, 'Broken');
    await tester.pump();
    expect(find.text('Please provide a reason for the variance.'), findsNothing);
    expect(tester.getSize(reason).height, before);
  }, skip: _skip);

  ph5TestWidgets('Back on a clean form leaves; with a count typed it asks (Keep editing stays, Discard leaves)', (tester) async {
    await _review(tester);
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    expect(find.byType(ReportReviewScreen), findsNothing);

    await _review(tester);
    await tester.enterText(_hint('Physical count').first, '118');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    expect(find.text('Discard these counts?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await ph5Settle(tester);
    expect(find.byType(ReportReviewScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    await tester.tap(find.text('Discard'));
    await ph5Settle(tester);
    expect(find.byType(ReportReviewScreen), findsNothing);
  }, skip: _skip);

  ph5TestWidgets('ticking the declaration alone counts as entered (Back asks)', (tester) async {
    await _review(tester);
    final checkbox = find.byType(Checkbox);
    await tester.scrollUntilVisible(checkbox, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(checkbox);
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await ph5Settle(tester);
    expect(find.text('Discard these counts?'), findsOneWidget);
  }, skip: _skip);
}
