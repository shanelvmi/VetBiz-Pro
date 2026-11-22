// PAGE1: drives the shared page bar (ListPageBar under PagedListBody) the
// way a person does: Next, Previous, the page size; and reads what it says.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/list_page_bar.dart';

import 'phone_list_harness.dart';

Finder get page1Bar => find.byType(ListPageBar);

ListPageBar page1BarWidget(WidgetTester tester) => tester.widget<ListPageBar>(page1Bar);

/// The bar's range text ("Showing 1 to 25"), or its empty text.
String page1Range(WidgetTester tester) {
  final texts = find.descendant(of: page1Bar, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data);
  return texts.firstWhere((t) => t != null)!;
}

bool page1NextEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(find.ancestor(of: find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_right)), matching: find.byType(IconButton))).onPressed != null;

bool page1PreviousEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(find.ancestor(of: find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_left)), matching: find.byType(IconButton))).onPressed != null;

Future<void> page1Next(WidgetTester tester) async {
  await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_right)));
  await ph5Settle(tester);
}

Future<void> page1Previous(WidgetTester tester) async {
  await tester.tap(find.descendant(of: page1Bar, matching: find.byIcon(Icons.chevron_left)));
  await ph5Settle(tester);
}

Future<void> page1PageSize(WidgetTester tester, int size) async {
  await tester.tap(find.descendant(of: page1Bar, matching: find.byType(DropdownButton<int>)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$size per page').last);
  await ph5Settle(tester);
}

/// PAGE1 widths (content as wide as the window: these screens are pushed).
const page1Widths = [Size(768, 1024), Size(1200, 800), Size(1920, 1080)];
