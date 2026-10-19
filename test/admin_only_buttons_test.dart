// E4d-2, owner decision: assistants do not see Edit on services or
// transactions, nor Add Product (they still add batches to existing
// products). Each button below must sit under an `if (... isAdmin ...)`
// a few lines above it. The providers refuse the call too
// (test/providers/admin_only_edit_test.dart), and so do the rules.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// File -> the line that draws the button, and how many such buttons.
const _buttons = <(String, String, int)>[
  ('lib/screens/services/services_screen.dart', "PopupMenuItem(value: 'edit'", 1),
  ('lib/screens/services/services_screen.dart', 'label: Text(context.l10n.common_edit)', 1),
  ('lib/screens/transactions/transactions_screen.dart', "PopupMenuItem(value: 'edit'", 1),
  ('lib/screens/products/products_screen.dart', 'label: Text(context.l10n.products_addProduct)', 1),
  ('lib/screens/store/stockstore_screen.dart', 'label: Text(context.l10n.products_addProduct)', 1),
  ('lib/screens/dashboard/dashboard_screen.dart', 'title: context.l10n.products_addProduct', 1),
];

const _window = 12;
final _adminCondition = RegExp(r'^\s*if \(.*isAdmin');

void main() {
  for (final (file, button, count) in _buttons) {
    test('$file: "$button" is shown to admins only', () {
      final lines = File(file).readAsLinesSync();
      final at = [for (var i = 0; i < lines.length; i++) if (lines[i].contains(button)) i];
      expect(at, hasLength(count), reason: 'the button moved or was renamed: update this test');
      for (final i in at) {
        final above = lines.sublist(i < _window ? 0 : i - _window, i);
        expect(above.any(_adminCondition.hasMatch), isTrue,
            reason: '$file:${i + 1} is not under an isAdmin condition');
      }
    });
  }
}
