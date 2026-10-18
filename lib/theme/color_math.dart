import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Colour measurements used to derive and check the theme colours
/// (docs/design/themes.md): WCAG 2.1 contrast, and CIEDE2000 colour
/// distance ("dE"; under about 20 two colours are hard to tell apart at a
/// glance, under about 2 they look the same).
class ColorMath {
  ColorMath._();

  /// WCAG 2.1 relative luminance of an opaque colour.
  static double luminance(Color c) {
    double ch(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  /// [c] drawn over the opaque [over] (a translucent role on its fill).
  static Color composite(Color c, Color over) => Color.alphaBlend(c, over);

  /// WCAG 2.1 contrast ratio of [fg] on [bg] (1 to 21). A translucent [fg]
  /// is composited over [bg] first.
  static double contrast(Color fg, Color bg) {
    final a = luminance(composite(fg, bg));
    final b = luminance(bg);
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  static List<double> _lab(Color c) {
    double lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final r = lin(c.r), g = lin(c.g), b = lin(c.b);
    // sRGB -> XYZ (D65), relative to the D65 white.
    final x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    final z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
    double f(double t) => t > 216 / 24389 ? math.pow(t, 1 / 3).toDouble() : (24389 / 27 * t + 16) / 116;
    final fx = f(x), fy = f(y), fz = f(z);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  /// CIEDE2000 colour difference between two opaque colours.
  static double deltaE(Color c1, Color c2) {
    final lab1 = _lab(c1), lab2 = _lab(c2);
    final l1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
    final l2 = lab2[0], a2 = lab2[1], b2 = lab2[2];
    double deg(double r) => r * 180 / math.pi;
    double rad(double d) => d * math.pi / 180;

    final cBar = (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
    final g = 0.5 * (1 - math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7))));
    final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
    final c1p = math.sqrt(a1p * a1p + b1 * b1), c2p = math.sqrt(a2p * a2p + b2 * b2);
    double hue(double b, double a) {
      if (a == 0 && b == 0) return 0;
      final h = deg(math.atan2(b, a));
      return h < 0 ? h + 360 : h;
    }

    final h1p = hue(b1, a1p), h2p = hue(b2, a2p);
    final dLp = l2 - l1;
    final dCp = c2p - c1p;
    double dhp;
    if (c1p * c2p == 0) {
      dhp = 0;
    } else if ((h2p - h1p).abs() <= 180) {
      dhp = h2p - h1p;
    } else if (h2p - h1p > 180) {
      dhp = h2p - h1p - 360;
    } else {
      dhp = h2p - h1p + 360;
    }
    final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dhp / 2));

    final lBarP = (l1 + l2) / 2;
    final cBarP = (c1p + c2p) / 2;
    double hBarP;
    if (c1p * c2p == 0) {
      hBarP = h1p + h2p;
    } else if ((h1p - h2p).abs() <= 180) {
      hBarP = (h1p + h2p) / 2;
    } else if (h1p + h2p < 360) {
      hBarP = (h1p + h2p + 360) / 2;
    } else {
      hBarP = (h1p + h2p - 360) / 2;
    }
    final t = 1 -
        0.17 * math.cos(rad(hBarP - 30)) +
        0.24 * math.cos(rad(2 * hBarP)) +
        0.32 * math.cos(rad(3 * hBarP + 6)) -
        0.20 * math.cos(rad(4 * hBarP - 63));
    final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2));
    final rc = 2 * math.sqrt(math.pow(cBarP, 7) / (math.pow(cBarP, 7) + math.pow(25, 7)));
    final sl = 1 + 0.015 * math.pow(lBarP - 50, 2) / math.sqrt(20 + math.pow(lBarP - 50, 2));
    final sc = 1 + 0.045 * cBarP;
    final sh = 1 + 0.015 * cBarP * t;
    final rt = -math.sin(rad(2 * dTheta)) * rc;
    return math.sqrt(math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh));
  }
}
