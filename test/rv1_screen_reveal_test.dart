// RV1 (docs/design/screen_reveal.md sections 2 and 4): ScreenReveal and
// LateSlot: the skeleton, one fade and rise, once; reduced motion; the
// same rects when a late slot fills; semantics.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_motion.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'helpers/tree_fingerprint.dart';

const _skip = false;

const _skeletonKey = ValueKey('skeleton');
const _contentKey = ValueKey('content');

// Built once: a new ThemeData on every pump would run MaterialApp's theme
// animation.
final _themes = <Brightness, ThemeData>{};

Widget _app(Widget child, {bool still = false, Brightness brightness = Brightness.light, Locale locale = const Locale('en')}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: _themes[brightness] ??= AppTheme.build(AppColorTheme.pasture, brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(body: child),
        ),
      ),
    );

/// A group whose skeleton has the content's layout, as Home's does.
Widget _reveal(RevealGate gate, {Widget? late}) => ScreenReveal(
      gate: gate,
      skeleton: const Column(key: _skeletonKey, children: [SkeletonBox(height: 120), SkeletonBox(height: 80)]),
      child: Column(
        key: _contentKey,
        children: [
          const SizedBox(width: double.infinity, height: 120, child: Text('Hello content')),
          const SizedBox(width: double.infinity, height: 80, child: Text('Second block')),
          if (late != null) late,
        ],
      ),
    );

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.ancestor(of: find.byType(RevealedContent), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

double _rise(WidgetTester tester) => tester
    .widget<Transform>(find.ancestor(of: find.byType(RevealedContent), matching: find.byType(Transform)).first)
    .transform
    .getTranslation()
    .y;

bool _contentShown(WidgetTester tester) => find.byKey(_contentKey).evaluate().isNotEmpty;
bool _skeletonShown(WidgetTester tester) => find.byKey(_skeletonKey).evaluate().isNotEmpty;

void main() {
  test('the login entrance and the reveal share one motion, unchanged (350 ms, 12 px, easeOutCubic)', () {
    expect(AppMotion.authEntrance, AppMotion.revealDuration);
    expect(AppMotion.revealDuration, const Duration(milliseconds: 350));
    expect(AppMotion.authEntranceRise, AppMotion.revealRise);
    expect(AppMotion.revealCurve, Curves.easeOutCubic);
    expect(AppMotion.authEntranceStagger, const Duration(milliseconds: 40));
  }, skip: _skip);

  testWidgets('every primary source answered at the first frame: content at once, no skeleton, no rise',
      (tester) async {
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(true), (v) => v)]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate)));
    expect(_skeletonShown(tester), isFalse);
    expect(_contentShown(tester), isTrue);
    expect(_opacity(tester), 1);
    expect(_rise(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  }, skip: _skip);

  testWidgets('the skeleton at once, then ONE fade and 12 px rise of the whole content', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate)));
    expect(_skeletonShown(tester), isTrue);
    expect(_contentShown(tester), isFalse, reason: 'built offstage until the gate opens');
    expect(find.text('Hello content', skipOffstage: false), findsOneWidget);
    answered.value = true;
    await tester.pump();
    expect(_contentShown(tester), isTrue);
    expect(_rise(tester), AppMotion.revealRise);
    expect(AppMotion.revealRise, 12);
    await tester.pump(AppMotion.revealDuration ~/ 2);
    expect(_opacity(tester), inExclusiveRange(0, 1));
    expect(_rise(tester), inExclusiveRange(0, AppMotion.revealRise));
    expect(_skeletonShown(tester), isTrue, reason: 'the skeleton fades out under the content');
    await tester.pump(AppMotion.revealDuration);
    await tester.pump();
    expect(_skeletonShown(tester), isFalse);
    expect(_opacity(tester), 1);
    expect(_rise(tester), 0);
  }, skip: _skip);

  testWidgets('one primary source late: the reveal starts at 1200 ms', (tester) async {
    final gate = RevealGate(primary: [
      ListenableRevealSource<bool>(ValueNotifier(true), (v) => v),
      ListenableRevealSource<bool>(ValueNotifier(false), (v) => v),
    ]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate)));
    await tester.pump(const Duration(milliseconds: 1199));
    expect(_contentShown(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 2));
    expect(gate.state, RevealState.timedOut);
    expect(_contentShown(tester), isTrue);
    await tester.pumpAndSettle();
    expect(_skeletonShown(tester), isFalse);
  }, skip: _skip);

  testWidgets('the reveal plays once: not on a rebuild, a resize, a theme or a language change', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_reveal(gate)));
    answered.value = true;
    await tester.pumpAndSettle();
    // A theme change runs MaterialApp's own theme animation: the reveal
    // must still be at rest on the very next frame.
    Future<void> expectStill(String what, {bool themeAnimates = false}) async {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_skeletonShown(tester), isFalse, reason: what);
      if (!themeAnimates) expect(tester.hasRunningAnimations, isFalse, reason: what);
      expect(_opacity(tester), 1, reason: what);
      expect(_rise(tester), 0, reason: what);
    }

    await tester.pumpWidget(_app(_reveal(gate)));
    await expectStill('rebuild');
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    await expectStill('resize');
    await tester.pumpWidget(_app(_reveal(gate), brightness: Brightness.dark));
    await expectStill('theme', themeAnimates: true);
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(_reveal(gate), brightness: Brightness.dark, locale: const Locale('sw')));
    await expectStill('language', themeAnimates: true);
  }, skip: _skip);

  testWidgets('reduced motion: the skeleton is swapped for the content instantly', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate), still: true));
    expect(_skeletonShown(tester), isTrue);
    expect(tester.hasRunningAnimations, isFalse, reason: 'the skeleton does not pulse');
    answered.value = true;
    await tester.pump();
    expect(_skeletonShown(tester), isFalse);
    expect(_opacity(tester), 1);
    expect(_rise(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  }, skip: _skip);

  testWidgets('the skeleton and the content have the same outer size', (tester) async {
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate)));
    final before = tester.getRect(find.byType(ScreenReveal));
    final skeleton = tester.getRect(find.byKey(_skeletonKey));
    answered.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(ScreenReveal)), before);
    expect(tester.getRect(find.byKey(_contentKey)), skeleton);
  }, skip: _skip);

  testWidgets('a revealed screen lays out exactly as it would without the reveal', (tester) async {
    final gate = RevealGate(primary: const []);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(_reveal(gate)));
    final wrapped = treeFingerprint(tester, find.byType(Scaffold), stripReveal: true);
    await tester.pumpWidget(_app(tester.widget<ScreenReveal>(find.byType(ScreenReveal)).child));
    expect(treeFingerprint(tester, find.byType(Scaffold)), wrapped);
  }, skip: _skip);

  group('LateSlot', () {
    Widget slotted(bool ready, {bool still = false}) => _app(
          Column(
            children: [
              const SizedBox(key: ValueKey('above'), height: 50),
              LateSlot(height: 120, ready: ready, child: const SizedBox(key: ValueKey('late'), height: 120, child: Text('Late data'))),
              const SizedBox(key: ValueKey('below'), height: 50),
            ],
          ),
          still: still,
        );
    List<Rect> rects(WidgetTester tester) => [
          tester.getRect(find.byKey(const ValueKey('above'))),
          tester.getRect(find.byType(LateSlot)),
          tester.getRect(find.byKey(const ValueKey('below'))),
        ];

    testWidgets('it fills inside its reserved box: nothing around it moves', (tester) async {
      await tester.pumpWidget(slotted(false));
      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.text('Late data'), findsNothing);
      final before = rects(tester);
      await tester.pumpWidget(slotted(true));
      await tester.pump(AppMotion.revealDuration ~/ 2);
      expect(rects(tester), before, reason: 'during the fade');
      expect(find.text('Late data'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(rects(tester), before, reason: 'after the fade');
      expect(find.byType(SkeletonBox), findsNothing);
    }, skip: _skip);

    testWidgets('ready from the start: no skeleton, no fade', (tester) async {
      await tester.pumpWidget(slotted(true));
      expect(find.byType(SkeletonBox), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, skip: _skip);

    testWidgets('reduced motion: an instant swap', (tester) async {
      await tester.pumpWidget(slotted(false, still: true));
      await tester.pumpWidget(slotted(true, still: true));
      expect(find.byType(SkeletonBox), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, skip: _skip);

    testWidgets('a secondary source never delays the reveal', (tester) async {
      final gate = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(true), (v) => v)]);
      addTearDown(gate.dispose);
      await tester.pumpWidget(_app(_reveal(gate, late: const LateSlot(height: 60, ready: false, child: Text('Late data')))));
      expect(_contentShown(tester), isTrue);
      expect(_skeletonShown(tester), isFalse);
      expect(find.byType(SkeletonBox), findsOneWidget, reason: 'only the late slot waits');
    }, skip: _skip);
  });

  testWidgets('semantics: the skeleton is hidden from screen readers, the content is announced', (tester) async {
    final semantics = tester.ensureSemantics();
    final answered = ValueNotifier(false);
    final gate = RevealGate(primary: [ListenableRevealSource<bool>(answered, (v) => v)]);
    addTearDown(gate.dispose);
    await tester.pumpWidget(_app(ScreenReveal(
      gate: gate,
      skeleton: const Text('Skeleton words'),
      child: const Text('Hello content'),
    )));
    expect(find.bySemanticsLabel('Skeleton words'), findsNothing);
    expect(find.bySemanticsLabel('Hello content'), findsNothing);
    answered.value = true;
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Hello content'), findsOneWidget);
    semantics.dispose();
  }, skip: _skip);
}
