// RV2 (docs/design/screen_reveal.md section 8.3): every pushed page gets the
// RV1 page transition, because every route is a MaterialPageRoute (or a named
// route) and AppPageTransitionsBuilder is set for every platform. This reads
// lib/ and fails on a route that would bring its own transition outside the
// one place kept on purpose.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kept, with the reason (each path once; the count is how many it holds).
const _kept = <String, (int, String)>{
  // Facility activation replaces the whole app with a fade (RV1 section 5).
  'lib/utils/facility_activation.dart': (2, 'activation replaces the app: its own fade'),
};

final _ownTransition = RegExp(r'\bPageRouteBuilder\b|\bCupertinoPageRoute\b|\btransitionsBuilder\s*:|\bPageRoute<\w*>\s*\{');

void main() {
  test('no route with its own transition in lib/ outside the kept place', () {
    final found = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final path = f.path.replaceAll(r'\', '/');
      if (path == 'lib/theme/app_page_transitions.dart') continue;
      final n = _ownTransition.allMatches(f.readAsStringSync()).length;
      if (n > 0) found[path] = n;
    }
    expect(found, {for (final e in _kept.entries) e.key: e.value.$1});
  });

  test('the theme gives every platform the app page transition', () {
    final theme = File('lib/theme/app_theme.dart').readAsStringSync();
    expect(theme, contains('AppPageTransitionsBuilder.theme'));
  });
}
