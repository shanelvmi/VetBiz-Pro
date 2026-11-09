// UI4: no dead band: the shell reserves only the bar's own height; the
// button's small overhang is room inside each tab's scroll view, not a strip
// kept empty above the bar.
import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/dashboard/more_parts.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'helpers/ui4_shell.dart';

const _skip = false;

void main() {
  group('no dead band: the page reaches the bar\'s top edge beside the +', () {
    for (final theme in const [AppColorTheme.pasture, AppColorTheme.clinic]) {
      for (final brightness in Brightness.values) {
        testWidgets('${theme.id} ${brightness.name}', (tester) async {
          await ui4Shell(tester, theme: theme, brightness: brightness);
          final shape = tester.getRect(ui4Shape);
          expect(shape, Rect.fromLTWH(0, 844 - 64 - 34, 390, 64 + 34), reason: 'the drawn bar: 64 plus the home indicator');
          expect(tester.getRect(ui4Bar), shape, reason: 'the shell reserves only the bar');
          expect(tester.getRect(find.byKey(const ValueKey('home list'))).bottom, shape.top);
          for (final x in [40.0, 350.0]) {
            final result = HitTestResult();
            tester.binding.hitTestInView(result, Offset(x, shape.top - 4), tester.view.viewId);
            final list = tester.renderObject(find.byKey(const ValueKey('home list')));
            expect(result.path.any((e) => e.target == list), isTrue, reason: 'the page at $x, just above the bar');
          }
          expect(ui4SeenOverhang, PhoneShellMetrics.buttonRaise);
        }, skip: _skip);
      }
    }
  });

  for (final tab in const ['Sales', 'Home', 'More']) {
    testWidgets('$tab: after scrolling to the end the last row is clear of the button', (tester) async {
      await ui4Shell(tester, size: const Size(390, 640), real: true);
      if (tab != 'Home') {
        await tester.tap(find.descendant(of: ui4Bar, matching: find.text(tab)));
        await tester.pumpAndSettle();
      }
      final scroll = find.byType(Scrollable).hitTestable().first;
      await tester.drag(scroll, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final last = switch (tab) {
        'Sales' => tester.getRect(find.text('Sales row 29')),
        // UI5: the action grid is Home's last block (the strip is under the card).
        'Home' => tester.getRect(find.byType(HomeActionGrid)),
        _ => tester.getRect(find.byWidgetPredicate((w) => w is MoreSectionGrid).last),
      };
      final record = tester.getRect(ui4Record);
      expect(last.bottom, lessThanOrEqualTo(record.top - PhoneListMetrics.pagePadding + 0.5), reason: 'the page\'s own room, then the overhang');
    }, skip: _skip);
  }

  testWidgets('the keyboard hides the bar and the +, and the overhang is gone', (tester) async {
    await ui4Shell(tester, keyboard: 300);
    expect(ui4Bar, findsNothing);
    expect(ui4Record, findsNothing);
    expect(ui4SeenOverhang, 0);
  }, skip: _skip);

  testWidgets('a pushed screen has no bar and no overhang', (tester) async {
    await ui4Shell(tester);
    double? pushed;
    Navigator.of(tester.element(find.byKey(const ValueKey('home list')))).push(MaterialPageRoute<void>(builder: (context) {
      pushed = PhoneShellInsets.overhangOf(context);
      return const Scaffold(body: Text('DEEP'));
    }));
    await tester.pumpAndSettle();
    expect(find.text('DEEP'), findsOneWidget);
    expect(pushed, 0);
    expect(ui4Bar.hitTestable(), findsNothing);
  }, skip: _skip);

  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: no bar', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PhoneOrWide(
          phone: (_) => PhoneShell(home: (_) => ui4Plain('home'), sales: (_) => ui4Plain('s'), products: (_) => ui4Plain('p'), more: (_) => ui4Plain('m'), onRecord: () {}),
          wide: (_) => const Text('WIDE'),
        ),
      ));
      expect(ui4Bar, findsNothing);
      expect(ui4Record, findsNothing);
    }, skip: _skip);
  }
}
