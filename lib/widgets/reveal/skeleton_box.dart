import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/theme_context.dart';

// RV1: the one skeleton look (the phone list's, PH5a R9): a soft
// surfaceMuted box, pulsing gently as a group; still under reduced motion.

/// A soft placeholder box of a given size.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = RevealMetrics.skeletonRadius});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// [child] laid out but not drawn, with a [SkeletonBox] over exactly its
/// box: a skeleton the real block's size by construction. Never give it a
/// widget that starts a stream or a read.
class SkeletonOf extends StatelessWidget {
  const SkeletonOf({super.key, required this.child, this.radius = RevealMetrics.skeletonRadius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: child,
              ),
              Positioned.fill(child: SkeletonBox(radius: radius)),
            ],
          ),
        ),
      );
}

/// The soft pulse of everything under it (one animation for a whole
/// skeleton); still when the platform asks for reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: AppMotion.loop);
  late final Animation<double> _opacity =
      Tween<double>(begin: 1, end: RevealMetrics.skeletonLow).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Marks a subtree as a reveal's skeleton: a group can then be drawn twice
/// from one widget (ScreenReveal with no skeleton of its own), each block
/// choosing its look through [SkeletonOr].
class SkeletonScope extends InheritedWidget {
  const SkeletonScope({super.key, required super.child});

  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<SkeletonScope>() != null;

  @override
  bool updateShouldNotify(SkeletonScope oldWidget) => false;
}

/// [child] in the content; in a skeleton, a [SkeletonOf] of [placeholder]
/// (or of [child]): a placeholder stands in for a block that would start a
/// stream or carry a GlobalKey.
class SkeletonOr extends StatelessWidget {
  const SkeletonOr({super.key, required this.child, this.placeholder, this.radius = RevealMetrics.skeletonRadius});

  final Widget child;
  final Widget? placeholder;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      SkeletonScope.of(context) ? SkeletonOf(radius: radius, child: placeholder ?? child) : child;
}
