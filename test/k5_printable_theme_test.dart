import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/printable_theme.dart';

import 'helpers/color_roles.dart';

// K5 (D11, T0): the receipt previews, the A4 PdfPreview and the client card
// PNG are drawn under PrintableTheme, so in every app mode and every colour
// theme they read Pasture light roles, a light Material and Pasture light's
// default text, exactly as the Pasture Light app draws them.
void main() {
  final pastureLight = allColorRoles(AppColors.fromTheme(AppColorTheme.pasture));

  Future<({AppColors colors, Brightness brightness, TextStyle text, TextStyle outsideText})> seenUnder(
      WidgetTester tester, AppColorTheme theme, Brightness brightness) async {
    late AppColors colors;
    late Brightness seenBrightness;
    late TextStyle text;
    late TextStyle outsideText;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(theme, Brightness.light),
      darkTheme: AppTheme.build(theme, Brightness.dark),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Builder(builder: (outer) {
          outsideText = DefaultTextStyle.of(outer).style;
          return PrintableTheme(builder: (context) {
            colors = context.colors;
            seenBrightness = Theme.of(context).brightness;
            text = DefaultTextStyle.of(context).style;
            return const SizedBox();
          });
        }),
      ),
    ));
    return (colors: colors, brightness: seenBrightness, text: text, outsideText: outsideText);
  }

  for (final theme in AppColorTheme.all) {
    for (final brightness in Brightness.values) {
      testWidgets('${theme.id} ${brightness.name} app: the printable page sees Pasture light', (tester) async {
        final seen = await seenUnder(tester, theme, brightness);
        expect(seen.brightness, Brightness.light);
        final got = allColorRoles(seen.colors);
        for (final e in pastureLight.entries) {
          expect(got[e.key]!.toARGB32(), e.value.toARGB32(), reason: e.key);
        }
        // Text with no colour of its own (facility name, totals, the client
        // card values) gets Pasture light's text, not the dark app's.
        expect(seen.text.color, PrintableTheme.data.textTheme.bodyMedium!.color);
      });
    }
  }

  testWidgets('Pasture Light app: the default text inside equals the Scaffold text it replaced', (tester) async {
    final seen = await seenUnder(tester, AppColorTheme.pasture, Brightness.light);
    expect(seen.text, seen.outsideText);
  });

  testWidgets('every theme, both modes: the printable page text is identical', (tester) async {
    final first = await seenUnder(tester, AppColorTheme.pasture, Brightness.light);
    for (final theme in AppColorTheme.all) {
      for (final brightness in Brightness.values) {
        final seen = await seenUnder(tester, theme, brightness);
        expect(seen.text, first.text, reason: '${theme.id} ${brightness.name}');
      }
    }
  });
}
