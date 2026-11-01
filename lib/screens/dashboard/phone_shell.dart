import 'package:flutter/material.dart';

/// The four places of the phone shell (docs/design/phone_shell.md D1 and
/// section 4). The central "+" is not a place: it opens the record sheet.
enum PhoneTab { home, sales, products, more }

/// PH3: the phone shell. A Scaffold owning the bottom bar, the profile end
/// drawer and the "+" sheet, over a LAZY IndexedStack of the four tab roots:
/// each is built on its first visit and then kept, so it keeps its scroll
/// and state. Deep screens keep using Navigator.of(context).push (the root
/// navigator) and so cover the bar. Back on a tab other than Home goes to
/// Home; Back on Home is left to the route (it leaves the app, the root fix).
///
/// Only phones get it (AppLayout.isPhone); DashboardScreen keeps today's
/// layout for tablets and computers (see [PhoneOrWide]).
class PhoneShell extends StatefulWidget {
  /// Home's top bar (the avatar, the bell, Help; no hamburger). The other
  /// tabs draw their own.
  final PreferredSizeWidget? homeAppBar;

  /// The profile drawer the avatar opens.
  final Widget? endDrawer;

  final WidgetBuilder home;
  final WidgetBuilder sales;
  final WidgetBuilder products;
  final WidgetBuilder more;

  /// The central "+": opens the record sheet.
  final VoidCallback onRecord;

  /// Called after the tab changes.
  final ValueChanged<PhoneTab>? onTabChanged;

  const PhoneShell({
    super.key,
    this.homeAppBar,
    this.endDrawer,
    required this.home,
    required this.sales,
    required this.products,
    required this.more,
    required this.onRecord,
    this.onTabChanged,
  });

  @override
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// The bottom bar (phone_shell.md section 3): five equal slots (Home, Sales,
/// the raised "+", Products, More), 64 high plus the home indicator.
class PhoneBottomBar extends StatelessWidget {
  final PhoneTab current;
  final ValueChanged<PhoneTab> onSelect;
  final VoidCallback onRecord;

  const PhoneBottomBar({super.key, required this.current, required this.onSelect, required this.onRecord});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

/// The shell on a phone, today's layout everywhere else, from the one
/// signal (AppLayout.isPhone).
class PhoneOrWide extends StatelessWidget {
  final WidgetBuilder phone;
  final WidgetBuilder wide;

  const PhoneOrWide({super.key, required this.phone, required this.wide});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
