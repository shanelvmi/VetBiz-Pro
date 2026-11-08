import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/active_facility_memory.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import '../../widgets/app_safe_area.dart';

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

  /// The central "+": opens the record sheet. While the returned future is
  /// pending (the sheet is open) the plus shows as a cross (NAV1).
  final FutureOr<void> Function() onRecord;

  /// Called after the tab changes.
  final ValueChanged<PhoneTab>? onTabChanged;

  /// PH8a: the subscription banner, at the top of every tab under its app bar
  /// (Home here; the other tabs through [bodyWithBanner]), floating over the
  /// content (PH8a-fix); null when hidden.
  /// Deep screens are pushed over the shell, so they never show it.
  final Widget? banner;

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
    this.banner,
  });

  @override
  State<PhoneShell> createState() => _PhoneShellState();

  /// PH4: switches the shell around [context] to [tab] (Go to's Products).
  static void selectTab(BuildContext context, PhoneTab tab) =>
      context.findAncestorStateOfType<_PhoneShellState>()?._select(tab);

  /// PH8a: [body] under the shell's banner, for a tab that draws its own app
  /// bar; [body] alone outside the shell (a pushed screen) or with no banner.
  static Widget bodyWithBanner(BuildContext context, Widget body) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PhoneShellBanner>();
    return scope == null ? body : _withBanner(scope.banner, body);
  }

  // PH8a-fix (the owner's correction): the banner floats OVER the tab, its
  // top at the app bar's bottom (the top of the body under it), so the
  // content keeps its full height and never moves when the banner comes,
  // goes or is snoozed. The Stack clips, so the entrance never draws over the
  // app bar. Always the same shape, with or without the banner: a snooze must
  // not rebuild the tab under it (its scroll, its search).
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

class _PhoneShellState extends State<PhoneShell> with SingleTickerProviderStateMixin {
  // RELOAD1: Home, or after a reload in the same session the tab that was
  // open (a value it does not know is Home).
  PhoneTab _tab = PhoneTab.values.asNameMap()[ActiveFacilityMemory.takeTabToRestore()] ?? PhoneTab.home;

  // A plain IndexedStack would build all four at once, and so start every
  // tab's listeners on sign-in: each is built on its first visit instead.
  late final Set<PhoneTab> _visited = {_tab};

  // RV1: the tab being left fades out under the new one, which fades in
  // (AppMotion.tabFade); null once the fade is over. Every visited tab stays
  // built (its state kept, as the IndexedStack did); only the selected one
  // is hit-testable and seen by screen readers.
  PhoneTab? _leaving;
  late final AnimationController _fade = AnimationController(vsync: this, duration: AppMotion.tabFade, value: 1);
  late final Animation<double> _fadeIn = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  late final Animation<double> _fadeOut = ReverseAnimation(_fadeIn);

  void _select(PhoneTab tab) {
    if (tab == _tab) return;
    final still = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _leaving = still ? null : _tab;
      _tab = tab;
      _visited.add(tab);
    });
    if (still) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _fade.value == 1) setState(() => _leaving = null);
      });
    }
    ActiveFacilityMemory.rememberTab(tab.name);
    widget.onTabChanged?.call(tab);
  }

  // NAV1: the record sheet is open (the + shows a cross).
  bool _recordOpen = false;

  Future<void> _record() async {
    setState(() => _recordOpen = true);
    try {
      await widget.onRecord();
    } finally {
      if (mounted) setState(() => _recordOpen = false);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }


  WidgetBuilder _builder(PhoneTab tab) => switch (tab) {
        PhoneTab.home => widget.home,
        PhoneTab.sales => widget.sales,
        PhoneTab.products => widget.products,
        PhoneTab.more => widget.more,
      };

  @override
  Widget build(BuildContext context) {
    // Mobile browsers report the keyboard differently: the owner checks this
    // on the phone (phone_shell.md section 3).
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      // Home: Back is the route's (it is the only one, so the app or the page
      // is left). Any other tab: Back goes to Home.
      canPop: _tab == PhoneTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(PhoneTab.home);
      },
      child: Scaffold(
        appBar: _tab == PhoneTab.home ? widget.homeAppBar : null,
        endDrawer: widget.endDrawer,
        // PH8a: the banner sits under Home's app bar here; the other tabs draw
        // their own app bar and put it under theirs (PhoneShell.bodyWithBanner).
        body: _PhoneShellBanner(
          banner: widget.banner,
          // The selected tab is painted last, over the one fading out; keys
          // keep each tab's state when the order changes.
          child: Stack(
            children: [
              for (final tab in [
                ...PhoneTab.values.where((t) => t != _tab && t != _leaving),
                if (_leaving != null) _leaving!,
                _tab,
              ])
                KeyedSubtree(
                  key: ValueKey(tab),
                  child: Offstage(
                    offstage: tab != _tab && tab != _leaving,
                    child: TickerMode(
                      enabled: tab == _tab,
                      child: IgnorePointer(
                        ignoring: tab != _tab,
                        child: ExcludeSemantics(
                          excluding: tab != _tab,
                          child: FadeTransition(
                            opacity: tab == _tab
                                ? _fadeIn
                                : tab == _leaving
                                    ? _fadeOut
                                    : kAlwaysCompleteAnimation,
                            child: !_visited.contains(tab)
                                ? const SizedBox.shrink()
                                : tab == PhoneTab.home
                                    ? PhoneShell._withBanner(widget.banner, Builder(builder: _builder(tab)))
                                    : Builder(builder: _builder(tab)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : PhoneBottomBar(current: _tab, onSelect: _select, onRecord: _record, recordOpen: _recordOpen),
      ),
    );
  }
}

/// PH8a: the shell's banner, for the tabs under it.
class _PhoneShellBanner extends InheritedWidget {
  final Widget? banner;

  const _PhoneShellBanner({required this.banner, required super.child});

  @override
  bool updateShouldNotify(_PhoneShellBanner oldWidget) => banner != oldWidget.banner;
}

/// The bottom bar (phone_shell.md section 3, restyled in NAV1): docked, its
/// upper corners rounded, a faint primary tint (navBarFill) and a very light
/// shadow; five equal slots (Home, Sales, the "+", Products, More), 64 high
/// plus the home indicator. It sits below the Scaffold's body, so it never
/// covers content. Not a pill: the selected item shows its filled icon and a
/// semibold label in primary, under a short line at the bar's top edge that
/// slides and fades to the item chosen.
class PhoneBottomBar extends StatelessWidget {
  final PhoneTab current;
  final ValueChanged<PhoneTab> onSelect;
  final VoidCallback onRecord;

  /// The record sheet is open: the + shows a cross.
  final bool recordOpen;

  const PhoneBottomBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onRecord,
    this.recordOpen = false,
  });

  /// The slots, left to right; null is the +.
  static const List<PhoneTab?> slots = [PhoneTab.home, PhoneTab.sales, null, PhoneTab.products, PhoneTab.more];

  static AppIcon _icon(PhoneTab tab) => switch (tab) {
        PhoneTab.home => AppIcons.home,
        PhoneTab.sales => AppIcons.sales,
        PhoneTab.products => AppIcons.products,
        PhoneTab.more => AppIcons.more,
      };

  static String _label(BuildContext context, PhoneTab tab) => switch (tab) {
        PhoneTab.home => context.l10n.shell_tabHome,
        PhoneTab.sales => context.l10n.nav_sales,
        PhoneTab.products => context.l10n.nav_products,
        PhoneTab.more => context.l10n.shell_tabMore,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = AppSafeArea.bottomOf(context);
    final still = MediaQuery.disableAnimationsOf(context);
    const corners = BorderRadius.vertical(top: Radius.circular(PhoneShellMetrics.barRadius));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corners,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: PhoneShellMetrics.barShadowAlpha),
            blurRadius: PhoneShellMetrics.barShadowBlur,
            offset: const Offset(0, PhoneShellMetrics.barShadowOffsetY),
          ),
        ],
      ),
      child: Material(
        color: colors.navBarFill,
        borderRadius: corners,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox(
            height: PhoneShellMetrics.barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / slots.length;
                return Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final tab in slots)
                          Expanded(
                            child: tab == null
                                ? _RecordButton(onTap: onRecord, open: recordOpen)
                                : _BarItem(
                                    icon: _icon(tab),
                                    label: _label(context, tab),
                                    selected: current == tab,
                                    onTap: () => onSelect(tab),
                                  ),
                          ),
                      ],
                    ),
                    AnimatedPositioned(
                      key: const ValueKey('phone-bar-active-line'),
                      duration: still ? Duration.zero : AppMotion.normal,
                      curve: Curves.easeOutCubic,
                      top: 0,
                      left: slot * (slots.indexOf(current) + 0.5) - PhoneShellMetrics.indicatorWidth / 2,
                      width: PhoneShellMetrics.indicatorWidth,
                      height: PhoneShellMetrics.indicatorHeight,
                      child: _ActiveLine(current: current, still: still),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected item's line: rounded at its lower corners, faded in again
/// each time it moves to another item.
class _ActiveLine extends StatelessWidget {
  final PhoneTab current;
  final bool still;

  const _ActiveLine({required this.current, required this.still});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(current),
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: still ? Duration.zero : AppMotion.normal,
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(PhoneShellMetrics.indicatorHeight)),
          ),
        ),
      );
}

class _BarItem extends StatelessWidget {
  final AppIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = selected ? colors.primary : colors.navBarInactive;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? icon.filled : icon.outlined, size: PhoneShellMetrics.barIcon, color: ink),
            const SizedBox(height: PhoneShellMetrics.barLabelGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: PhoneShellMetrics.barLabel,
                  color: ink,
                  fontWeight: selected ? AppFontWeight.semibold : AppFontWeight.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The central "+": a squircle in accent with a soft shadow; the plus turns
/// to a cross while the sheet is open (at once under reduced motion). The
/// whole slot is the tap target.
class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool open;

  const _RecordButton({required this.onTap, required this.open});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.shell_record,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(PhoneShellMetrics.recordRadius)),
              ),
              shadows: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: PhoneShellMetrics.recordShadowAlpha),
                  blurRadius: PhoneShellMetrics.recordShadowBlur,
                  offset: const Offset(0, PhoneShellMetrics.recordShadowOffsetY),
                ),
              ],
            ),
            child: Material(
              key: const ValueKey('phone-bar-record'),
              color: colors.accent,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(PhoneShellMetrics.recordRadius)),
              ),
              child: SizedBox(
                width: PhoneShellMetrics.recordSize,
                height: PhoneShellMetrics.recordSize,
                child: AnimatedRotation(
                  turns: open ? PhoneShellMetrics.recordOpenTurns : 0,
                  duration: still ? Duration.zero : AppMotion.normal,
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.add, size: PhoneShellMetrics.recordIcon, color: colors.onAccent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shell on a phone, today's layout everywhere else, from the one
/// signal (AppLayout.isPhone).
class PhoneOrWide extends StatelessWidget {
  final WidgetBuilder phone;
  final WidgetBuilder wide;

  const PhoneOrWide({super.key, required this.phone, required this.wide});

  @override
  Widget build(BuildContext context) => AppLayout.isPhone(context) ? phone(context) : wide(context);
}
