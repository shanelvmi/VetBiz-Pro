import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/constants/crops.dart';
import 'package:vetbiz_pro/l10n/crop_labels.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';

import 'stored_labels_check.dart';

/// Display lookups for the client crop list (spec section 6).
void main() {
  test('crops', () {
    checkStoredList(CropLabels.crop, [for (final g in kCropGroups.values) ...g], (l, v) => l.cropLabel(v));
  });

  test('crop picker headings', () {
    checkStoredList(CropLabels.cropGroup, kCropGroups.keys.toList(), (l, v) => l.cropGroupLabel(v));
  });
}
