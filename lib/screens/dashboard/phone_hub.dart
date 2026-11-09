import 'package:flutter/material.dart';

/// HUB1: the phone shell as just Home (it lands next; this is its shape, for
/// the tests committed first).
class PhoneHub extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? endDrawer;
  final WidgetBuilder home;
  final Widget panel;
  final Widget? banner;

  const PhoneHub({super.key, this.appBar, this.endDrawer, required this.home, required this.panel, this.banner});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class HomePanelInsets extends InheritedWidget {
  final double bottom;

  const HomePanelInsets({super.key, required this.bottom, required super.child});

  static double bottomOf(BuildContext context) => 0;

  @override
  bool updateShouldNotify(HomePanelInsets oldWidget) => bottom != oldWidget.bottom;
}
