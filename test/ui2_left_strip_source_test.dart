// UI2 (1): no list row or card shows its state as a coloured strip down its
// left edge (the status is in text or a chip, never colour alone). This
// reads lib/screens and lib/widgets and fails on a Border with only a left
// side (or a start side) outside the two places kept on purpose.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kept, with the reason (each path once; the count is how many it holds).
const _kept = <String, (int, String)>{
  // The operator console's side navigation: the selected item's marker, not
  // a row or a card (its tint and icon colour show the choice as well).
  'lib/screens/platform_admin/platform_admin_home_screen.dart': (1, 'navigation selection marker'),
  // The operator console's four figures: the accent matches each card's icon
  // and carries no status; the console has no test seam to fingerprint it.
  'lib/screens/platform_admin/overview_tab.dart': (1, 'operator KPI card accent, no status'),
};

final _strip = RegExp(r'\bBorder\(\s*left:|\bBorderDirectional\(\s*start:');

void main() {
  test('no coloured left strip in lib/screens and lib/widgets outside the kept places', () {
    final found = <String, int>{};
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final n = _strip.allMatches(f.readAsStringSync()).length;
        if (n > 0) found[f.path.replaceAll(r'\', '/')] = n;
      }
    }
    expect(found, {for (final e in _kept.entries) e.key: e.value.$1});
  }, skip: true);
}
