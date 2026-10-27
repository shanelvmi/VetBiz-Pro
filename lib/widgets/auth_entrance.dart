import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// AN6: one part of the signed-out page entering (the header, or a card): a
/// short fade and an [AppMotion.authEntranceRise] px rise over
/// [AppMotion.authEntrance], starting [delay] after the page's one
/// [animation] starts (which runs for that time plus the stagger). The page
/// owns the animation and plays it once, so a rebuild, a resize or a theme
/// or language change never plays it again. At its end the part is exactly
/// where it would be without it.
class AuthEntrance extends StatelessWidget {
  const AuthEntrance({super.key, required this.animation, this.delay = Duration.zero, required this.child});

  /// The page's entrance, 0 to 1 over [total].
  final Animation<double> animation;
  final Duration delay;
  final Widget child;

  /// How long the page's animation runs: one entrance and the stagger.
  static final Duration total = AppMotion.authEntrance + AppMotion.authEntranceStagger;

  @override
  Widget build(BuildContext context) {
    final start = delay.inMicroseconds / total.inMicroseconds;
    final end = (delay + AppMotion.authEntrance).inMicroseconds / total.inMicroseconds;
    // drive() listens to the page's animation only while this is shown.
    final progress = animation.drive(CurveTween(curve: Interval(start, end.clamp(start, 1), curve: Curves.easeOutCubic)));
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        child: child,
        builder:
            (context, child) =>
                Transform.translate(offset: Offset(0, AppMotion.authEntranceRise * (1 - progress.value)), child: child),
      ),
    );
  }
}
