import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/facility_provider.dart';
import '../constants/product_categories.dart';
import '../theme/app_dimens.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';

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
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final selectedFacility = facilityProvider.selectedFacility;
    final facilityName = selectedFacility != null ? (selectedFacility['name'] ?? 'Facility') : 'Facility';
    final facilityType = selectedFacility != null ? (selectedFacility['type'] ?? '') : '';
    final logoUrl = selectedFacility != null ? selectedFacility['logoUrl'] : null;

    return Container(
      width: 260,
      color: context.colors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Facility identity - left-aligned, not a
            // back-navigation control (the AppBar already provides
            // its own automatic back button, since this screen is
            // reached via a push). ----
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: AppAlpha.a10),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  child: (logoUrl != null && logoUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.r6),
                          child: Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.storefront, color: widget.primaryColor, size: AppIconSize.i18),
                          ),
                        )
                      : Icon(Icons.storefront, color: widget.primaryColor, size: AppIconSize.i18),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facilityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f15),
                      ),
                      if (facilityType.isNotEmpty)
                        Text(
                          facilityType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppFontSize.f12, color: context.colors.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // ---- Categories ----
            Text('CATEGORIES',
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
            Text('STOCK STATUS',
                style: TextStyle(
                    fontSize: AppFontSize.f11,
                    fontWeight: AppFontWeight.bold,
                    color: context.colors.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.s8),
            _buildStatusRow('All', 'All Status', null, widget.totalCount),
            _buildStatusRow('Active', 'In Stock', context.colors.success, widget.statusCounts['Active'] ?? 0),
            _buildStatusRow('Low Stock', 'Low Stock', context.colors.warning, widget.statusCounts['Low Stock'] ?? 0),
            _buildStatusRow(
                'Reorder Soon', 'Reorder Soon', context.colors.warning, widget.statusCounts['Reorder Soon'] ?? 0),
            _buildStatusRow('Depleted', 'Depleted', context.colors.danger, widget.statusCounts['Depleted'] ?? 0),
            _buildStatusRow('Expired', 'Expired', context.colors.danger, widget.statusCounts['Expired'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProductsRow() {
    final isSelected = widget.selectedGroup == 'All';
    return _selectableRow(
      icon: Icons.grid_view_rounded,
      label: 'All Products',
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
    final label = group == 'Vet' ? 'Veterinary' : group;

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
                        label: category,
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
                  width: 8,
                  height: 8,
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
                  // 0.85 has no AppAlpha step; kept exact (design-open-questions.md).
                  color: isSelected ? context.colors.onPrimary.withValues(alpha: 0.85) : context.colors.textHint,
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
