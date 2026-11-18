import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/color_math.dart';
import '../../theme/polish_metrics.dart';
import '../../theme/theme_context.dart';

/// POL7, the owner's chart palette (final): ONE hue per chart. Lines and
/// bars use the theme's primary for the main series and a neutral grey for
/// a comparison ("previous period"); pies and donuts use steps of the
/// PRIMARY ramp, deep to light, then grey for "Other". No rainbow, no
/// colour per category; red and green only where a series means bad or
/// good (the state roles). Derived from the theme, so every theme, Light
/// and Dark, gets its own palette with no per-theme hex.
class ChartPalette {
  /// The colours of the theme in use.
  final AppColors colors;

  const ChartPalette(this.colors);

  factory ChartPalette.of(BuildContext context) => ChartPalette(context.colors);

  /// Every mark that carries meaning reaches this against [surface].
  static const double minContrast = 3.0;

  /// The owner approved three ramp steps (measured: a fourth step falls
  /// under 3:1 in Dark in every theme); the rest is folded into Other.
  static const int maxSteps = 3;

  /// The surface the charts are drawn on (the chart cards).
  Color get surface => colors.surface;

  /// The main series of a line or bar chart.
  Color get series => colors.primary;

  /// A comparison series (the dashed "previous period").
  Color get comparison => colors.textMuted;

  /// The "Other" slice of a pie or donut.
  Color get other => colors.textMuted;

  /// The ramp: [maxSteps] steps from the primary towards [surface], evenly
  /// spaced up to the lightest mix that still reaches [minContrast] (found
  /// by bisection, so the last step lands just above 3:1 in each theme).
  List<Color> get steps {
    final primary = colors.primary;
    final s = surface;
    if (ColorMath.contrast(primary, s) < minContrast) return [primary];
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      if (ColorMath.contrast(Color.lerp(primary, s, mid)!, s) >= minContrast) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return [for (var k = 0; k < maxSteps; k++) Color.lerp(primary, s, lo * k / (maxSteps - 1))!];
  }

  /// The first [n] ramp steps (at most [steps]'s length), deep to light.
  List<Color> ramp(int n) => steps.take(n).toList();

  /// Ramp step [i] (0 is the deepest); past the ramp, [other].
  Color step(int i) {
    final s = steps;
    return i < s.length ? s[i] : other;
  }
}

/// POL7: slices for a pie or donut as drawn: the named slices by value,
/// largest first (the deepest tone), the first [keep] of them, then ONE
/// Other slice last that sums the rest and any Other already given (none
/// when nothing is left). Display only: the loader's data is unchanged.
List<T> chartSlicesByValue<T>(
  List<T> slices, {
  required num Function(T) value,
  required bool Function(T) isOther,
  required int keep,
  required T Function(List<T> rest) fold,
}) {
  final named = [for (final s in slices) if (!isOther(s)) s];
  // A stable sort: equal values keep the loader's order.
  final order = [for (var i = 0; i < named.length; i++) i]
    ..sort((a, b) {
      final c = value(named[b]).compareTo(value(named[a]));
      return c != 0 ? c : a.compareTo(b);
    });
  final sorted = [for (final i in order) named[i]];
  final rest = [...sorted.skip(keep), for (final s in slices) if (isOther(s)) s];
  return [...sorted.take(keep), if (rest.isNotEmpty) fold(rest)];
}

/// POL7: a legend swatch that draws its line's style: solid when [dash] is
/// null, else the same dash pattern (on, off, ...) as the line, so lines
/// of one hue are told apart in the legend too.
class ChartLineSwatch extends StatelessWidget {
  final Color color;
  final List<int>? dash;

  const ChartLineSwatch({super.key, required this.color, this.dash});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: PolishMetrics.chartSwatchWidth,
        height: PolishMetrics.dot,
        child: CustomPaint(painter: _LinePainter(color, dash)),
      );
}

class _LinePainter extends CustomPainter {
  final Color color;
  final List<int>? dash;

  const _LinePainter(this.color, this.dash);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = PolishMetrics.chartSwatchStroke;
    final y = size.height / 2;
    final d = dash;
    if (d == null || d.isEmpty) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    for (var i = 0; x < size.width; i++) {
      final len = d[i % d.length].toDouble();
      if (i.isEven) canvas.drawLine(Offset(x, y), Offset((x + len).clamp(0, size.width).toDouble(), y), paint);
      x += len;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.color != color || old.dash != dash;
}
