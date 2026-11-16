// POL2 Step 3: SummaryCard (Home's eight wide cards, Add client's and Record
// visit's summaries) is flat: the surface with a hairline border, no
// elevation, no glow when a value changes, a neutral icon with no coloured
// circle. Its trend chip is the one StatusPill: a good change success, a bad
// one danger (by higherIsBetter, as before), new activity neutral; the
// tooltip keeps the comparison. Light and Dark, compact and wide, text scale
// 1.3; at 140 px the old chip overflowed at 1.3 (its Row had no room to shrink).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/status_pill.dart';
import 'package:vetbiz_pro/widgets/summary_card.dart';

KpiTrend _trend(double now, double before, {bool higherIsBetter = true}) => KpiTrend(
      currentValue: now,
      previousValue: before,
      higherIsBetter: higherIsBetter,
      comparisonLabel: 'vs Yesterday',
      formatChange: (v) => v.toStringAsFixed(0),
    );

Future<AppColors> _pump(WidgetTester tester, Widget card,
    {Brightness brightness = Brightness.light, double width = 300, double scale = 1}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = AppTheme.build(AppColorTheme.pasture, brightness);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, height: 140, child: card))),
    ),
  ));
  // A fixed pump: the trend arrow floated forever before POL2 (no settle).
  await tester.pump(const Duration(milliseconds: 500));
  return theme.extension<AppColors>()!;
}

SummaryCard _card({String value = '1,000', KpiTrend? trend, Color? color}) => SummaryCard(
      title: 'Total Sales',
      value: value,
      icon: Icons.shopping_cart,
      color: color ?? Colors.orange,
      shadow: true,
      trend: trend,
    );

void _noShadow(WidgetTester tester) {
  for (final b in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = b.decoration;
    if (d is BoxDecoration) {
      expect(d.boxShadow, anyOf(isNull, isEmpty));
      expect(d.gradient, isNull);
    }
  }
}

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [140.0, 300.0]) {
      testWidgets('${brightness.name} at $width wide: flat, bordered, the icon neutral, no circle', (tester) async {
        final c = await _pump(tester, _card(trend: _trend(120, 100)), brightness: brightness, width: width);
        expect(tester.takeException(), isNull);
        final card = tester.widget<Card>(find.byType(Card));
        expect(card.elevation, AppElevation.e0);
        expect(card.color, c.surface);
        expect((card.shape! as RoundedRectangleBorder).side.color, c.border);
        expect(find.byType(CircleAvatar), findsNothing);
        expect(tester.widget<Icon>(find.byIcon(Icons.shopping_cart)).color, c.textSecondary);
        _noShadow(tester);
      });
    }
  }

  testWidgets('a changed value draws no glow', (tester) async {
    await _pump(tester, _card(value: '1,000'));
    await _pump(tester, _card(value: '2,000'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      _noShadow(tester);
    }
    expect(find.text('2,000'), findsOneWidget);
  });

  for (final (name, trend, status) in [
    ('sales up', _trend(120, 100), AppStatus.success),
    ('sales down', _trend(80, 100), AppStatus.danger),
    ('expenses up (bad)', _trend(120, 100, higherIsBetter: false), AppStatus.danger),
    ('expenses down (good)', _trend(80, 100, higherIsBetter: false), AppStatus.success),
    ('new activity', _trend(50, 0), AppStatus.neutral),
  ]) {
    testWidgets('the trend chip for $name is the StatusPill in ${status.name}', (tester) async {
      await _pump(tester, _card(trend: trend));
      final pill = tester.widget<StatusPill>(find.byType(StatusPill));
      expect(pill.status, status);
      expect(find.byType(Tooltip), findsOneWidget, reason: 'the comparison stays in the tooltip');
    });
  }

  testWidgets('compact at text scale 1.3: no overflow, the value and the chip stay', (tester) async {
    await _pump(tester, _card(trend: _trend(120, 100)), width: 140, scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('1,000'), findsOneWidget);
    expect(find.byType(StatusPill), findsOneWidget);
  });
}
