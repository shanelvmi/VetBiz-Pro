// NAV1 (C): the phone Today card on the brand gradient, and its eye that
// masks the card's amounts (remembered on the device through
// UiSettingsProvider).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/config/money.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/dashboard_figures.dart';
import 'package:vetbiz_pro/screens/dashboard/today_card.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

const _skip = false;

const _figures = PhoneHomeFigures(sales: 1250000, collected: 980000, owed: 310000, netProfit: 145000);
final _amounts = [_figures.sales, _figures.collected, _figures.owed, _figures.netProfit].map(Money.format).toList();
const _key = 'ui_home_amounts_hidden';

/// The card under a UiSettingsProvider, wired as the dashboard wires it.
Future<UiSettingsProvider> _card(
  WidgetTester tester, {
  bool isAdmin = true,
  Size size = const Size(390, 844),
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
  UiSettingsProvider? settings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      reduceMotion ? const FakeAccessibilityFeatures(disableAnimations: true) : const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final provider = settings ?? UiSettingsProvider();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.build(theme, brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Consumer<UiSettingsProvider>(
            builder: (context, ui, _) => TodayCard(
              figures: _figures,
              isAdmin: isAdmin,
              period: 'Today',
              onPeriodChanged: (_) {},
              onAllDetails: () {},
              amountsHidden: ui.homeAmountsHidden,
              onToggleAmounts: () => ui.setHomeAmountsHidden(!ui.homeAmountsHidden),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return provider;
}

BoxDecoration _decoration(WidgetTester tester) => tester
    .widget<Container>(find.descendant(of: find.byType(TodayCard), matching: find.byType(Container)).first)
    .decoration! as BoxDecoration;

/// UI3: the soft blurred dots in place of each amount.
Finder get _masks => find.descendant(of: find.byType(TodayCard), matching: find.byType(ImageFiltered));

Future<void> _tapEye(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.descendant(of: find.byType(TodayCard), matching: find.byType(IconButton)));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the gradient, every theme, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        testWidgets('${theme.id} ${brightness.name}: primary to its deep tone, the inks at 4.5 at both ends',
            (tester) async {
          await _card(tester, theme: theme, brightness: brightness);
          final colors = AppColors.fromTheme(theme, brightness: brightness);
          final gradient = _decoration(tester).gradient! as LinearGradient;
          expect(gradient.colors, [colors.brandGradientStart, colors.brandGradientEnd]);
          expect(_decoration(tester).color, isNull);
          final sales = tester.widget<Text>(find.text(_amounts[0]));
          final label = tester.widget<Text>(find.text('Sales'));
          for (final end in gradient.colors) {
            expect(ColorMath.contrast(sales.style!.color!, end), greaterThanOrEqualTo(4.5));
            expect(ColorMath.contrast(Color.alphaBlend(label.style!.color!, end), end), greaterThanOrEqualTo(4.5));
          }
        }, skip: _skip);
      }
    }
  });

  testWidgets('the eye masks all four amounts and nothing else; the labels stay', (tester) async {
    await _card(tester);
    for (final amount in _amounts) {
      expect(find.text(amount), findsOneWidget);
    }
    await _tapEye(tester);
    for (final amount in _amounts) {
      expect(find.text(amount), findsNothing);
    }
    expect(_masks, findsNWidgets(4));
    for (final label in ['Sales', 'Collected', 'Owed', 'Net profit', 'Today', 'All details']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await _tapEye(tester);
    expect(_masks, findsNothing);
    for (final amount in _amounts) {
      expect(find.text(amount), findsOneWidget);
    }
  }, skip: _skip);

  testWidgets('a short cross-fade, no backdrop blur', (tester) async {
    await _card(tester);
    await _tapEye(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(_amounts[0]), findsOneWidget, reason: 'still fading out');
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpAndSettle();
    expect(_masks, findsNWidgets(4));
  }, skip: _skip);

  testWidgets('reduced motion: the mask replaces the amounts in one frame', (tester) async {
    await _card(tester, reduceMotion: true);
    await _tapEye(tester, settle: false);
    await tester.pump();
    expect(find.text(_amounts[0]), findsNothing);
    expect(_masks, findsNWidgets(4));
  }, skip: _skip);

  testWidgets('tooltip and Semantics say what a tap does; a 48 target', (tester) async {
    final semantics = tester.ensureSemantics();
    await _card(tester);
    expect(find.byTooltip('Hide amounts'), findsOneWidget);
    expect(tester.getSemantics(find.byTooltip('Hide amounts')).tooltip, 'Hide amounts');
    final size = tester.getSize(find.descendant(of: find.byType(TodayCard), matching: find.byType(IconButton)));
    expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$size');
    await _tapEye(tester);
    expect(find.byTooltip('Show amounts'), findsOneWidget);
    expect(tester.getSemantics(find.byTooltip('Show amounts')).tooltip, 'Show amounts');
    semantics.dispose();
  }, skip: _skip);

  testWidgets('remembered on the device: saved, kept across a rebuild and restored on the next start',
      (tester) async {
    final first = await _card(tester);
    expect(first.homeAmountsHidden, isFalse, reason: 'visible by default');
    await _tapEye(tester);
    expect((await SharedPreferences.getInstance()).getBool(_key), isTrue);
    await _card(tester, settings: first);
    expect(_masks, findsNWidgets(4), reason: 'a rebuild');
    // The next start: a new provider reads the saved choice.
    await _card(tester, settings: UiSettingsProvider());
    expect(_masks, findsNWidgets(4));
    await _tapEye(tester);
    expect((await SharedPreferences.getInstance()).getBool(_key), isFalse);
  }, skip: _skip);

  testWidgets('an assistant never sees Net profit, hidden or shown; hiding changes no figure', (tester) async {
    await _card(tester, isAdmin: false);
    expect(find.text('Net profit'), findsNothing);
    expect(find.text(_amounts[3]), findsNothing);
    await _tapEye(tester);
    expect(_masks, findsNWidgets(3));
    expect(find.text('Net profit'), findsNothing);
    await _tapEye(tester);
    expect(find.text(_amounts[3]), findsNothing);
    for (final amount in _amounts.take(3)) {
      expect(find.text(amount), findsOneWidget);
    }
  }, skip: _skip);

  group('size matrix', () {
    for (final size in const [Size(360, 740), Size(390, 844), Size(740, 360)]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('en'), Locale('sw')]) {
          for (final hidden in [false, true]) {
            testWidgets(
                '${size.width.toInt()}x${size.height.toInt()} ${brightness.name} ${locale.languageCode}'
                '${hidden ? ' hidden' : ''}', (tester) async {
              SharedPreferences.setMockInitialValues({_key: hidden});
              await _card(tester, size: size, brightness: brightness, locale: locale);
              expect(tester.takeException(), isNull);
              expect(_masks, hidden ? findsNWidgets(4) : findsNothing);
              final card = tester.getRect(find.byType(TodayCard));
              final eye = tester.getRect(find.descendant(of: find.byType(TodayCard), matching: find.byType(IconButton)));
              expect(card.contains(eye.topLeft) && card.contains(eye.bottomRight - const Offset(1, 1)), isTrue);
            }, skip: _skip);
          }
        }
      }
    }
  });
}
