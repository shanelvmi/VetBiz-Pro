import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../l10n/l10n.dart';
import '../../navigation/app_destinations.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';
import 'sidebar_item.dart';

/// LAY2: the wide shell's sidebar, built from the destination registry
/// (lib/navigation/app_destinations.dart). One widget, two modes: expanded
/// (250 px, icon and label) on a computer, and the rail (72 px, icons only,
/// the label as a tooltip) on a tablet and when collapsed on a computer.
///
/// It holds no data of its own: the facility header (logo, name, tagline)
/// and the Platform Admin item come from the caller, which also decides what
/// a tap does. The selected place shows its filled icon and the pill; every
/// other place its outlined icon.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.collapsed,
    required this.destinations,
    required this.header,
    this.platformAdminItem,
  });

  /// The rail's width and the expanded width (as before LAY2).
  static const double railWidth = AppSizes.sidebarCollapsed;
  static const double expandedWidth = AppSizes.sidebarExpanded;

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;

  /// True for the rail: icons only.
  final bool collapsed;
  final List<AppDestination> destinations;

  /// The facility block above the places, told whether it is collapsed.
  final Widget Function(bool collapsed) header;

  /// Shown under Settings for platform admins only (the caller decides).
  final Widget? platformAdminItem;

  Widget _item(BuildContext context, AppDestination d) {
    final isSelected = d == selected;
    return DrawerHoverItem(
      key: ValueKey('sidebar-${d.name}'),
      icon: isSelected ? d.selectedIcon : d.icon,
      title: d.label(context.l10n),
      isCollapsed: collapsed,
      selected: isSelected,
      onTap: () => onSelect(d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider = Divider(thickness: 1.2, color: context.colors.onBrandSurface.withValues(alpha: AppAlpha.a50));
    final main = destinations.where((d) => d.section == DestinationSection.main);
    final bottom = destinations.where((d) => d.section == DestinationSection.bottom);

    final content = Column(
      children: [
        header(collapsed),
        divider,
        for (final d in main) _item(context, d),
        divider,
        for (final d in bottom) _item(context, d),
        if (platformAdminItem != null) platformAdminItem!,
      ],
    );

    final footer = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: collapsed
          ? const SizedBox.shrink()
          : Text(
              '@${AppInfo.name}',
              style: TextStyle(fontSize: AppFontSize.f12, color: onBrandInk(context)),
            ),
    );

    return AnimatedContainer(
      // Was 200ms/easeInOut - reported as too quick/abrupt for a panel
      // this size sliding this far (72 to 250). Slower, and
      // easeInOutCubic eases in and out more gradually at both ends than
      // easeInOut (which is close to linear through its middle), reading
      // as a deliberate glide rather than a snap.
      duration: AppMotion.slower,
      curve: Curves.easeInOutCubic,
      width: collapsed ? railWidth : expandedWidth,
      color: context.colors.brandSurface,
      child: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: content)),
          footer,
        ],
      ),
    );
  }
}
