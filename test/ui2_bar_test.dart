// UI2 (2): the phone bar keeps NAV1's look (rounded tinted top, items, line,
// keyboard rule) with a smooth trough cut into the middle of its top edge,
// drawn as one shape (fill, hairline border and shadow follow it), and a
// round 56 px "+" on the theme's brand gradient floating in the trough.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_bar_shape.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

const _skip = false;

Widget _tab(String name) => Scaffold(
      body: ListView(
        key: ValueKey('$name list'),
        children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('$name row $i'))],
      ),
    );

Completer<void>? _sheet;

Future<void> _shell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      reduceMotion ? const FakeAccessibilityFeatures(disableAnimations: true) : const FakeAccessibilityFeatures();
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  _sheet = null;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(theme, brightness),
    home: PhoneShell(
      home: (_) => _tab('home'),
      sales: (_) => _tab('sales'),
      products: (_) => _tab('products'),
      more: (_) => _tab('more'),
      onRecord: () => (_sheet = Completer<void>()).future,
    ),
  ));
  await tester.pumpAndSettle();
}

final _bar = find.byType(PhoneBottomBar);
final _shape = find.byKey(const ValueKey('phone-bar-shape'));
final _record = find.byKey(const ValueKey('phone-bar-record'));
final _fill = find.byKey(const ValueKey('phone-bar-record-fill'));

/// The tangent's direction at each half pixel of the top edge between the
/// two rounded corners.
List<double> _topEdgeAngles(Path path, Size size) {
  final angles = <double>[];
  for (final PathMetric m in path.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 0.5) {
      final t = m.getTangentForOffset(d)!;
      final p = t.position;
      if (p.dy < PhoneShellMetrics.troughDepth + 2 && p.dx > PhoneShellMetrics.barRadius && p.dx < size.width - PhoneShellMetrics.barRadius) {
        angles.add(t.angle);
      }
    }
  }
  return angles;
}

void main() {
  group('the shape', () {
    const size = Size(390, 98);
    final path = phoneBarPath(size, centerX: 195);

    test('a trough at the centre: its bottom about 34 below the top edge, about 92 wide', () {
      const depth = PhoneShellMetrics.troughDepth;
      expect(path.contains(const Offset(195, depth - 0.5)), isFalse, reason: 'in the trough');
      expect(path.contains(const Offset(195, depth + 0.5)), isTrue, reason: 'the bar under it');
      expect(depth, closeTo(34, 2));
      final width = phoneTroughWidth();
      expect(width, inInclusiveRange(84, 96));
      expect(path.contains(Offset(195 - width / 2 - 2, 0.5)), isTrue, reason: 'flat top beside it');
      expect(path.contains(Offset(195 + width / 2 + 2, 0.5)), isTrue);
      expect(path.contains(Offset(195 - width / 2 + 6, 0.5)), isFalse, reason: 'its opening');
      expect(path.contains(const Offset(10, 2)), isFalse, reason: 'the rounded corner');
      expect(path.contains(const Offset(10, 30)), isTrue);
    });

    test('smooth: the edge never turns more than 6 degrees in half a pixel', () {
      final angles = _topEdgeAngles(path, size);
      expect(angles.length, greaterThan(500));
      for (var i = 1; i < angles.length; i++) {
        var turn = (angles[i] - angles[i - 1]).abs();
        if (turn > math.pi) turn = 2 * math.pi - turn;
        expect(turn, lessThan(6 * math.pi / 180), reason: 'at sample $i');
      }
    });

    test('the trough holds the button with the gap all round its lower half', () {
      final r = PhoneShellMetrics.recordSize / 2 + PhoneShellMetrics.troughGap;
      final centreY = PhoneShellMetrics.troughDepth - r;
      for (var a = 0.0; a <= math.pi; a += math.pi / 36) {
        final p = Offset(195 + (r - 0.5) * math.cos(a), centreY + (r - 0.5) * math.sin(a));
        expect(path.contains(p), isFalse, reason: 'inside the trough at ${(a * 180 / math.pi).round()} degrees');
      }
    });
  });

  for (final width in const [360.0, 390.0, 412.0]) {
    testWidgets('$width wide: the + centred within a pixel, floating, clear of its neighbours', (tester) async {
      await _shell(tester, size: Size(width, 844));
      final shape = tester.getRect(_shape);
      expect(shape, Rect.fromLTWH(0, 844 - 64 - 34, width, 64 + 34), reason: 'the drawn bar: 64 plus the home indicator');
      final record = tester.getRect(_record);
      expect(record.size, const Size(56, 56));
      expect(record.center.dx, closeTo(width / 2, 1));
      expect(shape.top - record.top, closeTo(PhoneShellMetrics.recordLift, 0.5), reason: 'raised above the top edge');
      expect(shape.top + PhoneShellMetrics.troughDepth - record.bottom, closeTo(PhoneShellMetrics.troughGap, 0.5));
      final row = find.descendant(of: _bar, matching: find.byType(Row)).first;
      final slots = find.descendant(of: row, matching: find.byType(Expanded));
      expect(slots, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(tester.getSize(slots.at(i)).width, closeTo(width / 5, 0.01));
      }
      expect(record.left, greaterThan(tester.getRect(slots.at(1)).right), reason: 'clear of Sales');
      expect(record.right, lessThan(tester.getRect(slots.at(3)).left), reason: 'clear of Products');
      expect(find.descendant(of: slots.at(2), matching: find.byType(InkWell)), findsNothing, reason: 'the centre slot is empty');
      expect(tester.getSize(find.bySemanticsLabel('Record')), const Size(56, 56), reason: 'the target: the whole circle');
    }, skip: _skip);
  }

  testWidgets('nothing in the trough takes a tap but the button', (tester) async {
    await _shell(tester);
    final shape = tester.getRect(_shape);
    final inTrough = Offset(195 - 33, shape.top + 4);
    final result = HitTestResult();
    tester.binding.hitTestInView(result, inTrough, tester.view.viewId);
    final shapeBox = tester.renderObject(_shape);
    expect(result.path.where((e) => e.target == shapeBox), isEmpty);
    await tester.tapAt(inTrough);
    await tester.pumpAndSettle();
    expect(_sheet, isNull);
    await tester.tapAt(tester.getCenter(_record));
    await tester.pumpAndSettle();
    expect(_sheet, isNotNull);
    _sheet!.complete();
  }, skip: _skip);

  testWidgets('the fill, the hairline border and the soft shadow all follow the trough', (tester) async {
    await _shell(tester);
    final colors = AppColors.fromTheme(AppColorTheme.pasture);
    const trough = Offset(195, 20);
    const under = Offset(195, 50);
    const side = Offset(60, 30);
    expect(
      _shape,
      paints
        ..path(includes: const [under, side], excludes: const [trough])
        ..path(includes: const [under, side], excludes: const [trough], color: colors.navBarFill)
        ..path(includes: const [under, side], excludes: const [trough], style: PaintingStyle.stroke),
    );
  }, skip: _skip);

  group('the gradient and the icon, every theme, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        testWidgets('${theme.id} ${brightness.name}', (tester) async {
          await _shell(tester, theme: theme, brightness: brightness);
          final colors = AppColors.fromTheme(theme, brightness: brightness);
          final decoration = tester.widget<DecoratedBox>(_fill).decoration as ShapeDecoration;
          expect(decoration.shape, const CircleBorder());
          expect((decoration.gradient! as LinearGradient).colors, [colors.brandGradientStart, colors.brandGradientEnd]);
          expect(decoration.shadows, hasLength(1));
          final icon = tester.widget<Icon>(find.descendant(of: _record, matching: find.byType(Icon)));
          expect(icon.color, colors.onBrandSurface);
          expect(icon.color, isNot(colors.accent));
          for (final end in [colors.brandGradientStart, colors.brandGradientEnd]) {
            expect(ColorMath.contrast(icon.color!, end), greaterThanOrEqualTo(4.5));
          }
        }, skip: _skip);
      }
    }
  });

  testWidgets('the plus turns to a cross while the sheet is open; at once under reduced motion', (tester) async {
    await _shell(tester);
    AnimatedRotation rotation() => tester.widget<AnimatedRotation>(find.descendant(of: _record, matching: find.byType(AnimatedRotation)));
    expect(rotation().turns, 0);
    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pumpAndSettle();
    expect(rotation().turns, PhoneShellMetrics.recordOpenTurns);
    _sheet!.complete();
    await tester.pumpAndSettle();
    expect(rotation().turns, 0);

    await _shell(tester, reduceMotion: true);
    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pump();
    expect(rotation().duration, Duration.zero);
    expect(rotation().turns, PhoneShellMetrics.recordOpenTurns);
    _sheet!.complete();
  }, skip: _skip);

  testWidgets('the keyboard hides the bar and the +', (tester) async {
    await _shell(tester, keyboard: 300);
    expect(_bar, findsNothing);
    expect(_record, findsNothing);
  }, skip: _skip);

  testWidgets('the last row is fully visible above the bar and the raised +', (tester) async {
    await _shell(tester);
    await tester.drag(find.byKey(const ValueKey('home list')), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.text('home row 39'));
    expect(last.bottom, lessThanOrEqualTo(tester.getRect(_record).top));
  }, skip: _skip);

  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: no bar', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PhoneOrWide(
          phone: (_) => PhoneShell(
            home: (_) => _tab('home'),
            sales: (_) => _tab('sales'),
            products: (_) => _tab('products'),
            more: (_) => _tab('more'),
            onRecord: () {},
          ),
          wide: (_) => const Text('WIDE'),
        ),
      ));
      expect(_bar, findsNothing);
      expect(_record, findsNothing);
    }, skip: _skip);
  }
}
