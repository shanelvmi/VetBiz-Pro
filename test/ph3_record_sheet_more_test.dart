// PH3 (4) and (5): the "+" sheet (with stand-in forms and guard) and the More
// page (its items by role); their size matrices.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/models/client.dart';
import 'package:vetbiz_pro/screens/dashboard/more_screen.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _rows = ['Record Sale', 'Record Visit', 'Record Payment', 'Add Client'];

/// What the stand-in forms and guard saw.
class _Log {
  final opened = <String>[];
  final guarded = <String>[];
  List<Client> debtors = [];
  Completer<void>? fetchGate;
  List<Client>? paidFrom;
}

RecordSheetActions _actions(_Log log) => RecordSheetActions(
      recordSale: (_) async => log.opened.add('sale'),
      recordVisit: (_) async => log.opened.add('visit'),
      recordPayment: (_, debtors) async {
        log.opened.add('payment');
        log.paidFrom = debtors;
      },
      addClient: (_) async => log.opened.add('client'),
      fetchDebtors: (_) async {
        await log.fetchGate?.future;
        return log.debtors;
      },
    );

/// The guard: locked, it only notes the call (as the real one shows its
/// dialog instead); unlocked, it goes on as the real one does.
RecordGuard _guard(_Log log, {required bool locked}) =>
    (context, destination, {onNavigate}) async {
      log.guarded.add(destination.runtimeType.toString());
      if (!locked) await onNavigate?.call();
    };

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: home,
    );

Future<_Log> _openSheet(WidgetTester tester, {bool locked = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = _Log();
  // A fresh app each time: a sheet left open by the last call must not stay.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(_app(Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showRecordSheet(context, actions: _actions(log), guard: _guard(log, locked: locked)),
        child: const Text('open'),
      ),
    ),
  )));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return log;
}

Client _client(String id, String name, double balance) => Client.fromMap(id, {'name': name, 'phone': '0712000000', 'balance': balance});

/// Opens the sheet once the first frame is drawn, for the size matrix.
class _SheetOpener extends StatefulWidget {
  const _SheetOpener();
  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    final log = _Log();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showRecordSheet(context, actions: _actions(log), guard: _guard(log, locked: false)),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

void main() {
  testWidgets('the sheet has its title and four rows, each at least 64 high', (tester) async {
    await _openSheet(tester);
    expect(find.text('What would you like to record?'), findsOneWidget);
    for (final row in _rows) {
      expect(find.text(row), findsOneWidget);
      expect(tester.getSize(find.ancestor(of: find.text(row), matching: find.byType(InkWell)).first).height,
          greaterThanOrEqualTo(64));
    }
  }, skip: _skip);

  testWidgets('every row goes through the locked-facility guard; locked, no form opens', (tester) async {
    for (final row in _rows) {
      final log = await _openSheet(tester, locked: true);
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      expect(log.guarded, hasLength(1), reason: row);
      expect(log.opened, isEmpty, reason: row);
    }
  }, skip: _skip);

  testWidgets('unlocked, each row closes the sheet and opens its form', (tester) async {
    for (final (row, form) in [('Record Sale', 'sale'), ('Record Visit', 'visit'), ('Add Client', 'client')]) {
      final log = await _openSheet(tester);
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      expect(log.opened, [form]);
      expect(find.text('What would you like to record?'), findsNothing);
    }
  }, skip: _skip);

  testWidgets('Record Payment: a loading line while the debtors load, then the form with them', (tester) async {
    final log = await _openSheet(tester);
    log.fetchGate = Completer<void>();
    log.debtors = [_client('c1', 'Juma', 12500)];
    await tester.tap(find.text('Record Payment'));
    await tester.pump();
    expect(find.text('Finding who owes money…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    log.fetchGate!.complete();
    await tester.pumpAndSettle();
    expect(log.opened, ['payment']);
    expect(log.paidFrom!.single.name, 'Juma');
  }, skip: _skip);

  testWidgets('Record Payment when nobody owes: a friendly line, no form, the sheet stays', (tester) async {
    final log = await _openSheet(tester);
    await tester.tap(find.text('Record Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody owes money right now.'), findsOneWidget);
    expect(log.opened, isEmpty);
    expect(find.text('Record Sale'), findsOneWidget);
  }, skip: _skip);

  // MR1: in the order of the sections (Daily work, Stock and reports, Team and
  // business, App, Platform); Printer settings and Manage Account joined as
  // Settings offers them to every role.
  test('More: the admin items, in order, and the assistant\'s (no admin item)', () {
    const admin = [
      MoreItem.clients, MoreItem.debtors, MoreItem.services, MoreItem.payments, MoreItem.transactions,
      MoreItem.stockStore, MoreItem.reports, MoreItem.insights, MoreItem.activityLog,
      MoreItem.team, MoreItem.facilities, MoreItem.businessHours, MoreItem.subscription,
      MoreItem.settings, MoreItem.printerSettings, MoreItem.export, MoreItem.trash, MoreItem.manageAccount, MoreItem.help,
    ];
    expect(moreItemsFor(isAdmin: true), admin);
    expect(moreItemsFor(isAdmin: false), [
      MoreItem.clients, MoreItem.debtors, MoreItem.services, MoreItem.payments, MoreItem.transactions,
      MoreItem.stockStore, MoreItem.reports, MoreItem.insights,
      MoreItem.settings, MoreItem.printerSettings, MoreItem.manageAccount, MoreItem.help,
    ]);
    expect(moreItemsFor(isAdmin: true, isPlatformAdmin: true), [...admin, MoreItem.platformAdmin]);
    expect(moreItemsFor(isAdmin: false, isPlatformAdmin: true).last, MoreItem.platformAdmin);
  }, skip: _skip);

  testWidgets('More as an assistant shows no admin label; a tap opens the item', (tester) async {
    final opened = <MoreItem>[];
    await tester.pumpWidget(_app(MoreScreen(isAdmin: false, onOpen: (_, item) async => opened.add(item))));
    for (final label in ['Team Members', 'Facilities', 'Trash', 'Export Data', 'Business Hours', 'Subscription', 'Activity Log']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    for (final label in ['Services', 'Payments', 'Transactions', 'Reports', 'Insights', 'Stock Store', 'Settings', 'Help']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Stock Store'));
    await tester.pump();
    expect(opened, [MoreItem.stockStore]);
  }, skip: _skip);

  testWidgets('More: four a row at 360 and 390', (tester) async {
    for (final width in [360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(MoreScreen(isAdmin: true, onOpen: (_, __) async {})));
      // Tops, not centres: a label may take one line or two.
      final y = tester.getTopLeft(find.text('Clients')).dy;
      final firstRow = ['Clients', 'Debtors', 'Services', 'Payments'].map((t) => tester.getTopLeft(find.text(t)).dy);
      expect(firstRow, everyElement(y));
      expect(tester.getTopLeft(find.text('Transactions')).dy, greaterThan(y));
    }
    tester.view.reset();
  }, skip: _skip);

  final stub = {for (final s in matrixSizes) for (final l in MatrixLook.values) matrixCase(s, l): 'stub', matrixTextScaleCase: 'stub'};
  screenSizeMatrix('+ sheet', screen: () => const _SheetOpener(), skip: _skip ? stub : const {});
  screenSizeMatrix('More page (admin)',
      screen: () => MoreScreen(isAdmin: true, isPlatformAdmin: true, onOpen: (_, __) async {}), skip: _skip ? stub : const {});
}
