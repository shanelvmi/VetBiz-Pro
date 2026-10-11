import 'app_localizations.dart';
import 'stored_labels.dart';

/// Labels for the crops saved on a crop-producer client (kCropGroups), and
/// for the picker's headings. See StoredLabelTable: only the display is
/// translated, and an unknown crop is shown as stored.
class CropLabels {
  CropLabels._();

  static final crop = StoredLabelTable({
    'Maize': (l) => l.crop_maize,
    'Rice': (l) => l.crop_rice,
    'Wheat': (l) => l.crop_wheat,
    'Cassava': (l) => l.crop_cassava,
    'Sorghum': (l) => l.crop_sorghum,
    'Millet': (l) => l.crop_millet,
    'Beans': (l) => l.crop_beans,
    'Bananas': (l) => l.crop_bananas,
    'Sweet Potatoes': (l) => l.crop_sweetPotatoes,
    'Irish Potatoes': (l) => l.crop_irishPotatoes,
    'Groundnuts': (l) => l.crop_groundnuts,
    'Coffee': (l) => l.crop_coffee,
    'Cotton': (l) => l.crop_cotton,
    'Tobacco': (l) => l.crop_tobacco,
    'Cashew Nuts': (l) => l.crop_cashewNuts,
    'Sisal': (l) => l.crop_sisal,
    'Tea': (l) => l.crop_tea,
    'Pyrethrum': (l) => l.crop_pyrethrum,
    'Sugarcane': (l) => l.crop_sugarcane,
    'Cloves': (l) => l.crop_cloves,
    'Sesame': (l) => l.crop_sesame,
    'Sunflower': (l) => l.crop_sunflower,
    'Tomatoes': (l) => l.crop_tomatoes,
    'Onions': (l) => l.crop_onions,
    'Cabbage': (l) => l.crop_cabbage,
    'Okra': (l) => l.crop_okra,
    'Mangoes': (l) => l.crop_mangoes,
    'Oranges': (l) => l.crop_oranges,
    'Avocado': (l) => l.crop_avocado,
    'Watermelon': (l) => l.crop_watermelon,
  });

  /// The picker's headings (kCropGroups keys); not stored.
  static final cropGroup = StoredLabelTable({
    'Food Crops': (l) => l.cropGroup_foodCrops,
    'Cash Crops': (l) => l.cropGroup_cashCrops,
    'Vegetables': (l) => l.cropGroup_vegetables,
    'Fruits': (l) => l.cropGroup_fruits,
  });
}

extension CropLabelsOf on AppLocalizations {
  String cropLabel(String stored) => CropLabels.crop.labelOf(this, stored);
  String cropGroupLabel(String stored) => CropLabels.cropGroup.labelOf(this, stored);
}
