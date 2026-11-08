import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

// UI2: the phone bar's outline, one path for its fill, its hairline border
// and its shadow: the rounded upper corners and, at the centre of the top
// edge, a smooth trough that holds the round "+" (PhoneShellMetrics).

double get _troughRadius => PhoneShellMetrics.recordSize / 2 + PhoneShellMetrics.troughGap;

/// Where the trough's circle has its centre, below the top edge (it is the
/// button's centre too).
double get phoneTroughCentreY => PhoneShellMetrics.troughDepth - _troughRadius;

/// How far from the centre each edge curve meets the flat top edge.
double get _edgeCurveOffset {
  const f = PhoneShellMetrics.troughEdgeRadius;
  final dy = f - phoneTroughCentreY;
  return math.sqrt((_troughRadius + f) * (_troughRadius + f) - dy * dy);
}

/// The trough's width at the top edge, where its curves leave the edge.
double phoneTroughWidth() => 2 * _edgeCurveOffset;

/// The bar's outline in a box of [size] whose top is the bar's top edge;
/// the trough is centred on [centerX].
Path phoneBarPath(Size size, {required double centerX}) {
  const r = PhoneShellMetrics.barRadius;
  const f = PhoneShellMetrics.troughEdgeRadius;
  final trough = Offset(centerX, phoneTroughCentreY);
  final leftCurve = Offset(centerX - _edgeCurveOffset, f);
  final rightCurve = Offset(centerX + _edgeCurveOffset, f);
  // An edge curve meets the trough's circle on the line between their centres.
  Offset meeting(Offset curve) => curve + (trough - curve) * (f / (_troughRadius + f));
  return Path()
    ..moveTo(0, size.height)
    ..lineTo(0, r)
    ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
    ..lineTo(leftCurve.dx, 0)
    ..arcToPoint(meeting(leftCurve), radius: const Radius.circular(f))
    ..arcToPoint(meeting(rightCurve), radius: Radius.circular(_troughRadius), clockwise: false)
    ..arcToPoint(Offset(rightCurve.dx, 0), radius: const Radius.circular(f))
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
