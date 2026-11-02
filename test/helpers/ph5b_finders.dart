// PH5b: what the four phone list tests look for (the keys come from
// PhoneListScaffold, lib/widgets/phone_list/).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone_list_harness.dart';

Finder ph5Key(String k) => find.byKey(ValueKey(k));

Finder get ph5List => find.descendant(of: ph5Key('phoneList-scroll'), matching: find.byType(Scrollable)).first;

Finder ph5InSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Finder get ph5Page => ph5Key('phoneList-details');

/// The ids of the rows built now.
Set<String> ph5RowIds(WidgetTester tester) => {
      for (final e in find
          .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-row-'))
          .evaluate())
        (e.widget.key as ValueKey<String>).value.substring('phoneList-row-'.length),
    };

/// Whether any day header is built (the grouped lists have them).
bool ph5HasDayHeaders(WidgetTester tester) => find
    .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-day-'))
    .evaluate()
    .isNotEmpty;

/// Whether the floating button shows [label] (extended) or only its icon.
bool ph5FabExtended(String label) =>
    find.descendant(of: ph5Key('phoneList-fab'), matching: find.text(label)).evaluate().isNotEmpty;

/// Every plain text under [root].
Set<String> ph5Texts(Finder root) => {
      for (final e in find.descendant(of: root, matching: find.byType(Text)).evaluate())
        if ((e.widget as Text).data != null) (e.widget as Text).data!,
    };

/// The Summary sheet's value beside the label that starts with [label].
String? ph5SheetValue(WidgetTester tester, String label) {
  final labelText = find.descendant(
      of: find.byType(BottomSheet), matching: find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(label)));
  final row = find.ancestor(of: labelText.first, matching: find.byType(Row)).first;
  final texts = ph5Texts(row)..removeWhere((t) => t.startsWith(label));
  return texts.isEmpty ? null : texts.single;
}

Future<void> ph5OpenSheet(WidgetTester tester, String opener) async {
  await tester.tap(find.byTooltip(opener));
  await ph5Settle(tester);
}

Future<void> ph5OpenSummary(WidgetTester tester) async {
  await tester.tap(ph5Key('phoneList-summaryLink'));
  await ph5Settle(tester);
}

/// The keyboard opens: the floating button goes.
Future<void> ph5OpenKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetViewInsets);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Pull to refresh.
Future<void> ph5Pull(WidgetTester tester) async {
  await tester.fling(ph5Key('phoneList-scroll'), const Offset(0, 500), 1500);
  await tester.pump(const Duration(seconds: 1));
  await ph5Settle(tester);
}

/// The skeleton's rows (keyed phoneList-skeletonRow-0 to -5).
final ph5SkeletonRows = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('phoneList-skeletonRow-'));
