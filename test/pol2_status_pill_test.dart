// POL2: StatusPill, the one low-opacity pill (owner rule 3). The same word
// size, word weight and dot gap as StatusDot, the pill padding and radius
// from PolishMetrics, the state's role at low opacity behind it; the word is
// always shown; an icon may take the dot's place. Light and Dark, text scale
// 1.3, no gradient and no shadow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/status_pill.dart';

Future<AppColors> _pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light, double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = AppTheme.build(AppColorTheme.pasture, brightness);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(size: const Size(360, 640), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    ),
  ));
  return theme.extension<AppColors>()!;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('each state: its role at low opacity, the dot in the role, the word as StatusDot\'s (${brightness.name})', (tester) async {
      for (final s in AppStatus.values) {
        final c = await _pump(tester, StatusPill(status: s, label: 'Word ${s.name}'), brightness: brightness);
        final role = s.roleIn(c);
        final pill = tester.widget<Container>(find.byType(Container).first);
        final d = pill.decoration! as BoxDecoration;
        expect(d.color, role.withValues(alpha: PolishMetrics.pillAlpha), reason: s.name);
        expect(d.borderRadius, BorderRadius.circular(PolishMetrics.pillRadius));
        expect(d.gradient, isNull);
        expect(d.boxShadow, isNull);
        expect(pill.padding,
            const EdgeInsets.symmetric(horizontal: PolishMetrics.pillPaddingH, vertical: PolishMetrics.pillPaddingV));
        final dot = tester.widget<DecoratedBox>(
            find.descendant(of: find.byKey(const ValueKey('statusPill-dot')), matching: find.byType(DecoratedBox)));
        expect((dot.decoration as BoxDecoration).color, role);
        expect(tester.getSize(find.byKey(const ValueKey('statusPill-dot'))), const Size.square(PolishMetrics.dot));
        final word = tester.widget<Text>(find.text('Word ${s.name}'));
        expect(word.style!.fontSize, PolishMetrics.statusText);
        expect(word.style!.color, c.textPrimary);
        final gap = tester.getTopLeft(find.text('Word ${s.name}')).dx -
            tester.getTopRight(find.byKey(const ValueKey('statusPill-dot'))).dx;
        expect(gap, PolishMetrics.dotGap);
      }
    });
  }

  testWidgets('an icon takes the dot\'s place, in the role, the word still shown', (tester) async {
    final c = await _pump(tester, const StatusPill(status: AppStatus.success, label: 'up 12%', icon: Icons.arrow_upward));
    expect(find.byKey(const ValueKey('statusPill-dot')), findsNothing);
    expect(tester.widget<Icon>(find.byKey(const ValueKey('statusPill-icon'))).color, c.success);
    expect(find.text('up 12%'), findsOneWidget);
  });

  testWidgets('text scale 1.3 in a narrow slot: no overflow, the word ends in an ellipsis', (tester) async {
    await _pump(
        tester,
        const SizedBox(width: 90, child: Row(children: [Flexible(child: StatusPill(status: AppStatus.danger, label: 'down 40% vs yesterday'))])),
        scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.textContaining('down')).overflow, TextOverflow.ellipsis);
  });
}
