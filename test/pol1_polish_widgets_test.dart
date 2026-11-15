// POL1 Step B: the shared consistency widgets (lib/ui/polish). Roles in light
// and dark, the word always shown (never colour alone), text scale 1.3, no
// gradient and no shadow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/polish_metrics.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/ui/polish/flat_stat_card.dart';
import 'package:vetbiz_pro/ui/polish/section_label.dart';

Future<AppColors> _pump(WidgetTester tester, Widget child,
    {Brightness brightness = Brightness.light, double scale = 1, double width = 390}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = AppTheme.build(AppColorTheme.pasture, brightness);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    ),
  ));
  return theme.extension<AppColors>()!;
}

Color _dotColor(WidgetTester tester) => ((tester
            .widget<DecoratedBox>(find.descendant(of: find.byKey(const ValueKey('statusDot-dot')), matching: find.byType(DecoratedBox)))
            .decoration as BoxDecoration)
        .color)!;

void _noGradientOrShadow(WidgetTester tester) {
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = box.decoration;
    if (d is BoxDecoration) {
      expect(d.gradient, isNull);
      expect(d.boxShadow, anyOf(isNull, isEmpty));
    }
  }
  for (final m in tester.widgetList<Material>(find.byType(Material))) {
    if (m.type != MaterialType.canvas) expect(m.elevation, 0);
  }
}

void main() {
  group('StatusDot', () {
    for (final brightness in Brightness.values) {
      testWidgets('each state uses its role, the word in textPrimary ($brightness)', (tester) async {
        for (final s in AppStatus.values) {
          final c = await _pump(tester, StatusDot(status: s, label: 'Word ${s.name}'), brightness: brightness);
          final role = switch (s) {
            AppStatus.success => c.success,
            AppStatus.warning => c.warning,
            AppStatus.danger => c.danger,
            AppStatus.neutral => c.textSecondary,
          };
          expect(_dotColor(tester), role);
          final word = tester.widget<Text>(find.text('Word ${s.name}'));
          expect(word.style!.color, c.textPrimary);
          expect(word.style!.fontSize, PolishMetrics.statusText);
        }
      });
    }

    testWidgets('the dot is 8 px and the word is always there, at text scale 1.3', (tester) async {
      await _pump(tester, const StatusDot(status: AppStatus.danger, label: 'Rejected'), scale: 1.3);
      expect(tester.getSize(find.byKey(const ValueKey('statusDot-dot'))), const Size(8, 8));
      expect(find.text('Rejected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FlatStatCard', () {
    for (final brightness in Brightness.values) {
      testWidgets('surface, hairline border role, no gradient, glow or shadow ($brightness)', (tester) async {
        final c = await _pump(tester, const SizedBox(width: 200, child: FlatStatCard(label: 'Sales', value: '12', hint: 'today')),
            brightness: brightness);
        final material = tester.widget<Material>(find.descendant(of: find.byType(FlatStatCard), matching: find.byType(Material)));
        expect(material.color, c.surface);
        expect(material.elevation, 0);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, c.border);
        expect(shape.side.width, PolishMetrics.hairline);
        expect(shape.borderRadius, BorderRadius.circular(PolishMetrics.cardRadius));
        expect(tester.widget<Text>(find.text('12')).style!.color, c.textPrimary);
        expect(tester.widget<Text>(find.text('Sales')).style!.color, c.textSecondary);
        _noGradientOrShadow(tester);
      });
    }

    testWidgets('selected: the primary border; text scale 1.3 fits', (tester) async {
      final c = await _pump(tester, const SizedBox(width: 160, child: FlatStatCard(label: 'Pending', value: '3', selected: true)),
          scale: 1.3);
      final material = tester.widget<Material>(find.descendant(of: find.byType(FlatStatCard), matching: find.byType(Material)));
      expect((material.shape! as RoundedRectangleBorder).side.color, c.primary);
      expect(tester.takeException(), isNull);
    });
  });

  group('FilterRow', () {
    Widget row(String selected, ValueChanged<String> onSelected) => FilterRow(
          values: const ['all', 'unread', 'stock'],
          selected: selected,
          keyPrefix: 'f-',
          label: (v) => 'Label $v',
          count: (v) => v == 'stock' ? null : (v == 'all' ? 12 : 3),
          onSelected: onSelected,
        );

    for (final brightness in Brightness.values) {
      testWidgets('the chosen segment in primary with an underline, the others secondary ($brightness)', (tester) async {
        final c = await _pump(tester, row('unread', (_) {}), brightness: brightness);
        expect(tester.widget<Text>(find.text('Label unread')).style!.color, c.primary);
        expect(tester.widget<Text>(find.text('Label all')).style!.color, c.textSecondary);
        BorderSide underline(String v) =>
            ((tester.widget<Container>(find.descendant(of: find.byKey(ValueKey('f-$v')), matching: find.byType(Container)).first)
                        .decoration! as BoxDecoration)
                    .border! as Border)
                .bottom;
        expect(underline('unread').color, c.primary);
        expect(underline('unread').width, PolishMetrics.filterUnderline);
        expect(underline('all').color, Colors.transparent);
        _noGradientOrShadow(tester);
      });
    }

    testWidgets('counts are shown after their label; a null count shows none; a tap passes the stored value', (tester) async {
      String? tapped;
      await _pump(tester, row('all', (v) => tapped = v));
      expect(tester.widget<Text>(find.byKey(const ValueKey('f-all-count'))).data, '12');
      expect(tester.widget<Text>(find.byKey(const ValueKey('f-unread-count'))).data, '3');
      expect(find.byKey(const ValueKey('f-stock-count')), findsNothing);
      // The test font is wide: the last segment is reached by scrolling.
      await tester.ensureVisible(find.byKey(const ValueKey('f-stock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('f-stock')));
      expect(tapped, 'stock');
    });

    testWidgets('each segment is a 48 px tap target; on a narrow phone at text scale 1.3 it scrolls, no overflow', (tester) async {
      await _pump(tester, row('all', (_) {}), width: 200, scale: 1.3);
      expect(tester.getSize(find.byKey(const ValueKey('f-all'))).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });

  group('SectionLabel', () {
    for (final brightness in Brightness.values) {
      testWidgets('secondary text, one size, a header for screen readers ($brightness)', (tester) async {
        final c = await _pump(tester, const SectionLabel('Earlier'), brightness: brightness);
        final t = tester.widget<Text>(find.text('Earlier'));
        expect(t.style!.color, c.textSecondary);
        expect(t.style!.fontSize, PolishMetrics.sectionLabel);
        final handle = tester.ensureSemantics();
        expect(tester.getSemantics(find.text('Earlier')), matchesSemantics(label: 'Earlier', isHeader: true));
        handle.dispose();
      });
    }
  });
}
