import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../navigation/app_destinations.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import 'shell_banner.dart';

/// Builds the sidebar (or rail) for the place now [selected]; a tap calls
/// [onSelect].
typedef ShellSidebarBuilder = Widget Function(AppDestination selected, ValueChanged<AppDestination> onSelect);

/// LAY4 (owner, 2026-11-18): the PC/tablet shell keeps the sidebar and the
/// top bar on screen. The area under the top bar hosts its own Navigator:
/// Home is its base page, and a migrated destination ([pageFor] gives a
/// screen) sits on top of it, replacing any other destination with a short
/// fade. Screens pushed from inside a destination stay in the content area.
/// A destination not yet migrated ([pageFor] gives null) keeps opening full
/// screen over everything through [onOpenFullScreen], as before.
///
/// Home stays alive underneath (its streams are not recreated), and
/// [onReturnedHome] is told which destination was left when the content
/// comes back to Home, so the caller refreshes only where the registry says.
///
/// Back (the browser's, Android's, Windows') pops the content first: a
/// screen pushed inside, then the destination, then Home as before.
///
/// Width: the screens inside measure the window (MediaQuery), but they have
/// only the content area. The navigator gets a MediaQuery whose width is the
/// content's (never below [AppBreakpoints.compact], so no phone layout shows
/// inside the shell) and whose height stays the window's (the phone-landscape
/// rule is not touched). Home keeps the window's MediaQuery, as it had.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.sidebar,
    required this.topBar,
    this.banner,
    required this.home,
    required this.pageFor,
    required this.onOpenFullScreen,
    required this.onReturnedHome,
  });

  final ShellSidebarBuilder sidebar;
  final Widget topBar;

  /// UX8b: the subscription banner, floating over the top of the content
  /// (ShellBannerHost); it takes no layout space. Null: none. (UX7 had it in
  /// the layout under [topBar], which pushed every page down.)
  final ShellBannerSpec? banner;
  final Widget home;

  /// The screen of a destination that lives in the shell, or null for one
  /// that still opens full screen.
  final Widget? Function(AppDestination d) pageFor;
  final Future<void> Function(AppDestination d) onOpenFullScreen;
  final ValueChanged<AppDestination> onReturnedHome;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  final GlobalKey<NavigatorState> contentNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell-content');

  /// UX8b: the content area (the banner's coordinates) and where the current
  /// page header has its title and actions.
  final GlobalKey _contentAreaKey = GlobalKey(debugLabel: 'shell-content-area');
  final ShellHeaderSpan _headerSpan = ShellHeaderSpan();

  @override
  void dispose() {
    _headerSpan.dispose();
    super.dispose();
  }

  /// The destination on top of Home, or null when Home shows.
  AppDestination? _open;

  /// LAY4b: screens opened with [openInContent] (not places of their own) and
  /// the place each highlights while it shows, newest last.
  final List<(Route<void>, AppDestination)> _shown = [];

  /// The place the sidebar highlights: the newest [openInContent] screen's,
  /// else the open destination (a screen pushed above it keeps it), else Home.
  /// UX4: the shell around [context], or null with none (a phone, or a test
  /// that pumps a screen alone). A dropdown on the root navigator is outside
  /// it: look it up from the screen that opens the dropdown.
  static AppShellState? maybeOf(BuildContext context) => context.findAncestorStateOfType<AppShellState>();

  AppDestination get selected => _shown.isNotEmpty ? _shown.last.$2 : (_open ?? AppDestination.home);

  /// LAY4b: shows [page] in the content area, on top of what is there, with
  /// [highlight] selected in the sidebar while it shows (Activity Log and
  /// Notifications highlight Settings). Back returns where you were.
  Future<void> openInContent(Widget page, {required AppDestination highlight}) async {
    final navigator = contentNavigatorKey.currentState;
    if (navigator == null) return;
    final route = MaterialPageRoute<void>(builder: (_) => page);
    setState(() => _shown.add((route, highlight)));
    await navigator.push(route);
    if (mounted) setState(() => _shown.removeWhere((e) => e.$1 == route));
  }

  /// Back to the first screen of what is open (a place, or Home): screens
  /// pushed above it, [openInContent] ones included, are closed.
  void _toFirstScreen() {
    contentNavigatorKey.currentState?.popUntil((r) => r.settings is _ShellPage);
    _shown.clear();
  }

  void select(AppDestination d) {
    if (d == AppDestination.home) {
      if (_open != null) {
        _leave();
      } else {
        setState(_toFirstScreen);
      }
      return;
    }
    if (widget.pageFor(d) == null) {
      widget.onOpenFullScreen(d);
      return;
    }
    if (d == _open) {
      // The place already open: back to its own first screen.
      setState(_toFirstScreen);
      return;
    }
    // Close what was shown above Home or the old place first, so nothing is
    // left between Home and the new place.
    setState(() {
      _toFirstScreen();
      _open = d;
    });
  }

  void _leave() {
    final left = _open!;
    setState(() {
      _shown.clear();
      _open = null;
    });
    widget.onReturnedHome(left);
  }

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.of(context);
    final open = _open;
    final page = open == null ? null : widget.pageFor(open);
    return Row(
      children: [
        widget.sidebar(selected, select),
        Expanded(
          child: Column(
            children: [
              widget.topBar,
              Expanded(
                // UX8b: the banner floats over the content; the page lays out as if
                // it were not there.
                child: Stack(
                  key: _contentAreaKey,
                  children: [
                    Positioned.fill(
                      child: ShellHeaderScope(
                        span: _headerSpan,
                        child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: window.copyWith(
                      size: Size(math.max(constraints.maxWidth, AppBreakpoints.compact), window.size.height),
                    ),
                    child: NavigatorPopHandler<Object?>(
                      onPopWithResult: (_) => contentNavigatorKey.currentState?.maybePop(),
                      child: Navigator(
                        key: contentNavigatorKey,
                        pages: [
                          _ShellPage(
                            key: const ValueKey('shell-home'),
                            child: MediaQuery(data: window, child: widget.home),
                          ),
                          if (open != null && page != null)
                            _ShellPage(
                              key: ValueKey('shell-${open.name}'),
                              child: ShellScope(child: page),
                            ),
                        ],
                        onDidRemovePage: (removed) {
                          if (open != null && removed.key == ValueKey('shell-${open.name}') && _open == open) _leave();
                        },
                      ),
                    ),
                  ),
                ),
                      ),
                    ),
                    Positioned.fill(
                      child: ShellBannerHost(spec: widget.banner, span: _headerSpan, areaKey: _contentAreaKey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// LAY4: marks a destination's own screen in the shell (top level: no back
/// arrow; the sidebar is the way out). Screens pushed above it are not
/// inside the marker and keep theirs.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required super.child});

  /// True for a destination's first screen inside the shell.
  static bool isTopLevel(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>() != null;

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// A content page: a short fade in and out (no slide), kept alive under the
/// page above it. The route reads the current page's child, so the caller's
/// rebuilds (Home's figures) reach it.
class _ShellPage extends Page<void> {
  const _ShellPage({required LocalKey super.key, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _ShellRoute(this);
}

class _ShellRoute extends PageRoute<void> {
  _ShellRoute(_ShellPage page) : super(settings: page);

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => AppMotion.fast;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      (settings as _ShellPage).child;

  @override
  Widget buildTransitions(
          BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: animation, child: child);
}
