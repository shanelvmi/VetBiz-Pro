// DK1: the dark-surface scan itself. It must catch the owner's case (a light
// box with text on a dark page) and its reverse in Light, see translucent
// fills as they show, and leave out what is bright on purpose: boxes with no
// text, the accent fills, a white badge on the brand header, printable pages.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/printable_theme.dart';

import 'helpers/dark_surface_scan.dart';

Future<List<SurfaceFinding>> _scan(WidgetTester tester, Brightness brightness, Widget Function(AppColors c) body) async {
  final colors = AppColors.fromTheme(AppColorTheme.pasture, brightness: brightness);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.build(AppColorTheme.pasture, brightness),
    home: Scaffold(body: Center(child: body(colors))),
  ));
  return scanFilledSurfaces(tester, dark: brightness == Brightness.dark, brand: {
    if (brightness == Brightness.dark) colors.accent.toARGB32() else colors.primary.toARGB32(),
  }, badges: {
    colors.onBrandSurface.toARGB32(): {colors.brandSurface.toARGB32()},
  }, allow: surfaceScanAlwaysAllowed);
}

void main() {
  testWidgets('Dark: a white box with text is found, named by its widget and text', (tester) async {
    final found = await _scan(tester, Brightness.dark, (_) => Container(color: Colors.white, child: const Text('Amina')));
    expect(found, hasLength(1));
    expect(found.single.widget, 'ColoredBox');
    expect(found.single.text, 'Amina');
    expect(found.single.luminance, 1.0);
  });

  testWidgets('Dark: a light Card and a light chip from a raw colour are found', (tester) async {
    final found = await _scan(
        tester,
        Brightness.dark,
        (_) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Card(color: Color(0xFFF5F5F5), child: Text('card')),
              DecoratedBox(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9)), child: const Icon(Icons.phone)),
            ]));
    expect(found.map((f) => f.text), containsAll(['card', startsWith('icon')]));
  });

  testWidgets('Dark: a faint white tint, a white box with no text, the accent and a badge on the brand fill are not', (tester) async {
    final found = await _scan(
        tester,
        Brightness.dark,
        (c) => Column(mainAxisSize: MainAxisSize.min, children: [
              Container(color: Colors.white.withValues(alpha: 0.1), child: const Text('tint')),
              Container(color: Colors.white, width: 20, height: 20),
              Container(color: c.accent, child: Icon(Icons.add, color: c.onAccent)),
              Container(color: c.brandSurface, child: Container(color: c.onBrandSurface, child: const Text('VB'))),
              PrintableTheme(builder: (light) => Container(color: light.theme.colorScheme.surface, child: const Text('receipt'))),
            ]));
    expect(found, isEmpty, reason: found.join('\n'));
  });

  testWidgets('Light: a dark box with text is found; the brand fill is not', (tester) async {
    final found = await _scan(
        tester,
        Brightness.light,
        (c) => Column(mainAxisSize: MainAxisSize.min, children: [
              Container(color: const Color(0xFF162325), child: const Text('dark surface')),
              Container(color: c.primary, child: Text('brand', style: TextStyle(color: c.onPrimary))),
            ]));
    expect(found.map((f) => f.text), ['dark surface']);
  });
}

extension on BuildContext {
  ThemeData get theme => Theme.of(this);
}
