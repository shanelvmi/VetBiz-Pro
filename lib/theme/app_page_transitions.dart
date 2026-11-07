import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// RV1 (docs/design/screen_reveal.md section 5): every pushed page slides in
/// [AppMotion.pageSlideOffset] of the width from the right with a fade, and
/// the page under it moves [AppMotion.pageSlideOutgoingOffset] to the left;
/// the reverse on pop. Set for every platform in
/// ThemeData.pageTransitionsTheme, so every MaterialPageRoute gets it.
///
/// Not changed: dialogs and sheets (not page routes); routes with their own
/// transitionsBuilder (facility activation's PageRouteBuilder); the '/login'
/// route, which keeps Flutter's previous platform transition so the login's
/// own entrance stays as it was. On iOS and macOS the page keeps the
/// Cupertino transition, which carries the back swipe (Flutter's gesture
/// detector is private to it). Instant under reduced motion.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  /// The route whose transition stays Flutter's default (main.dart routes).
  static const String loginRouteName = '/login';

  static final PageTransitionsTheme theme = PageTransitionsTheme(
    builders: {for (final platform in TargetPlatform.values) platform: const AppPageTransitionsBuilder()},
  );

  static bool _cupertino(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  /// Flutter's default before RV1 (MaterialRouteTransitionMixin).
  static PageTransitionsBuilder previousDefault(TargetPlatform platform) =>
      _cupertino(platform) ? const CupertinoPageTransitionsBuilder() : const ZoomPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.pageSlide;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageSlide;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final platform = Theme.of(context).platform;
    if (route.settings.name == loginRouteName || _cupertino(platform)) {
      return previousDefault(platform).buildTransitions(route, context, animation, secondaryAnimation, child);
    }
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AppPageSlide(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }
}

/// The slide itself: [animation] brings this page in, [secondaryAnimation]
/// moves it aside while a page above it comes in.
class AppPageSlide extends StatefulWidget {
  const AppPageSlide({super.key, required this.animation, required this.secondaryAnimation, required this.child});

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<AppPageSlide> createState() => _AppPageSlideState();
}

class _AppPageSlideState extends State<AppPageSlide> {
  // Made once and disposed: a CurvedAnimation listens to the route's.
  late CurvedAnimation _incoming;
  late CurvedAnimation _outgoing;

  CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
        parent: parent,
        curve: AppMotion.pageSlideCurve,
        reverseCurve: AppMotion.pageSlideCurve.flipped,
      );

  @override
  void initState() {
    super.initState();
    _incoming = _curve(widget.animation);
    _outgoing = _curve(widget.secondaryAnimation);
  }

  @override
  void didUpdateWidget(AppPageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _incoming.dispose();
      _incoming = _curve(widget.animation);
    }
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _outgoing.dispose();
      _outgoing = _curve(widget.secondaryAnimation);
    }
  }

  @override
  void dispose() {
    _incoming.dispose();
    _outgoing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(-AppMotion.pageSlideOutgoingOffset, 0))
          .animate(_outgoing),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(AppMotion.pageSlideOffset, 0), end: Offset.zero).animate(_incoming),
        child: FadeTransition(opacity: _incoming, child: widget.child),
      ),
    );
  }
}
