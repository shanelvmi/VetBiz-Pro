// UI6 (3): the Sales chart's legend shows a swatch before each entry: "Last
// n days" a solid one, "Previous n days" a DASHED one matching its dashed
// line (14 x 2, the dashes visible, the muted role at 3:1 or better on the
// page). Before UI6 the dashes were drawn 0 px high (a ColoredBox under a
// loose height). The legend stays on one line, uncut, at 360, 390 and 412
// wide in English and Kiswahili (Roboto, as on a phone), for 7 and 30 days.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/data/home_chart_range.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/color_math.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';

import 'helpers/phone_home_harness.dart';
import 'helpers/real_font.dart';
import 'helpers/screen_size_matrix.dart';

const _legend = ValueKey('home-chart-legend');
const _solid = ValueKey('home-chart-legend-solid');
const _dashed = ValueKey('home-chart-legend-dashed');
// Each dash is 'home-chart-legend-dash-<i>'.
final _dash = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('home-chart-legend-dash-'));
const _swatchWidth = 14.0;
const _swatchHeight = 2.0;

Future<void> _pump(WidgetTester tester, {double width = 390, MatrixLook look = MatrixLook.light,
    HomeChartRange range = HomeChartRange.week}) async {
  await pumpAtSize(
    tester,
    size: Size(width, 844),
    look: look,
    screen: Builder(builder: (context) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: realFontFamily)),
        child: phoneHomeHarness(charts: HarnessCharts().build(range: range)),
      );
    }),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFont);

  for (final range in HomeChartRange.values) {
    testWidgets('${range.key}: a solid and a dashed swatch, 14 x 2, before their texts', (tester) async {
      await _pump(tester, range: range);
      final n = range.days;
      for (final (key, label) in [(_solid, 'Last $n days'), (_dashed, 'Previous $n days')]) {
        final swatch = find.descendant(of: find.byKey(_legend), matching: find.byKey(key));
        expect(swatch, findsOneWidget, reason: '$key');
        final rect = tester.getRect(swatch);
        expect(rect.size, const Size(_swatchWidth, _swatchHeight));
        final text = tester.getRect(find.descendant(of: find.byKey(_legend), matching: find.text(label)));
        expect(rect.right, lessThan(text.left), reason: 'the swatch comes first');
        expect(rect.center.dy, closeTo(text.center.dy, 1), reason: 'centred on the text');
      }
      // Visible dashes: at least two, each drawn (not 0 px), with a gap.
      final dashes = find.descendant(of: find.byKey(_dashed), matching: _dash);
      expect(dashes, findsAtLeastNWidgets(2));
      final rects = [for (final e in dashes.evaluate()) tester.getRect(find.byWidget(e.widget))];
      for (final r in rects) {
        expect(r.height, _swatchHeight);
        expect(r.width, greaterThanOrEqualTo(3));
      }
      expect(rects[1].left - rects[0].right, greaterThanOrEqualTo(3), reason: 'a visible gap');
      // The dashes in the muted role (the dashed line's), at 3:1 or more.
      final colors = tester.element(find.byKey(_legend)).colors;
      for (final e in dashes.evaluate()) {
        final box = tester.widget<DecoratedBox>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(DecoratedBox)));
        expect((box.decoration as BoxDecoration).color, colors.textMuted);
      }
      expect(ColorMath.contrast(colors.textMuted, colors.surface), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('the muted role reaches 3:1 on the page in Dark too', (tester) async {
    await pumpAtSize(tester, size: const Size(390, 844), look: MatrixLook.dark,
        screen: phoneHomeHarness(charts: HarnessCharts().build()));
    await tester.pumpAndSettle();
    final colors = tester.element(find.byKey(_legend)).colors;
    expect(find.descendant(of: find.byKey(_dashed), matching: _dash), findsAtLeastNWidgets(2));
    expect(ColorMath.contrast(colors.textMuted, colors.surface), greaterThanOrEqualTo(3));
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
      for (final range in HomeChartRange.values) {
        testWidgets('$width ${look.name} ${range.key}: one line, nothing cut', (tester) async {
          await _pump(tester, width: width, look: look, range: range);
          final legend = tester.getRect(find.byKey(_legend));
          expect(legend.height, HomeChartMetrics.legendRow, reason: 'one line');
          final texts = find.descendant(of: find.byKey(_legend), matching: find.byType(RichText));
          expect(texts, findsNWidgets(2));
          for (final e in texts.evaluate()) {
            final p = e.renderObject! as RenderParagraph;
            expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
            expect(tester.getRect(find.byWidget(e.widget)).right, lessThanOrEqualTo(legend.right));
          }
          final dashed = tester.getRect(find.byKey(_dashed));
          expect(dashed.left, greaterThan(tester.getRect(texts.first).right), reason: 'both entries on the one line');
        });
      }
    }
  }
}
