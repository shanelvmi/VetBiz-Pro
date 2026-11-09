// RV2b (1) (docs/design/screen_reveal.md 8.4): RevealImage, every list and
// card image in one place: a fixed slot with the initials (or a soft
// skeleton) at once, the image fading in over it when decoded, decoded at
// twice the slot's size, a failed image keeps the initials, nothing moves;
// the first screenful's images hold a reveal for a short grace, never past
// the gate's 1200 ms and never for an offscreen or failing image.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

const _skip = true;

class _FakeTimer implements Timer {
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

class _FakeClock extends RevealClock {
  final timers = <(Duration, VoidCallback, _FakeTimer)>[];

  @override
  Timer start(Duration after, VoidCallback onFire) {
    final t = _FakeTimer();
    timers.add((after, onFire, t));
    return t;
  }

  /// Fires the timer started for [after].
  void fire(Duration after) {
    final (_, onFire, t) = timers.firstWhere((e) => e.$1 == after);
    if (!t.cancelled) onFire();
  }
}

/// An image the test decodes (or fails) when it chooses.
class _ManualImage extends ImageProvider<_ManualImage> {
  _ManualImage(this.url);

  final String url;
  final _completer = Completer<ImageInfo>();

  void decode(ui.Image image) => _completer.complete(ImageInfo(image: image));
  void fail() => _completer.completeError(StateError('no image'));

  @override
  Future<_ManualImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_ManualImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_completer.future);
}

final _images = <String, _ManualImage>{};

ImageProvider _provider(String url) => _images.putIfAbsent(url, () => _ManualImage(url));

const _initials = Text('AB', key: ValueKey('initials'));

final _theme = AppTheme.build(AppColorTheme.pasture, Brightness.light);

Widget _app(Widget child, {bool still = false}) => MaterialApp(
      theme: _theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Scaffold(body: child),
        ),
      ),
    );

Widget _slot(String url) => Column(children: [
      const SizedBox(key: ValueKey('above'), height: 30, width: 100),
      RevealImage(key: const ValueKey('slot'), url: url, width: 40, height: 40, placeholder: _initials),
      const SizedBox(key: ValueKey('below'), height: 30, width: 100),
    ]);

Map<String, Rect> _rects(WidgetTester tester) => {
      for (final k in ['above', 'slot', 'below']) k: tester.getRect(find.byKey(ValueKey(k))),
    };

double? _imageOpacity(WidgetTester tester) {
  final fade = find.ancestor(of: find.byKey(const ValueKey('revealImage-image')), matching: find.byType(AnimatedOpacity));
  final inner = find.descendant(of: find.byKey(const ValueKey('revealImage-image')), matching: find.byType(AnimatedOpacity));
  final f = inner.evaluate().isNotEmpty ? inner : fade;
  return f.evaluate().isEmpty ? null : tester.widget<AnimatedOpacity>(f.first).opacity;
}

Future<ui.Image> _png(WidgetTester tester) async => (await tester.runAsync(() => createTestImage(width: 8, height: 8)))!;

void main() {
  setUp(() {
    _images.clear();
    RevealImage.providerFor = _provider;
  });
  tearDown(() => RevealImage.providerFor = NetworkImage.new);

  testWidgets('the slot has its fixed size and the initials at once; nothing moves when the image arrives', (tester) async {
    await tester.pumpWidget(_app(_slot('a')));
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
    final before = _rects(tester);
    expect(before['slot']!.size, const Size(40, 40));
    _images['a']!.decode(await _png(tester));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_rects(tester), before);
    // The initials stay under the image.
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
  }, skip: _skip);

  testWidgets('the image fades in over the slot when its first frame is decoded', (tester) async {
    await tester.pumpWidget(_app(_slot('a')));
    expect(_imageOpacity(tester), 0);
    _images['a']!.decode(await _png(tester));
    await tester.pump();
    expect(_imageOpacity(tester), 1);
    final fading = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
    expect(fading.duration, greaterThan(Duration.zero));
  }, skip: _skip);

  testWidgets('reduced motion: the image shows at once, with no fade', (tester) async {
    await tester.pumpWidget(_app(_slot('a'), still: true));
    _images['a']!.decode(await _png(tester));
    await tester.pump();
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.byKey(const ValueKey('revealImage-image')), findsOneWidget);
  }, skip: _skip);

  testWidgets('a failed image keeps the initials and the slot', (tester) async {
    await tester.pumpWidget(_app(_slot('a')));
    final before = _rects(tester);
    _images['a']!.fail();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
    expect(find.byKey(const ValueKey('revealImage-image')), findsNothing);
    expect(_rects(tester), before);
  }, skip: _skip);

  testWidgets('no URL: the initials only, no image', (tester) async {
    await tester.pumpWidget(_app(const RevealImage(url: null, width: 40, height: 40, placeholder: _initials)));
    expect(find.byKey(const ValueKey('initials')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  }, skip: _skip);

  testWidgets('no placeholder: a soft skeleton, still under reduced motion', (tester) async {
    await tester.pumpWidget(_app(const RevealImage(url: 'a', width: 40, height: 40), still: true));
    expect(find.byType(SkeletonBox), findsOneWidget);
    final pulse = tester.widget<FadeTransition>(
        find.descendant(of: find.byType(SkeletonPulse), matching: find.byType(FadeTransition)).first);
    expect(pulse.opacity.value, 1);
  }, skip: _skip);

  testWidgets('decoded at twice the slot size', (tester) async {
    await tester.pumpWidget(_app(_slot('a')));
    final image = tester.widget<Image>(find.byKey(const ValueKey('revealImage-image'))).image;
    expect(image, isA<ResizeImage>());
    final resize = image as ResizeImage;
    expect((resize.width, resize.height), (80, 80));
    expect(resize.policy, ResizeImagePolicy.fit);
    expect(resize.imageProvider, same(_images['a']));
  }, skip: _skip);

  group('the grace of the first screenful', () {
    late _FakeClock clock;
    late ValueNotifier<bool> rows;
    late RevealGate gate;

    Widget list(int count, {double rowHeight = 50}) => _app(ScreenReveal(
          gate: gate,
          skeleton: const SizedBox.expand(),
          child: ValueListenableBuilder<bool>(
            valueListenable: rows,
            builder: (context, ready, _) => ready
                ? ListView(children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(
                          height: rowHeight,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: RevealImage(url: 'r$i', width: 40, height: 40, placeholder: _initials))),
                  ])
                : const SizedBox.shrink(),
          ),
        ));

    setUp(() {
      clock = _FakeClock();
      rows = ValueNotifier(false);
      gate = RevealGate(
        primary: [ListenableRevealSource<bool>(rows, (v) => v)],
        clock: clock,
        imageGrace: AppTimeouts.revealImageGrace,
      );
    });
    tearDown(() => gate.dispose());

    testWidgets('rows answered, images pending: the gate waits; the images decoded: it opens', (tester) async {
      await tester.pumpWidget(list(3));
      rows.value = true;
      await tester.pump();
      await tester.pump();
      expect(gate.isOpen, isFalse);
      final png = await _png(tester);
      for (var i = 0; i < 3; i++) {
        _images['r$i']!.decode(png);
      }
      await tester.pump();
      await tester.pump();
      expect(gate.state, RevealState.revealed);
    }, skip: _skip);

    testWidgets('an image that never decodes holds it only for the grace', (tester) async {
      await tester.pumpWidget(list(3));
      rows.value = true;
      await tester.pump();
      await tester.pump();
      expect(gate.isOpen, isFalse);
      expect(clock.timers.map((t) => t.$1), contains(AppTimeouts.revealImageGrace));
      expect(AppTimeouts.revealImageGrace, lessThan(AppTimeouts.revealGate));
      clock.fire(AppTimeouts.revealImageGrace);
      await tester.pump();
      expect(gate.state, RevealState.revealed);
    }, skip: _skip);

    testWidgets('never past the gate: the 1200 ms timeout opens it while images wait', (tester) async {
      await tester.pumpWidget(list(3));
      await tester.pump();
      clock.fire(AppTimeouts.revealGate);
      await tester.pump();
      expect(gate.state, RevealState.timedOut);
    }, skip: _skip);

    testWidgets('a failing image answers at once', (tester) async {
      await tester.pumpWidget(list(1));
      rows.value = true;
      await tester.pump();
      await tester.pump();
      expect(gate.isOpen, isFalse);
      _images['r0']!.fail();
      await tester.pump();
      await tester.pump();
      expect(gate.state, RevealState.revealed);
    }, skip: _skip);

    testWidgets('only the first eight, and never one below the screen', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // 300 high, rows of 50: six rows on screen (and some built below).
      await tester.pumpWidget(list(12));
      rows.value = true;
      await tester.pump();
      await tester.pump();
      expect(gate.isOpen, isFalse);
      final png = await _png(tester);
      for (var i = 0; i < 6; i++) {
        _images['r$i']!.decode(png);
      }
      await tester.pump();
      await tester.pump();
      expect(gate.state, RevealState.revealed, reason: 'rows 7 and on are below the screen');
    }, skip: _skip);

    test('at most eight images hold it', () {
      final g = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(false), (v) => v)], clock: _FakeClock(),
          imageGrace: AppTimeouts.revealImageGrace);
      final held = [for (var i = 0; i < 10; i++) g.holdForImage(_Src())];
      expect(held.where((h) => h).length, AppTimeouts.revealImageGraceSlots);
      expect(AppTimeouts.revealImageGraceSlots, 8);
      g.dispose();
    }, skip: _skip);

    test('a gate open before the first frame, or one with no grace, takes no image', () {
      final open = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(true), (v) => v)], clock: _FakeClock(),
          imageGrace: AppTimeouts.revealImageGrace);
      expect(open.holdForImage(_Src()), isFalse);
      final none = RevealGate(primary: [ListenableRevealSource<bool>(ValueNotifier(false), (v) => v)], clock: _FakeClock());
      expect(none.holdForImage(_Src()), isFalse);
      open.dispose();
      none.dispose();
    }, skip: _skip);
  });
}

class _Src extends RevealSource {}
