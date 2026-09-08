import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/facility_provider.dart';
import '../constants/product_categories.dart';

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
    final facilityName = selectedFacility != null ? (selectedFacility['name'] as String? ?? 'Facility') : 'Facility';
    final facilityType = selectedFacility != null ? (selectedFacility['type'] as String? ?? '') : '';
    final logoUrl = selectedFacility != null ? selectedFacility['logoUrl'] as String? : null;

    return Container(
      width: 260,
      color: const Color(0xFFFDFDF9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: (logoUrl != null && logoUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.storefront, color: widget.primaryColor, size: 18),
                          ),
                        )
                      : Icon(Icons.storefront, color: widget.primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facilityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (facilityType.isNotEmpty)
                        Text(
                          facilityType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _buildAllProductsRow(),
            const SizedBox(height: 4),
            ...kProductCategoryGroups.keys.map((group) => _buildGroupSection(group)),

            const Divider(height: 28),

            // ---- Stock status ----
            Text('STOCK STATUS',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _buildStatusRow('All', 'All Status', null, widget.totalCount),
            _buildStatusRow('Active', 'In Stock', Colors.green, widget.statusCounts['Active'] ?? 0),
            _buildStatusRow('Low Stock', 'Low Stock', Colors.orange, widget.statusCounts['Low Stock'] ?? 0),
            _buildStatusRow('Reorder Soon', 'Reorder Soon', Colors.amber[700], widget.statusCounts['Reorder Soon'] ?? 0),
            _buildStatusRow('Depleted', 'Depleted', Colors.red, widget.statusCounts['Depleted'] ?? 0),
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
      'Vet' => Icons.pets,
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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 20),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected ? widget.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
                const SizedBox(width: 8),
              ] else if (leadingDot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: leadingDot),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? 12.5 : 13.5,
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white.withValues(alpha: 0.85) : Colors.grey[500],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 2), trailing],
            ],
          ),
        ),
      ),
    );
  }
}
