/// The canonical list of product categories, shared between the Add/Edit
/// Product form (a flat dropdown - you pick one specific category
/// regardless of group) and the Products/Stock Store list screens
/// (grouped into a two-level filter: a top-level department, then the
/// specific categories within it) - defined once here so a category can
/// never be invisible as a filter just because no product happens to
/// use it yet, and so the flat list and the grouping can never drift
/// out of sync with each other.
const List<String> kProductCategories = [
  'Antibiotic',
  'Anthelmintics',
  'Vitamin & Supplements',
  'Hormones & Reproductive',
  'Vaccines',
  'Disinfectant',
  'Feeds',
  'Anti-inflammatory',
  'Ectoparasiticides',
  'Wound Management',
  'Surgical Supplies',
  'Farm Tools & Equipment',
  'Seeds',
  'Fertilizers',
  'Crop Pesticides',
  'Miscellaneous',
];

/// Top-level department groups for the two-level category filter.
/// "Miscellaneous" is its own group (not folded into Vet or Agro) since
/// items like farm tools and gumboots genuinely cut across both sides of
/// the business rather than belonging to either one specifically.
const Map<String, List<String>> kProductCategoryGroups = {
  'Vet': [
    'Antibiotic',
    'Anthelmintics',
    'Vitamin & Supplements',
    'Hormones & Reproductive',
    'Vaccines',
    'Disinfectant',
    'Feeds',
    'Anti-inflammatory',
    'Ectoparasiticides',
    'Wound Management',
    'Surgical Supplies',
  ],
  'Agro': [
    'Seeds',
    'Fertilizers',
    'Crop Pesticides',
  ],
  'Miscellaneous': [
    'Farm Tools & Equipment',
    'Miscellaneous',
  ],
};

/// Which group a category belongs to - any category not found in the
/// map above (e.g. a legacy value from before this grouping existed)
/// falls back to "Miscellaneous" rather than being invisible under any
/// group filter.
String groupOfCategory(String category) {
  for (final entry in kProductCategoryGroups.entries) {
    if (entry.value.contains(category)) return entry.key;
  }
  return 'Miscellaneous';
}
