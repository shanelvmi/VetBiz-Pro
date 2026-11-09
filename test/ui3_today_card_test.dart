// UI3 (1) and (2): the phone Today card's hidden amounts as soft blurred
// dots (the currency stays, the real digits are never built) and the current
// facility's name as a small line at the top of the card.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/facility_provider.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = false;

const _figures = PhoneHomeFigures(sales: 1250000, collected: 980000, owed: 310000, netProfit: 145000);
final _amounts = [_figures.sales, _figures.collected, _figures.owed, _figures.netProfit].map(Money.format).toList();
const _facility = 'Mwanzo Agrovet';

/// The card wired as the dashboard wires it: the eye through
/// UiSettingsProvider, the facility name from FacilityProvider.
Future<FacilityProvider> _card(
  WidgetTester tester, {
  bool isAdmin = true,
  Size size = const Size(390, 844),
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
  bool hidden = false,
  String facility = _facility,
  PhoneHomeFigures figures = _figures,
}) async {
  // The provider loads the saved facility on creation; saved first, so that
  // load and setFacility agree.
  SharedPreferences.setMockInitialValues(
      {'ui_home_amounts_hidden': hidden, 'facilityId': 'f1', 'facilityName': facility, 'facilityType': 'Agrovet'});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      reduceMotion ? const FakeAccessibilityFeatures(disableAnimations: true) : const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final facilities = FacilityProvider(firestore: FakeFirebaseFirestore());
  await facilities.setFacility(id: 'f1', name: facility, type: 'Agrovet');
  final ui = UiSettingsProvider();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ui),
      ChangeNotifierProvider.value(value: facilities),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(theme, brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Consumer2<UiSettingsProvider, FacilityProvider>(
            builder: (context, ui, f, _) => TodayCard(
              figures: figures,
              isAdmin: isAdmin,
              period: 'Today',
              onPeriodChanged: (_) {},
              onAllDetails: () {},
              amountsHidden: ui.homeAmountsHidden,
              onToggleAmounts: () => ui.setHomeAmountsHidden(!ui.homeAmountsHidden),
              periodLabel: 'Mon 9 Nov',
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return facilities;
}

Future<void> _tapEye(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.descendant(of: find.byType(TodayCard), matching: find.byType(IconButton)));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

Finder get _placeholders => find.descendant(of: find.byType(TodayCard), matching: find.byType(ImageFiltered));

/// The dots of one placeholder.
Finder _dots(Finder placeholder) => find.descendant(
      of: placeholder,
      matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).shape == BoxShape.circle),
    );

/// Every text drawn inside the card.
List<String> _cardTexts(WidgetTester tester) => find
    .descendant(of: find.byType(TodayCard), matching: find.byType(RichText))
    .evaluate()
    .map((e) => (e.widget as RichText).text.toPlainText())
    .toList();

double _sigma(ImageFilter filter) =>
    double.parse(RegExp(r'[\d.]+').firstMatch(filter.toString().split('(').last)!.group(0)!);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('(1) hidden amounts', () {
    testWidgets('four placeholders of four soft dots each, the currency kept beside each', (tester) async {
      await _card(tester);
      expect(_placeholders, findsNothing);
      await _tapEye(tester);
      expect(_placeholders, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(_dots(_placeholders.at(i)), findsNWidgets(4), reason: 'placeholder $i');
        expect(_sigma(tester.widget<ImageFiltered>(_placeholders.at(i)).imageFilter), inInclusiveRange(1.4, 2.6));
      }
      expect(_cardTexts(tester).where((t) => t.trim() == 'Tsh').length, 4);
    }, skip: _skip);

    testWidgets('always four dots, whatever the amount (0, small, 8 digits, loading)', (tester) async {
      for (final figures in const [
        PhoneHomeFigures(sales: 0, collected: 0, owed: 0, netProfit: 0),
        PhoneHomeFigures(sales: 5, collected: 50, owed: 500, netProfit: -5000),
        ph4BigFigures,
        PhoneHomeFigures(sales: 0, collected: 0, owed: 0, netProfit: 0, loading: true),
      ]) {
        await _card(tester, hidden: true, figures: figures);
        expect(_placeholders, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          expect(_dots(_placeholders.at(i)), findsNWidgets(4));
        }
      }
    }, skip: _skip);

    testWidgets('the dots scale with the text: about 0.3 of the font size', (tester) async {
      await _card(tester, hidden: true);
      double dot(int i) => tester.getSize(_dots(_placeholders.at(i)).first).width;
      expect(dot(0), closeTo(PhoneHomeMetrics.salesValue * 0.3, 0.6));
      for (final i in [1, 2, 3]) {
        expect(dot(i), closeTo(PhoneHomeMetrics.statValue * 0.3, 0.6));
      }
    }, skip: _skip);

    testWidgets('the real digits are never built: no text and no semantics label holds a digit', (tester) async {
      final semantics = tester.ensureSemantics();
      await _card(tester, hidden: true);
      // UI5: the period line ("Sales · Mon 9 Nov") is a date, not an amount.
      for (final t in _cardTexts(tester).where((t) => !t.startsWith('Sales · '))) {
        expect(RegExp(r'\d').hasMatch(t), isFalse, reason: t);
      }
      for (final amount in _amounts) {
        expect(find.textContaining(amount), findsNothing);
      }
      expect(find.bySemanticsLabel(RegExp(r'^(?!Sales · )[^\n]*\d')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Amount hidden')), findsNWidgets(4));
      semantics.dispose();
    }, skip: _skip);

    testWidgets('the eye masks the four amounts and nothing else; the labels stay', (tester) async {
      await _card(tester);
      await _tapEye(tester);
      // UI5: the period line, and no "All details" line or facility name.
      for (final label in ['Sales · Mon 9 Nov', 'Collected', 'Owed', 'Net profit', 'Today']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await _tapEye(tester);
      expect(_placeholders, findsNothing);
      for (final amount in _amounts) {
        expect(find.text(amount), findsOneWidget);
      }
    }, skip: _skip);

    testWidgets('an assistant: three placeholders, never Net profit', (tester) async {
      await _card(tester, isAdmin: false, hidden: true);
      expect(_placeholders, findsNWidgets(3));
      expect(find.text('Net profit'), findsNothing);
      await _tapEye(tester);
      expect(find.text(_amounts[3]), findsNothing);
    }, skip: _skip);

    testWidgets('a short cross-fade (AppMotion) between the amounts and the dots', (tester) async {
      await _card(tester);
      await _tapEye(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(_amounts[0]), findsOneWidget, reason: 'still fading out');
      expect(_placeholders, findsNWidgets(4), reason: 'fading in');
      expect(find.descendant(of: find.byType(TodayCard), matching: find.byType(FadeTransition)), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text(_amounts[0]), findsNothing);
    }, skip: _skip);

    testWidgets('reduced motion: the dots replace the amounts in one frame', (tester) async {
      await _card(tester, reduceMotion: true);
      await _tapEye(tester, settle: false);
      await tester.pump();
      expect(find.text(_amounts[0]), findsNothing);
      expect(_placeholders, findsNWidgets(4));
    }, skip: _skip);

    group('the dots against the gradient: at least 3:1 at their blurred centre', () {
      for (final theme in AppColorTheme.all) {
        for (final brightness in Brightness.values) {
          testWidgets('${theme.id} ${brightness.name}', (tester) async {
            await _card(tester, theme: theme, brightness: brightness, hidden: true);
            final colors = AppColors.fromTheme(theme, brightness: brightness);
            for (var i = 0; i < 4; i++) {
              final placeholder = _placeholders.at(i);
              final dot = _dots(placeholder).first;
              final fill = (tester.widget<DecoratedBox>(dot).decoration as BoxDecoration).color!;
              expect(fill.a, closeTo(0.7, 0.05), reason: 'about 70 percent of the on-brand ink');
              expect(fill.withValues(alpha: 1), colors.onBrandSurface);
              final r = tester.getSize(dot).width / 2;
              final sigma = _sigma(tester.widget<ImageFiltered>(placeholder).imageFilter);
              // A disc of radius r under a Gaussian blur keeps this share of
              // its ink at its centre.
              final peak = 1 - math.exp(-r * r / (2 * sigma * sigma));
              for (final end in [colors.brandGradientStart, colors.brandGradientEnd]) {
                final drawn = Color.alphaBlend(fill.withValues(alpha: fill.a * peak), end);
                expect(ColorMath.contrast(drawn, end), greaterThanOrEqualTo(3.0), reason: 'placeholder $i on $end');
              }
            }
          }, skip: _skip);
        }
      }
    });
  });

  // UI5 moved the facility name from the card to Home's top bar (once, there:
  // ui5_home_layout_test); these replace UI3's two tests of the card's line.
  group('(2) the facility name', () {
    testWidgets('UI5: no longer inside the card, even after a switch', (tester) async {
      final facilities = await _card(tester);
      expect(find.descendant(of: find.byType(TodayCard), matching: find.text(_facility)), findsNothing);
      await facilities.setFacility(id: 'f2', name: 'Kliniki ya Mifugo Arusha', type: 'Vet Clinic');
      await tester.pump();
      expect(find.text('Kliniki ya Mifugo Arusha'), findsNothing);
    }, skip: _skip);

    testWidgets('the skeleton has the same height as the card (no shift when the content arrives)', (tester) async {
      Future<double> height({required bool skeleton}) async {
        await pumpAtSize(
          tester,
          size: const Size(390, 844),
          screen: Scaffold(
            body: PhoneHome(
              skeleton: skeleton,
              figures: _figures,
              isAdmin: true,
              period: 'Today',
              onPeriodChanged: (_) {},
              attention: ph4SomeAttention,
              onAllDetails: () {},
              onAttention: () {},
            ),
          ),
        );
        return tester.getSize(find.byType(TodayCard)).height;
      }

      expect(await height(skeleton: true), await height(skeleton: false));
    }, skip: _skip);

    // UI5: the provider's current name goes to Home's top bar instead.
    test('the dashboard passes the provider\'s current name to Home\'s top bar', () {
      final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
      expect(source, contains('FacilityDisplay.name(Provider.of<FacilityProvider>(context).selectedFacilityName)'));
      expect(source, contains('facilityName: facilityName,'));
    }, skip: _skip);
  });

  group('size matrix with a very long facility name', () {
    for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360)]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('en'), Locale('sw')]) {
          testWidgets('${size.width.toInt()}x${size.height.toInt()} ${brightness.name} ${locale.languageCode}',
              (tester) async {
            await _card(tester, size: size, brightness: brightness, locale: locale, facility: matrixLongFacilityName);
            expect(tester.takeException(), isNull);
            final shown = tester.getRect(find.byType(TodayCard));
            await _tapEye(tester);
            expect(tester.takeException(), isNull);
            expect(tester.getRect(find.byType(TodayCard)), shown, reason: 'the card keeps its size hidden');
            await _tapEye(tester);
            expect(tester.getRect(find.byType(TodayCard)), shown);
          }, skip: _skip);
        }
      }
    }
    testWidgets('8-digit amounts at 360: the card keeps its size hidden and shown', (tester) async {
      await _card(tester, size: const Size(360, 740), figures: ph4BigFigures);
      final shown = tester.getRect(find.byType(TodayCard));
      await _tapEye(tester);
      expect(tester.getRect(find.byType(TodayCard)), shown);
    }, skip: _skip);
  });
}
