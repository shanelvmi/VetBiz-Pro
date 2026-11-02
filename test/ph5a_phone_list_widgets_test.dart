// PH5a: the phone list's pieces on their own (lib/widgets/phone_list/): the
// row (R6, R11), the quick chips and the filter sheet (R3), the summary sheet
// (R4), the skeleton (R9) and the floating button (R2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/phone_list/collapsing_fab.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_filter_sheet.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_list_skeleton.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_quick_chips.dart';
import 'package:vetbiz_pro/widgets/phone_list/phone_summary_sheet.dart';
import 'package:vetbiz_pro/widgets/phone_list/record_tile.dart';

import 'helpers/screen_size_matrix.dart';

Future<void> _pump(WidgetTester tester, Widget child, {bool reduceMotion = false}) => pumpAtSize(
      tester,
      size: const Size(390, 844),
      screen: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      ),
    );

/// The skeleton's rows (keyed phoneList-skeletonRow-0 to -5).
final _skeletonRows = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-skeletonRow-'));

void main() {
  testWidgets('a row: initials, two lines, the status as text, one spoken label, at least 64 high', (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      RecordTile(
        key: const ValueKey('row'),
        title: 'Amina Juma',
        amount: 'Tsh 45,000',
        details: const ['SL-000001', '10:15'],
        status: const RecordStatus('Paid', Colors.green),
        initialsOf: 'Amina Juma',
        colorSeed: 'Amina Juma',
        semanticsLabel: 'Amina Juma, Tsh 45,000, Paid, 27 Oct 10:15',
        onTap: () => taps++,
      ),
    );
    for (final t in ['AJ', 'Amina Juma', 'Tsh 45,000', 'SL-000001', '10:15', 'Paid']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.getSize(find.byKey(const ValueKey('row'))).height, greaterThanOrEqualTo(64));
    expect(find.bySemanticsLabel('Amina Juma, Tsh 45,000, Paid, 27 Oct 10:15'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('row')));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('quick chips select a stored value', (tester) async {
    String? chosen;
    await _pump(
      tester,
      PhoneQuickChips(values: const ['All', 'Unpaid'], selected: 'All', label: (v) => 'L-$v', onSelected: (v) => chosen = v),
    );
    await tester.tap(find.text('L-Unpaid'));
    expect(chosen, 'Unpaid');
  });

  testWidgets('the filter sheet: Reset puts the defaults in the sheet, Apply returns the stored values', (tester) async {
    Map<String, String>? applied;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => applied = await showPhoneFilterSheet(context, fields: {
            'date': PhoneFilterField(title: 'Date', options: const ['d30', 'd7'], label: (v) => 'L-$v', defaultValue: 'd30'),
          }, values: {'date': 'd7'}),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, {'date': 'd30'});
  });

  testWidgets('the summary sheet lists each figure as a label and value row', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showPhoneSummarySheet(context, period: 'Last 30 days', rows: const [('Revenue', 'Tsh 97,000')]),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
    final row = find.ancestor(of: find.text('Revenue'), matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.text('Tsh 97,000')), findsOneWidget);
  });

  testWidgets('the skeleton: six rows, pulsing; still under reduced motion', (tester) async {
    await _pump(tester, const PhoneListSkeleton());
    expect(_skeletonRows, findsNWidgets(6));
    expect(find.byType(FadeTransition), findsWidgets);
    await _pump(tester, const PhoneListSkeleton(), reduceMotion: true);
    expect(find.descendant(of: find.byType(PhoneListSkeleton), matching: find.byType(FadeTransition)), findsNothing);
  });

  testWidgets('the floating button shows its label only while extended', (tester) async {
    Widget fab(bool extended) => CollapsingFab(label: 'Record Visit', icon: Icons.add, extended: extended, onPressed: () {});
    await _pump(tester, fab(true));
    expect(find.text('Record Visit'), findsOneWidget);
    await _pump(tester, fab(false));
    expect(find.text('Record Visit'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
