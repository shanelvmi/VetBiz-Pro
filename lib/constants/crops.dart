/// `crops` on a crop-producer client, grouped for the client form's picker.
/// Each crop is saved as this English text, so the values and their order
/// never change; the group names are headings only. What is shown is their
/// label (lib/l10n/crop_labels.dart). Moved here from add_client_screen.dart
/// unchanged.
const Map<String, List<String>> kCropGroups = {
  'Food Crops': [
    'Maize', 'Rice', 'Wheat', 'Cassava', 'Sorghum', 'Millet', 'Beans',
    'Bananas', 'Sweet Potatoes', 'Irish Potatoes', 'Groundnuts',
  ],
  'Cash Crops': [
    'Coffee', 'Cotton', 'Tobacco', 'Cashew Nuts', 'Sisal', 'Tea',
    'Pyrethrum', 'Sugarcane', 'Cloves', 'Sesame', 'Sunflower',
  ],
  'Vegetables': ['Tomatoes', 'Onions', 'Cabbage', 'Okra'],
  'Fruits': ['Mangoes', 'Oranges', 'Avocado', 'Watermelon'],
};
