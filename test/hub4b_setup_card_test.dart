// HUB4b (2): the phone Home's "Set up your facility" card, in the attention
// strip's place (the strip wins), at most two steps plus an "n more" line
// opening a sheet; each step runs through its panel tile; Hide; the reveal's
// skeleton keeps every rect with and without the card; Home still fits
// without scrolling at 360x740, 390x844, 412x915 and 360x640 in Light, Dark
// and Kiswahili, with 48 px targets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/screens/dashboard/home_setup.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

final _en = lookupAppLocalizations(const Locale('en'));

const _card = ValueKey('phone-home-setup');

/// A new facility with a client already added (admin: three steps).
const _partly = [
  HomeSetupItem(HomeSetupStep.addProduct, done: false),
  HomeSetupItem(HomeSetupStep.recordSale, done: false),
  HomeSetupItem(HomeSetupStep.addClient, done: true),
];

/// An assistant's steps on a new facility.
const _assistant = [
  HomeSetupItem(HomeSetupStep.addClient, done: false),
  HomeSetupItem(HomeSetupStep.recordSale, done: false),
];

double _maxScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byKey(const ValueKey('phone-home-list')), matching: find.byType(Scrollable)).first,
    )
    .position
    .maxScrollExtent;

void main() {
  setUpAll(() => initializeDateFormatting());

  testWidgets('no strip: the card, two steps (to do first), "1 more step", done and to-do marks', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness(attention: const [], setup: _partly));
    expect(find.byKey(_card), findsOneWidget);
    expect(find.text(_en.home_setupTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-home-setup-addProduct')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-home-setup-recordSale')), findsOneWidget);
    expect(find.byKey(const ValueKey('phone-home-setup-addClient')), findsNothing, reason: 'in the sheet');
    expect(find.text(_en.home_setupMore(1)), findsOneWidget);
    expect(tester.getSize(find.byKey(_card)).height, PhoneHomeMetrics.setupHeader + 3 * PhoneHomeMetrics.setupRow);
    expect(find.byKey(const ValueKey('phone-home-attention')), findsNothing);
  }, skip: _skip);

  testWidgets('the strip wins: never both', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness(attention: ph4SomeAttention, setup: _partly));
    expect(find.byKey(const ValueKey('phone-home-attention')), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
  }, skip: _skip);

  testWidgets('no steps: no card', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness(attention: const []));
    expect(find.byKey(_card), findsNothing);
  }, skip: _skip);

  testWidgets('an assistant: their two steps, no "more" line, no Add product', (tester) async {
    await pumpPhoneHome(tester, phoneHomeHarness(attention: const [], setup: _assistant, isAdmin: false));
    expect(find.byKey(const ValueKey('phone-home-setup-more')), findsNothing);
    expect(find.text(_en.home_setupAddProduct), findsNothing);
    expect(tester.getSize(find.byKey(_card)).height, PhoneHomeMetrics.setupHeader + 2 * PhoneHomeMetrics.setupRow);
  }, skip: _skip);

  testWidgets('a step runs its own tile; the sheet lists every step; Hide', (tester) async {
    final steps = <HomeSetupStep>[];
    var hidden = 0;
    await pumpPhoneHome(
      tester,
      phoneHomeHarness(attention: const [], setup: _partly, onSetupStep: steps.add, onSetupHide: () => hidden++),
    );
    await tester.tap(find.byKey(const ValueKey('phone-home-setup-addProduct')));
    await tester.pump();
    expect(steps, [HomeSetupStep.addProduct]);
    expect(steps.single.tile, HubTile.addProduct);

    await tester.tap(find.byKey(const ValueKey('phone-home-setup-more')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    for (final item in _partly) {
      expect(find.descendant(of: sheet, matching: find.byKey(ValueKey('phone-home-setup-${item.step.name}'))),
          findsOneWidget);
    }
    await tester.tap(find.descendant(of: sheet, matching: find.byKey(const ValueKey('phone-home-setup-addClient'))));
    await tester.pumpAndSettle();
    expect(steps, [HomeSetupStep.addProduct, HomeSetupStep.addClient]);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('phone-home-setup-hide')));
    expect(hidden, 1);
  }, skip: _skip);

  testWidgets('a short screen (360x640): the strip\'s shape; it opens the sheet, which has Hide', (tester) async {
    var hidden = 0;
    await pumpPhoneHome(
      tester,
      phoneHomeHarness(attention: const [], setup: _partly, onSetupHide: () => hidden++),
      size: const Size(360, 640),
    );
    expect(tester.getSize(find.byKey(_card)).height, PhoneHomeMetrics.attentionStripHeight);
    expect(find.byKey(const ValueKey('phone-home-setup-hide')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('phone-home-setup-more')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(InkWell)), findsNWidgets(3 + 1));
    await tester.tap(find.byKey(const ValueKey('phone-home-setup-sheet-hide')));
    await tester.pumpAndSettle();
    expect(hidden, 1);
  }, skip: _skip);

  testWidgets('screen readers hear done or to do for each step', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPhoneHome(tester, phoneHomeHarness(attention: const [], setup: _assistant));
    expect(find.bySemanticsLabel(_en.home_setupStepToDo(_en.home_setupAddClient)), findsOneWidget);
    semantics.dispose();
  }, skip: _skip);

  group('the reveal: the skeleton keeps every rect', () {
    for (final (name, setup) in [('with the card', _partly), ('without it', const <HomeSetupItem>[])]) {
      testWidgets(name, (tester) async {
        final answered = ValueNotifier(false);
        final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
        addTearDown(gate.dispose);
        await pumpPhoneHome(
          tester,
          phoneHomeHarness(gate: gate, attention: const [], setup: setup, charts: HarnessCharts().build()),
        );
        Rect? cardRect() => setup.isEmpty ? null : tester.getRect(find.byKey(_card).first);
        final charts = tester.getRect(find.byKey(const ValueKey('phone-home-charts')).first);
        final card = cardRect();
        answered.value = true;
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(const ValueKey('phone-home-charts'))), charts);
        expect(cardRect(), card);
        expect(find.byKey(_card), setup.isEmpty ? findsNothing : findsOneWidget);
      }, skip: _skip);
    }
  });

  group('the size matrix with the card (charts on, admin and assistant)', () {
    const sizes = [
      MatrixSize('360x740', Size(360, 740), phone: true),
      MatrixSize('390x844', Size(390, 844), phone: true),
      MatrixSize('412x915', Size(412, 915), phone: true),
      MatrixSize('360x640', Size(360, 640), phone: true),
    ];
    for (final s in sizes) {
      for (final look in MatrixLook.values) {
        for (final admin in [true, false]) {
          testWidgets('${matrixCase(s, look)} ${admin ? 'admin' : 'assistant'}: fits, no scroll', (tester) async {
            await pumpAtSize(
              tester,
              screen: phoneHomeHarness(
                attention: const [],
                isAdmin: admin,
                setup: admin ? _partly : _assistant,
                charts: HarnessCharts().build(),
              ),
              size: s.size,
              look: look,
            );
            await tester.pumpAndSettle();
            await checkCase(tester, phone: true, where: matrixCase(s, look));
            expect(_maxScroll(tester), 0, reason: '${matrixCase(s, look)}: Home fits without scrolling');
          }, skip: _skip);
        }
      }
    }
  });
}
