// DK1: a filled box that is bright in Dark (or dark in Light) with text or
// icons on it. The owner saw one on the phone: a client's details showed a
// white box at the centre in Dark. Reading the screen found nothing, because
// the colours came from a theme set lower in the tree, so this scan reads the
// built tree instead: every fill the way it is painted, translucent fills
// composited over the fill behind them.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/theme/theme_context.dart';
import 'package:vetbiz_pro/widgets/printable_theme.dart';
import 'package:vetbiz_pro/widgets/vetbiz_loading_indicator.dart';

/// Brighter than this in Dark is a "white box" (about #BCBCBC).
const darkScanMaxLuminance = 0.5;

/// Darker than this in Light is a "black box" (deeper than every theme's
/// light background and surfaces by far).
const lightScanMinLuminance = 0.1;

/// A subtree the scan leaves out on purpose, with the reason.
class SurfaceScanAllow {
  final String reason;
  final bool Function(Widget widget) matches;

  const SurfaceScanAllow(this.reason, this.matches);
}

/// Light on purpose in every mode, so never a finding. The app has no QR
/// code and no colour picker today; posters and logos are images, not
/// fills, so the scan does not see them.
final surfaceScanAlwaysAllowed = [
  // D11, K5: what is printed or shared as a picture (the receipt previews,
  // the A4 PdfPreview, the client card PNG's off-screen copy) stays Pasture
  // light.
  SurfaceScanAllow('a printable page (PrintableTheme)', (w) => w is PrintableTheme),
  // K0: the startup loading screen shows before the saved mode is read, so
  // it stays Pasture light (the short light flash was accepted).
  SurfaceScanAllow('the startup loading screen', (w) => w is VetBizLoadingTheme || w is VetBizLoadingIndicator),
];

/// Wrap a subtree in this key to leave it out of the scan; the reason is the
/// value. Kept for pictures that are light by design (a QR code, a poster, a
/// logo plate, the colour picker's swatches).
const darkScanAllowedKey = ValueKey('dark-scan-allowed');

/// One fill that failed, as the failure message names it.
class SurfaceFinding {
  final String widget;
  final Color fill;
  final double luminance;
  final String text;
  final String location;

  SurfaceFinding(this.widget, this.fill, this.luminance, this.text, this.location);

  @override
  String toString() =>
      '$widget fill #${fill.toARGB32().toRadixString(16).padLeft(8, '0')} (luminance ${luminance.toStringAsFixed(2)}) '
      'behind "$text"\n    at $location';
}

/// The fill [element] paints itself, if any (null: it paints none, or a
/// fully transparent one).
Color? _ownFill(Element element) {
  final widget = element.widget;
  Color? fill;
  if (widget is ColoredBox) {
    fill = widget.color;
  } else if (widget is DecoratedBox) {
    final d = widget.decoration;
    if (d is BoxDecoration) fill = d.color;
    if (d is ShapeDecoration) fill = d.color;
  } else if (widget is Ink) {
    final d = widget.decoration;
    if (d is BoxDecoration) fill = d.color;
    if (d is ShapeDecoration) fill = d.color;
  } else if (widget is InputDecorator && widget.decoration.filled == true) {
    final theme = Theme.of(element);
    fill = widget.decoration.applyDefaults(theme.inputDecorationTheme).fillColor ??
        theme.colorScheme.surfaceContainerHighest;
  } else {
    // Material, Card, Dialog, Chip, the bottom sheet: they paint through a
    // physical model, whatever default the theme gave them.
    final render = element.renderObject;
    if (element is RenderObjectElement) {
      if (render is RenderPhysicalShape) fill = render.color;
      if (render is RenderPhysicalModel) fill = render.color;
    }
  }
  if (fill == null || fill.a == 0) return null;
  return fill;
}

Color _over(Color top, Color below) => Color.alphaBlend(top, below);

/// The colour on screen behind [element]'s own fill: the fills above it in
/// the tree composited, down to the first opaque one (or the page).
Color _behind(Element element) {
  Color? behind;
  final under = <Color>[];
  element.visitAncestorElements((a) {
    final f = _ownFill(a);
    if (f != null) {
      under.add(f);
      if (f.a >= 1) {
        behind = f;
        return false;
      }
    }
    return true;
  });
  var colour = behind ?? Theme.of(element).scaffoldBackgroundColor;
  for (final f in under.reversed.where((f) => f.a < 1)) {
    colour = _over(f, colour);
  }
  return colour;
}

bool _allowed(Element element, List<SurfaceScanAllow> allow) {
  var out = false;
  bool hit(Widget w) => w.key == darkScanAllowedKey || allow.any((a) => a.matches(w));
  if (hit(element.widget)) return true;
  element.visitAncestorElements((a) {
    if (hit(a.widget)) {
      out = true;
      return false;
    }
    return true;
  });
  return out;
}

/// The first text or icon drawn inside [element], or null.
String? _firstInk(Element element) {
  String? found;
  void visit(Element e) {
    if (found != null) return;
    final r = e.renderObject;
    if (e is RenderObjectElement && r is RenderParagraph && r.size.width > 0) {
      final text = r.text.toPlainText().trim();
      if (text.isNotEmpty) {
        // An icon's glyph is a private-use character: name the icon.
        final icon = e.findAncestorWidgetOfExactType<Icon>();
        found = icon != null ? 'icon ${icon.icon?.codePoint.toRadixString(16)}' : text;
        return;
      }
    }
    e.visitChildElements(visit);
  }

  element.visitChildElements(visit);
  return found;
}

/// The widgets above [element], nearest first (Flutter's creator chain).
String _location(Element element) => element.debugGetCreatorChain(14);

/// Every filled box on screen (onstage) whose shown colour is brighter than
/// [darkScanMaxLuminance] when [dark], or darker than [lightScanMinLuminance]
/// when not, and that holds text or icons. [brand] fills are the intended
/// brand surfaces, given as colours: in Light the sidebar, headers, banners,
/// the bottom bar's + button and primary buttons; in Dark the accent fills
/// (K0: they keep the light accent and carry dark onAccent ink). [badges]
/// maps a badge's fill to the brand fills it may sit on: the white logo plate
/// and avatar on the brand header, the same in Light and Dark.
List<SurfaceFinding> scanFilledSurfaces(
  WidgetTester tester, {
  required bool dark,
  List<SurfaceScanAllow> allow = const [],
  Set<int> brand = const {},
  Map<int, Set<int>> badges = const {},
}) {
  final out = <SurfaceFinding>[];
  final seen = <RenderObject>{};
  for (final element in collectAllElementsFrom(tester.binding.rootElement!, skipOffstage: true)) {
    final own = _ownFill(element);
    if (own == null) continue;
    final render = element.renderObject;
    if (render is RenderBox && (!render.hasSize || render.size.isEmpty)) continue;
    final behind = _behind(element);
    final shown = _over(own, behind);
    final lum = shown.computeLuminance();
    final bad = dark ? lum > darkScanMaxLuminance : lum < lightScanMinLuminance;
    if (!bad) continue;
    if (brand.contains(shown.toARGB32())) continue;
    if (badges[shown.toARGB32()]?.contains(behind.toARGB32()) ?? false) continue;
    if (_allowed(element, allow)) continue;
    final ink = _firstInk(element);
    if (ink == null) continue;
    // A Container's DecoratedBox and the ColoredBox under it are one box.
    if (render != null && !seen.add(render)) continue;
    out.add(SurfaceFinding(element.widget.runtimeType.toString(), shown, lum, ink, _location(element)));
  }
  return out;
}

/// Fails, naming every bright box (Dark) or dark box (Light) with text or
/// icons on it, with its widget path.
void expectNoBadSurfaces(
  WidgetTester tester, {
  required bool dark,
  required String where,
  List<SurfaceScanAllow> allow = const [],
}) {
  // The app's roles, above every page (a test page may have no Scaffold).
  final colors = tester.element(find.byType(Navigator).first).colors;
  final brandFills = [colors.brandSurface, colors.sidebarHover, colors.sidebarPress];
  final brand = {
    for (final c in dark ? [colors.accent] : [colors.primary, ...brandFills]) c.toARGB32(),
  };
  final badges = {
    colors.onBrandSurface.toARGB32(): {for (final c in brandFills) c.toARGB32()},
  };
  final found = scanFilledSurfaces(tester, dark: dark, brand: brand, badges: badges, allow: [
    ...allow,
    ...surfaceScanAlwaysAllowed,
    // Material tints an app bar's fill when the page scrolls under it, so a
    // brand header no longer equals its brand colour exactly.
    SurfaceScanAllow('a page header on a brand fill', (w) => w is AppBar && brand.contains(w.backgroundColor?.toARGB32())),
  ]);
  expect(found, isEmpty,
      reason: '$where (${dark ? 'Dark' : 'Light'}): ${found.length} ${dark ? 'bright' : 'dark'} box(es) with text or icons:\n'
          '${found.join('\n')}');
}
