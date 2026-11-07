import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import 'reveal_gate.dart';
import 'skeleton_box.dart';

/// RV1 (docs/design/screen_reveal.md): a screen's content arriving as one
/// piece. While [gate] is closed the [skeleton] is drawn (pulsing, hidden
/// from screen readers) and [child] is built offstage, so its own streams
/// start at today's moment; when the gate opens the skeleton fades out and
/// the content fades in and rises [AppMotion.revealRise] px, the login
/// entrance's motion, once per instance: a rebuild, a resize or a theme or
/// language change never plays it again. A gate already open when this is
/// first built (cached data, a widened window) shows the content at once,
/// with no skeleton and no rise; under reduced motion the swap is instant.
///
/// The [skeleton] must have the content's layout and sizes (SkeletonOf),
/// so nothing moves when it is swapped.
class ScreenReveal extends StatefulWidget {
  const ScreenReveal({super.key, required this.gate, this.skeleton, required this.child});

  final RevealGate gate;

  /// With none, [child] is drawn again under a [SkeletonScope], its blocks
  /// choosing their skeleton look through [SkeletonOr].
  final Widget? skeleton;
  final Widget child;

  @override
  State<ScreenReveal> createState() => _ScreenRevealState();
}

class _ScreenRevealState extends State<ScreenReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this, duration: AppMotion.revealDuration);
  late final Animation<double> _progress = CurvedAnimation(parent: _reveal, curve: AppMotion.revealCurve);
  late final Animation<double> _skeletonOpacity = ReverseAnimation(_progress);

  // The content is shown (the gate opened); the skeleton has left the tree.
  late bool _open = widget.gate.isOpen;
  late bool _skeletonGone = _open;

  @override
  void initState() {
    super.initState();
    if (_open) {
      _reveal.value = 1;
    } else {
      widget.gate.addListener(_onGate);
      // The skeleton is on screen from this frame: the gate's wait starts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.gate.firstFrame();
      });
    }
  }

  @override
  void didUpdateWidget(ScreenReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) {
      oldWidget.gate.removeListener(_onGate);
      if (!_open) {
        widget.gate.addListener(_onGate);
        widget.gate.firstFrame();
        _onGate();
      }
    }
  }

  void _onGate() {
    if (_open || !widget.gate.isOpen || !mounted) return;
    widget.gate.removeListener(_onGate);
    final still = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _open = true;
      if (still) {
        _reveal.value = 1;
        _skeletonGone = true;
      }
    });
    if (!still) {
      _reveal.forward().whenCompleteOrCancel(() {
        if (mounted) setState(() => _skeletonGone = true);
      });
    }
  }

  @override
  void dispose() {
    widget.gate.removeListener(_onGate);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One shape from the first frame to the last, so the content keeps its
    // state when it shows and when the skeleton leaves; passthrough, so a
    // revealed screen lays out exactly as it would without this.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(
          offstage: !_open,
          child: FadeTransition(
            opacity: _progress,
            child: AnimatedBuilder(
              animation: _progress,
              child: RevealedContent(child: widget.child),
              builder: (context, child) =>
                  Transform.translate(offset: Offset(0, AppMotion.revealRise * (1 - _progress.value)), child: child),
            ),
          ),
        ),
        if (!_skeletonGone)
          IgnorePointer(
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: _skeletonOpacity,
                child: SkeletonPulse(child: widget.skeleton ?? SkeletonScope(child: widget.child)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Marks where a reveal's (or a late slot's) own content starts, so a test
/// can compare a revealed tree with the same tree before RV1.
class RevealedContent extends StatelessWidget {
  const RevealedContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
