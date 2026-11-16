// POL2 Step 2: Insights without its gradient and glows. The Business pulse
// card and the three chart cards are flat surfaces with a hairline border;
// the pulse keeps its title, headline and sentence (its read is in words,
// no live state, so no dot is added), its icon is neutral with no tinted
// tile; the charts keep their palette. Phone and wide, Light and Dark, text
// scale 1.3 with reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/insights_screen.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';

import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart' show MatrixLook;

const _pulse = ValueKey('pulse-content');

Future<void> _pump(WidgetTester tester, Size size, {MatrixLook look = MatrixLook.light, bool reduceMotion = false}) async {
  await pumpPh5(tester, (fs) => InsightsScreen(firestore: fs), size: size, look: look, pushed: true, reduceMotion: reduceMotion);
  await ph5SettleUntil(tester, () => find.byKey(_pulse).evaluate().isNotEmpty);
  expect(find.byKey(_pulse), findsOneWidget, reason: 'the Business pulse card is shown');
}

void _flat(WidgetTester tester) {
  final colors = Theme.of(tester.element(find.byType(InsightsScreen))).extension<AppColors>()!;
  var cards = 0;
  for (final c in tester.widgetList<Container>(find.descendant(of: find.byType(InsightsScreen), matching: find.byType(Container)))) {
    final d = c.decoration;
    if (d is! BoxDecoration) continue;
    expect(d.gradient, isNull, reason: '$c');
    expect(d.boxShadow, anyOf(isNull, isEmpty), reason: '$c');
    if (d.border != null) {
      expect(d.color, colors.surface);
      expect((d.border! as Border).top.color, colors.border);
      cards++;
    }
  }
  // The list builds what is in view: the pulse and at least one chart card.
  expect(cards, greaterThanOrEqualTo(2), reason: 'the pulse and the chart cards in view');
}

void main() {
  for (final (where, size) in [('phone', const Size(390, 844)), ('wide', const Size(1200, 800))]) {
    for (final look in [MatrixLook.light, MatrixLook.dark]) {
      ph5TestWidgets('$where ${look.name}: the pulse and the chart cards are flat, with a hairline border', (tester) async {
        await _pump(tester, size, look: look);
        expect(tester.takeException(), isNull);
        _flat(tester);
        final colors = Theme.of(tester.element(find.byType(InsightsScreen))).extension<AppColors>()!;
        expect(find.text('Business Pulse'), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('pulse-headline'))).style!.color, colors.textPrimary);
        expect(tester.widget<Icon>(find.byIcon(Icons.monitor_heart_outlined)).color, colors.textSecondary);
      });
    }
  }

  ph5TestWidgets('phone 360x640 at text scale 1.3 with reduced motion: no overflow, the pulse stays', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const Size(360, 640), reduceMotion: true);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pulse-headline')), findsOneWidget);
  });
}
