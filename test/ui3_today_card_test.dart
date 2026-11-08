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
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/utils/facility_display.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/screen_size_matrix.dart';

const _skip = true; // UI3: until the implementation

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
  SharedPreferences.setMockInitialValues({'ui_home_amounts_hidden': hidden});
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
              facilityName: FacilityDisplay.name(f.selectedFacilityName),
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
      for (final t in _cardTexts(tester)) {
        expect(RegExp(r'\d').hasMatch(t), isFalse, reason: t);
      }
      for (final amount in _amounts) {
        expect(find.textContaining(amount), findsNothing);
      }
      expect(find.bySemanticsLabel(RegExp(r'\d')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Amount hidden')), findsNWidgets(4));
      semantics.dispose();
    }, skip: _skip);

    testWidgets('the eye masks the four amounts and nothing else; the labels and the name stay', (tester) async {
      await _card(tester);
      await _tapEye(tester);
      for (final label in ['Sales', 'Collected', 'Owed', 'Net profit', 'Today', 'All details', _facility]) {
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

  group('(2) the facility name', () {
    testWidgets('the name alone, a small muted line at the top, above the Sales row', (tester) async {
      await _card(tester);
      final name = find.text(_facility);
      expect(name, findsOneWidget);
      final text = tester.widget<Text>(name);
      expect(text.style!.fontSize, AppFontSize.f12);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      final colors = AppColors.fromTheme(AppColorTheme.pasture);
      expect(text.style!.color, colors.onBrandSurfaceMuted);
      expect(tester.getRect(name).bottom, lessThanOrEqualTo(tester.getRect(find.text('Sales')).top));
      expect(find.descendant(of: find.byType(TodayCard), matching: find.byIcon(Icons.store_outlined)), findsNothing);
      // One small line only: the card's top padding, the line, then the row.
      final card = tester.getRect(find.byType(TodayCard));
      expect(tester.getRect(name).top - card.top, closeTo(PhoneHomeMetrics.cardPadding, 0.5));
    }, skip: _skip);

    testWidgets('follows the active facility: changes at once after a switch', (tester) async {
      final facilities = await _card(tester);
      await facilities.setFacility(id: 'f2', name: 'Kliniki ya Mifugo Arusha', type: 'Vet Clinic');
      await tester.pump();
      expect(find.text('Kliniki ya Mifugo Arusha'), findsOneWidget);
      expect(find.text(_facility), findsNothing);
    }, skip: _skip);

    testWidgets('the skeleton has the same height as the card (no shift when the content arrives)', (tester) async {
      Future<double> height({required bool skeleton}) async {
        await pumpAtSize(
          tester,
          size: const Size(390, 844),
          screen: Scaffold(
            body: PhoneHome(
              skeleton: skeleton,
              facilityName: matrixLongFacilityName,
              figures: _figures,
              isAdmin: true,
              period: 'Today',
              onPeriodChanged: (_) {},
              attention: ph4SomeAttention,
              onAllDetails: () {},
              onQuickAction: (_) async {},
              onViewAll: () {},
              onGoTo: (_) {},
              onAttention: (_) {},
            ),
          ),
        );
        return tester.getSize(find.byType(TodayCard)).height;
      }

      expect(await height(skeleton: true), await height(skeleton: false));
    }, skip: _skip);

    test('the dashboard passes the provider\'s current name to the phone Home', () {
      final source = File('lib/screens/dashboard/dashboard_screen.dart').readAsStringSync();
      expect(source, contains('facilityName: FacilityDisplay.name(facilityProvider.selectedFacilityName)'));
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
            final name = tester.getRect(find.text(matrixLongFacilityName));
            expect(name.right, lessThanOrEqualTo(shown.right));
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
