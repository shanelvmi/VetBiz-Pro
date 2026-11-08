import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

// UI2: the phone bar's outline, one path for its fill, its hairline border
// and its shadow: the rounded upper corners and, at the centre of the top
// edge, a smooth trough that holds the round "+" (PhoneShellMetrics).
// UI4: the trough deeper and wider, cradling the button with
// [PhoneShellMetrics.troughClearance] all round: its bottom a circle around
// the button's centre, reached from the flat edge by a long S-curve (one
// cubic a side, tangent to the edge and to the circle, so no bevel).

const double _troughRadius = PhoneShellMetrics.recordSize / 2 + PhoneShellMetrics.troughClearance;

/// Where the trough's circle has its centre, below the top edge (it is the
/// button's centre too: the button rises [PhoneShellMetrics.buttonRaise]).
double get phoneTroughCentreY => PhoneShellMetrics.recordSize / 2 - PhoneShellMetrics.buttonRaise;

/// The bar's outline in a box of [size] whose top is the bar's top edge;
/// the trough is centred on [centerX].
Path phoneBarPath(Size size, {required double centerX}) {
  const r = PhoneShellMetrics.barRadius;
  const k = PhoneShellMetrics.troughCurve;
  const half = PhoneShellMetrics.troughWidth / 2;
  final join = PhoneShellMetrics.troughJoinDegrees * math.pi / 180;
  // Where each S-curve meets the circle, and the circle's direction there
  // (downwards, towards the bottom), which the curve's last handle follows.
  final joinX = _troughRadius * math.sin(join);
  final joinY = phoneTroughCentreY + _troughRadius * math.cos(join);
  final along = Offset(math.cos(join), math.sin(join)) * k;
  return Path()
    ..moveTo(0, size.height)
    ..lineTo(0, r)
    ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
    ..lineTo(centerX - half, 0)
    ..cubicTo(centerX - half + k, 0, centerX - joinX - along.dx, joinY - along.dy, centerX - joinX, joinY)
    ..arcToPoint(Offset(centerX + joinX, joinY), radius: const Radius.circular(_troughRadius), clockwise: false)
    ..cubicTo(centerX + joinX + along.dx, joinY - along.dy, centerX + half - k, 0, centerX + half, 0)
    ..lineTo(size.width - r, 0)
    ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
    ..lineTo(size.width, size.height)
    ..close();
}

/// Paints the bar: a soft shadow cast upwards, the fill, then the hairline
/// border, all along [phoneBarPath]. Only the drawn bar takes a tap (the
/// trough lets it through).
class PhoneBarPainter extends CustomPainter {
  final Color fill;
  final Color border;
  final Color shadow;

  PhoneBarPainter({required this.fill, required this.border, required this.shadow});

  Path? _path;

  Path _pathFor(Size size) => phoneBarPath(size, centerX: size.width / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path = _pathFor(size);
    canvas.drawPath(
      path.shift(const Offset(0, PhoneShellMetrics.barShadowOffsetY)),
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, Shadow.convertRadiusToSigma(PhoneShellMetrics.barShadowBlur)),
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PhoneShellMetrics.barBorderWidth
        ..color = border,
    );
  }

  @override
  bool? hitTest(Offset position) => _path?.contains(position) ?? false;

  @override
  bool shouldRepaint(PhoneBarPainter oldDelegate) =>
      fill != oldDelegate.fill || border != oldDelegate.border || shadow != oldDelegate.shadow;
}
