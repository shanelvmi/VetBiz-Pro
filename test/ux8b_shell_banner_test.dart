// UX8b (owner): the subscription banner floats over the top of the shell's
// content on PC and tablet. It takes no layout space (a page lays out exactly
// as with no banner), never covers the page title or the header actions, has
// Renew and Close, and fades out after 10 s idle; closed or faded, it comes
// back when the status changes.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/navigation/app_destinations.dart';
import 'package:vetbiz_pro/screens/settings/settings_screen.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/ui/polish/filter_row.dart';
import 'package:vetbiz_pro/widgets/shell/app_shell.dart';
import 'package:vetbiz_pro/widgets/shell/page_header.dart';
import 'package:vetbiz_pro/widgets/shell/shell_banner.dart';

import 'helpers/ph8b_team.dart';
import 'helpers/phone_list_harness.dart';
import 'helpers/screen_size_matrix.dart';
import 'ph8a_settings_wide_test.dart' show seedTrash;

final _shell = GlobalKey<AppShellState>();
final _request = ValueNotifier<SettingsRequest?>(null);

/// The status shown, and the one closed or faded (as the dashboard keeps
/// them: hidden while they are the same).
final _status = ValueNotifier<String>('grace');
String? _dismissedFor;
var _renewTaps = 0;
final _tick = ValueNotifier<int>(0);

const _sentence = 'Your subscription has expired. You have a few days of grace left to renew.';

ShellBannerSpec? _spec(bool on) => !on || _status.value == _dismissedFor
    ? null
    : ShellBannerSpec(
        identity: _status.value,
        message: _sentence,
        icon: Icons.warning_amber_rounded,
        accent: const Color(0xFF8A5A00),
        fill: const Color(0xFFFFF4DC),
        actionLabel: 'Renew',
        onAction: () => _renewTaps++,
        onDismissed: () {
          _dismissedFor = _status.value;
          _tick.value++;
        },
      );

Widget _harness(FirebaseFirestore fs, {required bool banner}) => ListenableBuilder(
      listenable: Listenable.merge([_status, _tick]),
      builder: (context, _) => Scaffold(
          body: AppShell(
            key: _shell,
            sidebar: (s, o) => const SizedBox(width: 72),
            topBar: const SizedBox(height: 64),
            banner: _spec(banner),
            home: const Text('HOME'),
            pageFor: (d) =>
                d == AppDestination.settings ? SettingsScreen(firestore: fs, auth: Ph8bAuth(), request: _request) : null,
            onOpenFullScreen: (_) async {},
            onReturnedHome: (_) {},
          ),
        ),
    );

Future<void> _seed(FirebaseFirestore fs) async {
  await ph8bSeedTeam(fs, twoFacilities: false);
  await seedTrash(fs);
}

Future<void> _pump(WidgetTester tester, Size size,
    {required bool banner, MatrixLook look = MatrixLook.light, double textScale = 1}) async {
  _request.value = null;
  _status.value = 'grace';
  _dismissedFor = null;
  _renewTaps = 0;
  await pumpPh5(tester, (fs) => _harness(fs, banner: banner),
      size: size, seed: _seed, look: look, textScale: textScale);
  _shell.currentState!.select(AppDestination.settings);
  await tester.pumpAndSettle();
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
}

Future<void> _openTrash(WidgetTester tester) async {
  final row = find.byKey(const ValueKey('settingsHub-trash'));
  await tester.scrollUntilVisible(row, 150,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
  await tester.tap(row);
  await ph5Settle(tester);
  while (tester.takeException() != null) {}
}

/// Where the current page's title, first row and filter row are.
List<Rect> _layout(WidgetTester tester, {bool trash = false}) {
  final header = find.byType(PageHeader).last;
  return [
    tester.getRect(header),
    tester.getRect(find.descendant(of: header, matching: find.byType(Text)).first),
    tester.getRect((trash ? find.byType(FilterRow) : find.byKey(const ValueKey('settingsHub-trash'))).first),
  ];
}

Finder get _pill => find.byWidgetPredicate(
    (w) => w.key == const ValueKey('shell-banner-full') || w.key == const ValueKey('shell-banner-chip'));

const _sizes = [Size(768, 1024), Size(1200, 800), Size(1920, 1080)];

void main() {
  for (final size in _sizes) {
    final at = '${size.width.toInt()}';

    ph5TestWidgets('$at: the page lays out exactly as without the banner (Settings, Trash)', (tester) async {
      await _pump(tester, size, banner: false);
      final hubBefore = _layout(tester);
      await _pump(tester, size, banner: true);
      expect(_pill, findsOneWidget);
      expect(_layout(tester), hubBefore);

      await _pump(tester, size, banner: false);
      await _openTrash(tester);
      final trashBefore = _layout(tester, trash: true);
      await _pump(tester, size, banner: true);
      await _openTrash(tester);
      expect(_pill, findsOneWidget);
      expect(_layout(tester, trash: true), trashBefore);
    });

    for (final (look, scale) in const [(MatrixLook.light, 1.0), (MatrixLook.light, 1.3), (MatrixLook.kiswahili, 1.3)]) {
      ph5TestWidgets('$at ${look.name} $scale: never over the page title or the header actions', (tester) async {
        await _pump(tester, size, banner: true, look: look, textScale: scale);
        for (final page in ['hub', 'trash']) {
          if (page == 'trash') await _openTrash(tester);
          final pill = tester.getRect(_pill);
          final header = find.byType(PageHeader).last;
          final headerRect = tester.getRect(header);
          final title = tester.getRect(find.descendant(of: header, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true)).first);
          final slot = tester.getRect(find.descendant(of: header, matching: find.byType(Column)).first);
          expect(pill.height, ShellBannerMetrics.height);
          if (pill.top < headerRect.bottom) {
            expect(pill.left, greaterThanOrEqualTo(title.right), reason: '$page: clear of the title');
            expect(pill.right, lessThanOrEqualTo(slot.right), reason: '$page: clear of the actions');
          }
          expect(pill.width, lessThanOrEqualTo(ShellBannerMetrics.maxWidth));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  ph5TestWidgets('Renew and Close are 44 px targets; Renew acts; Close hides it until the status changes', (tester) async {
    await _pump(tester, const Size(1920, 1080), banner: true);
    final renew = find.byKey(const ValueKey('shell-banner-action'));
    final close = find.byKey(const ValueKey('shell-banner-close'));
    expect(tester.getSize(renew).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(close), const Size(44, 44));
    await tester.tap(renew);
    await tester.pump();
    expect(_renewTaps, 1);

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(_pill, findsNothing, reason: 'closed for this status');
    _status.value = 'locked';
    await tester.pump();
    await tester.pump();
    expect(_pill, findsOneWidget, reason: 'back for a new status');
  });

  ph5TestWidgets('it fades out on its own after 10 s without interaction; a hover restarts the wait', (tester) async {
    await _pump(tester, const Size(1200, 800), banner: true);
    await tester.pump(AppTimeouts.shellBannerIdle - const Duration(seconds: 3));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_pill));
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump(const Duration(seconds: 5));
    expect(_pill, findsOneWidget, reason: 'the hover restarted the wait');
    await mouse.moveTo(Offset.zero);
    await tester.pump(AppTimeouts.shellBannerIdle);
    await tester.pumpAndSettle();
    expect(_pill, findsNothing);
    expect(_dismissedFor, 'grace');
    await mouse.removePointer();
  });

  ph5TestWidgets('reduced motion: gone at once, no fade', (tester) async {
    _request.value = null;
    _status.value = 'grace';
    _dismissedFor = null;
    await pumpPh5(tester, (fs) => _harness(fs, banner: true), size: const Size(1200, 800), seed: _seed, reduceMotion: true);
    _shell.currentState!.select(AppDestination.settings);
    await ph5Settle(tester);
    while (tester.takeException() != null) {}
    await tester.tap(find.byKey(const ValueKey('shell-banner-close')));
    await tester.pump();
    expect(find.byType(AnimatedOpacity).evaluate().where((e) => (e.widget as AnimatedOpacity).opacity < 1), isEmpty);
    expect(_pill, findsNothing);
  });

  group('placement rule', () {
    test('centred on the content when the header gap allows', () {
      final p = placeShellBanner(areaWidth: 1200, fullWidth: 500, chipWidth: 150, header: (left: 200, right: 1100, bottom: 72));
      expect(p.compact, isFalse);
      expect(p.left, 350);
      expect(p.top, (72 - ShellBannerMetrics.height) / 2);
    });
    test('in the gap when the centre would touch the title or actions', () {
      final p = placeShellBanner(areaWidth: 1200, fullWidth: 500, chipWidth: 150, header: (left: 400, right: 1180, bottom: 72));
      expect(p.left, greaterThanOrEqualTo(416));
      expect(p.left + 500, lessThanOrEqualTo(1164));
    });
    test('the chip when the full pill does not fit; under the header when neither does', () {
      final chip = placeShellBanner(areaWidth: 700, fullWidth: 600, chipWidth: 150, header: (left: 200, right: 560, bottom: 72));
      expect(chip.compact, isTrue);
      expect(chip.top, lessThan(72));
      final below = placeShellBanner(areaWidth: 700, fullWidth: 600, chipWidth: 150, header: (left: 300, right: 420, bottom: 72));
      expect(below.compact, isTrue);
      expect(below.top, 72 + ShellBannerMetrics.belowHeaderGap);
    });
    test('no header: centred at the top', () {
      final p = placeShellBanner(areaWidth: 1000, fullWidth: 400, chipWidth: 150);
      expect(p.left, 300);
    });
  });
}
