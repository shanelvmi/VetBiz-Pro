// UI1 (2), written before the change: one brand loading look. The brand mark
// (AppAssets.logo) at 96 px (88 on a screen under 360 high) inside a soft ring
// spinner, centred at every size and never overflowing, on the theme's page
// (Dark shows a dark page); reduced motion shows a still ring. The missing
// illustration is referred to nowhere, the logo's path lives in one constant,
// and every wait after signing in is this page.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_assets.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/vetbiz_loading_indicator.dart';

const _skip = true;

const _sizes = [Size(360, 740), Size(390, 844), Size(740, 360), Size(768, 1024), Size(1200, 800)];

Future<void> _pump(WidgetTester tester, Size size, Brightness brightness, {bool reduceMotion = false, String? title}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.build(AppColorTheme.pasture, brightness),
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
    home: VetBizLoadingPage(title: title),
  ));
  await tester.pump(const Duration(seconds: 1));
}

CircularProgressIndicator _ring(WidgetTester tester) => tester.widget<CircularProgressIndicator>(
    find.descendant(of: find.byKey(VetBizLoadingIndicator.ringKey), matching: find.byType(CircularProgressIndicator)));

String _read(String path) => File(path).readAsStringSync();

Iterable<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

void main() {
  for (final size in _sizes) {
    for (final brightness in Brightness.values) {
      final at = '${size.width.toInt()}x${size.height.toInt()} ${brightness.name}';
      testWidgets('$at: the mark (88 px or more) in its ring, centred, on the theme\'s page, no overflow', (tester) async {
        await _pump(tester, size, brightness, title: 'Setting up Kituo cha Huduma za Mifugo na Pembejeo Mwanzo Mpya');
        expect(tester.takeException(), isNull);
        final mark = tester.getRect(find.byKey(VetBizLoadingIndicator.markKey));
        final ring = tester.getRect(find.byKey(VetBizLoadingIndicator.ringKey));
        expect(mark.width, greaterThanOrEqualTo(88 - 0.5));
        expect(mark.height, greaterThanOrEqualTo(88 - 0.5));
        if (size.height >= 360) expect(mark.width, closeTo(96, 0.5));
        expect(ring.width, greaterThan(mark.width));
        expect((ring.center - mark.center).distance, lessThan(1));
        expect(mark.center.dx, closeTo(size.width / 2, 1), reason: 'centred across');
        // The column (mark, caption) is centred; the mark sits in its upper part.
        final body = tester.getRect(find.byType(VetBizLoadingIndicator));
        expect(ring.top - body.top, greaterThanOrEqualTo(0));
        expect(body.contains(ring.bottomRight - const Offset(1, 1)), isTrue);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, AppColors.fromTheme(AppColorTheme.pasture, brightness: brightness).background);
        expect(_ring(tester).value, isNull, reason: 'it turns');
      }, skip: _skip);
    }
  }

  testWidgets('without a caption the mark is in the middle of the page, both ways', (tester) async {
    await _pump(tester, const Size(390, 844), Brightness.light);
    final mark = tester.getRect(find.byKey(VetBizLoadingIndicator.markKey));
    expect(mark.center.dx, closeTo(195, 1));
    expect(mark.center.dy, closeTo(422, 1));
  }, skip: _skip);

  testWidgets('reduced motion: a still ring', (tester) async {
    await _pump(tester, const Size(390, 844), Brightness.dark, reduceMotion: true);
    expect(_ring(tester).value, isNotNull);
    expect(tester.takeException(), isNull);
  }, skip: _skip);

  test('the missing illustration is referred to nowhere (lib, pubspec)', () {
    expect(File('assets/vetbiz_loading_illustration.png').existsSync(), isFalse, reason: 'the file is really missing');
    for (final f in _dartFiles('lib')) {
      expect(f.readAsStringSync().contains('vetbiz_loading_illustration.png'), isFalse, reason: f.path);
    }
    expect(_read('pubspec.yaml').contains('vetbiz_loading_illustration.png'), isFalse);
  }, skip: _skip);

  test('the logo\'s path is written once, in AppAssets.logo', () {
    expect(AppAssets.logo, 'assets/vetbiz_pro_logo.png');
    final writers = [
      for (final f in _dartFiles('lib'))
        if (f.readAsStringSync().contains("'assets/vetbiz_pro_logo.png'")) f.path.replaceAll('\\', '/'),
    ];
    expect(writers, ['lib/config/app_assets.dart']);
  }, skip: _skip);

  test('one look: the compact style is gone; every wait after signing in is the loading page', () {
    for (final f in _dartFiles('lib')) {
      expect(f.readAsStringSync().contains('VetBizLoadingStyle'), isFalse, reason: f.path);
    }
    final main = _read('lib/main.dart');
    expect(main.contains('Center(child: CircularProgressIndicator())'), isFalse, reason: 'the decision\'s waits');
    expect(main.contains('VetBizLoadingPage'), isTrue);
    expect(_read('lib/utils/facility_activation.dart').contains('VetBizLoadingPage('), isTrue, reason: 'setting up the facility');
    expect(_read('lib/screens/facilities/facility_picker_screen.dart').contains('VetBizLoadingPage('), isTrue);
  }, skip: _skip);
}
