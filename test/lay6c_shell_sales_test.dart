// LAY6c: Sales and its archive inside AppShell over a seeded fake Firestore,
// at windows 768, 1024 and 1200 with the sidebar open and collapsed (content
// 696, 774, 952, 950, 1128), text 1.3, Light and Dark in every theme, and
// Kiswahili: no overflow with Sales' list and details open, then the Archive
// (pushed inside the content, its back arrow, Sales still highlighted) with
// its list and details open. Details inline from 900 of the content, a
// slide-over below. The receipt preview opens inside the content and Back
// returns to Sales. Back pops then Home, told to refresh.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/sales/receipt_preview_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_archive_screen.dart';
import 'package:vetbiz_pro/screens/sales/sales_screen.dart';
import 'package:vetbiz_pro/theme/app_breakpoints.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/pol4_checks.dart';
import 'helpers/screen_size_matrix.dart';
import 'pol4_fingerprints_test.dart' show seedPol4Archives;

/// The archive's rows (POL4's, inside its default window, 180 to 270 days
/// back), then the POL4 sales the list shows.
Future<void> _seed(dynamic fs) async {
  await seedPol4Archives(fs as FirebaseFirestore);
  await ph5SeedSales(fs, pol4Sales);
}

final _shell = GlobalKey<AppShellState>();
dynamic _fs;
final _returned = <AppDestination>[];

Widget _harness(dynamic fs, double sidebar) => Scaffold(
      body: AppShell(
        key: _shell,
        sidebar: (selected, onSelect) => SizedBox(
          width: sidebar,
          child: Column(children: [
            for (final d in [AppDestination.home, AppDestination.sales])
              SizedBox(
                key: ValueKey('sb-${d.name}${d == selected ? '-selected' : ''}'),
                height: 48,
                child: TextButton(onPressed: () => onSelect(d), child: const SizedBox.shrink()),
              ),
          ]),
        ),
        topBar: const SizedBox(height: 64),
        home: const Text('HOME'),
        pageFor: (d) => d == AppDestination.sales ? SalesScreen(firestore: fs) : null,
        onOpenFullScreen: (_) async {},
        onReturnedHome: _returned.add,
      ),
    );

Future<void> _pump(WidgetTester tester, Size size, double sidebar,
        {MatrixLook look = MatrixLook.light, AppColorTheme theme = AppColorTheme.pasture, double scale = 1}) =>
    pumpPh5(tester, (fs) {
      _fs = fs;
      return _harness(fs, sidebar);
    }, size: size, look: look, colorTheme: theme, textScale: scale, seed: _seed);

Future<void> _openSales(WidgetTester tester) async {
  _shell.currentState!.select(AppDestination.sales);
  await ph5Settle(tester);
  await ph5SettleUntil(tester, () => find.text('Amina Juma').evaluate().isNotEmpty, what: 'the sales');
}

Future<void> _openRow(WidgetTester tester, Finder scope) async {
  final row = find.descendant(of: scope, matching: find.text('Amina Juma')).last;
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await ph5Settle(tester);
}

final _slideOver = find.byKey(const ValueKey('details-slide-over'));

/// The details are open, inline or sliding over as the content width says;
/// then closed with the panel's own button.
Future<void> _checkDetails(WidgetTester tester, Finder scope, {required bool inline, required String where}) async {
  expect(tester.takeException(), isNull, reason: '$where: details');
  final slide = find.descendant(of: scope, matching: _slideOver);
  if (inline) {
    expect(slide, findsNothing, reason: where);
    expect(find.descendant(of: scope, matching: find.byType(VerticalDivider)), findsOneWidget, reason: where);
    // Closed with its own button, so the next tap reaches the list's controls.
    await tester.tap(find.descendant(of: scope, matching: find.byIcon(Icons.close)).first);
    await ph5Settle(tester);
    expect(find.descendant(of: scope, matching: find.byType(VerticalDivider)), findsNothing, reason: '$where: closed');
  } else {
    expect(slide, findsOneWidget, reason: where);
    await tester.tap(find.descendant(of: slide, matching: find.byIcon(Icons.close)).first);
    await ph5Settle(tester);
    expect(slide, findsNothing, reason: '$where: its close button closes it');
  }
}

void main() {
  setUp(_returned.clear);

  const layouts = [
    (Size(768, 1024), 72.0),
    (Size(1024, 768), 250.0),
    (Size(1024, 768), 72.0),
    (Size(1200, 800), 250.0),
    (Size(1200, 800), 72.0),
  ];
  final looks = [
    for (final theme in AppColorTheme.all)
      for (final look in const [MatrixLook.light, MatrixLook.dark]) (theme, look),
    (AppColorTheme.pasture, MatrixLook.kiswahili),
  ];

  for (final (size, sidebar) in layouts) {
    final content = size.width - sidebar;
    final inline = content >= AppBreakpoints.medium;
    for (final (theme, look) in looks) {
      ph5TestWidgets(
          'Sales and its archive at content ${content.toInt()} ${theme.id} ${look.name} text 1.3: '
          'no overflow; details ${inline ? 'inline' : 'slide over'}', (tester) async {
        await _pump(tester, size, sidebar, look: look, theme: theme, scale: 1.3);
        await _openSales(tester);
        expect(tester.takeException(), isNull, reason: 'the Sales list');
        final sales = find.byType(SalesScreen);
        expect(tester.getTopLeft(sales).dx, sidebar, reason: 'beside the sidebar');
        expect(find.byKey(const ValueKey('sb-sales-selected')), findsOneWidget);
        expect(find.byType(BackButton), findsNothing, reason: 'top level: no back arrow');
        await _openRow(tester, sales);
        await _checkDetails(tester, sales, inline: inline, where: 'Sales');

        // The Archive button opens it inside the content (its own screen reads
        // the app's Firestore, so it is closed again and the same screen is
        // pushed from Sales' navigator over the fake one to check its layout).
        await tester.tap(find.byIcon(Icons.archive_outlined).first);
        await ph5Settle(tester);
        expect(tester.getTopLeft(find.byType(SalesArchiveScreen)).dx, sidebar, reason: 'the button: inside the content');
        expect(find.byKey(const ValueKey('sb-sales-selected')), findsOneWidget, reason: 'Sales stays highlighted');
        await tester.binding.handlePopRoute();
        await ph5Settle(tester);
        tester.takeException(); // the app Firestore the button's screen asked for
        Navigator.of(tester.element(sales)).push(MaterialPageRoute<void>(builder: (_) => SalesArchiveScreen(firestore: _fs)));
        await ph5Settle(tester);
        final archive = find.byType(SalesArchiveScreen);
        await ph5SettleUntil(tester, () => find.descendant(of: archive, matching: find.text('Amina Juma')).evaluate().isNotEmpty,
            what: 'the archived sales');
        expect(tester.takeException(), isNull, reason: 'the archive list');
        expect(tester.getTopLeft(archive).dx, sidebar, reason: 'inside the content area');
        expect(find.byKey(const ValueKey('sb-sales-selected')), findsOneWidget, reason: 'Sales stays highlighted');
        expect(find.descendant(of: archive, matching: find.byType(BackButton)), findsOneWidget, reason: 'its back arrow');
        await _openRow(tester, archive);
        await _checkDetails(tester, archive, inline: inline, where: 'the archive');

        await tester.binding.handlePopRoute();
        await ph5Settle(tester);
        expect(find.byType(SalesArchiveScreen), findsNothing);
        expect(find.byType(SalesScreen), findsOneWidget, reason: 'Back returns to Sales');
      });
    }
  }

  ph5TestWidgets('the receipt opens inside the content with its back arrow; Back returns to Sales', (tester) async {
    await _pump(tester, const Size(1200, 800), 250);
    await _openSales(tester);
    await _openRow(tester, find.byType(SalesScreen));
    await tester.tap(find.byIcon(Icons.print_outlined).first);
    await ph5Settle(tester);
    final receipt = find.byType(ReceiptPreviewScreen);
    expect(receipt, findsOneWidget);
    expect(tester.getTopLeft(receipt).dx, 250, reason: 'inside the content area');
    expect(find.byKey(const ValueKey('sb-sales-selected')), findsOneWidget);
    expect(find.descendant(of: receipt, matching: find.byType(BackButton)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.byType(SalesScreen), findsOneWidget);
  });

  ph5TestWidgets('Sales: Back pops inside, then Home, and Home is told to refresh', (tester) async {
    await _pump(tester, const Size(1200, 800), 250);
    await _openSales(tester);
    await tester.binding.handlePopRoute();
    await ph5Settle(tester);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('sb-home-selected')), findsOneWidget);
    expect(_returned, [AppDestination.sales]);
    expect(AppDestination.sales.refreshHomeOnReturn, isTrue, reason: 'the registry');
  });
}
