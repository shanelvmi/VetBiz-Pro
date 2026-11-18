import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

// The light ink on the brand areas (sidebar items and labels, the logo
// plate, the profile drawer buttons). In light it stays `background`, value
// for value as before; in dark `background` is the dark page colour, which
// would vanish on brandSurface, so it is onBrandSurface (white) there
// (dark_mode.md section 4, K2).
Color onBrandInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? context.colors.onBrandSurface : context.colors.background;

/// One row of the wide shell's sidebar (moved from dashboard_screen.dart in
/// LAY2). [selected] (owner, LAY2): a soft pill in sidebarPress, an existing
/// sidebar colour, and a heavier label; the caller passes the filled icon
/// then. The pill never carries the meaning alone: the icon, the weight and
/// Semantics' selected state say it too. Hover stays sidebarHover.
class DrawerHoverItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isCollapsed;
  final bool selected;

  const DrawerHoverItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isCollapsed = false,
    this.selected = false,
  });

  // The collapsed-label tooltip wait (300 ms), snapped to the nearest motion
  // step (parked_values.md C2). The Platform Admin item uses it too.
  static const Duration tooltipWait = AppMotion.slow;

  @override
  State<DrawerHoverItem> createState() => _DrawerHoverItemState();
}

class _DrawerHoverItemState extends State<DrawerHoverItem> {
  bool _hovered = false;
  // The hover fill's fade (was 200 ms), snapped to the nearest motion step
  // (parked_values.md C1).
  static const Duration _hoverFade = AppMotion.normal;

  @override
  Widget build(BuildContext context) {
    final weight = widget.selected ? AppFontWeight.semibold : AppFontWeight.medium;
    final row = LayoutBuilder(
      builder: (context, constraints) {
        // Ramps from fully transparent to fully opaque over the same
        // width range the sidebar itself passes through mid-animation -
        // constraints.maxWidth updates every frame as the parent
        // AnimatedContainer's width transitions, so this fade is
        // genuinely synchronized with that motion rather than the
        // label instantly popping in/out the moment isCollapsed flips,
        // which is what made the toggle feel abrupt.
        final labelOpacity = ((constraints.maxWidth - 100) / 60).clamp(0.0, 1.0);
        final canShowLabel = labelOpacity > 0.01;
        return Row(
          mainAxisAlignment: canShowLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: onBrandInk(context)),
            if (canShowLabel) ...[
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    widget.title,
                    style: TextStyle(color: onBrandInk(context), fontWeight: weight),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    final Color fill = widget.selected
        ? context.colors.sidebarPress
        : _hovered
            ? context.colors.sidebarHover
            : Colors.transparent;

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? AppSpacing.s4 : AppSpacing.s8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _hoverFade,
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: widget.isCollapsed ? AppSpacing.s12 : AppSpacing.s16),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: row,
          ),
        ),
      ),
    );

    // One node for a screen reader: the name, a button, selected or not
    // (the tooltip and the label would otherwise read it twice).
    Widget item = Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.title,
      onTap: widget.onTap,
      child: ExcludeSemantics(child: content),
    );

    // Tooltip only when collapsed - the label is already visible
    // otherwise, so a tooltip on top of visible text would be
    // redundant.
    if (!widget.isCollapsed) return item;
    return Tooltip(
      message: widget.title,
      waitDuration: DrawerHoverItem.tooltipWait,
      excludeFromSemantics: true,
      child: item,
    );
  }
}
