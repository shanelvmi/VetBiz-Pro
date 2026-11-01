import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';
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

  /// PH4: switches the shell around [context] to [tab] (Go to's Products).
  static void selectTab(BuildContext context, PhoneTab tab) =>
      context.findAncestorStateOfType<_PhoneShellState>()?._select(tab);
}

class _PhoneShellState extends State<PhoneShell> {
  PhoneTab _tab = PhoneTab.home;

  // A plain IndexedStack would build all four at once, and so start every
  // tab's listeners on sign-in: each is built on its first visit instead.
  final Set<PhoneTab> _visited = {PhoneTab.home};

  void _select(PhoneTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    widget.onTabChanged?.call(tab);
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
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in PhoneTab.values)
              KeyedSubtree(
                key: ValueKey(tab),
                child: TickerMode(
                  enabled: tab == _tab,
                  child: _visited.contains(tab) ? Builder(builder: _builder(tab)) : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
        bottomNavigationBar:
            keyboardOpen ? null : PhoneBottomBar(current: _tab, onSelect: _select, onRecord: widget.onRecord),
      ),
    );
  }
}

/// The bottom bar (phone_shell.md section 3): five equal slots (Home, Sales,
/// the raised "+", Products, More), 64 high plus the home indicator.
class PhoneBottomBar extends StatelessWidget {
  final PhoneTab current;
  final ValueChanged<PhoneTab> onSelect;
  final VoidCallback onRecord;

  const PhoneBottomBar({super.key, required this.current, required this.onSelect, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = AppSafeArea.bottomOf(context);
    Widget item(PhoneTab tab, IconData icon, IconData selectedIcon, String label) => Expanded(
          child: _BarItem(
            icon: current == tab ? selectedIcon : icon,
            label: label,
            selected: current == tab,
            onTap: () => onSelect(tab),
          ),
        );

    // The + rises [recordRaise] above the bar's top edge: the bar's own box
    // is that much taller, and only its lower part is filled.
    return SizedBox(
      height: PhoneShellMetrics.recordRaise + PhoneShellMetrics.barHeight + bottom,
      child: Stack(
        children: [
          Positioned.fill(
            top: PhoneShellMetrics.recordRaise,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.borderStrong, width: PhoneShellMetrics.barBorder)),
              ),
            ),
          ),
          Positioned.fill(
            bottom: bottom,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(PhoneTab.home, Icons.home_outlined, Icons.home, context.l10n.shell_tabHome),
                item(PhoneTab.sales, Icons.attach_money, Icons.attach_money, context.l10n.nav_sales),
                Expanded(child: _RecordButton(onTap: onRecord)),
                item(PhoneTab.products, Icons.inventory_2_outlined, Icons.inventory_2, context.l10n.nav_products),
                item(PhoneTab.more, Icons.grid_view_outlined, Icons.grid_view, context.l10n.shell_tabMore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = selected ? colors.primary : colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: PhoneShellMetrics.recordRaise),
      child: Semantics(
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
              Container(
                width: PhoneShellMetrics.pillWidth,
                height: PhoneShellMetrics.pillHeight,
                decoration: BoxDecoration(
                  color: selected ? colors.primary.withValues(alpha: PhoneShellMetrics.pillAlpha) : null,
                  borderRadius: BorderRadius.circular(PhoneShellMetrics.pillRadius),
                ),
                child: Icon(icon, size: PhoneShellMetrics.barIcon, color: ink),
              ),
              const SizedBox(height: PhoneShellMetrics.barLabelGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: PhoneShellMetrics.barLabel,
                  color: ink,
                  fontWeight: selected ? AppFontWeight.semibold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The central "+": the whole slot (the raised part included) is the target.
class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.shell_record,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: colors.accent,
            shape: const CircleBorder(),
            elevation: PhoneShellMetrics.recordElevation,
            child: SizedBox(
              width: PhoneShellMetrics.recordSize,
              height: PhoneShellMetrics.recordSize,
              child: Icon(Icons.add, size: PhoneShellMetrics.recordIcon, color: colors.onAccent),
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
