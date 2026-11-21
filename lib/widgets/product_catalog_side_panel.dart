import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../constants/product_categories.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import '../ui/polish/app_status.dart';

/// The light filter panel shared by Products and Stock Store.
/// Deliberately NOT a copy of the Dashboard's own sidebar: that one is
/// a solid dark teal navigation rail with the app's full menu; this
/// one is a light-background filter panel with no app-wide nav icons
/// or dark strip at all, purely local to whichever catalog screen is
/// showing it.
class ProductCatalogSidePanel extends StatefulWidget {
  final String selectedGroup;
  final String selectedCategory;
  final String selectedStatus;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;

  /// Every category actually in use right now (including any legacy
  /// value not in the canonical list), so a count is never computed
  /// for a category with nothing in it, and nothing is silently
  /// invisible under every group either.
  final Set<String> extraCategoriesInData;

  /// Counts to display next to each row - computed by the screen from
  /// its own base product list (already-loaded, filtered to "belongs
  /// on this screen" before status/category/search), not recomputed
  /// here, so this panel stays purely presentational.
  final int totalCount;
  final Map<String, int> categoryCounts;
  final Map<String, int> statusCounts; // 'Active' | 'Low Stock' | 'Depleted'

  final Color primaryColor;
  final Color accentColor;

  const ProductCatalogSidePanel({
    super.key,
    required this.selectedGroup,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.onGroupChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.extraCategoriesInData,
    required this.totalCount,
    required this.categoryCounts,
    required this.statusCounts,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<ProductCatalogSidePanel> createState() => _ProductCatalogSidePanelState();
}

class _ProductCatalogSidePanelState extends State<ProductCatalogSidePanel> {
  // Each group's own expanded/collapsed state - independent of each
  // other, so more than one can be open at once. Starts empty (all
  // collapsed) - expanding is now purely a click action, not a
  // default state.
  final Set<String> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    return _buildFilterPanel(context);
  }

  // ---------------- Light filter panel ----------------
  Widget _buildFilterPanel(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: 260,
      color: context.colors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UX2 (owner, 2026-11-21): no facility logo and name here: the
            // sidebar already shows the facility. The panel starts with the
            // categories (in the side panel and in the drawer below 900).

            // ---- Categories ----
            Text(context.l10n.products_categoriesHeading,
                style: TextStyle(
                    fontSize: AppFontSize.f11,
                    fontWeight: AppFontWeight.bold,
                    color: context.colors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.s8),
            _buildAllProductsRow(),
            const SizedBox(height: AppSpacing.s4),
            ...kProductCategoryGroups.keys.map((group) => _buildGroupSection(group)),

            const Divider(height: 28),

            // ---- Stock status ----
            Text(context.l10n.products_stockStatusHeading,
                style: TextStyle(
                    fontSize: AppFontSize.f11,
                    fontWeight: AppFontWeight.bold,
                    color: context.colors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.s8),
            // POL5: each dot is its stored value's state (stockAppStatus); In
            // stock is neutral, the normal case.
            _buildStatusRow('All', l10n.products_statusAll, null, widget.totalCount),
            _buildStatusRow(
                'Active', l10n.products_statusInStock, stockAppStatus('Active').roleIn(context.colors), widget.statusCounts['Active'] ?? 0),
            _buildStatusRow(
                'Low Stock', l10n.products_statusLowStock, stockAppStatus('Low Stock').roleIn(context.colors), widget.statusCounts['Low Stock'] ?? 0),
            _buildStatusRow('Reorder Soon', l10n.products_statusReorderSoon, stockAppStatus('Reorder Soon').roleIn(context.colors),
                widget.statusCounts['Reorder Soon'] ?? 0),
            _buildStatusRow(
                'Depleted', l10n.products_statusDepleted, stockAppStatus('Depleted').roleIn(context.colors), widget.statusCounts['Depleted'] ?? 0),
            _buildStatusRow(
                'Expired', l10n.products_statusExpired, stockAppStatus('Expired').roleIn(context.colors), widget.statusCounts['Expired'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProductsRow() {
    final isSelected = widget.selectedGroup == 'All';
    return _selectableRow(
      icon: Icons.grid_view_rounded,
      label: context.l10n.products_allProducts,
      count: widget.totalCount,
      isSelected: isSelected,
      onTap: () {
        widget.onGroupChanged('All');
        widget.onCategoryChanged('All');
      },
    );
  }

  Widget _buildGroupSection(String group) {
    final subcategories = kProductCategoryGroups[group] ?? [];
    final extrasInThisGroup = widget.extraCategoriesInData.where((c) => groupOfCategory(c) == group);
    final allSubcategories = {...subcategories, ...extrasInThisGroup}.toList();

    final groupCount = allSubcategories.fold<int>(0, (sum, c) => sum + (widget.categoryCounts[c] ?? 0));
    final isExpanded = _expandedGroups.contains(group);

    final icon = switch (group) {
      'Vet' => Icons.vaccines_outlined,
      'Agro' => Icons.eco_outlined,
      _ => Icons.category_outlined,
    };
    // The panel has the room for the Vet group's long name. The group's
    // name itself (what the filter compares) is unchanged.
    final label = group == 'Vet' ? context.l10n.productGroup_veterinary : context.l10n.productGroupLabel(group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectableRow(
          icon: icon,
          label: label,
          count: groupCount,
          // Not a filter target anymore - clicking this row only
          // expands/collapses its subcategories now, matching how the
          // department names worked before this redesign (clicking
          // Veterinary/Agro/Miscellaneous revealed its categories
          // rather than selecting the whole department as a filter).
          isSelected: false,
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: AppMotion.normal,
            curve: Curves.easeInOut,
            child: Icon(Icons.expand_more, size: AppIconSize.i18, color: context.colors.textMuted),
          ),
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedGroups.remove(group);
            } else {
              _expandedGroups.add(group);
            }
          }),
        ),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: allSubcategories.map((category) {
                      final isSelected = widget.selectedCategory == category;
                      return _selectableRow(
                        label: context.l10n.productCategoryLabel(category),
                        count: widget.categoryCounts[category] ?? 0,
                        isSelected: isSelected,
                        dense: true,
                        onTap: () {
                          widget.onGroupChanged(group);
                          widget.onCategoryChanged(category);
                        },
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String value, String label, Color? dotColor, int count) {
    final isSelected = widget.selectedStatus == value;
    return _selectableRow(
      leadingDot: dotColor,
      label: label,
      count: count,
      isSelected: isSelected,
      onTap: () => widget.onStatusChanged(value),
    );
  }

  // The one shared row style for every selectable item in this panel
  // (All Products, a group, a subcategory, a status) - keeps them all
  // visually consistent without four separate near-duplicate widgets.
  Widget _selectableRow({
    IconData? icon,
    Color? leadingDot,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
    bool dense = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: dense ? AppSpacing.s6 : AppSpacing.s8),
          decoration: BoxDecoration(
            color: isSelected ? widget.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.i16, color: isSelected ? context.colors.onPrimary : context.colors.textSoft),
                const SizedBox(width: AppSpacing.s8),
              ] else if (leadingDot != null) ...[
                Container(
                  width: AppSizes.statusDot,
                  height: AppSizes.statusDot,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: leadingDot),
                ),
                const SizedBox(width: AppSpacing.s10),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? AppFontSize.f12_5 : AppFontSize.f13_5,
                    color: isSelected ? context.colors.onPrimary : context.colors.textPrimary,
                    fontWeight: isSelected ? AppFontWeight.semibold : AppFontWeight.regular,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: AppFontSize.f12,
                  color: isSelected ? context.colors.onPrimary.withValues(alpha: AppAlpha.a85) : context.colors.textHint,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSpacing.s2), trailing],
            ],
          ),
        ),
      ),
    );
  }
}
