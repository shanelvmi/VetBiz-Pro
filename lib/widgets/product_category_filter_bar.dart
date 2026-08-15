import 'package:flutter/material.dart';

import '../constants/product_categories.dart';

/// Two-level category filter, shared by Products and Stock Store so
/// both screens can never drift into different behavior. A top row picks
/// the department (All / Vet / Agro / Miscellaneous), a second row
/// narrows to the specific categories within whichever department is
/// selected - keeps a long flat list of 16+ categories from turning into
/// a wall of chips, the same two-level pattern most established POS/
/// inventory SaaS products use once a category list grows past a
/// handful.
class ProductCategoryFilterBar extends StatelessWidget {
  final String selectedGroup;
  final String selectedCategory;
  final Set<String> extraCategoriesInData;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onCategoryChanged;
  final Color primaryColor;
  final Color accentColor;

  const ProductCategoryFilterBar({
    super.key,
    required this.selectedGroup,
    required this.selectedCategory,
    required this.extraCategoriesInData,
    required this.onGroupChanged,
    required this.onCategoryChanged,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final groupNames = ['All', ...kProductCategoryGroups.keys];

    List<String> categoryOptions;
    if (selectedGroup == 'All') {
      categoryOptions = {...kProductCategories, ...extraCategoriesInData}.toList()..sort();
    } else {
      final groupList = kProductCategoryGroups[selectedGroup] ?? [];
      final extrasInThisGroup = extraCategoriesInData.where((c) => groupOfCategory(c) == selectedGroup);
      categoryOptions = {...groupList, ...extrasInThisGroup}.toList();
    }

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: groupNames.map((group) {
            return ChoiceChip(
              label: Text(group),
              selected: selectedGroup == group,
              selectedColor: accentColor,
              onSelected: (_) => onGroupChanged(group),
            );
          }).toList(),
        ),
        // "All" at the top level already means "show everything, no
        // further narrowing" - a second row here would just be the same
        // wall of every category we grouped these to avoid in the first
        // place. Only show it once a specific department is picked.
        if (selectedGroup != 'All') ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: ['All', ...categoryOptions].map((category) {
              return ChoiceChip(
                label: Text(category, style: const TextStyle(fontSize: 12.5)),
                selected: selectedCategory == category,
                selectedColor: accentColor,
                onSelected: (_) => onCategoryChanged(category),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
