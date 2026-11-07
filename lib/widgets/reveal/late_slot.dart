import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import 'screen_reveal.dart';
import 'skeleton_box.dart';

/// RV1 (docs/design/screen_reveal.md): the reserved box where a secondary
/// block appears. Until [ready] it shows the soft skeleton; then [child]
/// fades in inside the same box, so nothing around it moves. Ready from the
/// start, the child shows at once; under reduced motion the swap is instant.
///
/// [height] reserves the box's height (in a box with a bounded width); with
/// no height the parent reserves it (for example a Positioned.fill over a
/// box already sized for the block, as the Recent Activity feed's).
class LateSlot extends StatefulWidget {
  const LateSlot({super.key, required this.ready, required this.child, this.height});

  final bool ready;
  final double? height;
  final Widget child;

  @override
  State<LateSlot> createState() => _LateSlotState();
}

class _LateSlotState extends State<LateSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: AppMotion.revealDuration);
  late final Animation<double> _opacity = CurvedAnimation(parent: _fade, curve: AppMotion.revealCurve);
  late final Animation<double> _skeletonOpacity = ReverseAnimation(_opacity);
  late bool _skeletonGone = widget.ready;

  @override
  void initState() {
    super.initState();
    if (widget.ready) _fade.value = 1;
  }

  @override
  void didUpdateWidget(LateSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.ready) {
      // Loading again (a new period): the skeleton comes back, in place.
      if (oldWidget.ready) {
        _fade.value = 0;
        _skeletonGone = false;
      }
      return;
    }
    if (oldWidget.ready) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
      _skeletonGone = true;
    } else {
      _fade.forward().whenCompleteOrCancel(() {
        if (mounted) setState(() => _skeletonGone = true);
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.ready) FadeTransition(opacity: _opacity, child: RevealedContent(child: widget.child)),
        if (!_skeletonGone)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: FadeTransition(
                  opacity: _skeletonOpacity,
                  child: const SkeletonPulse(child: SkeletonBox()),
                ),
              ),
            ),
          ),
      ],
    );
    final height = widget.height;
    return height == null ? slot : SizedBox(height: height, width: double.infinity, child: slot);
  }
}
