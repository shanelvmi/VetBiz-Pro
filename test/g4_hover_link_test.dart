import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/hover_link.dart';

// G4: the one hover link of the signed-out pages. Written before the widget
// (c7eec14): run against the stub, a plain tappable Text, every test but the
// tap failed.
const _skip = false;

void main() {
  final colors = AppColors.fromTheme(AppColorTheme.pasture);
  const rest = Color(0xFF123456); // A resting colour no role has.

  Future<void> pump(WidgetTester tester, Widget link) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      routes: {'/next': (_) => const Scaffold(body: Text('next page'))},
      home: Scaffold(body: Center(child: link)),
    ));
  }

  Widget textLink({bool underlineAtRest = false}) => Builder(
        builder: (context) => HoverLink(
          label: 'Forgot Password?',
          color: rest,
          underlineAtRest: underlineAtRest,
          onTap: () => Navigator.pushNamed(context, '/next'),
        ),
      );

  TextStyle styleOf(WidgetTester tester) => tester.widget<Text>(find.text('Forgot Password?')).style!;

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    return mouse;
  }

  group('HoverLink: text', () {
    testWidgets('at rest: its own colour, no underline, 48 px high, a link', (tester) async {
      await pump(tester, textLink());
      expect(styleOf(tester).color, rest);
      expect(styleOf(tester).decoration, anyOf(isNull, TextDecoration.none));
      expect(tester.getSize(find.byType(HoverLink)).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(find.text('Forgot Password?')), isSemantics(isLink: true, hasTapAction: true, label: 'Forgot Password?'));
    }, skip: _skip);

    testWidgets('hover: accent, underlined, the click cursor, no size change', (tester) async {
      await pump(tester, textLink());
      final before = tester.getSize(find.byType(HoverLink));
      final textBefore = tester.getSize(find.text('Forgot Password?'));
      final mouse = await hover(tester, find.byType(HoverLink));
      expect(styleOf(tester).color, colors.accent);
      expect(styleOf(tester).decoration, TextDecoration.underline);
      expect(styleOf(tester).decorationColor, colors.accent);
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
      expect(tester.getSize(find.byType(HoverLink)), before);
      expect(tester.getSize(find.text('Forgot Password?')), textBefore);
      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(styleOf(tester).color, rest);
    }, skip: _skip);

    testWidgets('keyboard focus: accent, underlined, a focus ring; Enter opens it', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await pump(tester, textLink());
      final before = tester.getSize(find.byType(HoverLink));
      expect(tester.widget<CustomPaint>(find.byKey(HoverLink.focusRingKey)).foregroundPainter, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(styleOf(tester).color, colors.accent);
      expect(styleOf(tester).decoration, TextDecoration.underline);
      expect(tester.widget<CustomPaint>(find.byKey(HoverLink.focusRingKey)).foregroundPainter, isNotNull);
      expect(tester.getSize(find.byType(HoverLink)), before);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('next page'), findsOneWidget);
    }, skip: _skip);

    testWidgets('a tap opens it', (tester) async {
      await pump(tester, textLink());
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('next page'), findsOneWidget);
    });

    testWidgets('underlineAtRest keeps the underline in the resting colour', (tester) async {
      await pump(tester, textLink(underlineAtRest: true));
      expect(styleOf(tester).decoration, TextDecoration.underline);
      expect(styleOf(tester).decorationColor, rest);
    }, skip: _skip);
  });

  group('HoverLink.icon', () {
    Widget iconLink(VoidCallback onTap) => HoverLink.icon(
          icon: (color) => Icon(Icons.star, color: color, semanticLabel: 'Facebook'),
          tooltip: 'Facebook',
          color: rest,
          onTap: onTap,
        );
    Color underline(WidgetTester tester) => tester.widget<ColoredBox>(find.byKey(HoverLink.iconUnderlineKey)).color;

    testWidgets('48 by 48; hover: the icon and its underline turn accent, no size change', (tester) async {
      var taps = 0;
      await pump(tester, iconLink(() => taps++));
      final before = tester.getSize(find.byType(HoverLink));
      expect(before.width, greaterThanOrEqualTo(48));
      expect(before.height, greaterThanOrEqualTo(48));
      expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, rest);
      expect(underline(tester).a, 0);
      await hover(tester, find.byType(HoverLink));
      expect(tester.widget<Icon>(find.byIcon(Icons.star)).color, colors.accent);
      expect(underline(tester), colors.accent);
      expect(tester.getSize(find.byType(HoverLink)), before);
      await tester.tap(find.byIcon(Icons.star));
      expect(taps, 1);
      expect(find.byTooltip('Facebook'), findsOneWidget);
    }, skip: _skip);
  });
}
