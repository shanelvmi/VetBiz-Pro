import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context.dart';

/// A Card that lifts slightly on mouse hover - higher elevation, a
/// small upward shift - rather than sitting static regardless of
/// whether a mouse is over it. Touch devices never fire hover events
/// at all, so this has zero effect there; it's purely a desktop/mouse
/// affordance. Shared across screens rather than each keeping its own
/// private copy.
class HoverElevateCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets margin;
  final double baseElevation;
  final double hoverElevation;
  final BorderRadius borderRadius;
  /// The card's fill; the theme's surface when not given.
  final Color? color;

  const HoverElevateCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.baseElevation = AppElevation.e1,
    this.hoverElevation = AppElevation.e6,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.r12)),
    this.color,
  });

  @override
  State<HoverElevateCard> createState() => _HoverElevateCardState();
}

class _HoverElevateCardState extends State<HoverElevateCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        margin: widget.margin,
        transform: _isHovering
            ? (Matrix4.identity()..translate(0.0, -3.0))
            : Matrix4.identity(),
        child: Card(
          color: widget.color ?? context.colors.surface,
          elevation: _isHovering ? widget.hoverElevation : widget.baseElevation,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}
