import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/screens/platform_admin/poster_picker_field.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/utils/poster_image_check.dart';

// AN1 (docs/design/announcements_v2.md section 3), written before the widget:
// the Platform Admin's poster field shows the one-line hint, a 16:9 box, an
// optional safe-zone overlay (90 percent by 85 percent), and refuses a bad
// file with the validator's sentence without handing it to the form.

void main() {
  Future<List<PosterImage>> pump(WidgetTester tester, {Future<Uint8List?> Function()? pick, String? error}) async {
    final picked = <PosterImage>[];
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PosterPickerField(picked: null, onPicked: picked.add, error: error, pick: pick),
        ),
      ),
    ));
    return picked;
  }

  testWidgets('the hint, the 16:9 box and no safe zone until it is switched on', (tester) async {
    await pump(tester);
    expect(find.text('16:9, 1600 x 900 px, JPG or WebP, under 1 MB'), findsOneWidget);
    final box = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(box.aspectRatio, AppLimits.posterAspectRatio);
    expect(find.byKey(PosterPickerField.safeZoneKey), findsNothing);

    await tester.tap(find.text('Show safe zone'));
    await tester.pump();
    final zone = tester.widget<FractionallySizedBox>(find.byKey(PosterPickerField.safeZoneKey));
    expect(zone.widthFactor, AppLimits.posterSafeWidth);
    expect(zone.heightFactor, AppLimits.posterSafeHeight);
    expect([AppLimits.posterSafeWidth, AppLimits.posterSafeHeight], [0.9, 0.85]);
  });

  testWidgets('an SVG is refused with the validator\'s sentence and never reaches the form', (tester) async {
    final picked = await pump(tester,
        pick: () async => Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"></svg>')));
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.text(PosterImageCheck.svgRefused), findsOneWidget);
    expect(picked, isEmpty);
  });

  testWidgets('cancelling the picker changes nothing; the form\'s own error shows', (tester) async {
    final picked = await pump(tester, pick: () async => null, error: 'Choose a poster image.');
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text('Choose a poster image.'), findsOneWidget);
  });
}
