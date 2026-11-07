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

/// The colour [element]'s fill shows on screen: composited over the fills
/// behind it, down to the page.
Color _shownFill(Element element, Color own) {
  if (own.a >= 1) return own;
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
  return _over(own, colour);
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
/// when not, and that holds text or icons. [brand] fills (Light only) are the
/// intended brand surfaces: the sidebar, headers, banners, the bottom bar's +
/// button and primary buttons, given as colours.
List<SurfaceFinding> scanFilledSurfaces(
  WidgetTester tester, {
  required bool dark,
  List<SurfaceScanAllow> allow = const [],
  Set<int> brand = const {},
}) {
  final out = <SurfaceFinding>[];
  final seen = <RenderObject>{};
  for (final element in collectAllElementsFrom(tester.binding.rootElement!, skipOffstage: true)) {
    final own = _ownFill(element);
    if (own == null) continue;
    final render = element.renderObject;
    if (render is RenderBox && (!render.hasSize || render.size.isEmpty)) continue;
    final shown = _shownFill(element, own);
    final lum = shown.computeLuminance();
    final bad = dark ? lum > darkScanMaxLuminance : lum < lightScanMinLuminance;
    if (!bad) continue;
    if (!dark && brand.contains(shown.toARGB32())) continue;
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
  final brand = <int>{};
  if (!dark) {
    final colors = tester.element(find.byType(Scaffold).first).colors;
    for (final c in [colors.primary, colors.brandSurface, colors.sidebarHover, colors.sidebarPress]) {
      brand.add(c.toARGB32());
    }
  }
  final found = scanFilledSurfaces(tester, dark: dark, allow: allow, brand: brand);
  expect(found, isEmpty,
      reason: '$where (${dark ? 'Dark' : 'Light'}): ${found.length} ${dark ? 'bright' : 'dark'} box(es) with text or icons:\n'
          '${found.join('\n')}');
}
