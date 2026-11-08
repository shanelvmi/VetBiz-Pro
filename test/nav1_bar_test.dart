// NAV1 (B): the restyled phone bottom bar, with fake tab roots (as
// ph3_phone_shell_test).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_shell.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_icons.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_text.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/color_math.dart';

const _skip = true;

/// The slots, left to right (null is the +), and the cross the plus turns to.
const _slots = [PhoneTab.home, PhoneTab.sales, null, PhoneTab.products, PhoneTab.more];
const _cross = 0.125;

Widget _tab(String name) => Scaffold(
      body: ListView(
        key: ValueKey('$name list'),
        children: [
          for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('$name row $i')),
        ],
      ),
    );

Completer<void>? _sheet;

Future<void> _shell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double homeIndicator = 34,
  double keyboard = 0,
  AppColorTheme theme = AppColorTheme.pasture,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: homeIndicator);
  tester.view.viewPadding = FakeViewPadding(bottom: homeIndicator);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      reduceMotion ? const FakeAccessibilityFeatures(disableAnimations: true) : const FakeAccessibilityFeatures();
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  _sheet = null;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
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
Finder _label(String text) => find.descendant(of: _bar, matching: find.text(text));
final _line = find.byKey(const ValueKey('phone-bar-active-line'));
final _record = find.byKey(const ValueKey('phone-bar-record'));

const _labels = {PhoneTab.home: 'Home', PhoneTab.sales: 'Sales', PhoneTab.products: 'Products', PhoneTab.more: 'More'};
const _icons = {
  PhoneTab.home: AppIcons.home,
  PhoneTab.sales: AppIcons.sales,
  PhoneTab.products: AppIcons.products,
  PhoneTab.more: AppIcons.more,
};

Icon _iconOf(WidgetTester tester, PhoneTab tab) => tester.widget<Icon>(find.descendant(
      of: find.ancestor(of: _label(_labels[tab]!), matching: find.byType(Column)).first,
      matching: find.byType(Icon),
    ));

void main() {
  testWidgets('the bar: docked at the bottom, 64 high plus the home indicator, the full width', (tester) async {
    await _shell(tester);
    expect(tester.getRect(_bar), const Rect.fromLTWH(0, 844 - 64 - 34, 390, 64 + 34));
  }, skip: _skip);

  testWidgets('rounded upper corners (20), the navBarFill tint and a very light shadow', (tester) async {
    await _shell(tester);
    final colors = AppColors.fromTheme(AppColorTheme.pasture);
    final material = tester.widget<Material>(find.descendant(of: _bar, matching: find.byType(Material)).first);
    expect(material.color, colors.navBarFill);
    expect(material.borderRadius, const BorderRadius.vertical(top: Radius.circular(20)));
    final shadow = (tester.widget<DecoratedBox>(find.descendant(of: _bar, matching: find.byType(DecoratedBox)).first)
            .decoration as BoxDecoration)
        .boxShadow!
        .single;
    expect(shadow.color.a, lessThanOrEqualTo(0.1), reason: 'very light');
    expect(shadow.offset.dy, lessThan(0), reason: 'cast upwards');
  }, skip: _skip);

  testWidgets('five equal slots; one icon size and one label size; the labels on one baseline', (tester) async {
    await _shell(tester);
    final row = find.descendant(of: _bar, matching: find.byType(Row)).first;
    final slots = find.descendant(of: row, matching: find.byType(Expanded));
    expect(slots, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      expect(tester.getSize(slots.at(i)).width, closeTo(390 / 5, 0.01));
    }
    final bottoms = <double>{};
    for (final tab in PhoneTab.values) {
      expect(_iconOf(tester, tab).size, 24);
      expect(tester.widget<Text>(_label(_labels[tab]!)).style!.fontSize, 12);
      bottoms.add(tester.getRect(_label(_labels[tab]!)).bottom);
    }
    expect(bottoms, hasLength(1));
  }, skip: _skip);

  for (final tab in PhoneTab.values) {
    testWidgets('${tab.name} selected: its filled icon and semibold label in primary, the line above it', (tester) async {
      await _shell(tester);
      await tester.tap(_label(_labels[tab]!));
      await tester.pumpAndSettle();
      final colors = AppColors.fromTheme(AppColorTheme.pasture);
      for (final other in PhoneTab.values) {
        final icon = _iconOf(tester, other);
        final text = tester.widget<Text>(_label(_labels[other]!));
        if (other == tab) {
          expect(icon.icon, _icons[other]!.filled);
          expect(icon.color, colors.primary);
          expect(text.style!.color, colors.primary);
          expect(text.style!.fontWeight, AppFontWeight.semibold);
        } else {
          expect(icon.icon, _icons[other]!.outlined);
          expect(icon.color, colors.navBarInactive);
          expect(text.style!.color, colors.navBarInactive);
        }
      }
      final line = tester.getRect(_line);
      final bar = tester.getRect(_bar);
      final slot = 390 / 5;
      final index = _slots.indexOf(tab);
      expect(line.size, const Size(20, 3));
      expect(line.top, bar.top);
      expect(line.center.dx, closeTo(slot * (index + 0.5), 0.01));
      expect(find.byType(Container).evaluate().where((e) {
        final w = e.widget as Container;
        return w.constraints?.maxWidth == 56 && w.constraints?.maxHeight == 32;
      }), isEmpty, reason: 'no pill');
    }, skip: _skip);
  }

  testWidgets('the line slides (and fades in) to the new item; at once under reduced motion', (tester) async {
    await _shell(tester);
    await tester.tap(_label('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final mid = tester.getRect(_line).center.dx;
    expect(mid, greaterThan(390 / 10));
    expect(mid, lessThan(390 / 5 * 4.5));
    await tester.pumpAndSettle();
    expect(tester.getRect(_line).center.dx, closeTo(390 / 5 * 4.5, 0.01));

    await _shell(tester, reduceMotion: true);
    await tester.tap(_label('More'));
    await tester.pump();
    expect(tester.getRect(_line).center.dx, closeTo(390 / 5 * 4.5, 0.01));
  }, skip: _skip);

  group('contrast on the tinted fill, every theme, Light and Dark', () {
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        testWidgets('${theme.id} ${brightness.name}', (tester) async {
          await _shell(tester, theme: theme, brightness: brightness);
          final colors = AppColors.fromTheme(theme, brightness: brightness);
          final fill = tester.widget<Material>(find.descendant(of: _bar, matching: find.byType(Material)).first).color!;
          expect(fill, colors.navBarFill);
          final active = _iconOf(tester, PhoneTab.home).color!;
          final inactive = _iconOf(tester, PhoneTab.sales).color!;
          expect(ColorMath.contrast(active, fill), greaterThanOrEqualTo(4.5));
          expect(ColorMath.contrast(inactive, fill), greaterThanOrEqualTo(4.5), reason: 'labels share the icon ink');
        }, skip: _skip);
      }
    }
  });

  testWidgets('the +: a 56 squircle (radius 20) in accent with a soft shadow, a 48+ target labelled Record', (tester) async {
    await _shell(tester);
    final colors = AppColors.fromTheme(AppColorTheme.pasture);
    final material = tester.widget<Material>(_record);
    expect(material.color, colors.accent);
    final shape = material.shape as RoundedSuperellipseBorder;
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(20)));
    expect(tester.getSize(_record), const Size(56, 56));
    final decoration = tester.widget<DecoratedBox>(find.ancestor(of: _record, matching: find.byType(DecoratedBox)).first)
        .decoration as ShapeDecoration;
    expect(decoration.shadows, hasLength(1));
    final target = tester.getSize(find.bySemanticsLabel('Record'));
    expect(target.width >= 48 && target.height >= 48, isTrue);
    expect(tester.getRect(_record).top, greaterThanOrEqualTo(tester.getRect(_bar).top), reason: 'inside the bar');
  }, skip: _skip);

  testWidgets('the plus turns to a cross while the sheet is open, and back when it closes', (tester) async {
    await _shell(tester);
    double turns() => tester.widget<AnimatedRotation>(find.descendant(of: _record, matching: find.byType(AnimatedRotation))).turns;
    expect(turns(), 0);
    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pumpAndSettle();
    expect(turns(), _cross);
    _sheet!.complete();
    await tester.pumpAndSettle();
    expect(turns(), 0);
  }, skip: _skip);

  testWidgets('reduced motion: the cross appears at once', (tester) async {
    await _shell(tester, reduceMotion: true);
    await tester.tap(find.bySemanticsLabel('Record'));
    await tester.pump();
    final rotation = tester.widget<AnimatedRotation>(find.descendant(of: _record, matching: find.byType(AnimatedRotation)));
    expect(rotation.duration, Duration.zero);
    expect(rotation.turns, _cross);
    _sheet!.complete();
  }, skip: _skip);

  for (final size in const [Size(360, 740), Size(390, 844)]) {
    testWidgets('Kiswahili at ${size.width.toInt()}: every label one line, ellipsis, inside its slot', (tester) async {
      await _shell(tester, size: size, locale: const Locale('sw'));
      expect(tester.takeException(), isNull);
      final texts = find.descendant(of: _bar, matching: find.byType(Text));
      for (final element in texts.evaluate()) {
        final text = element.widget as Text;
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.getSize(find.byWidget(text)).width, lessThanOrEqualTo(size.width / 5));
      }
    }, skip: _skip);
  }

  testWidgets('nothing hides behind the bar: the last row is fully visible above it', (tester) async {
    await _shell(tester);
    await tester.drag(find.byKey(const ValueKey('home list')), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.text('home row 39'));
    expect(last.bottom, lessThanOrEqualTo(tester.getRect(_bar).top));
  }, skip: _skip);

  testWidgets('the keyboard hides the bar', (tester) async {
    await _shell(tester, keyboard: 300);
    expect(_bar, findsNothing);
  }, skip: _skip);

  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1200, 800)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: no bar (tablets and computers keep their layout)',
        (tester) async {
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
      expect(find.text('WIDE'), findsOneWidget);
      expect(_bar, findsNothing);
    }, skip: _skip);
  }
}
