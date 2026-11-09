import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_motion.dart';
import 'home_action_panel.dart';

/// HUB1: the phone shell is now just Home (the owner's hub, phone_shell.md D1
/// SUPERSEDED): its top bar, Home, the subscription banner floating over
/// Home's top, and the action panel docked over Home's bottom. No bottom
/// bar, no "+", no tabs: every other screen is pushed over it with its own
/// back arrow, and this route stays underneath, so Home keeps its state.
/// Back is the panel's (folds it when open) and then the route's (it is the
/// only one, so the app or the page is left, as RELOAD1 made it).
class PhoneHub extends StatelessWidget {
  /// Home's top bar (the avatar, the facility over the greeting, the bell).
  final PreferredSizeWidget? appBar;

  /// The profile menu the avatar opens.
  final Widget? endDrawer;

  final WidgetBuilder home;

  /// The action panel (HomeActionPanel).
  final Widget panel;

  /// PH8a: the subscription banner, floating over Home's top under the app
  /// bar; null when hidden. Pushed screens never show it.
  final Widget? banner;

  const PhoneHub({super.key, this.appBar, this.endDrawer, required this.home, required this.panel, this.banner});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar,
        endDrawer: endDrawer,
        body: Builder(
          builder: (context) => Stack(
            children: [
              Positioned.fill(
                child: HomePanelInsets(
                  bottom: HomeActionPanel.collapsedHeightOf(context),
                  child: _withBanner(banner, Builder(builder: home)),
                ),
              ),
              Positioned.fill(child: panel),
            ],
          ),
        ),
      );

  // PH8a-fix (the owner's correction): the banner floats OVER Home, its top
  // at the app bar's bottom, so the content keeps its full height and never
  // moves when the banner comes, goes or is snoozed. The Stack clips, so the
  // entrance never draws over the app bar. Always the same shape, with or
  // without the banner: a snooze must not rebuild Home under it.
  static Widget _withBanner(Widget? banner, Widget body) => Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: 0,
            left: PhoneBannerMetrics.overlayMargin,
            right: PhoneBannerMetrics.overlayMargin,
            child: _BannerEntrance(key: const ValueKey('phone-subscription-banner-entrance'), banner: banner),
          ),
        ],
      );
}

/// PH8a-fix: the banner slides down a little and fades in when it comes;
/// at once when the platform asks for reduced motion.
class _BannerEntrance extends StatelessWidget {
  final Widget? banner;

  const _BannerEntrance({super.key, required this.banner});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : AppMotion.normal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -PhoneBannerMetrics.enterSlide), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: banner ?? const SizedBox.shrink(),
    );
  }
}

/// HUB1: the room the folded action panel takes at the bottom of Home. Home's
/// scroll view adds it under its last row, so its end (the Needs attention
/// strip) is never under the panel. Zero outside the hub.
class HomePanelInsets extends InheritedWidget {
  final double bottom;

  const HomePanelInsets({super.key, required this.bottom, required super.child});

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomePanelInsets>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(HomePanelInsets oldWidget) => bottom != oldWidget.bottom;
}

/// The hub on a phone, today's layout everywhere else, from the one signal
/// (AppLayout.isPhone).
class PhoneOrWide extends StatelessWidget {
  final WidgetBuilder phone;
  final WidgetBuilder wide;

  const PhoneOrWide({super.key, required this.phone, required this.wide});

  @override
  Widget build(BuildContext context) => AppLayout.isPhone(context) ? phone(context) : wide(context);
}
