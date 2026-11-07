// RV1 (docs/design/screen_reveal.md section 5): one page transition for
// every pushed page: a subtle slide from the right with a fade; dialogs,
// sheets and the '/login' route unchanged; instant under reduced motion; the
// iOS back swipe still works.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_page_transitions.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

const _skip = false;

final _theme = AppTheme.build(AppColorTheme.pasture, Brightness.light);
const _home = ValueKey('home page');
const _next = ValueKey('next page');

Widget _app({bool still = false, ThemeData? theme}) => MaterialApp(
      theme: theme ?? _theme,
      routes: {
        AppPageTransitionsBuilder.loginRouteName: (_) => const Scaffold(key: ValueKey('login'), body: Text('LOGIN')),
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          key: _home,
          body: Column(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(key: _next, body: Text('NEXT')),
                )),
                child: const Text('push'),
              ),
              TextButton(
                onPressed: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('DIALOG'))),
                child: const Text('dialog'),
              ),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => const Text('SHEET')),
                child: const Text('sheet'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(AppPageTransitionsBuilder.loginRouteName),
                child: const Text('login'),
              ),
            ],
          ),
        ),
      ),
    );

double _ease(double t) => AppMotion.pageSlideCurve.transform(t);

void main() {
  test('every platform uses the one builder, 280 ms', () {
    final builders = _theme.pageTransitionsTheme.builders;
    expect(builders.keys.toSet(), TargetPlatform.values.toSet());
    expect(builders.values.every((b) => b is AppPageTransitionsBuilder), isTrue);
    expect(const AppPageTransitionsBuilder().transitionDuration, AppMotion.pageSlide);
    expect(AppMotion.pageSlide, const Duration(milliseconds: 280));
    expect(AppMotion.pageSlideOffset, 0.06);
  }, skip: _skip);

  for (final progress in [0.0, 0.5, 1.0]) {
    testWidgets('the slide at progress $progress: offset and opacity', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppPageSlide(
          animation: AlwaysStoppedAnimation(progress),
          secondaryAnimation: kAlwaysDismissedAnimation,
          child: const SizedBox.expand(key: _next),
        ),
      ));
      final slides = tester
          .widgetList<SlideTransition>(find.descendant(of: find.byType(AppPageSlide), matching: find.byType(SlideTransition)))
          .toList();
      final incoming = slides[1].position.value;
      expect(incoming.dx, closeTo(AppMotion.pageSlideOffset * (1 - _ease(progress)), 1e-9));
      expect(incoming.dy, 0);
      expect(slides[0].position.value, Offset.zero, reason: 'nothing above it');
      final fade = tester.widget<FadeTransition>(find.ancestor(of: find.byKey(_next), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, closeTo(_ease(progress), 1e-9));
    }, skip: _skip);
  }

  testWidgets('the page underneath moves a little less, to the left', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppPageSlide(
        animation: kAlwaysCompleteAnimation,
        secondaryAnimation: kAlwaysCompleteAnimation,
        child: const SizedBox.expand(key: _home),
      ),
    ));
    final outgoing = tester
        .widgetList<SlideTransition>(find.descendant(of: find.byType(AppPageSlide), matching: find.byType(SlideTransition)))
        .first
        .position
        .value;
    expect(outgoing.dx, -AppMotion.pageSlideOutgoingOffset);
    expect(AppMotion.pageSlideOutgoingOffset, lessThan(AppMotion.pageSlideOffset));
  }, skip: _skip);

  testWidgets('a pushed MaterialPageRoute slides in from the right, and back out on pop', (tester) async {
    await tester.pumpWidget(_app());
    final width = tester.getSize(find.byKey(_home)).width;
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(AppMotion.pageSlide ~/ 2);
    final x = tester.getTopLeft(find.byKey(_next)).dx;
    expect(x, greaterThan(0));
    expect(x, lessThanOrEqualTo(width * AppMotion.pageSlideOffset));
    expect(tester.getTopLeft(find.byKey(_home)).dx, lessThan(0), reason: 'the page under it moves left');
    expect(find.ancestor(of: find.byKey(_next), matching: find.byType(AppPageSlide)), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_next)).dx, 0);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(AppMotion.pageSlide ~/ 2);
    expect(tester.getTopLeft(find.byKey(_next)).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(_next), findsNothing);
    expect(tester.getTopLeft(find.byKey(_home)).dx, 0);
  }, skip: _skip);

  testWidgets('dialogs and bottom sheets do not slide', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('dialog'));
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.text('DIALOG'), matching: find.byType(AppPageSlide)), findsNothing);
    expect(tester.getTopLeft(find.byKey(_home)).dx, 0);
    Navigator.of(tester.element(find.text('DIALOG'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.text('SHEET'), matching: find.byType(AppPageSlide)), findsNothing);
    expect(tester.getTopLeft(find.byKey(_home)).dx, 0);
  }, skip: _skip);

  testWidgets("the '/login' route keeps Flutter's previous transition", (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('login'));
    await tester.pump();
    await tester.pump(AppMotion.pageSlide ~/ 2);
    expect(find.ancestor(of: find.text('LOGIN'), matching: find.byType(AppPageSlide)), findsNothing);
    expect(AppPageTransitionsBuilder.previousDefault(TargetPlatform.android), isA<ZoomPageTransitionsBuilder>());
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
  }, skip: _skip);

  testWidgets('reduced motion: the page is there at once, no slide', (tester) async {
    await tester.pumpWidget(_app(still: true));
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byKey(_next)).dx, 0);
    expect(find.byType(AppPageSlide), findsNothing);
    await tester.pumpAndSettle();
  }, skip: _skip);

  testWidgets('on iOS the back swipe still works', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // ThemeData keeps the platform it was built on.
    await tester.pumpWidget(_app(theme: AppTheme.build(AppColorTheme.pasture, Brightness.light)));
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(find.byKey(_next), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(5, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_next), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  }, skip: _skip);
}
